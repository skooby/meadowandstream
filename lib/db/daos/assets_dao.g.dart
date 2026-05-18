// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assets_dao.dart';

// ignore_for_file: type=lint
mixin _$AssetsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AssetsTable get assets => attachedDatabase.assets;
  AssetsDaoManager get managers => AssetsDaoManager(this);
}

class AssetsDaoManager {
  final _$AssetsDaoMixin _db;
  AssetsDaoManager(this._db);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db.attachedDatabase, _db.assets);
}
