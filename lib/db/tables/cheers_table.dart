import 'package:drift/drift.dart';

class Cheers extends Table {
  TextColumn get id => text()(); // UUID from server
  TextColumn get userId => text()(); // Supabase user ID
  TextColumn get targetId => text()(); // Target user or asset ID
  IntColumn get amount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
