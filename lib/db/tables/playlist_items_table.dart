import 'package:drift/drift.dart';

@DataClassName('PlaylistItem')
class PlaylistItems extends Table {
  TextColumn get playlistId => text()();
  IntColumn get sortIndex => integer()();
  TextColumn get itemId => text()();

  // Denormalized fields for robustness
  TextColumn get title => text().nullable()();
  TextColumn get artist => text().nullable()();

  @override
  Set<Column> get primaryKey => {playlistId, sortIndex};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE',
      ];
}
