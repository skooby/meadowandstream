import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/item.dart';
import '../../db/daos/assets_dao.dart';

import '../../services/storage_url_resolver.dart';
import 'player_controller.dart';
import '../../models/item_source.dart';
import '../../state/tag_filter_controller.dart';
import '../../scripts/tenant_service.dart';

class CollectionItemsController extends ChangeNotifier {
  final AssetsDao _assetsDao;
  final StorageUrlResolver _resolver;
  final TagFilterController _tagFilterController;
  final String collectionId;

  StreamSubscription<List<Item>>? _subscription;
  List<Item> _items = [];
  bool _hasLoaded = false;
  bool _isDisposed = false;
  String? _error;

  final Set<String> _resolvingIds = {};
  final Set<String> _failedIds = {};



  CollectionItemsController(this._assetsDao, this._resolver,
      this._tagFilterController, this.collectionId) {
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

    _subscription = _assetsDao
        .watchAssetsInFolder(TenantService.currentTenantId ?? 0, int.tryParse(collectionId) ?? 0)
        .asyncMap((localList) async {
            final Map<String, Item> resolvedItems = {};
            
            for (var a in localList) {
               if (a.type == 'FILE' || a.type == 'TRACK') {
                   if ((a.mimeType ?? '').startsWith('audio/') || a.name.toLowerCase().endsWith('.mp3')) {
                       String cleanTitle = a.name.replaceAll(RegExp(r'\.mp3$|\.wav$', caseSensitive: false), '');
                       resolvedItems[a.id.toString()] = Item(id: a.id.toString(), title: cleanTitle, assetFolderId: a.parentId, audioUrl: a.storagePath ?? '', collectionId: a.parentId?.toString());
                   }
               } else if (a.type == 'FOLDER') {
                   // This is a dedicated Track Folder nested dynamically inside the Album!
                   final subFiles = await _assetsDao.getAssetsInFolder(a.id);
                   final audioFile = subFiles.where((sf) => (sf.mimeType ?? '').startsWith('audio/') || sf.name.toLowerCase().endsWith('.mp3')).firstOrNull;
                   
                   if (audioFile != null) {
                       // THE FIX: Title cleanly mirrors the outer generic Track Folder exactly, skipping internal raw ugly filenames
                       resolvedItems[a.id.toString()] = Item(
                           id: a.id.toString(), 
                           title: a.name, 
                           assetFolderId: a.parentId, 
                           audioUrl: audioFile.storagePath ?? '', 
                           collectionId: a.parentId?.toString()
                       );
                   }
               }
            }
            final finalItems = resolvedItems.values.toList();
            // Optional: Maintain organic drift sorting order over alphanumeric sorting for albums
            return finalItems;
        })
        .listen((mappedList) {
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
      debugPrint('CollectionItemsController: Requesting url resolution for tappedItem "${tappedItem.title}"');
      final url = await _resolver.resolveUrlForItem(tappedItem);
      debugPrint('CollectionItemsController: Final resolved URL -> $url');
      
      await _resolver.resolveUrlsForItems(_items);

      final queue = _items.map((t) {
        final cachedUrl = _resolver.getCachedUrl(t.audioUrl);
        final sourceUrl = (t.id == tappedItem.id) ? (url ?? cachedUrl ?? t.audioUrl) : (cachedUrl ?? t.audioUrl);
        final SourceType st;
        if (sourceUrl.startsWith('assets/')) {
          st = SourceType.asset;
        } else if (sourceUrl.startsWith('/') || sourceUrl.startsWith('C:') || sourceUrl.startsWith('file:')) {
          st = SourceType.file;
        } else {
          st = SourceType.url;
        }
        debugPrint('CollectionItemsController: Queue Mapper -> Track: ${t.title} evaluates to SourceType.${st.name} | URL: $sourceUrl');
        return ItemSource(
          id: t.id,
          title: t.title,
          artist: t.artist,
          sourceType: st,
          source: sourceUrl,
          artworkAsset: t.artworkUrl,
        );
      }).toList();

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
