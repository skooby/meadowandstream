import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';

import '../../db/daos/assets_dao.dart';
import '../../db/daos/asset_tags_dao.dart';
import '../../services/storage_url_resolver.dart';
import '../../state/player_controller.dart';
import '../../models/item_source.dart';
import '../../state/tag_filter_controller.dart';
import '../../scripts/tenant_service.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../state/favorites_state.dart';
import '../../state/selection_controller.dart';

class AllItemsController extends ChangeNotifier {
  final AssetsDao _assetsDao;
  final AssetTagsDao _assetTagsDao;
  final StorageUrlResolver _resolver;
  final TagFilterController _tagFilterController;

  StreamSubscription<List<Item>>? _subscription;
  List<Item> _items = [];
  bool _hasLoaded = false;
  bool _isDisposed = false;
  String? _error;

  final Set<String> _resolvingIds = {};
  final Set<String> _failedIds = {};

  AllItemsController(this._assetsDao, this._assetTagsDao, this._resolver,
      this._tagFilterController) {
    _tagFilterController.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    start();
  }

  String? get error => _error;
  List<Item> get items => _items;
  bool get hasLoaded => _hasLoaded;

  bool isResolving(String id) => _resolvingIds.contains(id);
  bool isFailed(String id) => _failedIds.contains(id);

  void start() {
    _subscription?.cancel();

    final tags = _tagFilterController.selectedTagIds.toList();
    Stream<List<Item>> source;

    if (tags.isEmpty) {
        source = _assetsDao.watchFilesByQuery('').asyncMap((files) async {
            final Map<String, Item> resolvedItems = {};
            final audioFiles = files.where((sf) => (sf.mimeType ?? '').startsWith('audio/') || sf.name.toLowerCase().endsWith('.mp3')).toList();
            
            final Map<int, String> trackFolderNames = {};
            
            for (var f in audioFiles) {
                String title = f.name.replaceAll(RegExp(r'\.mp3$|\.wav$', caseSensitive: false), '');
                
                if (f.parentId != null) {
                    if (trackFolderNames.containsKey(f.parentId)) {
                        if (trackFolderNames[f.parentId]!.isNotEmpty) {
                            title = trackFolderNames[f.parentId]!;
                        }
                    } else {
                        final parent = await _assetsDao.getAssetById(f.parentId!);
                        if (parent != null) {
                            final siblings = await _assetsDao.getAssetsInFolder(parent.id);
                            final audioSiblings = siblings.where((sf) => (sf.mimeType ?? '').startsWith('audio/') || sf.name.toLowerCase().endsWith('.mp3')).toList();
                            
                            // If exactly 1 audio file exists in this directory, it's structurally a dedicated Track Folder!
                            if (audioSiblings.length == 1) {
                                trackFolderNames[f.parentId!] = parent.name;
                                title = parent.name;
                            } else {
                                trackFolderNames[f.parentId!] = ''; // Leave flat, use raw file name
                            }
                        }
                    }
                }
                
                resolvedItems[f.id.toString()] = Item(
                    id: f.id.toString(), 
                    title: title, 
                    assetFolderId: f.parentId, 
                    audioUrl: f.storagePath ?? '', 
                    collectionId: f.parentId?.toString()
                );
            }
            final finalItems = resolvedItems.values.toList();
            finalItems.sort((a, b) => (a.title).compareTo(b.title));
            return finalItems;
        });
    } else {
        final tenantId = TenantService.currentTenantId ?? 0;
        source = _assetTagsDao.watchAssetsByFilters(
           tenantId: tenantId,
           stringIds: tags,
        ).asyncMap((taggedAssets) async {
           final Map<String, Item> resolvedItems = {};
           
           for (var a in taggedAssets) {
               if (a.type == 'FILE' || a.type == 'TRACK') {
                   if ((a.mimeType ?? '').startsWith('audio/') || a.name.toLowerCase().endsWith('.mp3')) {
                       String cleanTitle = a.name.replaceAll(RegExp(r'\.mp3$|\.wav$', caseSensitive: false), '');
                       resolvedItems[a.id.toString()] = Item(id: a.id.toString(), title: cleanTitle, assetFolderId: a.parentId, audioUrl: a.storagePath ?? '', collectionId: a.parentId?.toString());
                   }
               } else if (a.type == 'FOLDER') {
                   final childFiles = await _assetsDao.getAssetsInFolder(a.id);
                   final audioFiles = childFiles.where((sf) => (sf.mimeType ?? '').startsWith('audio/') || sf.name.toLowerCase().endsWith('.mp3')).toList();
                   
                   if (audioFiles.isNotEmpty) {
                       if (audioFiles.length == 1) {
                           // structurally, 'a' is a Track folder!
                           resolvedItems[a.id.toString()] = Item(id: a.id.toString(), title: a.name, assetFolderId: a.parentId, audioUrl: audioFiles.first.storagePath ?? '', collectionId: a.parentId?.toString());
                       } else {
                           // 'a' is a flat album folder containing multiple independent tracks!
                           for (var f in audioFiles) {
                               String cleanTitle = f.name.replaceAll(RegExp(r'\.mp3$|\.wav$', caseSensitive: false), '');
                               resolvedItems[f.id.toString()] = Item(id: f.id.toString(), title: cleanTitle, assetFolderId: f.parentId, audioUrl: f.storagePath ?? '', collectionId: f.parentId?.toString());
                           }
                       }
                   }
                   
                   // Dive deeper into Album -> Track Folders
                   final childFolders = await _assetsDao.getFoldersInFolder(a.id);
                   for (var f in childFolders) {
                       final subFiles = await _assetsDao.getAssetsInFolder(f.id);
                       final subAudio = subFiles.where((sf) => (sf.mimeType ?? '').startsWith('audio/') || sf.name.toLowerCase().endsWith('.mp3')).toList();
                       
                       if (subAudio.isNotEmpty) {
                           if (subAudio.length == 1) {
                               resolvedItems[f.id.toString()] = Item(id: f.id.toString(), title: f.name, assetFolderId: f.parentId, audioUrl: subAudio.first.storagePath ?? '', collectionId: f.parentId?.toString());
                           } else {
                               for (var sf in subAudio) {
                                   String cleanTitle = sf.name.replaceAll(RegExp(r'\.mp3$|\.wav$', caseSensitive: false), '');
                                   resolvedItems[sf.id.toString()] = Item(id: sf.id.toString(), title: cleanTitle, assetFolderId: sf.parentId, audioUrl: sf.storagePath ?? '', collectionId: sf.parentId?.toString());
                               }
                           }
                       }
                   }
               }
           }
           final finalItems = resolvedItems.values.toList();
           finalItems.sort((a, b) => (a.title).compareTo(b.title));
           return finalItems;
        });
    }

    _subscription = source.listen((mappedList) {
      if (_isDisposed) return;
      _items = mappedList;
      _hasLoaded = true;
      notifyListeners();
    }, onError: (e) {
      if (_isDisposed) return;
      _error = e.toString();
      _hasLoaded = true;
      notifyListeners();
    });
  }

  Future<void> resolveAndPlayQueue(
      Item tappedItem, PlayerController player) async {
    if (isResolving(tappedItem.id)) return;

    _resolvingIds.add(tappedItem.id);
    notifyListeners();

    try {
      await _resolver.resolveUrlsForItems(_items);

      final queue = <ItemSource>[];
      for (var t in _items) {
        final sourceUrl = await _resolver.resolveUrlForItem(t) ?? t.audioUrl;
        queue.add(ItemSource(
          id: t.id,
          title: t.title,
          artist: t.artist,
          sourceType: SourceType.url,
          source: sourceUrl,
          artworkAsset: t.artworkUrl,
        ));
      }

      final index = _items.indexOf(tappedItem);
      if (index >= 0) {
        await player.loadQueue(queue, startIndex: index, autoplay: true);
      }
    } finally {
      _resolvingIds.remove(tappedItem.id);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tagFilterController.removeListener(_onStateChanged);
    _subscription?.cancel();
    super.dispose();
  }
}

class AllItemsScreen extends StatelessWidget {
  const AllItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AllItemsController(
        context.read<AssetsDao>(),
        context.read<AssetTagsDao>(),
        context.read<StorageUrlResolver>(),
        context.read<TagFilterController>(),
      )..start(),
      child: Scaffold(
        appBar: context.watch<SelectionController>().isSelecting
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      context.read<SelectionController>().exitSelectMode(),
                ),
                title: Text(
                    '${context.watch<SelectionController>().selectedCount} Selected'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.playlist_add),
                    onPressed: () {
                      final selection = context.read<SelectionController>();
                      if (selection.selectedCount > 0) {
                        final allController =
                            context.read<AllItemsController>();
                        final selectedItems = allController.items
                            .where((t) => selection.isSelected(t.id))
                            .toList();
                        showModalBottomSheet(
                          context: context,
                          builder: (context) =>
                              AddToPlaylistSheet(items: selectedItems),
                        ).then((_) {
                          // Exit selection mode after adding
                          selection.exitSelectMode();
                        });
                      }
                    },
                  ),
                ],
              )
            : AppBar(
                title: const Text('All Items'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Select',
                    onPressed: () =>
                        context.read<SelectionController>().enterSelectMode(),
                  ),
                ],
              ),
        body: const AllItemsListBody(),
      ),
    );
  }
}

class AllItemsListBody extends StatelessWidget {
  const AllItemsListBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AllItemsController>(
      builder: (context, controller, child) {
        final theme = Theme.of(context);
        final selectionController = context.watch<SelectionController>();

        return Column(children: [

          Expanded(
            child:
                () {
              if (!controller.hasLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.items.isEmpty) {
                if (controller.error != null) {
                  return Center(child: Text('Error: ${controller.error}'));
                }
                return const Center(child: Text('No items found.', style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: controller.items.length,
                itemBuilder: (context, index) {
                  final item = controller.items[index];
                  final isValidUrl = item.isValid;
                  return Builder(builder: (context) {
                    final isCurrent =
                        context.select<PlayerController, bool>(
                            (p) => p.currentItem?.id == item.id);
                    final isPlaying = context
                        .select<PlayerController, bool>((p) => p.isPlaying);
                    final isResolving = controller.isResolving(item.id);
                    final isFailed = controller.isFailed(item.id);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 0),
                      leading: selectionController.isSelecting
                          ? Checkbox(
                              value:
                                  selectionController.isSelected(item.id),
                              onChanged: (bool? value) {
                                selectionController.toggle(item.id);
                              },
                            )
                          : const Icon(Icons.music_note,
                              color: Colors.grey),
                      title: Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color:
                              isCurrent ? theme.colorScheme.primary : null,
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
                                            controller.resolveAndPlayQueue(
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
                        if (selectionController.isSelecting) {
                          selectionController.toggle(item.id);
                        } else if (isValidUrl || !isFailed) {
                          controller.resolveAndPlayQueue(
                              item, context.read<PlayerController>()).then((_) {
                            if (context.mounted) {
                              Navigator.pushNamed(context, '/now-playing');
                            }
                          });
                        }
                      },
                    );
                  });
                },
              );
            }(),
          )
        ]);
      },
    );
  }
}
