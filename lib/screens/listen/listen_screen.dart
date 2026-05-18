import 'package:flutter/material.dart';
import '../../engine/ui_inspector/element_registry.dart';
import '../../constants.dart';

import '../../scripts/supabase_service.dart';
import '../../state/theme_controller.dart';
import '../../state/item_catalog_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/daos/assets_dao.dart';
import '../../db/daos/playlists_dao.dart';
import '../../db/daos/recent_plays_dao.dart';
import '../../db/daos/favorites_dao.dart';
import '../../db/app_database.dart' show Playlist, RecentPlay, Asset;
import '../../models/app_album.dart';
import '../../app/routes.dart';
import '../../widgets/horizontal_media_rail.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  List<int> _albumFolderIds = [];
  List<String> _sectionOrder = ['recents', 'favorites', 'playlists', 'albums', 'allItems'];

  @override
  void initState() {
    super.initState();
    _loadAlbumConfig();
    _loadSectionOrder();
  }

  Future<void> _loadSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> defaultOrder = ['recents', 'favorites', 'playlists', 'albums', 'allItems'];
    final List<String> savedOrder = (prefs.getStringList('listen_screen_section_order') ?? []).toList();
    
    // Ensure backwards compatibility with missing new sections
    for (final sec in defaultOrder) {
      if (!savedOrder.contains(sec)) savedOrder.add(sec);
    }
    
    // Extricate obsolete sections mapping incorrectly natively perfectly smoothly safely accurately physically reliably correctly perfectly precisely
    savedOrder.retainWhere((sec) => defaultOrder.contains(sec));

    if (mounted) {
       setState(() {
          _sectionOrder = savedOrder;
       });
    }
  }



  Future<void> _loadAlbumConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final albumStr = prefs.getStringList('project_album_folder_ids') ?? [];
    if (mounted) {
      setState(() {
        _albumFolderIds = albumStr.map(int.parse).toList();
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActiveScreenScope(
      screenName: 'Listen',
      child: Scaffold(
        body: Stack(
          children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  backgroundColor: innerBoxIsScrolled ? (theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface).withOpacity(0.5) : theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
                  elevation: innerBoxIsScrolled ? 0 : 4,
                  scrolledUnderElevation: 0,
                  title: const RegisteredElement(
                    id: 'listen_screen_title',
                    meta: {'type': 'Text'},
                    child: Text(AppStrings.screenListen),
                  ),
                  actions: MediaQuery.of(context).size.width < 250 ? null : [
                    if (MediaQuery.of(context).size.width >= 320) ...[
                      RegisteredElement(
                         id: 'listen_screen_btn_search',
                         meta: const {'type': 'Button'},
                         child: IconButton(
                           icon: const Icon(Icons.search),
                           onPressed: () => Navigator.pushNamed(context, '/search'),
                           tooltip: 'Search the catalog',
                         )
                      ),
                      RegisteredElement(
                         id: 'listen_screen_btn_theme',
                         meta: const {'type': 'Button'},
                         child: IconButton(
                           icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
                           onPressed: () {
                              debugPrint("THEME BUTTON CLICKED");
                              context.read<ThemeController>().toggleTheme();
                           },
                         )
                      ),
                      RegisteredElement(
                         id: 'listen_screen_btn_refresh',
                         meta: const {'type': 'Button'},
                         child: IconButton(
                           icon: const Icon(Icons.refresh),
                           onPressed: () {
                             context.read<ItemCatalogController>().loadInitial();
                           },
                         )
                      ),
                    ],
                    RegisteredElement(
                       id: 'listen_screen_btn_options',
                       meta: const {'type': 'Button'},
                       child: IconButton(
                       icon: const Icon(Icons.more_vert),
                       onPressed: () {
                         showModalBottomSheet(
                             context: context,
                             useRootNavigator: false,
                             builder: (sheetContext) {
                               return SafeArea(
                                 child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     ListTile(
                                       leading: const Icon(Icons.settings),
                                       title: const Text('Settings'),
                                       onTap: () {
                                         Navigator.pop(sheetContext);
                                         Navigator.of(context).pushNamed('/cache');
                                       },
                                     ),
                                     ListTile(
                                       leading: const Icon(Icons.logout),
                                       title: const Text('Sign Out'),
                                       onTap: () async {
                                         Navigator.pop(sheetContext);
                                         context.read<ItemCatalogController>().clear();
                                         await SupabaseService().signOut();
                                       },
                                     ),
                                   ],
                                 ),
                               );
                             },
                           );
                         },
                       )
                    ),
                  ],
                ),
                const SliverToBoxAdapter(
                  child: SizedBox.shrink(),
                ),
              ];
            },
            body: Padding(
               padding: const EdgeInsets.only(bottom: 20.0),
               child: _buildCurrentSection(theme),
            ),
          ),
        ],
      ),
    ));
  }



  Widget _buildCurrentSection(ThemeData theme) {
    return ReorderableListView(
      padding: const EdgeInsets.only(top: 16),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
         setState(() {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final item = _sectionOrder.removeAt(oldIndex);
            _sectionOrder.insert(newIndex, item);
         });
         SharedPreferences.getInstance().then((prefs) {
            prefs.setStringList('listen_screen_section_order', _sectionOrder);
         });
      },
      children: _sectionOrder.asMap().entries.map((entry) {
        final index = entry.key;
        final sectionId = entry.value;
        Widget child;
        switch (sectionId) {
          case 'recents': child = _buildRecentsCarousel(theme, index); break;
          case 'favorites': child = _buildFavoritesCarousel(theme, index); break;
          case 'playlists': child = _buildPlaylistsCarousel(theme, index); break;
          case 'albums': child = _buildAlbumsCarousel(theme, index); break;
          case 'allItems': child = _buildAllItemsBanner(theme, index); break;
          default: child = const SizedBox.shrink();
        }
        return KeyedSubtree(
          key: ValueKey(sectionId),
          child: child,
        );
      }).toList(),
    );
  }

  Widget _buildCard(String categoryPrefix, String objectId, String title, String? subtitle, {IconData? icon, VoidCallback? onTap}) {
    return RegisteredElement(
       id: 'listen_card_${categoryPrefix}_${objectId}_${title.replaceAll(' ', '_').toLowerCase()}',
       meta: const {'type': 'Card'},
       child: GestureDetector(
         onTap: onTap,
         child: Container(
           width: 140,
           decoration: BoxDecoration(
             color: Theme.of(context).cardColor,
             borderRadius: BorderRadius.circular(12),
           ),
           clipBehavior: Clip.antiAlias,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Container(
                 height: 100,
                 color: Colors.black12,
                 child: Center(
                   child: Icon(icon ?? Icons.music_note, size: 40, color: Colors.grey),
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.all(8.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                     if (subtitle != null) ...[
                       const SizedBox(height: 2),
                       Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                     ]
                   ],
                 ),
               )
             ],
           ),
         ),
       )
    );
  }

  Widget _buildRecentsCarousel(ThemeData theme, int index) {
     return StreamBuilder<List<RecentPlay>>(
        stream: context.read<RecentPlaysDao>().watchRecent(limit: 50).map((items) {
           final keys = <String>{};
           return items.where((item) => keys.add(item.itemId)).take(10).toList();
        }),
        builder: (context, snapshot) {
           final items = snapshot.data ?? [];
           if (items.isEmpty) return const SizedBox.shrink();
           return HorizontalMediaRail(
              title: 'Recently Played',
              reorderIndex: index,
              onSeeAll: () => Navigator.pushNamed(context, AppRoutes.recent),
              items: items.map((t) => _buildCard('recent', t.itemId.toString(), t.title ?? 'Unknown', t.artist, icon: Icons.history)).toList()
           );
        }
     );
  }

  Widget _buildFavoritesCarousel(ThemeData theme, int index) {
     return StreamBuilder<List<Asset>>(
        stream: context.read<FavoritesDao>().watchFavoriteItems(),
        builder: (context, snapshot) {
           final items = snapshot.data ?? [];
           if (items.isEmpty) return const SizedBox.shrink();
           final reScrubbed = RegExp(r'\.mp3$|\.wav$', caseSensitive: false);
           return HorizontalMediaRail(
              title: 'Favorites',
              reorderIndex: index,
              onSeeAll: () => Navigator.pushNamed(context, AppRoutes.favorites),
              items: items.take(10).map((t) {
                 final cleanTitle = t.name.replaceAll(reScrubbed, '');
                 return _buildCard('favorite', t.id.toString(), cleanTitle, null, icon: Icons.favorite);
              }).toList()
           );
        }
     );
  }

  Widget _buildPlaylistsCarousel(ThemeData theme, int index) {
     return StreamBuilder<List<Playlist>>(
        stream: context.read<PlaylistsDao>().watchPlaylists(),
        builder: (context, snapshot) {
           final items = snapshot.data ?? [];
           if (items.isEmpty) return const SizedBox.shrink();
           return HorizontalMediaRail(
              title: 'Playlists',
              reorderIndex: index,
              onSeeAll: () => Navigator.pushNamed(context, AppRoutes.playlists),
              items: items.take(10).map((t) => _buildCard('playlist', t.id.toString(), t.name, null, icon: Icons.playlist_play, onTap: () => Navigator.pushNamed(context, AppRoutes.playlist, arguments: t))).toList()
           );
        }
     );
  }

  Widget _buildAlbumsCarousel(ThemeData theme, int index) {
     if (_albumFolderIds.isEmpty) return const SizedBox.shrink();
     return StreamBuilder<List<AppAlbum>>(
        stream: context.read<AssetsDao>().watchConfiguredAlbums(_albumFolderIds),
        builder: (context, snapshot) {
           final items = snapshot.data ?? [];
           if (items.isEmpty) return const SizedBox.shrink();
           return HorizontalMediaRail(
              title: 'Albums',
              reorderIndex: index,
              onSeeAll: () => Navigator.pushNamed(context, '/mapped-albums'),
              items: items.take(10).map((a) => _buildCard('album', a.albumFolder.id.toString(), a.albumFolder.name, a.albumFolder.description, icon: Icons.album, onTap: () => Navigator.pushNamed(context, AppRoutes.collectionDetail, arguments: {
                  'collectionId': a.albumFolder.id.toString(), 'collectionTitle': a.albumFolder.name, 'collectionArtist': a.albumFolder.description
                 }))).toList()
           );
        }
     );
  }
  
  Widget _buildAllItemsBanner(ThemeData theme, int index) {
     return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: InkWell(
           borderRadius: BorderRadius.circular(12),
           onTap: () => Navigator.pushNamed(context, AppRoutes.items),
           child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
             decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1))
             ),
             child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.library_music, color: theme.colorScheme.primary),
                  ],
                ),
                title: Text('Browse All Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurfaceVariant),
             )
           )
        )
     );
  }


}
