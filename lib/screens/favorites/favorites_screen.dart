import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/daos/favorites_dao.dart';
import '../../db/app_database.dart';
import '../../models/item.dart';
import '../../state/player_controller.dart';
import '../../db/daos/assets_dao.dart';
import '../../services/storage_url_resolver.dart';
import '../../models/item_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _selectedTab = 'Collections'; // 'Collections' or 'Items'

  Future<void> _playItem(Item item, List<Item> allItemsContext) async {
    final prefs = await SharedPreferences.getInstance();
    final playInCollectionContext = prefs.getBool('search_play_in_collection') ?? true;

    if (!mounted) return;
    final player = context.read<PlayerController>();
    final resolver = context.read<StorageUrlResolver>();
    final assetsDao = context.read<AssetsDao>();

    final url = await resolver.resolveUrlForItem(item);
    if (url == null) return;

    List<Item> targetQueue = allItemsContext;

    if (playInCollectionContext && item.collectionId != null && int.tryParse(item.collectionId!) != null) {
      final collectionLocalAssets =
          await assetsDao.getAssetsInFolder(int.parse(item.collectionId!));
      if (collectionLocalAssets.isNotEmpty) {
        targetQueue = collectionLocalAssets.map((a) => Item(
           id: a.id.toString(),
           title: a.name,
           assetFolderId: a.parentId,
           audioUrl: a.storagePath ?? '',
           collectionId: a.parentId?.toString(),
        )).toList();
      }
    }

    final queue = targetQueue.map((t) {
      final sourceUrl = (t.id == item.id) ? url : t.audioUrl;
      return ItemSource(
        id: t.id,
        title: t.title,
        artist: t.artist,
        sourceType: SourceType.url,
        source: sourceUrl,
        artworkAsset: t.artworkUrl,
      );
    }).toList();

    final startIndex = targetQueue.indexWhere((t) => t.id == item.id);
    if (startIndex >= 0) {
      await player.loadQueue(queue, startIndex: startIndex, autoplay: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'Collections', label: Text('Collections')),
                ButtonSegment(value: 'Items', label: Text('Items')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedTab = newSelection.first;
                });
              },
            ),
          ),
          Expanded(
            child: _selectedTab == 'Collections'
                ? _buildCollectionsTab(theme)
                : _buildItemsTab(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsTab(ThemeData theme) {
    return StreamBuilder<List<Asset>>(
      stream: context.read<FavoritesDao>().watchFavoriteCollections(),
      builder: (context, snapshot) {
        final collections = snapshot.data ?? [];
        if (collections.isEmpty) {
          return Center(
            child: Text('No favorite collections yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final collection = collections[index];
            return GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/collection-detail', arguments: {
                  'collectionId': collection.id.toString(),
                  'collectionTitle': collection.name,
                  'collectionArtist': 'Unknown Artist',
                  'collectionArtworkUrl': null,
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.folder,
                               size: 48, color: Colors.grey)
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    collection.description ?? 'Folder',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildItemsTab(ThemeData theme) {
    return StreamBuilder<List<Asset>>(
      stream: context.read<FavoritesDao>().watchFavoriteItems(),
      builder: (context, snapshot) {
        final localItems = snapshot.data ?? [];
        if (localItems.isEmpty) {
          return Center(
            child: Text('No favorite items yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
          );
        }

        final items = localItems.map((a) {
           String cleanTitle = a.name.replaceAll(RegExp(r'\.mp3$|\.wav$', caseSensitive: false), '');
           return Item(
             id: a.id.toString(),
             title: cleanTitle,
             assetFolderId: a.parentId,
             audioUrl: a.storagePath ?? '',
             collectionId: a.parentId?.toString(),
           );
        }).toList();

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Builder(builder: (context) {
              final isCurrent = context.select<PlayerController, bool>(
                  (p) => p.currentItem?.id == item.id);

              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? theme.colorScheme.primary : null,
                  ),
                ),
                subtitle: const Text(
                  'Unknown Artist',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.favorite,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        context.read<FavoritesDao>().toggleItem(item.id);
                      },
                    ),
                  ],
                ),
                onTap: () => _playItem(item, items),
              );
            });
          },
        );
      },
    );
  }
}
