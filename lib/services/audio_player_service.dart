import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import '../models/item_source.dart';
import 'profiler_service.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  // Expose streams for state management
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<bool> get shuffleModeEnabledStream => _player.shuffleModeEnabledStream;

  Future<void> prepareForTeardown() async {
    debugPrint('AudioPlayerService: Custom teardown sequence initiated to free C++ media_kit locks.');
    try {
      await _player.stop();
      await _player.dispose();
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {
      debugPrint('AudioPlayerService: Error during teardown: ');
    }
  }

  Future<void> init() async {
    debugPrint('AudioPlayerService: init() started');
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _player.playbackEventStream.listen((event) {
        // You could log specific events here if needed
      }, onError: (Object e, StackTrace stackTrace) {
        debugPrint('AudioPlayerService: Playback error stream: $e\\n$stackTrace');
      });
      
      _player.playerStateStream.listen((state) {
          debugPrint('AudioPlayerService: PlayerState changed: playing=${state.playing}, processingState=${state.processingState}');
      });



      debugPrint('AudioPlayerService: init() completed successfully');
    } catch (e) {
      debugPrint('AudioPlayerService: init() ERROR: $e');
    }
  }

  Future<void> setQueue(List<ItemSource> queue,
      {int startIndex = 0,
      Duration position = Duration.zero,
      bool autoplay = false}) async {
    
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
             throw Exception('AudioPlayerService FATAL: The explicitly mapped local absolute file path does not physically exist on disk: $path');
          }
          final length = await file.length();
          if (length == 0) {
             throw Exception('AudioPlayerService FATAL: Native crash prevention. The target mapped file exists but explicitly has 0 bytes (empty dummy file). FFmpeg probing segfaults on these structures natively: $path');
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
             audioSources.add(AudioSource.uri(Uri.parse('http://localhost/dummy_failed_track.mp3'), tag: item));
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
    debugPrint('AudioPlayerService: play() requested');
    try {
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: play() failed: $e');
    }
  }

  Future<void> pause() async {
    debugPrint('AudioPlayerService: pause() requested');
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: pause() failed: $e');
    }
  }

  Future<void> stop() async {
    debugPrint('AudioPlayerService: stop() requested');
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: stop() failed: $e');
    }
  }

  Future<void> seek(Duration position, {int? index}) async {
    debugPrint('AudioPlayerService: seek($position, index: $index) requested');
    try {
      await _player.seek(position, index: index);
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: seek() failed: $e');
    }
  }

  Future<void> next() async {
     debugPrint('AudioPlayerService: next() requested');
     try {
       await _player.seekToNext();
     } catch (e) {
       debugPrint('AudioPlayerService ERROR: seekToNext() failed: $e');
     }
  }

  Future<void> previous() async {
     debugPrint('AudioPlayerService: previous() requested');
     try {
       await _player.seekToPrevious();
     } catch (e) {
       debugPrint('AudioPlayerService ERROR: seekToPrevious() failed: $e');
     }
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
      debugPrint('AudioPlayerService: setShuffleModeEnabled($enabled) requested');
      try {
        await _player.setShuffleModeEnabled(enabled);
      } catch (e) {
        debugPrint('AudioPlayerService ERROR: setShuffleModeEnabled failed: $e');
      }
  }

  Future<void> setLoopMode(LoopMode mode) async {
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
      await _player.dispose();
    } catch (e) {
      debugPrint('AudioPlayerService ERROR: dispose() failed: $e');
    }
  }
}
