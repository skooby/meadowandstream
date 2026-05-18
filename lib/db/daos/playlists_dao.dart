import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/playlists_table.dart';
import '../tables/playlist_items_table.dart';

part 'playlists_dao.g.dart';

class PlaylistWithCount {
  final Playlist playlist;
  final int itemCount;
  PlaylistWithCount(this.playlist, this.itemCount);
}

@DriftAccessor(tables: [Playlists, PlaylistItems])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(AppDatabase db) : super(db);

  Stream<List<Playlist>> watchPlaylists() {
    return (select(playlists)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<List<Playlist>> getAllPlaylists() {
    return (select(playlists)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<PlaylistWithCount>> watchPlaylistsWithCounts() {
    final itemCount = playlistItems.itemId.count();
    final query = select(playlists).join([
      leftOuterJoin(
          playlistItems, playlistItems.playlistId.equalsExp(playlists.id))
    ])
      ..addColumns([itemCount])
      ..groupBy([playlists.id])
      ..orderBy([OrderingTerm.desc(playlists.updatedAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return PlaylistWithCount(
          row.readTable(playlists),
          row.read(itemCount) ?? 0,
        );
      }).toList();
    });
  }

  Future<String> createPlaylist(String name) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await into(playlists).insert(
      PlaylistsCompanion.insert(
        id: id,
        name: name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playlists)..where((t) => t.id.equals(id))).write(
      PlaylistsCompanion(
        name: Value(name),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deletePlaylist(String id) async {
    await (delete(playlists)..where((t) => t.id.equals(id))).go();
  }
}
