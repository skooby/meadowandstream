import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/collection_items_controller.dart';
import '../../state/player_controller.dart';
import '../../db/daos/assets_dao.dart';
import '../../services/storage_url_resolver.dart';
import '../../state/tag_filter_controller.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../state/favorites_state.dart';
import '../../engine/ui_inspector/element_registry.dart';

class CollectionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> arguments;

  const CollectionDetailScreen({super.key, required this.arguments});

  @override
  Widget build(BuildContext context) {
    final collectionId = arguments['collectionId'] as String;
    final collectionTitle = arguments['collectionTitle'] as String;
    final collectionArtist = arguments['collectionArtist'] as String?;
    final collectionArtworkUrl = arguments['collectionArtworkUrl'] as String?;

    return ActiveScreenScope(
      screenName: 'Album',
      child: ChangeNotifierProvider(
        create: (context) => CollectionItemsController(
          context.read<AssetsDao>(),
          context.read<StorageUrlResolver>(),
          context.read<TagFilterController>(),
          collectionId,
        )..start(),
        child: Scaffold(
        appBar: AppBar(
          title: Text(collectionTitle),
          actions: MediaQuery.of(context).size.width < 250 ? null : [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.pushNamed(context, '/search');
              },
            ),
            Builder(builder: (context) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'add_to_playlist') {
                    final items = context.read<CollectionItemsController>().items;
                    if (items.isNotEmpty) {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) =>
                            AddToPlaylistSheet(items: items),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No items to add')),
                      );
                    }
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem(
                      value: 'add_to_playlist',
                      child: Text('Add collection to playlist'),
                    ),
                  ];
                },
              );
            }),
          ],
        ),
        body: Consumer<CollectionItemsController>(
          builder: (context, controller, child) {
            final theme = Theme.of(context);

            return Column(children: [
              _buildArtworkHeader(context, theme, collectionId, collectionTitle,
                  collectionArtist, collectionArtworkUrl),

              Expanded(
                child: Builder(
                  builder: (context) {
                    if (!controller.hasLoaded) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (controller.items.isEmpty) {
                      if (controller.error != null) {
                        return Center(
                            child: Text('Error: ${controller.error}'));
                      }
                      return const Center(
                          child:
                              Text('No items found for this collection/filter.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: controller.items.length,
                      itemBuilder: (context, index) {
                        final item = controller.items[index];
                        final isValidUrl = item.isValid;
                        return Builder(builder: (context) {
                          final isCurrent =
                              context.select<PlayerController, bool>(
                                  (p) => p.currentItem?.id == item.id);
                          final isPlaying =
                              context.select<PlayerController, bool>(
                                  (p) => p.isPlaying);
                          final isResolving = controller.isResolving(item.id);
                          final isFailed = controller.isFailed(item.id);

                          return RegisteredElement(
                            id: 'album_track_row_${item.id}',
                            meta: const {'type': 'List Tile'},
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 0),
                              leading: const Icon(Icons.music_note,
                                  color: Colors.grey),
                            title: Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              isFailed
                                  ? 'Unavailable'
                                  : (item.artist ?? 'Unknown Artist'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isFailed ? Colors.red : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isResolving
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : IconButton(
                                        icon: Icon(isCurrent && isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_fill),
                                        iconSize: 36,
                                        color: isFailed
                                            ? Colors.grey
                                            : theme.colorScheme.primary,
                                        onPressed: (!isFailed && isValidUrl)
                                            ? () {
                                                final player = context
                                                    .read<PlayerController>();

                                                if (isCurrent) {
                                                  player.togglePlayPause();
                                                  if (context.mounted) {
                                                    Navigator.pushNamed(context, '/now-playing');
                                                  }
                                                } else {
                                                  controller
                                                      .resolveAndPlayQueue(
                                                          item, player).then((_) {
                                                    if (context.mounted) {
                                                      Navigator.pushNamed(context, '/now-playing');
                                                    }
                                                  });
                                                }
                                              }
                                            : null,
                                      ),
                                Consumer<FavoritesState>(
                                  builder: (context, favorites, _) {
                                    final isFavorited =
                                        favorites.isItemFavorited(item.id);
                                    return IconButton(
                                      icon: Icon(
                                        isFavorited
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFavorited
                                            ? theme.colorScheme.primary
                                            : Colors.grey,
                                      ),
                                      onPressed: () {
                                        favorites.toggleItem(item.id);
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) =>
                                          AddToPlaylistSheet(item: item),
                                    );
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              if (isValidUrl || !isFailed) {
                                controller.resolveAndPlayQueue(
                                    item, context.read<PlayerController>()).then((_) {
                                  if (context.mounted) {
                                    Navigator.pushNamed(context, '/now-playing');
                                  }
                                });
                              }
                            },
                          ));
                        });
                      },
                    );
                  },
                ),
              )
            ]);
          },
        ),
      ),
    ));
  }

  Widget _buildArtworkHeader(BuildContext context, ThemeData theme,
      String collectionId, String title, String? artist, String? artworkUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          RegisteredElement(
            id: 'album_header_artwork',
            meta: const {'type': 'Image'},
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildImage(artworkUrl),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Consumer<FavoritesState>(
                builder: (context, favorites, _) {
                  final isFavorited = favorites.isCollectionFavorited(collectionId);
                  return IconButton(
                    icon: Icon(
                      isFavorited ? Icons.favorite : Icons.favorite_border,
                      color: isFavorited
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      favorites.toggleCollection(collectionId);
                    },
                  );
                },
              ),
            ],
          ),
          if (artist != null && artist.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              artist,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.collections, size: 80, color: Colors.grey);
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 80, color: Colors.grey),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, size: 80, color: Colors.grey),
    );
  }
}
