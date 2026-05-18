// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_dao.dart';

// ignore_for_file: type=lint
mixin _$FavoritesDaoMixin on DatabaseAccessor<AppDatabase> {
  $FavoritesCollectionsTable get favoritesCollections =>
      attachedDatabase.favoritesCollections;
  $FavoritesItemsTable get favoritesItems => attachedDatabase.favoritesItems;
  $AssetsTable get assets => attachedDatabase.assets;
  FavoritesDaoManager get managers => FavoritesDaoManager(this);
}

class FavoritesDaoManager {
  final _$FavoritesDaoMixin _db;
  FavoritesDaoManager(this._db);
  $$FavoritesCollectionsTableTableManager get favoritesCollections =>
      $$FavoritesCollectionsTableTableManager(
          _db.attachedDatabase, _db.favoritesCollections);
  $$FavoritesItemsTableTableManager get favoritesItems =>
      $$FavoritesItemsTableTableManager(
          _db.attachedDatabase, _db.favoritesItems);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db.attachedDatabase, _db.assets);
}
