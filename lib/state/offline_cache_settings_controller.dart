import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class OfflineCacheSettingsController extends ChangeNotifier {
  bool _autoCacheEnabled = true;
  int _audioCacheMaxBytes = 1024 * 1024 * 1024; // 1GB
  bool _autoCacheWifiOnly = true;
  int _lyricsLineMode = AppLyricsConfig.defaultLineMode;

  bool get autoCacheEnabled => _autoCacheEnabled;
  int get audioCacheMaxBytes => _audioCacheMaxBytes;
  bool get autoCacheWifiOnly => _autoCacheWifiOnly;
  int get lyricsLineMode => _lyricsLineMode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _autoCacheEnabled = prefs.getBool('autoCacheEnabled') ?? true;
    _audioCacheMaxBytes =
        prefs.getInt('audioCacheMaxBytes') ?? (1024 * 1024 * 1024);
    _autoCacheWifiOnly = prefs.getBool('autoCacheWifiOnly') ?? true;
    _lyricsLineMode =
        prefs.getInt('lyricsLineMode') ?? AppLyricsConfig.defaultLineMode;
    notifyListeners();
  }

  Future<void> setAutoCacheEnabled(bool value) async {
    _autoCacheEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoCacheEnabled', value);
    notifyListeners();
  }

  Future<void> setAudioCacheMaxBytes(int value) async {
    _audioCacheMaxBytes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('audioCacheMaxBytes', value);
    notifyListeners();
  }

  Future<void> setAutoCacheWifiOnly(bool value) async {
    _autoCacheWifiOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoCacheWifiOnly', value);
    notifyListeners();
  }

  Future<void> setLyricsLineMode(int value) async {
    _lyricsLineMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lyricsLineMode', value);
    notifyListeners();
  }
}
