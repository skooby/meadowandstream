// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'i18n_dao.dart';

// ignore_for_file: type=lint
mixin _$I18nDaoMixin on DatabaseAccessor<AppDatabase> {
  $StringsTable get strings => attachedDatabase.strings;
  $LanguagesTable get languages => attachedDatabase.languages;
  $TranslationsTable get translations => attachedDatabase.translations;
  I18nDaoManager get managers => I18nDaoManager(this);
}

class I18nDaoManager {
  final _$I18nDaoMixin _db;
  I18nDaoManager(this._db);
  $$StringsTableTableManager get strings =>
      $$StringsTableTableManager(_db.attachedDatabase, _db.strings);
  $$LanguagesTableTableManager get languages =>
      $$LanguagesTableTableManager(_db.attachedDatabase, _db.languages);
  $$TranslationsTableTableManager get translations =>
      $$TranslationsTableTableManager(_db.attachedDatabase, _db.translations);
}
