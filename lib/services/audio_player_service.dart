import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'dart:async';
import '../models/item_source.dart';
import 'profiler_service.dart';

class AudioPlayerService {
  AudioPlayer _player = AudioPlayer();
  bool _isDisposed = false;

  late final StreamController<Duration> _positionController;
  late final StreamController<Duration?> _durationController;
  late final StreamController<PlayerState> _playerStateController;
  late final StreamController<int?> _currentIndexController;
  late final StreamController<LoopMode> _loopModeController;
  late final StreamController<bool> _shuffleModeEnabledController;

  // Expose streams for state management
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<int?> get currentIndexStream => _currentIndexController.stream;
  Stream<LoopMode> get loopModeStream => _loopModeController.stream;
  Stream<bool> get shuffleModeEnabledStream => _shuffleModeEnabledController.stream;

  List<StreamSubscription> _playerSubscriptions = [];

  AudioPlayerService() {
    _positionController = StreamController<Duration>.broadcast(
      onListen: () {
        if (!_isDisposed) {
          try {
            _positionController.add(_player.position);
          } catch (_) {}
        }
      },
    );
    _durationController = StreamController<Duration?>.broadcast(
      onListen: () {
        if (!_isDisposed) {
          try {
            _durationController.add(_player.duration);
          } catch (_) {}
        }
      },
    );
    _playerStateController = StreamController<PlayerState>.broadcast(
      onListen: () {
        if (!_isDisposed) {
          try {
            _playerStateController.add(_player.playerState);
          } catch (_) {}
        }
      },
    );
    _currentIndexController = StreamController<int?>.broadcast(
      onListen: () {
        if (!_isDisposed) {
          try {
            _currentIndexController.add(_player.currentIndex);
          } catch (_) {}
        }
      },
    );
    _loopModeController = StreamController<LoopMode>.broadcast(
      onListen: () {
        if (!_isDisposed) {
          try {
            _loopModeController.add(_player.loopMode);
          } catch (_) {}
        }
      },
    );
    _shuffleModeEnabledController = StreamController<bool>.broadcast(
      onListen: () {
        if (!_isDisposed) {
          try {
            _shuffleModeEnabledController.add(_player.shuffleModeEnabled);
          } catch (_) {}
        }
      },
    );
  }

  void _subscribeToPlayerStreams() {
    for (var sub in _playerSubscriptions) {
      sub.cancel();
    }
    _playerSubscriptions = [
      _player.positionStream.listen(_positionController.add, onError: _positionController.addError),
      _player.durationStream.listen(_durationController.add, onError: _durationController.addError),
      _player.playerStateStream.listen(_playerStateController.add, onError: _playerStateController.addError),
      _player.currentIndexStream.listen(_currentIndexController.add, onError: _currentIndexController.addError),
      _player.loopModeStream.listen(_loopModeController.add, onError: _loopModeController.addError),
      _player.shuffleModeEnabledStream.listen(_shuffleModeEnabledController.add, onError: _shuffleModeEnabledController.addError),
    ];
  }

  Future<void> _ensurePlayerActive() async {
    if (_isDisposed) {
      debugPrint('AudioPlayerService: Re-creating AudioPlayer because it was disposed.');
      _player = AudioPlayer();
      _isDisposed = false;
      _subscribeToPlayerStreams();
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      } catch (e) {
        debugPrint('AudioPlayerService: Error re-configuring audio session: $e');
      }
    }
  }

  Future<void> prepareForTeardown() async {
    debugPrint('AudioPlayerService: Custom teardown sequence initiated to free C++ media_kit locks.');
    try {
      for (var sub in _playerSubscriptions) {
        sub.cancel();
      }
      _playerSubscriptions.clear();
      await _player.stop();
      await _player.dispose();
      _isDisposed = true;
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {
      debugPrint('AudioPlayerService: Error during teardown: $e');
    }
  }

  Future<void> init() async {
    debugPrint('AudioPlayerService: init() started');
    try {
      await _ensurePlayerActive();
      
      _player.playbackEventStream.listen((event) {
        // You could log specific events here if needed
      }, onError: (Object e, StackTrace stackTrace) {
        debugPrint('AudioPlayerService: Playback error stream: $e\n$stackTrace');
      });
      
      _player.playerStateStream.listen((state) {
          debugPrint('AudioPlayerService: PlayerState changed: playing=${state.playing}, processingState=${state.processingState}');
      });

      _subscribeToPlayerStreams();

      debugPrint('AudioPlayerService: init() completed successfully');
    } catch (e) {
      debugPrint('AudioPlayerService: init() ERROR: $e');
    }
  }

  Future<void> setQueue(List<ItemSource> queue,
      {int startIndex = 0,
      Duration position = Duration.zero,
      bool autoplay = false}) async {
    
    await _ensurePlayerActive();
    debugPrint('AudioPlayerService: Initializing queue with ${queue.length} items.');

    final audioSources = <AudioSource>[];
    
    for (var item in queue) {
      debugPrint('AudioPlayerService: Mapping track "${item.title}" [SourceType: ${item.sourceType.name}] -> ${item.source}');
      try {
        if (item.sourceType == SourceType.asset) {
          audioSources.add(AudioSource.asset(item.source, tag: item));
        } else if (item.sourceType == SourceType.file) {
          String path = item.source;
          if (path.startsWith('file://')) path = path.replaceFirst('file://', '');
          
          if (!path.startsWith('/')) { // Windows path mapping check
              if (path.startsWith('C:') || path.startsWith(r'C:\')) { }
          }
          
          final file = File(path);
          final exists = await file.exists();
          if (!exists) {
             debugPrint('AudioPlayerService WARNING: The explicitly mapped local absolute file path does not physically exist on disk: $path. Falling back to dummy source.');
             final silentPath = await _getOrCreateSilentFallbackFile();
             if (silentPath.isNotEmpty) {
               audioSources.add(AudioSource.file(silentPath, tag: item));
             } else {
               audioSources.add(AudioSource.uri(Uri.parse('data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARA8AAIA+AAACABAAZGF0YQAAAAA='), tag: item));
             }
             continue;
          }
          final length = await file.length();
          if (length == 0) {
             debugPrint('AudioPlayerService WARNING: The target mapped file exists but has 0 bytes: $path. Falling back to dummy source to prevent native crash.');
             final silentPath = await _getOrCreateSilentFallbackFile();
             if (silentPath.isNotEmpty) {
               audioSources.add(AudioSource.file(silentPath, tag: item));
             } else {
               audioSources.add(AudioSource.uri(Uri.parse('data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARA8AAIA+AAACABAAZGF0YQAAAAA='), tag: item));
             }
             continue;
          }
          
          final mbSize = (length / (1024 * 1024)).toStringAsFixed(2);
          debugPrint('AudioPlayerService: Resolving absolute local path: $path (Validation passed: File physically exists, Size: $mbSize MB)');

          String safePath = path;
          if (Platform.isWindows && path.contains(' ')) {
             // libmpv buffer deadlock native prevention (it interprets %20 literal characters natively crashing the C++ isolate process layout entirely on Windows)
             final Directory tempDir = Directory.systemTemp;
             final safeFileStr = 've_safe_cache_${item.id}.mp3';
             final safeFile = File('${tempDir.path}\\$safeFileStr');
             if (!await safeFile.exists() || (await safeFile.length()) != length) {
                await file.copy(safeFile.path);
             }
             safePath = safeFile.path;
             debugPrint('AudioPlayerService: Bypassing MPV deadlock natively natively copying literal spaces to safe bounding box: $safePath');
          }

          audioSources.add(AudioSource.file(safePath, tag: item));
        } else {
          final uriString = item.source;
          final uri = Uri.tryParse(uriString);
          if (uri == null || (!uri.hasScheme && !uriString.startsWith('/'))) {
             debugPrint('AudioPlayerService WARNING: Blocked invalid network URI without scheme: $uriString');
             final silentPath = await _getOrCreateSilentFallbackFile();
             if (silentPath.isNotEmpty) {
               audioSources.add(AudioSource.file(silentPath, tag: item));
             } else {
               audioSources.add(AudioSource.uri(Uri.parse('data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARA8AAIA+AAACABAAZGF0YQAAAAA='), tag: item));
             }
          } else {
             audioSources.add(AudioSource.uri(uri, tag: item));
          }
        }
      } catch (e) {
        debugPrint('AudioPlayerService ERROR [${item.title}]: Failed to map AudioSource natively. Exception: $e');
        return; // Abort loading the queue if we hit a critical mapper crash!
      }
    }

    final playlist = ConcatenatingAudioSource(children: audioSources);
    
    final sw = Stopwatch()..start();

    try {
      debugPrint('AudioPlayerService: setAudioSource() started (startIndex: $startIndex, position: $position)');
      await _player.setAudioSource(
        playlist,
        initialIndex: startIndex,
        initialPosition: position,
      );
      debugPrint('AudioPlayerService: setAudioSource() finished');
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: setAudioSource failed: $e');
    }
    
    sw.stop();
    AppProfilerService.instance.recordAudioLatency(sw.elapsedMicroseconds / 1000.0);

    if (autoplay) {
      await play();
    }
  }

  Future<void> play() async {
    await _ensurePlayerActive();
    debugPrint('AudioPlayerService: play() requested');
    try {
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: play() failed: $e');
    }
  }

  Future<void> pause() async {
    await _ensurePlayerActive();
    debugPrint('AudioPlayerService: pause() requested');
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: pause() failed: $e');
    }
  }

  Future<void> stop() async {
    await _ensurePlayerActive();
    debugPrint('AudioPlayerService: stop() requested');
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: stop() failed: $e');
    }
  }

  Future<void> seek(Duration position, {int? index}) async {
    await _ensurePlayerActive();
    debugPrint('AudioPlayerService: seek($position, index: $index) requested');
    try {
      await _player.seek(position, index: index);
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: seek() failed: $e');
    }
  }

  Future<void> next() async {
     await _ensurePlayerActive();
     debugPrint('AudioPlayerService: next() requested');
     try {
       await _player.seekToNext();
     } catch (e) {
       debugPrint('AudioPlayerService ERROR: seekToNext() failed: $e');
     }
  }

  Future<void> previous() async {
     await _ensurePlayerActive();
     debugPrint('AudioPlayerService: previous() requested');
     try {
       await _player.seekToPrevious();
     } catch (e) {
       debugPrint('AudioPlayerService ERROR: seekToPrevious() failed: $e');
     }
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
      await _ensurePlayerActive();
      debugPrint('AudioPlayerService: setShuffleModeEnabled($enabled) requested');
      try {
        await _player.setShuffleModeEnabled(enabled);
      } catch (e) {
        debugPrint('AudioPlayerService ERROR: setShuffleModeEnabled failed: $e');
      }
  }

  Future<void> setLoopMode(LoopMode mode) async {
       await _ensurePlayerActive();
       debugPrint('AudioPlayerService: setLoopMode($mode) requested');
       try {
         await _player.setLoopMode(mode);
       } catch (e) {
         debugPrint('AudioPlayerService ERROR: setLoopMode failed: $e');
       }
  }

  Future<void> dispose() async {
    debugPrint('AudioPlayerService: dispose() requested');
    try {
      for (var sub in _playerSubscriptions) {
        sub.cancel();
      }
      _playerSubscriptions.clear();
      await _player.dispose();
      _isDisposed = true;
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: dispose() failed: $e');
    }
  }

  Future<String> _getOrCreateSilentFallbackFile() async {
    try {
      final scratchDir = Directory('.ai_scratch');
      if (!await scratchDir.exists()) {
        await scratchDir.create(recursive: true);
      }
      final file = File('.ai_scratch/silent_fallback.wav');
      if (!await file.exists()) {
        final bytes = [
          0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
          0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20,
          0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
          0x40, 0x1f, 0x00, 0x00, 0x80, 0x3e, 0x00, 0x00,
          0x02, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
          0x00, 0x00, 0x00, 0x00
        ];
        await file.writeAsBytes(bytes);
      }
      return file.absolute.path;
    } catch (e) {
      debugPrint('AudioPlayerService: Error creating silent fallback file in .ai_scratch: $e');
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/silent_fallback.wav');
        if (!await file.exists()) {
          final bytes = [
            0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
            0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20,
            0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
            0x40, 0x1f, 0x00, 0x00, 0x80, 0x3e, 0x00, 0x00,
            0x02, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
            0x00, 0x00, 0x00, 0x00
          ];
          await file.writeAsBytes(bytes);
        }
        return file.path;
      } catch (e2) {
        debugPrint('AudioPlayerService: Error creating silent fallback file in temp: $e2');
        return '';
      }
    }
  }
}
