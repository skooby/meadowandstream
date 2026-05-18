import 'package:flutter/foundation.dart';

class TagFilterController extends ChangeNotifier {
  final Set<int> _selectedTagIds = {};

  Set<int> get selectedTagIds => Set.unmodifiable(_selectedTagIds);

  bool get hasFilters => _selectedTagIds.isNotEmpty;

  void toggleTag(int tagId) {
    if (_selectedTagIds.contains(tagId)) {
      _selectedTagIds.remove(tagId);
    } else {
      _selectedTagIds.add(tagId);
    }
    notifyListeners();
  }

  void clear() {
    _selectedTagIds.clear();
    notifyListeners();
  }
}
