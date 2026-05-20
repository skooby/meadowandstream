import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' as drift;
import '../db/app_database.dart';
import '../scripts/tenant_service.dart';

class FolderEngine {
  /// Resolves the parent ID dynamically based on the target table.
  static Future<int?> _resolveParent(String? parentName, String table, AppDatabase db) async {
      if (parentName == null) return null;
      final t = table.trim().toLowerCase();
      if (t == 'assets') {
          final res = await (db.select(db.assets)..where((x) => x.name.equals(parentName) & x.type.equals('FOLDER'))).getSingleOrNull();
          if (res == null) throw Exception('Parent folder "$parentName" missing in Assets.');
          return res.id;
      } else if (t == 'strings' || t == 'tags') {
          final res = await (db.select(db.strings)..where((x) => x.key.equals(parentName) & x.type.equals('FOLDER'))).getSingleOrNull();
          if (res == null) throw Exception('Parent folder "$parentName" missing in Strings/Tags.');
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
      final tid = TenantService.currentTenantId ?? 1;
      
      if (t == 'assets') {
          final existing = await (db.select(db.assets)..where((x) => x.name.equals(slug) & x.type.equals('FOLDER'))).getSingleOrNull();
          if (existing != null) return false;
          
          int newId = 0;
          try {
              final resp = await supabase.from('assets').insert({
                  'tenant_id': tid, 'name': slug, 'type': 'FOLDER', 'parent_id': parentId,
                  'created_at': DateTime.now().millisecondsSinceEpoch, 'updated_at': DateTime.now().millisecondsSinceEpoch
              }).select().single();
              newId = resp['id'] as int;
          } catch (_) {}
          
          if (newId != 0) {
              await db.into(db.assets).insert(AssetsCompanion(
                 id: drift.Value(newId), tenantId: drift.Value(tid),
                 name: drift.Value(slug), type: const drift.Value('FOLDER'), parentId: drift.Value(parentId),
                 createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch), updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch)
              ));
          } else {
              await db.into(db.assets).insert(AssetsCompanion(
                 tenantId: drift.Value(tid),
                 name: drift.Value(slug), type: const drift.Value('FOLDER'), parentId: drift.Value(parentId),
                 createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch), updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch)
              ));
          }
          return true;
      } 
      else if (t == 'strings' || t == 'tags') {
          final existing = await (db.select(db.strings)..where((x) => x.key.equals(slug) & x.type.equals('FOLDER'))).getSingleOrNull();
          if (existing != null) return false;
          
          int newId = 0;
          try {
              final resp = await supabase.from('strings').insert({
                  'tenant_id': tid, 'key': slug, 'type': 'FOLDER', 'parent_id': parentId,
              }).select().single();
              newId = resp['id'] as int;
          } catch (_) {}
          
          if (newId != 0) {
              await db.into(db.strings).insert(StringsCompanion(
                 id: drift.Value(newId), tenantId: drift.Value(tid),
                 key: drift.Value(slug), type: const drift.Value('FOLDER'), parentId: drift.Value(parentId),
              ));
          } else {
              await db.into(db.strings).insert(StringsCompanion(
                 tenantId: drift.Value(tid),
                 key: drift.Value(slug), type: const drift.Value('FOLDER'), parentId: drift.Value(parentId),
              ));
          }
          return true;
      } else {
          throw Exception('Table $t not supported by folder engine');
      }
  }
}
