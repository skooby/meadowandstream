import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/asset_relations_table.dart';

part 'asset_relations_dao.g.dart';

@DriftAccessor(tables: [AssetRelations])
class AssetRelationsDao extends DatabaseAccessor<AppDatabase>
    with _$AssetRelationsDaoMixin {
  AssetRelationsDao(super.db);

  Future<void> saveRelationsBatch(List<AssetRelationsCompanion> relations) async {
    await batch((batch) {
      batch.insertAll(assetRelations, relations, mode: InsertMode.insertOrReplace);
    });
  }

  Stream<List<AssetRelation>> watchRelationsForAsset(int assetId) {
    return (select(assetRelations)..where((t) => t.primaryAssetId.equals(assetId))).watch();
  }

  Future<List<AssetRelation>> getRelationsForAsset(int assetId) {
    return (select(assetRelations)..where((t) => t.primaryAssetId.equals(assetId))).get();
  }

  Future<void> deleteRelation(int primaryId, int relatedId, String type) {
    return (delete(assetRelations)
          ..where((t) =>
              t.primaryAssetId.equals(primaryId) &
              t.relatedAssetId.equals(relatedId) &
              t.relationType.equals(type)))
        .go();
  }
}
