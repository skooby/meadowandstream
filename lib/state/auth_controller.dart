import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../db/daos/playback_dao.dart';
import '../services/auto_cache_manager.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;
  final PlaybackDao _playbackDao;
  final AutoCacheManager _autoCacheManager;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoading = true;
  Session? _session;

  AuthController(this._authService, this._playbackDao, this._autoCacheManager) {
    _init();
  }

  bool get isLoading => _isLoading;
  Session? get session => _session;
  User? get user => _session?.user;
  bool get isAuthenticated => _session != null;

  void _init() {
    // Read the current session synchronously if available
    _session = _authService.currentSession;
    _isLoading = false;
    notifyListeners();

    // Listen to changes in auth state
    _authSubscription = _authService.onAuthStateChange.listen((data) {
      final newSession = data.session;

      // Only notify if there is an actual change in session state to prevent unnecessary rebuilds
      if (_session?.user.id != newSession?.user.id ||
          (_session == null && newSession != null) ||
          (_session != null && newSession == null)) {
        _session = newSession;

        if (_session != null) {
          _autoCacheManager.start();
        } else {
          _autoCacheManager.stop();
        }

        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    await _playbackDao.clear();
    _autoCacheManager.stop();

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
