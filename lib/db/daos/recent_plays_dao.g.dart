// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_plays_dao.dart';

// ignore_for_file: type=lint
mixin _$RecentPlaysDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecentPlaysTable get recentPlays => attachedDatabase.recentPlays;
  RecentPlaysDaoManager get managers => RecentPlaysDaoManager(this);
}

class RecentPlaysDaoManager {
  final _$RecentPlaysDaoMixin _db;
  RecentPlaysDaoManager(this._db);
  $$RecentPlaysTableTableManager get recentPlays =>
      $$RecentPlaysTableTableManager(_db.attachedDatabase, _db.recentPlays);
}
