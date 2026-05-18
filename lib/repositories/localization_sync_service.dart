import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/app_database.dart';
import '../db/daos/i18n_dao.dart';
import '../scripts/tenant_service.dart';

class LocalizationSyncService {
  final SupabaseClient _supabase;
  final I18nDao _i18nDao;

  LocalizationSyncService(this._supabase, AppDatabase db) : _i18nDao = db.i18nDao;

  Future<void> sync() async {
    try {
      final tid = TenantService.currentTenantId ?? 0;
      
      // 1. SYNC LANGUAGES (Small table, bulk bypass works perfectly)
      final langResponse = await _supabase.from('languages').select();
      final List<Map<String, dynamic>> langRecords = List.from(langResponse);
      
      if (langRecords.isNotEmpty) {
         final parsedLangs = langRecords.map<SystemLanguage>((r) {
            return SystemLanguage(
               id: r['id'] as int,
               code: r['code'] as String,
               nameStringId: r['name_string_id'] as int?
            );
         }).toList();
         await _i18nDao.upsertLanguages(parsedLangs);
      }



      // 2. SYNC STRINGS (Based on updated_at delta logic explicitly linked by Tenant struct)
      final lastStringUpdate = await _i18nDao.maxStringsUpdatedAt() ?? 0;
      final stringResponse = await _supabase.from('strings')
          .select()
          .eq('tenant_id', tid)
          .gt('updated_at', DateTime.fromMillisecondsSinceEpoch(lastStringUpdate, isUtc: true).toIso8601String())
          .order('updated_at', ascending: true)
          .limit(500);
          
      final List<Map<String, dynamic>> stringRecords = List.from(stringResponse);
      if (stringRecords.isNotEmpty) {
         final parsedStrings = stringRecords.map<SystemString>((r) {
            return SystemString(
               id: r['id'] as int,
               tenantId: r['tenant_id'] as int,
               key: r['key'] as String,
               description: r['description'] as String?,
               parentId: r['parent_id'] as int?,
               type: (r['type'] as String?) ?? 'STRING',
               sortOrder: (r['sort_order'] as int?) ?? 0,
               createdAt: r['created_at'] != null ? DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch : null,
               updatedAt: r['updated_at'] != null ? DateTime.parse(r['updated_at'] as String).millisecondsSinceEpoch : null,
            );
         }).toList();
         await _i18nDao.upsertStrings(parsedStrings);
      }
      
      // 3. SYNC TRANSLATIONS (Based on updated_at delta logic referencing strings inside tenants natively)
      final lastTransUpdate = await _i18nDao.maxTranslationsUpdatedAt() ?? 0;
      final transResponse = await _supabase.from('translations')
          .select()
          .eq('tenant_id', tid)
          .gt('updated_at', DateTime.fromMillisecondsSinceEpoch(lastTransUpdate, isUtc: true).toIso8601String())
          .order('updated_at', ascending: true)
          .limit(1000);
          
      final List<Map<String, dynamic>> transRecords = List.from(transResponse);
      if (transRecords.isNotEmpty) {
         final parsedTrans = transRecords.map<SystemTranslation>((r) {
            return SystemTranslation(
               id: r['id'] as int,
               tenantId: r['tenant_id'] as int,
               stringId: r['string_id'] as int,
               langId: r['lang_id'] as int,
               value: r['value'] as String,
               createdAt: r['created_at'] != null ? DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch : null,
               updatedAt: r['updated_at'] != null ? DateTime.parse(r['updated_at'] as String).millisecondsSinceEpoch : null,
            );
         }).toList();
         await _i18nDao.upsertTranslations(parsedTrans);
      }
      
    } catch (e) {
      print('Localization Sync Framework Error: $e');
    }
  }
}
