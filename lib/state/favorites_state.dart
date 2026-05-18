import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/daos/favorites_dao.dart';

/// Holds the in-memory set of favorited item and collection IDs for O(1) synchronous lookups in lists
/// without requiring hundreds of sqlite database StreamBuilders.
class FavoritesState extends ChangeNotifier {
  final FavoritesDao _favoritesDao;

  final Set<String> _collectionIds = {};
  final Set<String> _itemIds = {};

  StreamSubscription? _collectionsSub;
  StreamSubscription? _itemsSub;

  FavoritesState(this._favoritesDao) {
    _init();
  }

  void _init() {
    _collectionsSub = _favoritesDao.watchFavoriteCollections().listen((collections) {
      _collectionIds.clear();
      _collectionIds.addAll(collections.map((a) => a.id.toString()));
      notifyListeners();
    });

    _itemsSub = _favoritesDao.watchFavoriteItems().listen((items) {
      _itemIds.clear();
      _itemIds.addAll(items.map((t) => t.id.toString()));
      notifyListeners();
    });
  }

  bool isCollectionFavorited(String id) => _collectionIds.contains(id);
  bool isItemFavorited(String id) => _itemIds.contains(id);
  
  Set<String> get favoriteItemIds => _itemIds;
  Set<String> get favoriteCollectionIds => _collectionIds;

  Future<void> toggleCollection(String id) async {
    // Optimistic UI update
    if (_collectionIds.contains(id)) {
      _collectionIds.remove(id);
    } else {
      _collectionIds.add(id);
    }
    notifyListeners();
    await _favoritesDao.toggleCollection(id);
  }

  Future<void> toggleItem(String id) async {
    // Optimistic UI update
    if (_itemIds.contains(id)) {
      _itemIds.remove(id);
    } else {
      _itemIds.add(id);
    }
    notifyListeners();
    await _favoritesDao.toggleItem(id);
  }

  @override
  void dispose() {
    _collectionsSub?.cancel();
    _itemsSub?.cancel();
    super.dispose();
  }
}
