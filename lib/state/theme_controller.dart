import 'package:flutter/material.dart';
import '../scripts/tenant_service.dart';
import '../db/daos/user_preferences_dao.dart';

class ThemeController extends ChangeNotifier {
  final UserPreferencesDao _prefsDao;
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark as requested natively

  ThemeController(this._prefsDao) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    final tenantId = TenantService.currentTenantId ?? 0;
    final savedMode = await _prefsDao.getPreference(tenantId, 'theme_mode');
    if (savedMode == 'light') {
       _themeMode = ThemeMode.light;
       notifyListeners();
    } else if (savedMode == 'dark') {
       _themeMode = ThemeMode.dark;
       notifyListeners();
    }
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    return _themeMode == ThemeMode.dark || _themeMode == ThemeMode.system;
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light || _themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
    
    final tenantId = TenantService.currentTenantId ?? 0;
    await _prefsDao.setPreference(tenantId, 'theme_mode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }
}
