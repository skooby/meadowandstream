// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$AudioCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioCacheTable get audioCache => attachedDatabase.audioCache;
  AudioCacheDaoManager get managers => AudioCacheDaoManager(this);
}

class AudioCacheDaoManager {
  final _$AudioCacheDaoMixin _db;
  AudioCacheDaoManager(this._db);
  $$AudioCacheTableTableManager get audioCache =>
      $$AudioCacheTableTableManager(_db.attachedDatabase, _db.audioCache);
}
