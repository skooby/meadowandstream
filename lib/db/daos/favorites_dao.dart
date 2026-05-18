import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/favorites_collections_table.dart';
import '../tables/favorites_items_table.dart';
import '../tables/assets_table.dart';

part 'favorites_dao.g.dart';

@DriftAccessor(tables: [FavoritesCollections, FavoritesItems, Assets])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  Stream<List<Asset>> watchFavoriteCollections() {
    return (select(favoritesCollections)
      ..orderBy([(t) => OrderingTerm(expression: t.favoritedAt, mode: OrderingMode.desc)]))
      .watch()
      .asyncMap((favs) async {
        final ids = favs.map((f) => int.tryParse(f.collectionId)).whereType<int>().toList();
        if (ids.isEmpty) return [];
        final localAssets = await (select(assets)..where((t) => t.id.isIn(ids))).get();
        final assetMap = {for (var a in localAssets) a.id: a};
        return ids.map((id) => assetMap[id]).whereType<Asset>().toList();
    });
  }

  Stream<List<Asset>> watchFavoriteItems() {
    return (select(favoritesItems)
      ..orderBy([(t) => OrderingTerm(expression: t.favoritedAt, mode: OrderingMode.desc)]))
      .watch()
      .asyncMap((favs) async {
        final ids = favs.map((f) => int.tryParse(f.itemId)).whereType<int>().toList();
        if (ids.isEmpty) return [];
        final localAssets = await (select(assets)..where((t) => t.id.isIn(ids))).get();
        final assetMap = {for (var a in localAssets) a.id: a};
        return ids.map((id) => assetMap[id]).whereType<Asset>().toList();
    });
  }

  Stream<bool> isCollectionFavorited(String collectionId) {
    return (select(favoritesCollections)..where((t) => t.collectionId.equals(collectionId)))
        .watchSingleOrNull()
        .map((row) => row != null);
  }

  Stream<bool> isItemFavorited(String itemId) {
    return (select(favoritesItems)..where((t) => t.itemId.equals(itemId)))
        .watchSingleOrNull()
        .map((row) => row != null);
  }

  Future<void> toggleCollection(String collectionId) async {
    final existing = await (select(favoritesCollections)
          ..where((t) => t.collectionId.equals(collectionId)))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(favoritesCollections)..where((t) => t.collectionId.equals(collectionId)))
          .go();
    } else {
      await into(favoritesCollections).insert(FavoritesCollectionsCompanion.insert(
        collectionId: collectionId,
        favoritedAt: DateTime.now(),
      ));
    }
  }

  Future<void> toggleItem(String itemId) async {
    final existing = await (select(favoritesItems)
          ..where((t) => t.itemId.equals(itemId)))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(favoritesItems)..where((t) => t.itemId.equals(itemId)))
          .go();
    } else {
      await into(favoritesItems).insert(FavoritesItemsCompanion.insert(
        itemId: itemId,
        favoritedAt: DateTime.now(),
      ));
    }
  }
}
