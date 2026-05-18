import 'package:flutter/material.dart';
import '../../engine/ui_inspector/element_registry.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/daos/assets_dao.dart';
import '../../models/app_album.dart';
import '../../app/routes.dart';

class MappedAlbumsScreen extends StatefulWidget {
  const MappedAlbumsScreen({super.key});

  @override
  State<MappedAlbumsScreen> createState() => _MappedAlbumsScreenState();
}

class _MappedAlbumsScreenState extends State<MappedAlbumsScreen> {
  List<int> _albumFolderIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final albumStr = prefs.getStringList('project_album_folder_ids') ?? [];
    if (mounted) {
      setState(() {
        _albumFolderIds = albumStr.map(int.parse).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return ActiveScreenScope(
      screenName: 'Albums',
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: StreamBuilder<List<AppAlbum>>(
        stream: context.read<AssetsDao>().watchConfiguredAlbums(_albumFolderIds),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final albums = snapshot.data!;
          if (albums.isEmpty) return const Center(child: Text('No albums found in configured folders.', style: TextStyle(color: Colors.grey)));
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 2,
               childAspectRatio: 0.8,
               crossAxisSpacing: 16,
               mainAxisSpacing: 16,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
               final album = albums[index];
               final cover = album.coverArt;
               return RegisteredElement(
                 id: 'album_card_${album.albumFolder.id}',
                 meta: {'type': 'AlbumCard', 'title': album.albumFolder.name, 'tracks_count': album.tracks.length},
                 child: GestureDetector(
                   onTap: () {
                      Navigator.pushNamed(context, AppRoutes.collectionDetail, arguments: {
                         'collectionId': (album.albumFolder.id).toString(),
                         'collectionTitle': album.albumFolder.name,
                         'collectionArtworkUrl': cover?.storagePath,
                      });
                   },
                   child: Card(
                     clipBehavior: Clip.antiAlias,
                     elevation: 2,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                         Expanded(
                           child: cover?.storagePath != null
                              ? Image.network(cover!.storagePath!, fit: BoxFit.cover)
                              : Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.album, size: 48, color: Colors.grey),
                                ),
                         ),
                         Padding(
                           padding: const EdgeInsets.all(8.0),
                           child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text(
                                    album.albumFolder.name, 
                                    style: Theme.of(context).textTheme.titleSmall, 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis
                                 ),
                                 const SizedBox(height: 2),
                                 Text(
                                    '${album.tracks.length} tracks', 
                                    style: Theme.of(context).textTheme.bodySmall
                                 ),
                              ]
                           )
                         ),
                       ]
                     )
                   )
                 )
               );
            }
          );
        }
      )
    ));
  }
}
