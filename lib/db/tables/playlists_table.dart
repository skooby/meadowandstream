import 'package:drift/drift.dart';

@DataClassName('Playlist')
class Playlists extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
