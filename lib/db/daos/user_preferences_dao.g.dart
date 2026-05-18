// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences_dao.dart';

// ignore_for_file: type=lint
mixin _$UserPreferencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserPreferencesTable get userPreferences => attachedDatabase.userPreferences;
  UserPreferencesDaoManager get managers => UserPreferencesDaoManager(this);
}

class UserPreferencesDaoManager {
  final _$UserPreferencesDaoMixin _db;
  UserPreferencesDaoManager(this._db);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(
          _db.attachedDatabase, _db.userPreferences);
}
