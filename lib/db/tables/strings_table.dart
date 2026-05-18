import 'package:drift/drift.dart';

@DataClassName('SystemString')
class Strings extends Table {
  IntColumn get id => integer()();
  IntColumn get tenantId => integer()();
  TextColumn get key => text()();
  TextColumn get description => text().nullable()();
  
  // Folder capability fields
  IntColumn get parentId => integer().nullable().references(Strings, #id)();
  TextColumn get type => text().withDefault(const Constant('STRING'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  
  // Custom string payload metadata
  TextColumn get color => text().nullable()();
  TextColumn get parameter => text().nullable()();

  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(tenant_id, key)'
  ];
}
