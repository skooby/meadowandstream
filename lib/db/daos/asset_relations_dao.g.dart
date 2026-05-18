// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_relations_dao.dart';

// ignore_for_file: type=lint
mixin _$AssetRelationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AssetRelationsTable get assetRelations => attachedDatabase.assetRelations;
  AssetRelationsDaoManager get managers => AssetRelationsDaoManager(this);
}

class AssetRelationsDaoManager {
  final _$AssetRelationsDaoMixin _db;
  AssetRelationsDaoManager(this._db);
  $$AssetRelationsTableTableManager get assetRelations =>
      $$AssetRelationsTableTableManager(
          _db.attachedDatabase, _db.assetRelations);
}
