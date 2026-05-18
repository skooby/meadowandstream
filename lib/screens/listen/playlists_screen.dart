import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/daos/playlists_dao.dart';
import '../../db/app_database.dart';
import '../../widgets/draggable_alert_dialog.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  void _showCreateDialog(BuildContext context) {
    final theme = Theme.of(context);
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => DraggableAlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist Name',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                await context.read<PlaylistsDao>().createPlaylist(name);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final theme = Theme.of(context);
    final textController = TextEditingController(text: playlist.name);

    showDialog(
      context: context,
      builder: (context) => DraggableAlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist Name',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty && name != playlist.name) {
                await context
                    .read<PlaylistsDao>()
                    .renamePlaylist(playlist.id, name);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Playlist playlist) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => DraggableAlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer),
            onPressed: () async {
              await context.read<PlaylistsDao>().deletePlaylist(playlist.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Delete',
                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistsDao = context.watch<PlaylistsDao>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Playlist'),
      ),
      body: StreamBuilder<List<PlaylistWithCount>>(
        stream: playlistsDao.watchPlaylistsWithCounts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final playlists = snapshot.data!;

          if (playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text('No playlists yet.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Space for FAB
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final item = playlists[index];
              final playlist = item.playlist;
              final count = item.itemCount;

              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.playlist_play),
                ),
                title: Text(playlist.name),
                subtitle: Text('$count item${count == 1 ? '' : 's'}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      _showRenameDialog(context, playlist);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, playlist);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/playlist',
                      arguments: playlist);
                },
              );
            },
          );
        },
      ),
    );
  }
}
