// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_items_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaylistItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlaylistsTable get playlists => attachedDatabase.playlists;
  $PlaylistItemsTable get playlistItems => attachedDatabase.playlistItems;
  PlaylistItemsDaoManager get managers => PlaylistItemsDaoManager(this);
}

class PlaylistItemsDaoManager {
  final _$PlaylistItemsDaoMixin _db;
  PlaylistItemsDaoManager(this._db);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db.attachedDatabase, _db.playlists);
  $$PlaylistItemsTableTableManager get playlistItems =>
      $$PlaylistItemsTableTableManager(_db.attachedDatabase, _db.playlistItems);
}
