import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/asset_tags_table.dart';
import '../tables/assets_table.dart';
import '../tables/strings_table.dart';

part 'asset_tags_dao.g.dart';

@DriftAccessor(tables: [AssetTags, Assets, Strings])
class AssetTagsDao extends DatabaseAccessor<AppDatabase> with _$AssetTagsDaoMixin {
  AssetTagsDao(super.db);

  Stream<List<SystemString>> watchStringsForAsset(int assetId) {
    final query = select(strings).join([
      innerJoin(assetTags, assetTags.stringId.equalsExp(strings.id)),
    ])
    ..where(assetTags.assetId.equals(assetId))
    ..orderBy([
      OrderingTerm(expression: strings.sortOrder, mode: OrderingMode.asc),
      OrderingTerm(expression: strings.id)
    ]);

    return query.map((row) => row.readTable(strings)).watch();
  }

  Future<void> replaceStringsForAsset(int assetId, List<int> stringIds) async {
    await batch((batch) {
      batch.deleteWhere(assetTags, (t) => t.assetId.equals(assetId));
      if (stringIds.isNotEmpty) {
        batch.insertAll(assetTags, stringIds.map((sid) => AssetTagsCompanion.insert(
          assetId: assetId,
          stringId: sid,
          createdAt: Value(DateTime.now().millisecondsSinceEpoch)
        )).toList(), mode: InsertMode.insertOrIgnore);
      }
    });
  }

  Stream<List<Asset>> watchAssetsByFilters({
    int? tenantId,
    List<int>? stringIds,
    String? searchQuery,
    String? collectionType,
  }) {
    var query = select(assets);
    
    if (tenantId != null) {
       query.where((a) => a.tenantId.equals(tenantId));
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
       query.where((a) => a.name.like('%$searchQuery%') | a.description.like('%$searchQuery%'));
    }

    if (collectionType != null && collectionType.isNotEmpty) {
       query.where((a) => a.collectionType.equals(collectionType));
    }

    if (stringIds != null && stringIds.isNotEmpty) {
        // Enforce ALL tags inherently bound (Intersection Query Pattern) natively
        for (var sid in stringIds) {
           query.where((a) => existsQuery(
              select(assetTags)
              ..where((at) => at.assetId.equalsExp(a.id) & at.stringId.equals(sid))
           ));
        }
    }

    query.orderBy([
       (a) => OrderingTerm(expression: a.type.equals('FOLDER'), mode: OrderingMode.desc),
       (a) => OrderingTerm(expression: a.name)
    ]);

    return query.watch();
  }

  Stream<List<AssetTag>> watchAllAssetTags() => select(assetTags).watch();

  Future<void> replaceAllAssetTags(List<AssetTag> allTags) async {
    await batch((batch) {
      batch.deleteAll(assetTags);
      batch.insertAll(assetTags, allTags, mode: InsertMode.insertOrReplace);
    });
  }
}
