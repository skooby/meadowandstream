import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/recent_searches_table.dart';

part 'recent_searches_dao.g.dart';

@DriftAccessor(tables: [RecentSearches])
class RecentSearchesDao extends DatabaseAccessor<AppDatabase>
    with _$RecentSearchesDaoMixin {
  RecentSearchesDao(super.db);

  Stream<List<RecentSearch>> watchRecent({int limit = 10}) {
    return (select(recentSearches)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.searchedAt, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> upsertQuery(String q) async {
    final now = DateTime.now();
    await into(recentSearches).insert(
      RecentSearchesCompanion.insert(
        query: q,
        searchedAt: now,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> pruneToLimit(int limit) async {
    final idsToKeep = await (select(recentSearches)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.searchedAt, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .map((r) => r.id)
        .get();

    if (idsToKeep.isEmpty) return;

    await (delete(recentSearches)..where((t) => t.id.isNotIn(idsToKeep))).go();
  }

  Future<void> clearAll() async {
    await delete(recentSearches).go();
  }
}
