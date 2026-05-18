import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/playlist_items_table.dart';
import '../tables/playlists_table.dart';
import '../../models/item.dart';

part 'playlist_items_dao.g.dart';

class PlaylistItemView {
  final PlaylistItem item;
  final bool isMissing;
  PlaylistItemView(this.item, this.isMissing);
}

@DriftAccessor(tables: [Playlists, PlaylistItems])
class PlaylistItemsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistItemsDaoMixin {
  PlaylistItemsDao(AppDatabase db) : super(db);

  Stream<List<PlaylistItem>> watchItems(String playlistId) {
    return (select(playlistItems)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch();
  }

  Future<List<PlaylistItem>> getItems(String playlistId) {
    return (select(playlistItems)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .get();
  }

  Stream<List<PlaylistItemView>> watchItemsWithItemInfo(String playlistId) {
    return (select(playlistItems)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch()
        .map((rows) {
      return rows.map((row) {
        return PlaylistItemView(row, false);
      }).toList();
    });
  }

  Future<void> addItem(String playlistId, String itemId,
      {String? title, String? artist}) async {
    await addItemsBatch(playlistId, [
      Item(
          id: itemId, title: title ?? 'Unknown', artist: artist, assetFolderId: null, audioUrl: '')
    ]);
  }

  Future<(int added, int duplicates)> addItemsBatch(
      String playlistId, List<Item> items) async {
    int added = 0;
    int duplicates = 0;

    await transaction(() async {
      // Find the current max sortIndex
      final maxIndexExpr = playlistItems.sortIndex.max();
      final query = selectOnly(playlistItems)
        ..addColumns([maxIndexExpr])
        ..where(playlistItems.playlistId.equals(playlistId));
      final result = await query.getSingleOrNull();
      int currentIndex = (result?.read(maxIndexExpr) ?? -1) + 1;

      List<PlaylistItemsCompanion> toInsert = [];

      for (final item in items) {
        // Check duplicate
        final exists = await (select(playlistItems)
              ..where((t) =>
                  t.playlistId.equals(playlistId) & t.itemId.equals(item.id)))
            .getSingleOrNull();

        if (exists != null) {
          duplicates++;
          continue;
        }

        toInsert.add(PlaylistItemsCompanion.insert(
          playlistId: playlistId,
          sortIndex: currentIndex++,
          itemId: item.id,
          title: Value(item.title),
          artist: Value(item.artist),
        ));
        added++;
      }

      if (toInsert.isNotEmpty) {
        await batch((b) {
          b.insertAll(playlistItems, toInsert,
              mode: InsertMode.insertOrReplace);
        });

        // Update the playlist's updatedAt timestamp
        final now = DateTime.now().millisecondsSinceEpoch;
        await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
          PlaylistsCompanion(updatedAt: Value(now)),
        );
      }
    });

    return (added, duplicates);
  }

  Future<void> removeAt(String playlistId, int sortIndex) async {
    await transaction(() async {
      await (delete(playlistItems)
            ..where((t) =>
                t.playlistId.equals(playlistId) &
                t.sortIndex.equals(sortIndex)))
          .go();

      // Shift remaining items to close the gap
      await customStatement(
        'UPDATE playlist_items SET sort_index = sort_index - 1 WHERE playlist_id = ? AND sort_index > ?',
        [playlistId, sortIndex],
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
        PlaylistsCompanion(updatedAt: Value(now)),
      );
    });
  }

  Future<void> reorder(String playlistId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    await transaction(() async {
      // Re-fetch all items to reindex in Dart logic (safest against collision)
      final items = await (select(playlistItems)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
          .get();

      if (oldIndex < 0 ||
          oldIndex >= items.length ||
          newIndex < 0 ||
          newIndex > items.length) {
        return;
      }

      final item = items.removeAt(oldIndex);

      // Adjust newIndex after removal
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      items.insert(newIndex, item);

      // Update all sort indices
      await (delete(playlistItems)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();

      final bulkInsert = items.asMap().entries.map((entry) {
        final original = entry.value;
        return PlaylistItemsCompanion.insert(
          playlistId: original.playlistId,
          sortIndex: entry.key,
          itemId: original.itemId,
          title: Value(original.title),
          artist: Value(original.artist),
        );
      }).toList();

      await batch((batch) {
        batch.insertAll(playlistItems, bulkInsert);
      });

      final now = DateTime.now().millisecondsSinceEpoch;
      await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
        PlaylistsCompanion(updatedAt: Value(now)),
      );
    });
  }

  Future<void> clear(String playlistId) async {
    await transaction(() async {
      await (delete(playlistItems)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();

      final now = DateTime.now().millisecondsSinceEpoch;
      await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
        PlaylistsCompanion(updatedAt: Value(now)),
      );
    });
  }

  Future<bool> containsItem(String playlistId, String itemId) async {
    final query = select(playlistItems)
      ..where(
          (t) => t.playlistId.equals(playlistId) & t.itemId.equals(itemId));
    final result = await query.get();
    return result.isNotEmpty;
  }

  Future<Set<String>> getPlaylistsContainingItem(String itemId) async {
    final query = selectOnly(playlistItems)
      ..addColumns([playlistItems.playlistId])
      ..where(playlistItems.itemId.equals(itemId));
    final result = await query.get();
    return result.map((row) => row.read(playlistItems.playlistId)!).toSet();
  }
}
