import 'package:drift/drift.dart';

class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tenantId => integer()();
  TextColumn get preferenceKey => text()();
  TextColumn get preferenceValue => text()();

  @override
  List<Set<Column>> get uniqueKeys => [{tenantId, preferenceKey}];
}
