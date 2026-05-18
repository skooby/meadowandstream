import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/engine_payload.dart';
import '../apps/music/music_app_payload.dart';

/// Manages the top-level IDE workspace state deciding which payload
/// is actively mounted onto the sandbox/engine at runtime.
class EngineController extends ChangeNotifier {
  
  // Hardcoded for now. Eventually this could load from an extensions folder or DB.
  final List<EnginePayload> _installedPayloads = [
    MusicAppPayload(),
  ];

  EnginePayload? _activePayload;
  bool _isLoading = true;

  List<EnginePayload> get installedPayloads => List.unmodifiable(_installedPayloads);
  
  EnginePayload? get activePayload => _activePayload;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lastName = prefs.getString('engine_active_project');
    if (lastName != null) {
      _activePayload = _installedPayloads.where((p) => p.name == lastName).firstOrNull;
    }
    _isLoading = false;
    notifyListeners();
  }

  void loadProject(EnginePayload payload) async {
    _activePayload = payload;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('engine_active_project', payload.name);
  }

  void closeProject() async {
    _activePayload = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('engine_active_project');
  }
}
