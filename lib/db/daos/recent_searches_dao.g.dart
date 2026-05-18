// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_searches_dao.dart';

// ignore_for_file: type=lint
mixin _$RecentSearchesDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecentSearchesTable get recentSearches => attachedDatabase.recentSearches;
  RecentSearchesDaoManager get managers => RecentSearchesDaoManager(this);
}

class RecentSearchesDaoManager {
  final _$RecentSearchesDaoMixin _db;
  RecentSearchesDaoManager(this._db);
  $$RecentSearchesTableTableManager get recentSearches =>
      $$RecentSearchesTableTableManager(
          _db.attachedDatabase, _db.recentSearches);
}
