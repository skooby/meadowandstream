import 'package:drift/drift.dart';

class RecentPlays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text()();
  IntColumn get playedAt => integer()(); // unix ms
  TextColumn get collectionId => text().nullable()();
  TextColumn get collectionTitle => text().nullable()();
  TextColumn get title => text()(); // denormalized minimal display
  TextColumn get artist => text().nullable()();
}
