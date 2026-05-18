import 'package:drift/drift.dart';

@DataClassName('AssetRelation')
class AssetRelations extends Table {
  @override
  String get tableName => 'asset_relations';

  IntColumn get primaryAssetId => integer()();
  IntColumn get relatedAssetId => integer()();
  TextColumn get relationType => text()(); // e.g., 'VERSION', 'RECOMMENDATION'
  IntColumn get createdAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {primaryAssetId, relatedAssetId, relationType};
}
