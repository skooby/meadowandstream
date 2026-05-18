// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cheers_dao.dart';

// ignore_for_file: type=lint
mixin _$CheersDaoMixin on DatabaseAccessor<AppDatabase> {
  $CheersTable get cheers => attachedDatabase.cheers;
  CheersDaoManager get managers => CheersDaoManager(this);
}

class CheersDaoManager {
  final _$CheersDaoMixin _db;
  CheersDaoManager(this._db);
  $$CheersTableTableManager get cheers =>
      $$CheersTableTableManager(_db.attachedDatabase, _db.cheers);
}
