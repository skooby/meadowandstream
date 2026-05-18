import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/recent_plays_table.dart';

part 'recent_plays_dao.g.dart';

@DriftAccessor(tables: [RecentPlays])
class RecentPlaysDao extends DatabaseAccessor<AppDatabase>
    with _$RecentPlaysDaoMixin {
  RecentPlaysDao(super.db);

  Stream<List<RecentPlay>> watchRecent({int limit = 50}) {
    return (select(recentPlays)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<RecentPlay>> getRecentPlays({int limit = 50}) {
    return (select(recentPlays)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> insertPlay(String itemId, String title,
      {String? artist, String? collectionId, String? collectionTitle}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Purge any trailing duplicates aggressively mirroring distinct history behavior
    await (delete(recentPlays)..where((t) => t.itemId.equals(itemId))).go();

    await into(recentPlays).insert(
      RecentPlaysCompanion.insert(
        itemId: itemId,
        playedAt: now,
        title: title,
        artist: Value(artist),
        collectionId: Value(collectionId),
        collectionTitle: Value(collectionTitle),
      ),
    );
    await pruneToLimit(200);
  }

  Future<void> pruneToLimit(int limit) async {
    // Keep only the newest N records

    final offsetRows = await (select(recentPlays)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(1, offset: limit))
        .get();

    if (offsetRows.isNotEmpty) {
      final thresholdRow = offsetRows.first;
      await (delete(recentPlays)
            ..where((t) =>
                t.playedAt.isSmallerOrEqualValue(thresholdRow.playedAt) &
                t.id.isSmallerThanValue(thresholdRow.id)))
          .go();
    }
  }
}
