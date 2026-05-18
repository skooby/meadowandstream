import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/daos/recent_searches_dao.dart';

class AppSearchController extends ChangeNotifier {
  final RecentSearchesDao _recentSearchesDao;

  AppSearchController(this._recentSearchesDao);

  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  String get query => _query;
  String get debouncedQuery => _debouncedQuery;

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_debouncedQuery != _query) {
        _debouncedQuery = _query;
        notifyListeners();

        final trimmed = _debouncedQuery.trim();
        if (trimmed.length >= 2) {
          _recentSearchesDao.upsertQuery(trimmed);
          _recentSearchesDao.pruneToLimit(20);
        }
      }
    });
  }

  void clear() {
    setQuery('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
