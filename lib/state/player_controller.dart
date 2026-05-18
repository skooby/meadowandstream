import 'dart:async';
import 'package:flutter/material.dart';
import '../models/item_source.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import '../services/audio_player_service.dart';
import '../services/auto_cache_manager.dart';
import '../db/daos/recent_plays_dao.dart';
import '../db/daos/playback_dao.dart';
import '../db/daos/assets_dao.dart';
import '../db/daos/audio_cache_dao.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerController extends ChangeNotifier {
  final AudioPlayerService _audioService;
  final PlaybackDao _playbackDao;
  final AssetsDao _assetsDao;
  final AudioCacheDao? _audioCacheDao;
  final AutoCacheManager? _autoCacheManager;
  final RecentPlaysDao? _recentPlaysDao;

  bool _isReady = false;
  bool _isPlaying = false;
  List<ItemSource> _queue = [];
  int _currentIndex = 0;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _error;
  String? _lastRecordedItemId;

  bool _isShuffled = false;
  LoopMode _loopMode = LoopMode.off;

  // Throttling
  DateTime _lastPositionSaveTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _positionSaveThrottleMs = 5000;

  // Subscriptions
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _currentIndexSub;
  
  // Virtual Clock Fallback for Non-Music Timeline Editing
  Timer? _virtualTimer;

  PlayerController(this._audioService, this._playbackDao, this._assetsDao,
      [this._audioCacheDao, this._recentPlaysDao, this._autoCacheManager]) {
    _init();
  }

  bool get isReady => _isReady;
  bool get isPlaying => _isPlaying;
  List<ItemSource> get queue => _queue;
  int get currentIndex => _currentIndex;
  Duration get position => _position;
  Stream<Duration> get positionStream => _audioService.positionStream;
  Duration? get duration => _duration;
  String? get error => _error;
  bool get isShuffled => _isShuffled;
  LoopMode get loopMode => _loopMode;

  ItemSource? get currentItem {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) {
      return null;
    }
    return _queue[_currentIndex];
  }

  Future<void> _init() async {
    try {
      await _audioService.init();

      // Attempt to load persisted state
      final state = await _playbackDao.loadState();
      if (state != null && state.queue.isNotEmpty) {
        _isShuffled = state.session.isShuffled == 1;
        _loopMode = LoopMode.values[state.session.repeatMode.clamp(0, 2)];
        await _audioService.setShuffleModeEnabled(_isShuffled);
        await _audioService.setLoopMode(_loopMode);

        final prefs = await SharedPreferences.getInstance();
        final primaryUrl = prefs.getString('project_primary_storage_url') ?? '';

        final Map<String, ItemSource> itemsMap = {};
        for (final item in state.queue) {
          final parsedId = int.tryParse(item.itemId);
          if (parsedId == null) continue;
          final asset = await _assetsDao.getAssetById(parsedId);
          if (asset != null) {
            String audioSource = '';
            if (_audioCacheDao != null) {
              final cacheEntry = await _audioCacheDao!.getEntry(asset.id.toString());
              if (cacheEntry != null &&
                  cacheEntry.status == 3 &&
                  cacheEntry.localPath != null) {
                final file = File(cacheEntry.localPath!);
                if (await file.exists()) {
                  audioSource = cacheEntry.localPath!;
                }
              }
            }

            if (audioSource.isEmpty) {
                audioSource = asset.storagePath ?? '';
            }

            bool isLocalFile = audioSource.startsWith('/') ||
                      audioSource.startsWith('C:') ||
                      audioSource.startsWith('file:') ||
                      audioSource.startsWith('assets/');
                      
            if (!isLocalFile && !audioSource.startsWith('http') && audioSource.isNotEmpty && primaryUrl.isNotEmpty) {
               audioSource = '$primaryUrl/$audioSource';
            }

            if (isLocalFile || audioSource.startsWith('http')) {
              itemsMap[asset.id.toString()] = ItemSource(
                id: asset.id.toString(),
                title: asset.name,
                artist: 'Unknown Artist',
                sourceType: isLocalFile ? SourceType.file : SourceType.url,
                source: audioSource,
                artworkAsset: null,
              );
            } else {
              debugPrint('PlayerController: Skipping unplayable restored track (requires online resolution): ${asset.name}');
            }
          }
        }

        final restoredQueue = <ItemSource>[];
        for (final item in state.queue) {
          if (itemsMap.containsKey(item.itemId)) {
            restoredQueue.add(itemsMap[item.itemId]!);
          }
        }

        if (restoredQueue.isNotEmpty) {
          int restoredIndex = state.session.currentIndex;
          if (restoredIndex >= restoredQueue.length) {
            restoredIndex = 0;
          }

          _queue = restoredQueue;
          _currentIndex = restoredIndex;
          _position = Duration(milliseconds: state.session.positionMs);

          await _audioService.setQueue(_queue,
              startIndex: _currentIndex, autoplay: false);
          await _audioService.seek(_position);
        }
      }

      _isReady = true;
      notifyListeners();

      _playerStateSub = _audioService.playerStateStream.listen((state) {
        final playing = state.playing;
        if (_isPlaying != playing) {
          _isPlaying = playing;
          if (_isPlaying) {
            _recordPlayEvent();
          } else {
            // Write position immediately on pause
            _playbackDao.updatePosition(_position.inMilliseconds);
          }
          notifyListeners();
        }
      });

      _positionSub = _audioService.positionStream.listen((pos) {
        _position = pos;
        if (_isPlaying) {
          final now = DateTime.now();
          if (now.difference(_lastPositionSaveTime).inMilliseconds >
              _positionSaveThrottleMs) {
            _lastPositionSaveTime = now;
            _playbackDao.updatePosition(_position.inMilliseconds);
          }
        }
        notifyListeners(); // Can be optimized later if needed
      });

      _durationSub = _audioService.durationStream.listen((dur) {
        _duration = dur;
        notifyListeners();
      });

      _currentIndexSub = _audioService.currentIndexStream.listen((index) {
        if (index != null && index != _currentIndex) {
          _currentIndex = index;
          _lastRecordedItemId = null;
          _playbackDao.updateIndex(_currentIndex);
          _playbackDao.updatePosition(0);

          if (_isPlaying) {
            _recordPlayEvent();
          }
          notifyListeners();
        }
      });
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadQueue(List<ItemSource> newQueue,
      {int startIndex = 0,
      Duration position = Duration.zero,
      bool autoplay = false}) async {
    
    final prefs = await SharedPreferences.getInstance();
    final primaryUrl = prefs.getString('project_primary_storage_url') ?? '';
    
    // Convert ItemSource to local cache if available
    final processedQueue = <ItemSource>[];
    for (var item in newQueue) {
      var updatedItem = item;
      
      bool isLocalFile = item.source.startsWith('/') ||
                item.source.startsWith('C:') ||
                item.source.startsWith('file:') ||
                item.source.startsWith('assets/');
                
      if (!isLocalFile && !item.source.startsWith('http') && item.source.isNotEmpty && primaryUrl.isNotEmpty) {
          String combinedUrl = primaryUrl;
          if (!combinedUrl.endsWith('/')) combinedUrl += '/';
          String srcPath = item.source.startsWith('/') ? item.source.substring(1) : item.source;
          combinedUrl += srcPath;
          
          updatedItem = ItemSource(
              id: item.id,
              title: item.title,
              artist: item.artist,
              sourceType: SourceType.url,
              source: combinedUrl,
              artworkAsset: item.artworkAsset,
          );
      }
      
      if (_audioCacheDao != null && updatedItem.sourceType == SourceType.url) {
        final cacheEntry = await _audioCacheDao!.getEntry(updatedItem.id);
        if (cacheEntry != null &&
            cacheEntry.status == 3 &&
            cacheEntry.localPath != null) {
          final file = File(cacheEntry.localPath!);
          if (await file.exists()) {
            updatedItem = ItemSource(
              id: updatedItem.id,
              title: updatedItem.title,
              artist: updatedItem.artist,
              sourceType: SourceType.file,
              source: cacheEntry.localPath!,
              artworkAsset: updatedItem.artworkAsset,
            );
          }
        }
      }
      processedQueue.add(updatedItem);
    }

    _queue = processedQueue;
    _currentIndex = startIndex;
    _position = position;
    _error = null;

    final itemIds = _queue.map((t) => t.id).toList();
    await _playbackDao.saveQueue(itemIds,
        currentIndex: startIndex, positionMs: position.inMilliseconds);

    notifyListeners();

    try {
      await _audioService.setQueue(_queue,
          startIndex: startIndex, position: position, autoplay: autoplay);
      if (autoplay) {
        _recordPlayEvent();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> jumpToIndex(int newIndex) async {
    if (newIndex < 0 || newIndex >= _queue.length) return;
    _currentIndex = newIndex;
    _position = Duration.zero;
    await _audioService.seek(Duration.zero, index: newIndex);
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _queue.length) return;

    final newQueue = List<ItemSource>.from(_queue);
    newQueue.removeAt(index);

    if (newQueue.isEmpty) {
      await stopAndClear();
      return;
    }

    int resultingIndex = _currentIndex;
    Duration resultingPos = _position;
    bool wasCurrent = index == _currentIndex;

    if (index < _currentIndex) {
      resultingIndex--;
    } else if (wasCurrent) {
      if (resultingIndex >= newQueue.length) {
        resultingIndex = 0;
      }
      resultingPos = Duration.zero;
    }

    await loadQueue(newQueue,
        startIndex: resultingIndex,
        position: resultingPos,
        autoplay: wasCurrent && _isPlaying);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex > _queue.length) {
      return;
    }
    if (oldIndex == newIndex) return;

    final newQueue = List<ItemSource>.from(_queue);
    final item = newQueue.removeAt(oldIndex);

    // Adjust newIndex after removal
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    newQueue.insert(newIndex, item);

    int resultingIndex = _currentIndex;
    // Calculate what happens to current index
    if (_currentIndex == oldIndex) {
      resultingIndex = newIndex;
    } else if (_currentIndex > oldIndex && _currentIndex <= newIndex) {
      resultingIndex--;
    } else if (_currentIndex < oldIndex && _currentIndex >= newIndex) {
      resultingIndex++;
    }

    await loadQueue(newQueue,
        startIndex: resultingIndex, position: _position, autoplay: _isPlaying);
  }

  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    await _audioService.setShuffleModeEnabled(_isShuffled);
    await _playbackDao.updateShuffleMode(_isShuffled ? 1 : 0);
    notifyListeners();
  }

  Future<void> setRepeatMode(LoopMode mode) async {
    _loopMode = mode;
    await _audioService.setLoopMode(_loopMode);
    await _playbackDao.updateRepeatMode(_loopMode.index);
    notifyListeners();
  }

  void _recordPlayEvent() {
    final item = currentItem;
    if (item == null || _recentPlaysDao == null) return;

    if (_lastRecordedItemId == item.id) return;
    _lastRecordedItemId = item.id;

    _recentPlaysDao!.insertPlay(
      item.id,
      item.title,
      artist: item.artist,
    );

    _audioCacheDao?.markAccessed(
        item.id, DateTime.now().millisecondsSinceEpoch);
    _autoCacheManager?.scheduleSoon();
  }

  Future<void> togglePlayPause({int virtualLoopMs = 15000}) async {
    if (currentItem == null) {
      if (_isPlaying) {
        _isPlaying = false;
        _virtualTimer?.cancel();
        notifyListeners();
      } else {
        _isPlaying = true;
        _virtualTimer?.cancel();
        // Native 60 FPS precision virtual ticker
        _virtualTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
           _position += const Duration(milliseconds: 16);
           if (_position.inMilliseconds > virtualLoopMs && virtualLoopMs > 0) { 
              _position = Duration.zero; 
           }
           notifyListeners();
        });
        notifyListeners();
      }
      return;
    }

    if (_isPlaying) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
         // Aggressively halt the engine on Desktop when paused to release the native COM threads 
         // and prevent memory deadlocks during Flutter Hot Reload cascades.
         await _audioService.stop();
      } else {
         await _audioService.pause();
      }
    } else {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
         // Re-hydrate the timeline cache dynamically back into the fresh decoder
         await _audioService.seek(_position);
      }
      await _audioService.play();
    }
  }

  Future<void> seekTo(Duration pos) async {
    if (currentItem == null) {
       _position = pos;
       notifyListeners();
       return;
    }
    await _audioService.seek(pos);
    if (!_isPlaying) {
      await _playbackDao.updatePosition(pos.inMilliseconds);
    }
  }

  Future<void> next() async {
    await _audioService.next();
  }

  Future<void> previous() async {
    await _audioService.previous();
  }

  Future<void> stopAndClear() async {
    _virtualTimer?.cancel();
    await _audioService.stop();
    await _playbackDao.clear();
    _queue = [];
    _currentIndex = 0;
    _position = Duration.zero;
    _duration = null;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _virtualTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _currentIndexSub?.cancel();
    super.dispose();
  }
}
