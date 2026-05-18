import 'dart:async';
import 'package:flutter/foundation.dart';

class SearchControllerState extends ChangeNotifier {
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  String get query => _query;
  String get debouncedQuery => _debouncedQuery;

  bool get hasFilters => _debouncedQuery.isNotEmpty;

  void setQuery(String newQuery) {
    _query = newQuery;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_debouncedQuery != _query) {
        _debouncedQuery = _query;
        notifyListeners();
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
