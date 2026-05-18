import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/daos/playlist_items_dao.dart';
import '../../db/daos/assets_dao.dart';
import '../../db/app_database.dart';
import '../../state/favorites_state.dart';
import '../../state/player_controller.dart';
import '../../models/item_source.dart';
import '../../engine/ui_inspector/element_registry.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  void _playPlaylist(BuildContext context, List<PlaylistItemView> items,
      {int startIndex = 0}) async {
    if (items.isEmpty) return;

    final assetsDao = context.read<AssetsDao>();
    final playerController = context.read<PlayerController>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final itemSources = <ItemSource>[];
    int availableCount = 0;

    for (final view in items) {
      if (view.isMissing) continue; // Item was removed from catalog

      final item = view.item;
      final parsedId = int.tryParse(item.itemId);
      if (parsedId == null) continue;
      final localAsset = await assetsDao.getAssetById(parsedId);

      if (localAsset != null) {
        String finalUrl = localAsset.storagePath ?? '';

        itemSources.add(ItemSource(
          id: localAsset.id.toString(),
          title: localAsset.name,
          artist: 'Unknown Artist',
          sourceType: SourceType.url,
          source: finalUrl,
          artworkAsset: null,
        ));
        availableCount++;
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading indicator
    }

    if (itemSources.isEmpty) {
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No items available to play.')));
      return;
    }

    if (availableCount < items.length) {
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Some items are locally missing.')));
    }

    // Ensure we don't start out of bounds if items were skipped
    int safeIndex = startIndex;
    if (safeIndex >= itemSources.length) {
      safeIndex = 0;
    }

    await playerController.loadQueue(itemSources,
        startIndex: safeIndex, autoplay: true);
  }

  @override
  Widget build(BuildContext context) {
    final itemsDao = context.watch<PlaylistItemsDao>();

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
      ),
      body: StreamBuilder<List<PlaylistItemView>>(
        stream: itemsDao.watchItemsWithItemInfo(playlist.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${items.length} items',
                        style: Theme.of(context).textTheme.titleMedium),
                    RegisteredElement(
                      id: 'playlist_btn_play_all',
                      meta: const {'type': 'Button'},
                      child: ElevatedButton.icon(
                        onPressed: items.isEmpty
                            ? null
                            : () => _playPlaylist(context, items),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play All'),
                      )
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Playlist is empty.\nAdd items via the ⠇ menu in other screens.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: items.length,
                        onReorder: (oldIndex, newIndex) {
                          context
                              .read<PlaylistItemsDao>()
                              .reorder(playlist.id, oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final view = items[index];
                          final item = view.item;
                          final isMissing = view.isMissing;

                          return RegisteredElement(
                            id: 'list_tile_playlist_${item.itemId}_${item.sortIndex}',
                            meta: const {'type': 'Card'},
                            child: ListTile(
                            key: ValueKey('${item.itemId}_${item.sortIndex}'),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.music_note,
                                  color: Colors.grey),
                            ),
                            title: Text(item.title ?? 'Unknown Title',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              isMissing
                                  ? 'Missing item'
                                  : (item.artist ?? 'Unknown Artist'),
                              style: isMissing
                                  ? TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)
                                  : null,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            enabled: !isMissing,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Consumer<FavoritesState>(
                                  builder: (context, favorites, _) {
                                    final isFavorited = favorites
                                        .isItemFavorited(item.itemId);
                                    return RegisteredElement(
                                      id: 'btn_favorite_${item.itemId}_${item.sortIndex}',
                                      meta: const {'type': 'Button'},
                                      child: IconButton(
                                        icon: Icon(
                                          isFavorited
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isFavorited
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.grey,
                                        ),
                                        onPressed: () {
                                          favorites.toggleItem(item.itemId);
                                        },
                                      )
                                    );
                                  },
                                ),
                                RegisteredElement(
                                  id: 'btn_remove_${item.itemId}_${item.sortIndex}',
                                  meta: const {'type': 'Button'},
                                  child: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => context
                                        .read<PlaylistItemsDao>()
                                        .removeAt(playlist.id, item.sortIndex),
                                  )
                                ),
                              ],
                            ),
                            onTap: isMissing
                                ? null
                                : () => _playPlaylist(context, items,
                                    startIndex: index),
                          ));
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
