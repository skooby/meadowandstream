import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../db/app_database.dart';
import '../db/daos/assets_dao.dart';
import '../services/storage_url_resolver.dart';
import 'player_controller.dart';
import '../models/item_source.dart';
import '../repositories/assets_sync_service.dart';

class ItemCatalogController extends ChangeNotifier {
  final AssetsDao _assetsDao;
  final AssetsSyncService _syncService;
  final StorageUrlResolver _resolver;

  StreamSubscription<List<Asset>>? _subscription;

  List<Item> _items = [];
  List<LocalCollection> _collections = [];
  int? _selectedCollectionId; // Asset parentId representation

  bool _isLoading = false;
  String? _error;
  bool _hasInitialSynced = false;
  Timer? _periodicSyncTimer;

  final Set<String> _resolvingIds = {};
  final Set<String> _failedIds = {};

  ItemCatalogController(
    this._assetsDao,
    this._syncService,
    this._resolver,
  );

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Item> get items => _items;
  List<LocalCollection> get collections => _collections;
  String? get selectedCollectionId => _selectedCollectionId?.toString();
  bool get hasMore => false;

  bool isResolving(String id) => _resolvingIds.contains(id);
  bool isFailed(String id) => _failedIds.contains(id);

  void start() {
    if (_subscription != null) return;

    _listenToAssets();

    if (!_hasInitialSynced) {
      loadInitial();
    }

    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _syncService.sync();
    });
  }

  void _listenToAssets() {
    _subscription?.cancel();

    _subscription = _assetsDao.watchAllAssets().listen((allAssets) {
       final rawCollections = allAssets.where((a) => a.type == 'FOLDER').toList();
       rawCollections.sort((a,b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
       _collections = rawCollections.map((a) => LocalCollection(
           id: a.id.toString(),
           title: a.name,
           artist: null, // Assets FOLDERs do not natively host an artist metadata context cleanly yet
           artworkUrl: null,
       )).toList();

       // Sub-query files inside selected folder, or all if none
       final rawFiles = allAssets.where((a) => a.type == 'FILE' && (_selectedCollectionId == null || a.parentId == _selectedCollectionId)).toList();
       _items = rawFiles.map((a) => Item(
           id: a.id.toString(),
           title: a.name,
           assetFolderId: a.parentId,
           collectionId: a.parentId?.toString(),
           audioUrl: a.storagePath ?? '',
       )).toList();

       notifyListeners();
    }, onError: (e) {
       _error = e.toString();
       notifyListeners();
    });
  }

  void setCollectionFilter(String? collectionId) {
    _selectedCollectionId = collectionId != null ? int.tryParse(collectionId) : null;
    _listenToAssets();
    notifyListeners();
  }

  Future<void> loadInitial() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _syncService.sync();
      _hasInitialSynced = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {}

  Future<void> resolveAndPlayQueue(
      Item tappedItem, PlayerController player) async {
    if (isResolving(tappedItem.id)) return;

    _resolvingIds.add(tappedItem.id);
    notifyListeners();

    try {
      debugPrint('ItemCatalogController: Requesting url resolution for tappedItem "${tappedItem.title}"');
      final url = await _resolver.resolveUrlForItem(tappedItem);
      debugPrint('ItemCatalogController: Final resolved URL -> $url');

      if (url == null) {
        debugPrint('ItemCatalogController ERROR: Resolved URL is completely null for ${tappedItem.title}');
        _failedIds.add(tappedItem.id);
      } else {
        debugPrint('ItemCatalogController: Proceeding to map full queue of ${_items.length} items');
        final queue = _items.map((t) {
          final sourceUrl = (t.id == tappedItem.id) ? url : t.audioUrl;
          final SourceType st;
          if (sourceUrl.startsWith('assets/')) {
            st = SourceType.asset;
          } else if (sourceUrl.startsWith('/') || sourceUrl.startsWith('C:') || sourceUrl.startsWith('file:')) {
            st = SourceType.file;
          } else {
            st = SourceType.url;
          }
          debugPrint('ItemCatalogController: Queue Mapper -> Track: ${t.title} evaluates to SourceType.${st.name} | URL: $sourceUrl');
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
      }
    } finally {
      _resolvingIds.remove(tappedItem.id);
      notifyListeners();
    }
  }

  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;

    _items.clear();
    _collections.clear();
    _selectedCollectionId = null;
    _error = null;
    _isLoading = false;
    _hasInitialSynced = false;
    _resolvingIds.clear();
    _failedIds.clear();

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}
