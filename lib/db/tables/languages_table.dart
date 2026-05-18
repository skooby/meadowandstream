import 'package:drift/drift.dart';
import 'strings_table.dart';

@DataClassName('SystemLanguage')
class Languages extends Table {
  IntColumn get id => integer()();
  TextColumn get code => text().unique()();
  IntColumn get nameStringId => integer().nullable().references(Strings, #id)();

  @override
  Set<Column> get primaryKey => {id};
}
