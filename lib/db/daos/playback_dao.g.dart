// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaybackDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlaybackSessionTable get playbackSession => attachedDatabase.playbackSession;
  $PlaybackQueueItemsTable get playbackQueueItems =>
      attachedDatabase.playbackQueueItems;
  PlaybackDaoManager get managers => PlaybackDaoManager(this);
}

class PlaybackDaoManager {
  final _$PlaybackDaoMixin _db;
  PlaybackDaoManager(this._db);
  $$PlaybackSessionTableTableManager get playbackSession =>
      $$PlaybackSessionTableTableManager(
          _db.attachedDatabase, _db.playbackSession);
  $$PlaybackQueueItemsTableTableManager get playbackQueueItems =>
      $$PlaybackQueueItemsTableTableManager(
          _db.attachedDatabase, _db.playbackQueueItems);
}
