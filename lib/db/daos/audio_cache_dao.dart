import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/audio_cache_table.dart';

part 'audio_cache_dao.g.dart';

@DriftAccessor(tables: [AudioCache])
class AudioCacheDao extends DatabaseAccessor<AppDatabase>
    with _$AudioCacheDaoMixin {
  AudioCacheDao(super.db);

  Stream<AudioCacheEntry?> watchEntry(String itemId) {
    return (select(audioCache)..where((t) => t.itemId.equals(itemId)))
        .watchSingleOrNull();
  }

  Future<AudioCacheEntry?> getEntry(String itemId) {
    return (select(audioCache)..where((t) => t.itemId.equals(itemId)))
        .getSingleOrNull();
  }

  Future<void> upsertEntry(AudioCacheCompanion entry) {
    return into(audioCache).insertOnConflictUpdate(entry);
  }

  Future<void> markAccessed(String itemId, int atMs) async {
    final existing = await getEntry(itemId);
    if (existing != null) {
      await update(audioCache).replace(existing.copyWith(
        lastAccessedAt: atMs,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      await into(audioCache).insert(AudioCacheCompanion.insert(
        itemId: itemId,
        status: 0,
        lastAccessedAt: Value(atMs),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  Future<void> updateScore(String itemId, double score) async {
    final existing = await getEntry(itemId);
    if (existing != null) {
      await update(audioCache).replace(existing.copyWith(cacheScore: score));
    }
  }

  Future<List<AudioCacheEntry>> listCachedOrderedByScoreAsc() {
    return (select(audioCache)
          ..where((t) => t.status.equals(3)) // 3 = cached
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastPlayedAt, mode: OrderingMode.asc),
            (t) =>
                OrderingTerm(expression: t.cacheScore, mode: OrderingMode.asc)
          ]))
        .get();
  }

  Future<List<AudioCacheEntry>> listTargetsNotCached(int limit) {
    return (select(audioCache)
          ..where((t) =>
              t.status.isNotIn([2, 3])) // not downloading (2) or cached (3)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.cacheScore, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }

  Future<int> totalCachedBytes() async {
    final result = await (select(audioCache)
          ..where((t) => t.status.equals(3) & t.fileBytes.isNotNull()))
        .get();

    return result.fold<int>(0, (sum, item) => sum + (item.fileBytes ?? 0));
  }

  Future<void> remove(String itemId) {
    return (delete(audioCache)..where((t) => t.itemId.equals(itemId))).go();
  }

  Future<void> clearFailed() {
    return (delete(audioCache)..where((t) => t.status.equals(4))).go();
  }

  Future<List<AudioCacheEntry>> getAllEntries() {
    return select(audioCache).get();
  }
}
