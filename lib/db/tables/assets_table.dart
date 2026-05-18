import 'package:drift/drift.dart';

class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tenantId => integer()();
  IntColumn get parentId => integer().nullable()();
  TextColumn get type => text()(); // 'FOLDER', 'FILE'
  TextColumn get mimeType => text().nullable()(); 
  TextColumn get name => text()(); 
  TextColumn get storagePath => text().nullable()(); 
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get mappedStringFolderId => integer().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  IntColumn get titleStringId => integer().nullable()();
  TextColumn get collectionType => text().nullable()();
  TextColumn get searchKeywords => text().nullable()();
  TextColumn get relatedAssetIds => text().nullable()();
  TextColumn get alternateVersionIds => text().nullable()();

}
