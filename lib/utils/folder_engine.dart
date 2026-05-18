import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' as drift;
import '../db/app_database.dart';

class FolderEngine {
  /// Resolves the parent ID dynamically based on the target table.
  static Future<int?> _resolveParent(String? parentName, String table, AppDatabase db) async {
      if (parentName == null) return null;
      if (table == 'assets') {
          final res = await (db.select(db.assets)..where((t) => t.name.equals(parentName) & t.type.equals('FOLDER'))).getSingleOrNull();
          if (res == null) throw Exception('Parent folder "$parentName" missing in Assets.');
          return res.id;
      } else if (table == 'strings') {
          final res = await (db.select(db.strings)..where((t) => t.key.equals(parentName) & t.type.equals('FOLDER'))).getSingleOrNull();
          if (res == null) throw Exception('Parent folder "$parentName" missing in Strings.');
          return res.id;
      } else {
          throw Exception('Unknown hierarchical engine "$table".');
      }
  }

  /// Creates a folder in the target table elegantly.
  static Future<bool> createFolder({
      required String name, 
      required String? parentName, 
      required String table, 
      required AppDatabase db, 
      required SupabaseClient supabase
  }) async {
      final t = table.trim().toLowerCase();
      final parentId = await _resolveParent(parentName, t, db);
      final slug = name.trim();
      
      if (t == 'assets') {
          final existing = await (db.select(db.assets)..where((t) => t.name.equals(slug) & t.type.equals('FOLDER'))).getSingleOrNull();
          if (existing != null) return false;
          
          final resp = await supabase.from('assets').insert({
              'tenant_id': 1, 'name': slug, 'type': 'FOLDER', 'parent_id': parentId,
              'created_at': DateTime.now().millisecondsSinceEpoch, 'updated_at': DateTime.now().millisecondsSinceEpoch
          }).select().single();
          
          await db.into(db.assets).insert(AssetsCompanion(
             id: drift.Value(resp['id'] as int), tenantId: const drift.Value(1),
             name: drift.Value(slug), type: const drift.Value('FOLDER'), parentId: drift.Value(parentId),
             createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch), updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch)
          ));
          return true;
      } 
      else if (t == 'strings') {
          final existing = await (db.select(db.strings)..where((t) => t.key.equals(slug) & t.type.equals('FOLDER'))).getSingleOrNull();
          if (existing != null) return false;
          
          final resp = await supabase.from('strings').insert({
              'tenant_id': 1, 'key': slug, 'type': 'FOLDER', 'parent_id': parentId,
          }).select().single();
          
          await db.into(db.strings).insert(StringsCompanion(
             id: drift.Value(resp['id'] as int), tenantId: const drift.Value(1),
             key: drift.Value(slug), type: const drift.Value('FOLDER'), parentId: drift.Value(parentId),
          ));
          return true;
      } else {
          throw Exception('Table $t not supported by folder engine');
      }
  }
}
