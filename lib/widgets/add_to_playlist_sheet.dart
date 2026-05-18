import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item.dart';
import '../../db/daos/playlists_dao.dart';
import '../../db/daos/playlist_items_dao.dart';

import 'draggable_alert_dialog.dart';

class AddToPlaylistSheet extends StatefulWidget {
  final Item? item;
  final List<Item>? items;

  const AddToPlaylistSheet({super.key, this.item, this.items})
      : assert(item != null || items != null);

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  late Stream<List<PlaylistWithCount>> _playlistsStream;
  Future<Set<String>>? _existingPlaylistsFuture;

  List<Item> get _effectiveItems => widget.items ?? [widget.item!];

  @override
  void initState() {
    super.initState();
    final playlistsDao = context.read<PlaylistsDao>();
    _playlistsStream = playlistsDao.watchPlaylistsWithCounts();

    if (widget.item != null) {
      _existingPlaylistsFuture = context
          .read<PlaylistItemsDao>()
          .getPlaylistsContainingItem(widget.item!.id);
    }
  }

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
                final newId =
                    await context.read<PlaylistsDao>().createPlaylist(name);
                if (context.mounted) {
                  // Wait to close the dialog, then add item
                  Navigator.pop(context);
                  _addToPlaylist(context, newId, name);
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _addToPlaylist(
      BuildContext context, String playlistId, String playlistName) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final toAdd = _effectiveItems;
      final result = await context
          .read<PlaylistItemsDao>()
          .addItemsBatch(playlistId, toAdd);

      final added = result.$1;
      final duplicates = result.$2;

      String message;
      if (toAdd.length == 1) {
        if (duplicates > 0) {
          message = 'Already in "$playlistName"';
        } else {
          message = 'Added to "$playlistName"';
        }
      } else {
        message = 'Added $added items to "$playlistName"';
        if (duplicates > 0) {
          message += ' ($duplicates already added)';
        }
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to add: $e')),
      );
    } finally {
      if (nav.canPop()) {
        nav.pop(); // Close the sheet
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Add to Playlist',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New Playlist'),
            onTap: () {
              _showCreateDialog(context);
            },
          ),
          const Divider(),
          Flexible(
            child: StreamBuilder<List<PlaylistWithCount>>(
              stream: _playlistsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator()));
                }

                final playlists = snapshot.data ?? [];

                if (playlists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No saved playlists yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // If doing a batch operation, no need to load existing future set
                if (widget.items != null) {
                  return _buildListView(context, playlists, null, theme);
                }

                // Wait for the fast combined SQLite lookup
                return FutureBuilder<Set<String>>(
                  future: _existingPlaylistsFuture,
                  builder: (context, futureSnapshot) {
                    if (futureSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final existingSet = futureSnapshot.data ?? {};
                    return _buildListView(
                        context, playlists, existingSet, theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<PlaylistWithCount> playlists,
      Set<String>? existingSet, ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pItem = playlists[index];
        final p = pItem.playlist;
        final count = pItem.itemCount;

        if (widget.items != null) {
          // Batch mode
          return ListTile(
            leading: const Icon(Icons.queue_music),
            title: Text(p.name),
            subtitle: Text('$count item${count == 1 ? '' : 's'}'),
            onTap: () => _addToPlaylist(context, p.id, p.name),
          );
        }

        final hasItem = existingSet?.contains(p.id) ?? false;

        return ListTile(
          leading: const Icon(Icons.queue_music),
          title: Text(
            p.name,
            style: TextStyle(
              color: hasItem
                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                  : null,
            ),
          ),
          subtitle: Text(
            hasItem ? 'Already added' : '$count item${count == 1 ? '' : 's'}',
            style: TextStyle(
              color: hasItem ? theme.colorScheme.error : null,
            ),
          ),
          enabled: !hasItem,
          onTap: hasItem ? null : () => _addToPlaylist(context, p.id, p.name),
        );
      },
    );
  }
}
