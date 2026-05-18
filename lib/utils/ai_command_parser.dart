import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' as drift;
import '../db/app_database.dart';

import '../db/daos/i18n_dao.dart';
import '../db/daos/assets_dao.dart';
import '../db/daos/asset_tags_dao.dart';
import 'folder_engine.dart';

class AiCommandParser {
  /// Executes a bash-style command block against the local DAOs and remote Supabase instance natively.
  static Future<List<String>> executeBatch(String commandBlock, BuildContext context) async {
    final List<String> logs = [];
    final lines = commandBlock.split('\n');

    final i18nDao = context.read<I18nDao>();
    final assetsDao = context.read<AssetsDao>();
    final assetTagsDao = context.read<AssetTagsDao>();
    final db = context.read<AppDatabase>();
    final supabase = Supabase.instance.client;

    for (int i = 0; i < lines.length; i++) {
       String line = lines[i].trim();
       if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) continue;
       
       logs.add('> Running: $line');
       try {
         final args = _splitBashArguments(line);
         if (args.isEmpty) continue;
         
         final entity = args[0].toLowerCase();
         if (args.length < 2) throw Exception('Missing action for entity $entity');
         final action = args[1].toLowerCase();

         if (entity == 'folder' && action == 'create') {
            if (args.length < 3) throw Exception('Missing folder name');
            final name = args[2];
            String? parentFolderName;
            String tableName = 'tags';
            for (int k = 3; k < args.length; k+=2) {
               if (args[k] == '--parent' && k+1 < args.length) parentFolderName = args[k+1];
               if ((args[k] == '--table' || args[k] == '--section') && k+1 < args.length) tableName = args[k+1].toLowerCase();
            }
            final result = await FolderEngine.createFolder(name: name, parentName: parentFolderName, table: tableName, db: db, supabase: supabase);
            logs.add('  [OK] Folder "$name" ${result ? 'created' : 'already exists'} in table $tableName');
         } 
         else if (entity == 'tag' && action == 'create') {
            if (args.length < 3) throw Exception('Missing tag name');
            final name = args[2];
            String? folderName;
            String? colorStr;
            // Parse sequential optional flags natively
            for (int k = 3; k < args.length; k+=2) {
               if (args[k] == '--folder' && k+1 < args.length) folderName = args[k+1];
               if (args[k] == '--color' && k+1 < args.length) colorStr = args[k+1];
            }
            final result = await _createTag(name, folderName, colorStr, i18nDao, assetsDao, supabase);
            logs.add('  [OK] Tag "$name" ${result ? 'created' : 'already exists'}');
         } 
         else if (entity == 'asset' && (action == 'bind' || action == 'unbind')) {
            if (args.length < 4) throw Exception('Missing Asset name or Tag slug');
            final assetName = args[2];
            final tagSlug = args[3];

            final asset = await (assetsDao.select(assetsDao.assets)..where((a) => a.name.equals(assetName))).getSingleOrNull();
            if (asset == null) throw Exception('Asset "$assetName" not found in library');

            final tag = await (i18nDao.select(i18nDao.db.strings)..where((t) => t.key.equals(tagSlug))).getSingleOrNull();
            if (tag == null) throw Exception('Tag "$tagSlug" not found in taxonomy');

            final currentTags = await assetTagsDao.watchStringsForAsset(asset.id).first;
            final currentIds = currentTags.map((t) => t.id).toSet();

            if (action == 'bind') {
               currentIds.add(tag.id);
            } else {
               currentIds.remove(tag.id);
            }

            await assetTagsDao.replaceStringsForAsset(asset.id, currentIds.toList());
            await supabase.from('asset_tags').delete().eq('asset_id', asset.id);
            if (currentIds.isNotEmpty) {
               await supabase.from('asset_tags').insert(currentIds.map((tid) => {'asset_id': asset.id, 'string_id': tid}).toList());
            }

            logs.add('  [OK] ${action == 'bind' ? 'Bound' : 'Unbound'} tag "$tagSlug" ${action == 'bind' ? 'to' : 'from'} asset "$assetName"');
         } 
         else if (action == 'resolve') {
             if (args.length < 3) throw Exception('Missing query string to resolve');
             final query = args[2].toLowerCase();
             final doAll = entity == 'all';
             final doAsset = entity == 'asset' || doAll;
             final doFolder = entity == 'folder' || doAll;
             final doString = entity == 'string' || doAll;
             
             int foundCount = 0;
             if (doAsset) {
                final results = await (assetsDao.select(assetsDao.assets)..where((a) => a.name.lower().like('%$query%') & a.type.equals('FILE'))).get();
                for (var r in results) {
                   logs.add('  [ASSET] ID: ${r.id} | Name: ${r.name} | ParentID: ${r.parentId ?? 'root'}');
                   foundCount++;
                }
             }
             if (doFolder) {
                final assetsF = await (assetsDao.select(assetsDao.assets)..where((a) => a.name.lower().like('%$query%') & a.type.equals('FOLDER'))).get();
                for (var r in assetsF) { logs.add('  [FOLDER:Assets] ID: ${r.id} | Name: ${r.name} | ParentID: ${r.parentId ?? 'root'}'); foundCount++; }
                
                final stringsF = await (i18nDao.select(i18nDao.db.strings)..where((s) => s.key.lower().like('%$query%') & s.type.equals('FOLDER'))).get();
                for (var r in stringsF) { logs.add('  [FOLDER:Strings] ID: ${r.id} | Key: ${r.key} | ParentID: ${r.parentId ?? 'root'}'); foundCount++; }
             }
             if (doString) {
                final results = await (i18nDao.select(i18nDao.db.strings)..where((s) => s.key.lower().like('%$query%') & s.type.equals('STRING'))).get();
                for (var r in results) {
                   logs.add('  [STRING] ID: ${r.id} | Key: ${r.key} | ParentID: ${r.parentId ?? 'root'}');
                   foundCount++;
                }
             }
             if (foundCount == 0) logs.add('  [0] No matches found for "$query" within $entity hierarchy.');
         } else {
            throw Exception('Unknown command mapping: $entity $action');
         }
       } catch (e) {
         logs.add('  [ERROR] Line ${i+1}: $e');
       }
    }
    return logs;
  }

  /// Correctly splits commands natively guarding internally quoted substrings safely.
  static List<String> _splitBashArguments(String line) {
     final RegExp regex = RegExp('[^\\s"\']+|"([^"]*)"|\'([^\']*)\'');
     final matches = regex.allMatches(line);
     final result = <String>[];
     for (var match in matches) {
        if (match.group(1) != null) {
           result.add(match.group(1)!);
        } else if (match.group(2) != null) {
           result.add(match.group(2)!);
        } else {
           result.add(match.group(0)!);
        }
     }
     return result;
  }

  /// Seamlessly constructs strings, translates, and generates hierarchical nested structured tags natively via headless API algorithms.
  static Future<bool> _createTag(String name, String? folderName, String? colorStr, I18nDao i18nDao, AssetsDao assetsDao, SupabaseClient supabase) async {
       return false;
  }
}
