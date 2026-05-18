import 'package:drift/drift.dart';

@DataClassName('AudioCacheEntry')
class AudioCache extends Table {
  TextColumn get itemId => text()();
  IntColumn get status =>
      integer()(); // 0=none, 1=queued, 2=downloading, 3=cached, 4=failed
  TextColumn get localPath => text().nullable()();
  IntColumn get fileBytes => integer().nullable()();
  IntColumn get lastAccessedAt => integer().withDefault(const Constant(0))();
  IntColumn get lastPlayedAt => integer().withDefault(const Constant(0))();
  RealColumn get cacheScore => real().withDefault(const Constant(0.0))();
  TextColumn get error => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {itemId};
}
