import 'package:drift/drift.dart';

@DataClassName('AssetTag')
class AssetTags extends Table {
  @override
  String get tableName => 'asset_tags';

  IntColumn get assetId => integer()();
  IntColumn get stringId => integer()();
  IntColumn get createdAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {assetId, stringId};
}
