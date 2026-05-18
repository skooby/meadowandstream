import 'package:drift/drift.dart';
import 'strings_table.dart';
import 'languages_table.dart';

@DataClassName('SystemTranslation')
class Translations extends Table {
  IntColumn get id => integer()();
  IntColumn get tenantId => integer()();
  IntColumn get stringId => integer().references(Strings, #id)();
  TextColumn get value => text()();
  IntColumn get langId => integer().references(Languages, #id)();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(string_id, lang_id)'
  ];
}
