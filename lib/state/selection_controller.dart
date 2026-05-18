import 'package:flutter/foundation.dart';

class SelectionController extends ChangeNotifier {
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  bool get isSelecting => _isSelecting;
  Set<String> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;

  void enterSelectMode() {
    _isSelecting = true;
    _selectedIds.clear();
    notifyListeners();
  }

  void exitSelectMode() {
    _isSelecting = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggle(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clear() {
    _selectedIds.clear();
    notifyListeners();
  }

  bool isSelected(String id) => _selectedIds.contains(id);
}
