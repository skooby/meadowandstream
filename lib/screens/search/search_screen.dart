import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_search_controller.dart';
import '../../db/daos/assets_dao.dart'; // Double mapped to satisfy diff context boundaries
import '../../db/app_database.dart';
import '../../models/item.dart';
import '../../state/player_controller.dart';
import '../../services/storage_url_resolver.dart';
import '../../state/favorites_state.dart';
import '../../models/item_source.dart';
import '../../db/daos/recent_searches_dao.dart';
import '../../widgets/highlight_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/tag_filter_controller.dart';
import '../../db/daos/i18n_dao.dart';
import '../../db/daos/asset_tags_dao.dart';
import '../../engine/ui_inspector/element_registry.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final Set<String> _resolvingIds = {};
  final Set<String> _failedIds = {};

  String _selectedFilter = 'All';
  Map<int, String> _tagNames = {};
  List<SystemString> _tags = [];

  @override
  void initState() {
    super.initState();
    final initialQuery = context.read<AppSearchController>().query;
    if (initialQuery.isNotEmpty) {
      _textController.text = initialQuery;
    }
    _loadTags();
  }

  Future<void> _loadTags() async {
     final prefs = await SharedPreferences.getInstance();
     final strId = prefs.getString('project_tags_folder_id');
     final rootId = strId != null ? int.tryParse(strId) : null;
     
     if (!mounted) return;
     final i18n = context.read<I18nDao>();
     final strings = await i18n.watchAllStrings().first;
     
     final assetTagsDao = context.read<AssetTagsDao>();
     final activeTagEdges = await assetTagsDao.watchAllAssetTags().first;
     final activeTagIds = activeTagEdges.map((e) => e.stringId).toSet();
     
     final validTags = _filterStringsByRoot(strings, rootId)
         .where((t) => t.type != 'FOLDER' && activeTagIds.contains(t.id))
         .toList();
         
     final Map<int, String> names = {};
     for(var s in validTags) {
        final tr = await i18n.getTranslationById(s.id, 'en');
        names[s.id] = tr ?? (s.key.contains('___') ? s.key.substring(0, s.key.lastIndexOf('___')) : s.key);
     }
     
     if (mounted) {
       setState(() {
          _tags = validTags;
          _tagNames = names;
       });
     }
  }

  List<SystemString> _filterStringsByRoot(List<SystemString> sourceTags, int? rootId) {
     if (rootId == null) return sourceTags;
     Set<int> validIds = {};
     List<int> q = [rootId];
     while(q.isNotEmpty) {
        int curr = q.removeLast();
        for(var t in sourceTags) {
           if (t.parentId == curr && !validIds.contains(t.id)) {
              validIds.add(t.id);
              if (t.type == 'FOLDER') q.add(t.id);
           }
        }
     }
     return sourceTags.where((t) => validIds.contains(t.id)).toList();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _playItem(Item item, List<Item> queueContext) async {
    if (_resolvingIds.contains(item.id)) return;

    final player = context.read<PlayerController>();
    final resolver = context.read<StorageUrlResolver>();
    final assetsDao = context.read<AssetsDao>();

    final prefs = await SharedPreferences.getInstance();
    bool playInCollectionContext = prefs.getBool('play_in_collection_context') ?? true;

    if (!mounted) return;

    setState(() {
      _resolvingIds.add(item.id);
    });

    try {
      final url = await resolver.resolveUrlForItem(item);
      if (url == null) {
        if (mounted) {
          setState(() {
            _failedIds.add(item.id);
          });
        }
        return;
      }

      List<Item> targetQueue = queueContext;

      if (playInCollectionContext && item.collectionId != null && int.tryParse(item.collectionId!) != null) {
        final localAssets = await assetsDao.getAssetsInFolder(int.parse(item.collectionId!));
        if (localAssets.isNotEmpty) {
          targetQueue = localAssets.map((a) => Item(
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

      final index = targetQueue.indexWhere((t) => t.id == item.id);
      if (index >= 0) {
        await player.loadQueue(queue, startIndex: index, autoplay: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _resolvingIds.remove(item.id);
        });
      }
    }
  }

  void _showSettingsSheet() async {
    final prefs = await SharedPreferences.getInstance();
    bool playInCollectionContext = prefs.getBool('play_in_collection_context') ?? true;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Search Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Play item in collection context'),
                      subtitle: const Text(
                          'When tapping a item result, play it within its collection queue instead of the search results.'),
                      value: playInCollectionContext,
                      onChanged: (val) async {
                        await prefs.setBool('play_in_collection_context', val);
                        setSheetState(() => playInCollectionContext = val);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchController = context.watch<AppSearchController>();
    final debouncedQuery = searchController.debouncedQuery;
    final theme = Theme.of(context);

    return ActiveScreenScope(
      screenName: 'Search',
      child: Scaffold(
        appBar: AppBar(
        title: RegisteredElement(
          id: 'search_input_field',
          meta: const {'type': 'Text'},
          child: TextField(
            controller: _textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search collections or items...',
              border: InputBorder.none,
            ),
            onChanged: (val) {
              context.read<AppSearchController>().setQuery(val);
            },
          ),
        ),
        actions: MediaQuery.of(context).size.width < 250 ? null : [
          if (searchController.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _textController.clear();
                context.read<AppSearchController>().clear();
              },
            ),
          RegisteredElement(
            id: 'search_btn_settings',
            meta: const {'type': 'Button'},
            child: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showSettingsSheet(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          _buildActiveTags(theme),
          Expanded(
            child: debouncedQuery.isEmpty
                ? CustomScrollView(
                    slivers: [
                       SliverToBoxAdapter(child: _buildSmartMixHero(theme)),
                       SliverToBoxAdapter(child: _buildThemedTagRails(theme)),
                       if (_tags.isNotEmpty) const SliverToBoxAdapter(child: Divider()),
                       _buildRecentSearchesSliver(theme),
                    ],
                  )
                : CustomScrollView(
                    slivers: [
                      if (_selectedFilter == 'All' ||
                          _selectedFilter == 'Collections')
                        _buildCollectionsSection(debouncedQuery, theme),
                      if (_selectedFilter == 'All' ||
                          _selectedFilter == 'Items')
                        _buildItemsSection(debouncedQuery, theme),
                    ],
                  ),
          ),
        ],
      ),
    ));
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: RegisteredElement(
        id: 'search_type_tabs',
        meta: const {'type': 'Buttons'},
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'All', label: Text('All')),
            ButtonSegment(value: 'Collections', label: Text('Collections')),
            ButtonSegment(value: 'Items', label: Text('Items')),
          ],
          selected: {_selectedFilter},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _selectedFilter = newSelection.first;
            });
          },
        ),
      ),
    );
  }

  Widget _buildActiveTags(ThemeData theme) {
    final filterCtrl = context.watch<TagFilterController>();
    if (filterCtrl.selectedTagIds.isEmpty) return const SizedBox.shrink();
    
    final activeTags = filterCtrl.selectedTagIds.map((id) => _tagNames[id] ?? '').where((n) => n.isNotEmpty).toList();
    if (activeTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
         width: double.infinity,
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
         ),
         child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
               children: [
                   Icon(Icons.filter_list, size: 16, color: theme.colorScheme.primary),
                   const SizedBox(width: 8),
                   ...activeTags.map((t) => 
                      Padding(
                         padding: const EdgeInsets.only(right: 6.0),
                         child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                               color: theme.colorScheme.primary,
                               borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text(t.toLowerCase(), style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                         )
                      )
                   )
               ]
            )
         )
      )
    );
  }

  Widget _buildSmartMixHero(ThemeData theme) {
     final filterCtrl = context.watch<TagFilterController>();
     if (filterCtrl.selectedTagIds.isEmpty) return const SizedBox.shrink();

     final activeNames = filterCtrl.selectedTagIds.map((id) => _tagNames[id]?.toLowerCase() ?? '').where((n) => n.isNotEmpty).toList();
     String mixName = "Your Smart Mix";
     if (activeNames.isNotEmpty) {
        if (activeNames.length == 1) {
          mixName = "${activeNames[0]} Mix".toUpperCase();
        } else if (activeNames.length == 2) mixName = "${activeNames[0]} & ${activeNames[1]} Mix".toUpperCase();
        else mixName = "${activeNames[0]} & More Mix".toUpperCase();
     }

     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
       child: Container(
         width: double.infinity,
         padding: const EdgeInsets.all(20),
         decoration: BoxDecoration(
            gradient: LinearGradient(
               colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer],
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
            ]
         ),
         child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Icon(Icons.auto_awesome, color: Colors.amberAccent),
               const SizedBox(height: 8),
               Text(mixName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
               const SizedBox(height: 4),
               Text('Generated from your active filter capsules', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8))),
            ]
         )
       )
     );
  }

  Widget _buildThemedTagRails(ThemeData theme) {
    if (_tags.isEmpty) return const SizedBox.shrink();
    final filterCtrl = context.watch<TagFilterController>();

    final Map<int?, List<SystemString>> groupedTags = {};
    for (var t in _tags) {
       groupedTags.putIfAbsent(t.parentId, () => []).add(t);
    }
    
    IconData getCategoryIcon(int? parentId) {
        return Icons.local_offer_outlined;
    }
    String getCategoryName(int? parentId) {
        if (parentId == null) return 'Tags';
        return _tagNames[parentId] ?? 'Tags';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: groupedTags.entries.map((entry) {
         final lineTags = entry.value;
         final catName = getCategoryName(entry.key);
         
         return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Padding(
                 padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
                 child: Row(
                    children: [
                       Icon(getCategoryIcon(entry.key), size: 14, color: theme.colorScheme.primary),
                       const SizedBox(width: 6),
                       Text(catName.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    ]
                 )
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: lineTags.map((t) {
                    final isSelected = filterCtrl.selectedTagIds.contains(t.id);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text((_tagNames[t.id] ?? t.key).toLowerCase()),
                        selected: isSelected,
                        onSelected: (selected) => filterCtrl.toggleTag(t.id),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        selectedColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                           color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        )
                      )
                    );
                  }).toList(),
                )
              ),
              const SizedBox(height: 8),
           ]
         );
      }).toList(),
    );
  }

  Widget _buildRecentSearchesSliver(ThemeData theme) {
    return StreamBuilder<List<RecentSearch>>(
      stream: context.read<RecentSearchesDao>().watchRecent(),
      builder: (context, snapshot) {
        final recent = snapshot.data ?? [];
        if (recent.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('Search for collections or items')),
            )
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
            if (index == 0) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Searches',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        context.read<RecentSearchesDao>().clearAll();
                      },
                      child: const Text('Clear'),
                    )
                  ],
                ),
              );
            }

            final item = recent[index - 1];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(item.query),
              onTap: () {
                _textController.text = item.query;
                _textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: item.query.length));
                context.read<AppSearchController>().setQuery(item.query);
              },
            );
          },
          childCount: recent.length + 1,
        ));
      },
    );
  }

  Widget _buildCollectionsSection(String query, ThemeData theme) {
    return StreamBuilder<List<Asset>>(
      stream: context.read<AssetsDao>().watchFoldersByQuery(query, limit: 10),
      builder: (context, snapshot) {
        final collections = snapshot.data ?? [];
        if (collections.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Collections',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final collection = collections[index];
                  return ListTile(
                    leading: const Icon(Icons.collections),
                    title: HighlightText(
                      text: collection.name,
                      query: query,
                    ),
                    subtitle: HighlightText(
                      text: collection.description ?? 'Folder',
                      query: query,
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/collection-detail', arguments: {
                        'collectionId': collection.id.toString(),
                        'collectionTitle': collection.name,
                        'collectionArtist': 'Unknown Artist',
                        'collectionArtworkUrl': null,
                      });
                    },
                  );
                },
                childCount: collections.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemsSection(String query, ThemeData theme) {
    return StreamBuilder<List<Asset>>(
      stream:
          context.read<AssetsDao>().watchFilesByQuery(query, limit: 50),
      builder: (context, snapshot) {
        final localItems = snapshot.data ?? [];
        if (localItems.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final items = localItems.map((a) => Item(
           id: a.id.toString(),
           title: a.name,
           assetFolderId: a.parentId,
           audioUrl: a.storagePath ?? '',
           collectionId: a.parentId?.toString(),
        )).toList();

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Items',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  return Builder(builder: (context) {
                    final isCurrent = context.select<PlayerController, bool>(
                        (p) => p.currentItem?.id == item.id);
                    final isResolving = _resolvingIds.contains(item.id);
                    final isFailed = _failedIds.contains(item.id);

                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: HighlightText(
                        text: item.title,
                        query: query,
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? theme.colorScheme.primary : null,
                        ),
                      ),
                      subtitle: HighlightText(
                        text: isFailed
                            ? 'Unavailable'
                            : (item.artist ?? 'Unknown Artist'),
                        query: query,
                        style: TextStyle(color: isFailed ? Colors.red : null),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isResolving)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                        ],
                      ),
                      onTap: isFailed ? null : () => _playItem(item, items),
                    );
                  });
                },
                childCount: items.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
