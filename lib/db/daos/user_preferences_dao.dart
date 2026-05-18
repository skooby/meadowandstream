import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/user_preferences_table.dart';

part 'user_preferences_dao.g.dart';

@DriftAccessor(tables: [UserPreferences])
class UserPreferencesDao extends DatabaseAccessor<AppDatabase> with _$UserPreferencesDaoMixin {
  UserPreferencesDao(super.db);
  
  Future<String?> getPreference(int tenantId, String key) async {
    final record = await (select(userPreferences)..where((u) => u.tenantId.equals(tenantId) & u.preferenceKey.equals(key))).getSingleOrNull();
    return record?.preferenceValue;
  }

  Stream<String?> watchPreference(int tenantId, String key) {
    return (select(userPreferences)..where((u) => u.tenantId.equals(tenantId) & u.preferenceKey.equals(key))).watchSingleOrNull().map((r) => r?.preferenceValue);
  }
  
  Future<void> setPreference(int tenantId, String key, String value) async {
     await into(userPreferences).insert(
        UserPreferencesCompanion(
            tenantId: Value(tenantId),
            preferenceKey: Value(key),
            preferenceValue: Value(value)
        ),
        mode: InsertMode.insertOrReplace
     );
  }
}
