import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../lyrics/lyrics_source_resolver.dart';
import '../lyrics/lrc_parser.dart';
import '../lyrics/lyrics_sync_engine.dart';
import 'dart:convert';
import '../choreography/choreography_engine.dart';

class LyricsViewController extends ChangeNotifier {
  final LyricsSourceResolver _resolver;

  bool _isLoading = false;
  String? _errorMessage;
  List<LyricLine> _lines = [];
  ChoreographyConfig? _choreographyConfig;
  String? _baseName;

  // Tracking current item id/url to avoid redundant loading
  String? _currentItemId;
  String? _currentAudioUrl;

  LyricsSyncResult _currentResult =
      const LyricsSyncResult(currentLineIndex: -1, currentWordIndex: -1);
  EvaluatedConfig _currentConfig = EvaluatedConfig(globalItems: {}, bgLayers: {});
  Timer? _syncTimer;
  int _playerPositionMs = 0;
  bool _isPlaying = false;

  Orientation _currentOrientation = Orientation.portrait;
  
  String? _simulatedPlatform;
  Orientation? _simulatedOrientation;

  String? get simulatedPlatform => _simulatedPlatform;
  set simulatedPlatform(String? platform) {
     if (_simulatedPlatform != platform) {
        _simulatedPlatform = platform;
        _tick();
     }
  }

  Orientation? get simulatedOrientation => _simulatedOrientation;
  set simulatedOrientation(Orientation? orientation) {
     if (_simulatedOrientation != orientation) {
        _simulatedOrientation = orientation;
        _tick();
     }
  }

  set currentOrientation(Orientation orientation) {
    if (_currentOrientation != orientation) {
      _currentOrientation = orientation;
      notifyListeners();
      _tick();
    }
  }

  LyricsViewController({LyricsSourceResolver? resolver})
      : _resolver = resolver ?? LyricsSourceResolver();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<LyricLine> get lines => _lines;
  ChoreographyConfig? get choreographyConfig => _choreographyConfig;
  EvaluatedConfig get currentConfig => _currentConfig;
  String? get baseName => _baseName;
  String? get currentAudioUrl => _currentAudioUrl;

  // Viewport Accessors
  int get currentLineIndex => _currentResult.currentLineIndex;
  int get currentWordIndex => _currentResult.currentWordIndex;

  LyricLine? get prevLine {
    if (_currentResult.currentLineIndex > 0 && lines.isNotEmpty) {
      return lines[_currentResult.currentLineIndex - 1];
    }
    return null;
  }

  LyricLine? get currentLine {
    if (_currentResult.currentLineIndex >= 0 &&
        _currentResult.currentLineIndex < lines.length) {
      return lines[_currentResult.currentLineIndex];
    }
    return null;
  }

  LyricLine? get nextLine {
    if (_currentResult.currentLineIndex >= 0 &&
        _currentResult.currentLineIndex < lines.length - 1) {
      return lines[_currentResult.currentLineIndex + 1];
    } else if (_currentResult.currentLineIndex == -1 && lines.isNotEmpty) {
      return lines[0]; // If before song starts, show first line as next
    }
    return null;
  }

  bool get hasWordTimingsForCurrent {
    return currentLine?.words.isNotEmpty ?? false;
  }

  void updatePosition(int positionMs) {
    if (_playerPositionMs != positionMs) {
      _playerPositionMs = positionMs;
      if (!_isPlaying) {
        _tick();
      }
    }
  }

  Future<void> autoSaveLrc() async {
      try {
          if (_currentAudioUrl == null || _lines.isEmpty) return;
          String savePath = '';
          if (_currentAudioUrl!.startsWith('C:') || _currentAudioUrl!.startsWith('/') || _currentAudioUrl!.startsWith('file:')) {
              String sanitized = _currentAudioUrl!;
              if (sanitized.startsWith('file:///')) sanitized = sanitized.replaceAll('file:///', '');
              final audioDir = p.dirname(sanitized);
              savePath = p.join(audioDir, '$_baseName.lrc');
          } else {
              final docs = await getApplicationDocumentsDirectory();
              savePath = p.join(docs.path, 'lyrics', '$_baseName.lrc');
          }
          final file = File(savePath);
          if (!await file.parent.exists()) await file.parent.create(recursive: true);
          final lrcText = LrcParser.generateLrc(_lines);
          await file.writeAsString(lrcText);
      } catch (e) {
          debugPrint('Autosave LRC error: $e');
      }
  }

  int updateLineStartMs(int targetIndex, int newStartMs) {
      if (targetIndex >= 0 && targetIndex < _lines.length) {
          final targetLine = _lines[targetIndex].copyWith(startMs: newStartMs);
          _lines[targetIndex] = targetLine;
          // Re-sort and re-tick
          _lines.sort((a, b) => a.startMs.compareTo(b.startMs));
          _tick();
          autoSaveLrc();
          return _lines.indexOf(targetLine);
      }
      return targetIndex;
  }

  void replaceLines(List<LyricLine> newLines) {
      _lines.clear();
      _lines.addAll(newLines);
      _lines.sort((a, b) => a.startMs.compareTo(b.startMs));
      _tick();
      autoSaveLrc();
  }

  void updateLineText(int targetIndex, String newText) {
      if (targetIndex >= 0 && targetIndex < _lines.length) {
          _lines[targetIndex] = _lines[targetIndex].copyWith(text: newText);
          _tick();
          autoSaveLrc();
      }
  }

  void duplicateLine(int targetIndex) {
      if (targetIndex >= 0 && targetIndex < _lines.length) {
          final line = _lines[targetIndex];
          _lines.insert(targetIndex + 1, line.copyWith(startMs: line.startMs + 500));
          _lines.sort((a, b) => a.startMs.compareTo(b.startMs));
          _tick();
          autoSaveLrc();
      }
  }

  void deleteLine(int targetIndex) {
      if (targetIndex >= 0 && targetIndex < _lines.length) {
          _lines.removeAt(targetIndex);
          _tick();
          autoSaveLrc();
      }
  }

  void addLine(int startMs, String text) {
      _lines.add(LyricLine(startMs: startMs, text: text, words: []));
      _lines.sort((a, b) => a.startMs.compareTo(b.startMs));
      _tick();
      autoSaveLrc();
  }

  void setIsPlaying(bool playing) {
    if (_isPlaying != playing) {
      _isPlaying = playing;
      if (_isPlaying) {
        if (_syncTimer == null &&
            (_lines.isNotEmpty || _choreographyConfig != null)) {
          _initTimer();
        }
      } else {
        _stopTimer();
      }
    }
  }

  void _tick() {
    bool changed = false;

    if (_lines.isNotEmpty) {
      final newResult = LyricsSyncEngine.compute(
        linesSorted: _lines,
        positionMs: _playerPositionMs + 30, // Pad evaluation natively to defeat audio hardware buffer streaming bounds mapping backwards from explicitly targeted millisecond markers
      );
      if (newResult != _currentResult) {
        _currentResult = newResult;
        changed = true;
      }
    }

    if (_choreographyConfig != null) {
      String targetPlatform = _simulatedPlatform ?? (kIsWeb ? 'WEB' : (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS ? 'MOBILE' : 'DESKTOP'));
      Orientation targetOrientation = _simulatedOrientation ?? _currentOrientation;
      
      _currentConfig = _choreographyConfig!.evaluate(
         _playerPositionMs, 
         targetPlatform: targetPlatform, 
         targetOrientation: targetOrientation
      );
      changed = true; // Always trigger a frame for the UI to query new variables
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _initTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 166), (_) {
      _tick();
    });
  }

  void _stopTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void forceEvaluation() {
    _tick();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void overrideEditorConfig(ChoreographyConfig config) {
    _choreographyConfig = config;
    _tick();
  }

  void loadExternalConfig(ChoreographyConfig config) {
    _choreographyConfig = config;
    _currentItemId = null;
    _currentAudioUrl = null;
    // We intentionally don't wipe _lines here to allow element testing on existing lyrics
    _errorMessage = null;
    
    if (_isPlaying) {
      _initTimer();
    }
    
    _tick();
  }

  Future<void> loadForCurrentItem(String itemId, String audioUrl) async {
    // Check if we already loaded/parsed this item (prevent infinite retry loops)
    if (itemId == _currentItemId && audioUrl == _currentAudioUrl) {
      return;
    }

    _currentItemId = itemId;
    _currentAudioUrl = audioUrl;

    _isLoading = true;
    _errorMessage = null;
    _lines = [];
    _choreographyConfig = null;
    _baseName = null;
    _currentResult =
        const LyricsSyncResult(currentLineIndex: -1, currentWordIndex: -1);
    _currentConfig = EvaluatedConfig(globalItems: {}, bgLayers: {});

    // Stop the tick briefly while loading
    _stopTimer();
    notifyListeners();

    try {
      final sources = await _resolver.loadForItem(audioUrl: audioUrl);
      _baseName = sources.baseName;

      if (sources.lrcText == null) {
        _errorMessage = 'Lyrics not available';
      } else {
        _lines = LrcParser.parse(sources.lrcText!);
      }

      if (sources.jsonText != null && sources.jsonText!.isNotEmpty) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(sources.jsonText!);
          _choreographyConfig = ChoreographyConfig.fromJson(jsonMap);
        } catch (e) {
          debugPrint('Failed to parse ChoreographyConfigV2 JSON: $e');
        }
      }

      if (_lines.isEmpty && _choreographyConfig == null) {
        _errorMessage = 'Configuration not available';
      }
    } catch (e) {
      _errorMessage = 'Failed to load lyrics';
    } finally {
      _isLoading = false;
      if ((_lines.isNotEmpty || _choreographyConfig != null) &&
          _errorMessage == null &&
          _isPlaying) {
        _initTimer(); // Start 6Hz tick immediately once successfully loaded if playing
      }
      notifyListeners();
    }
  }
}
