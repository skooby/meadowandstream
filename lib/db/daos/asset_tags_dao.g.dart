// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_tags_dao.dart';

// ignore_for_file: type=lint
mixin _$AssetTagsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AssetTagsTable get assetTags => attachedDatabase.assetTags;
  $AssetsTable get assets => attachedDatabase.assets;
  $StringsTable get strings => attachedDatabase.strings;
  AssetTagsDaoManager get managers => AssetTagsDaoManager(this);
}

class AssetTagsDaoManager {
  final _$AssetTagsDaoMixin _db;
  AssetTagsDaoManager(this._db);
  $$AssetTagsTableTableManager get assetTags =>
      $$AssetTagsTableTableManager(_db.attachedDatabase, _db.assetTags);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db.attachedDatabase, _db.assets);
  $$StringsTableTableManager get strings =>
      $$StringsTableTableManager(_db.attachedDatabase, _db.strings);
}
