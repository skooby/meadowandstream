import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/app_database.dart';
import '../../db/daos/recent_plays_dao.dart';
import '../../db/daos/assets_dao.dart';
import '../../services/storage_url_resolver.dart';
import '../../state/player_controller.dart';
import '../../models/item.dart';
import '../../models/item_source.dart';

class RecentlyPlayedController extends ChangeNotifier {
  final RecentPlaysDao _recentPlaysDao;
  final AssetsDao _assetsDao;
  final StorageUrlResolver _resolver;

  StreamSubscription<List<RecentPlay>>? _subscription;
  List<RecentPlay> _recentPlays = [];
  String? _error;

  final Set<String> _resolvingIds = {};
  final Set<String> _failedIds = {};

  RecentlyPlayedController(
      this._recentPlaysDao, this._assetsDao, this._resolver);

  String? get error => _error;
  List<RecentPlay> get recentPlays => _recentPlays;

  bool isResolving(String id) => _resolvingIds.contains(id);
  bool isFailed(String id) => _failedIds.contains(id);

  void start() {
    if (_subscription != null) return;

    _subscription = _recentPlaysDao.watchRecent(limit: 50).listen((list) {
      _recentPlays = list;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<void> resolveAndPlaySingle(
      RecentPlay play, PlayerController player) async {
    if (isResolving(play.itemId)) return;

    _resolvingIds.add(play.itemId);
    notifyListeners();

    try {
      final parsedId = int.tryParse(play.itemId);
      if (parsedId == null) {
        _failedIds.add(play.itemId);
        return;
      }
      final asset = await _assetsDao.getAssetById(parsedId);

      if (asset == null) {
        _failedIds.add(play.itemId);
        return;
      }

      final item = Item(
         id: asset.id.toString(),
         title: asset.name,
         assetFolderId: asset.parentId,
         collectionId: asset.parentId?.toString(),
         audioUrl: asset.storagePath ?? '',
      );
      final url = await _resolver.resolveUrlForItem(item);

      if (url == null) {
        _failedIds.add(play.itemId);
      } else {
        final source = ItemSource(
          id: item.id,
          title: item.title,
          artist: item.artist,
          sourceType: SourceType.url,
          source: url,
          artworkAsset: item.artworkUrl,
        );

        // Load as a queue of 1
        await player.loadQueue([source], startIndex: 0, autoplay: true);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _resolvingIds.remove(play.itemId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class RecentlyPlayedScreen extends StatelessWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RecentlyPlayedController(
        context.read<RecentPlaysDao>(),
        context.read<AssetsDao>(),
        context.read<StorageUrlResolver>(),
      )..start(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<RecentlyPlayedController>(
          builder: (context, controller, child) {
            if (controller.recentPlays.isEmpty) {
              if (controller.error != null) {
                return Center(child: Text('Error: ${controller.error}'));
              }
              // It could just be empty, wait a tiny bit or assume empty if length is 0 and no error.
              // Stream will normally yield empty list instantly.
              return const Center(child: Text('No recent plays yet'));
            }

            final theme = Theme.of(context);

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: controller.recentPlays.length,
              itemBuilder: (context, index) {
                final play = controller.recentPlays[index];

                final isCurrent =
                    context.watch<PlayerController>().currentItem?.id ==
                        play.itemId;
                final isResolving = controller.isResolving(play.itemId);
                final isFailed = controller.isFailed(play.itemId);

                // Relative time could go here, for now just literal or nothing special

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(
                    play.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? theme.colorScheme.primary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isFailed
                        ? 'Unavailable'
                        : (play.artist ?? 'Unknown Artist'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isFailed ? Colors.red : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isResolving
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: Icon(isCurrent &&
                                  context.watch<PlayerController>().isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill),
                          iconSize: 36,
                          color: isFailed
                              ? Colors.grey
                              : theme.colorScheme.primary,
                          onPressed: (!isFailed)
                              ? () {
                                  final player =
                                      context.read<PlayerController>();

                                  if (isCurrent) {
                                    player.togglePlayPause();
                                  } else {
                                    controller.resolveAndPlaySingle(
                                        play, player);
                                  }
                                }
                              : null,
                        ),
                  onTap: () {
                    if (!isFailed) {
                      controller.resolveAndPlaySingle(
                          play, context.read<PlayerController>());
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
