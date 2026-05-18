import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../db/app_database.dart';
import '../models/item.dart';
import '../services/storage_url_resolver.dart';
import '../services/network_service.dart';
import 'package:drift/drift.dart';

class AutoCacheManager {
  final AppDatabase _db;
  final StorageUrlResolver _resolver;
  final NetworkService _networkService;
  final Dio _dio = Dio();

  Timer? _periodicTimer;
  Timer? _debounceTimer;

  bool _isRunning = false;

  static const int _defaultMaxBytes = 1024 * 1024 * 1024; // 1 GB
  static const int _downloadsPerRun = 5;

  AutoCacheManager(this._db, this._resolver, this._networkService);

  void start() {
    stop();
    // Run every 10 minutes
    _periodicTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _runCacheCheck();
    });
    // Schedule one immediately on start
    scheduleSoon();
  }

  void stop() {
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    _periodicTimer = null;
    _debounceTimer = null;
  }

  void scheduleSoon() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      _runCacheCheck();
    });
  }

  Future<void> _runCacheCheck() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('autoCacheEnabled') ?? true;
      if (!enabled) return;

      final maxBytes = prefs.getInt('audioCacheMaxBytes') ?? _defaultMaxBytes;

      // 1. Gather Candidate Sets
      final candidates = <String>{};

      // Top 30 recent plays
      final recentPlays = await _db.recentPlaysDao.getRecentPlays(limit: 30);
      final recentItemIds = recentPlays.map((r) => r.itemId).toSet();
      candidates.addAll(recentItemIds);

      // Current Queue Context (Current + next 10)
      final queueState = await _db.playbackDao.loadState();
      final queueItems = queueState?.queue ?? [];
      final queueIndex = queueState?.session.currentIndex ?? 0;

      final queueItemIds = <String>{};
      if (queueItems.isNotEmpty) {
        final start = max(0, queueIndex);
        final end =
            min(queueItems.length, queueIndex + 11); // up to 10 upcoming
        for (var i = start; i < end; i++) {
          queueItemIds.add(queueItems[i].itemId);
          candidates.add(queueItems[i].itemId);
        }
      }

      // Top Favorites (up to 50)
      final favoritesCollections =
          await _db.favoritesDao.watchFavoriteCollections().first;
      final favoritesItems =
          await _db.favoritesDao.watchFavoriteItems().first;
      final favoriteItemIds = favoritesItems.map((t) => t.id.toString()).toSet();
      candidates.addAll(favoriteItemIds);

      // Let's also include items from favorite collections just as a baseline
      for (final fa in favoritesCollections) {
        final parsedFolderId = int.tryParse(fa.id.toString());
        if (parsedFolderId != null) {
          final itemsInCollection = await _db.assetsDao.getAssetsInFolder(parsedFolderId);
          for (final t in itemsInCollection) {
            favoriteItemIds.add(t.id.toString());
            candidates.add(t.id.toString());
          }
        }
      }

      // Playlists (up to 100 items to not overwhelm candidates)
      final allPlaylists = await _db.playlistsDao.getAllPlaylists();
      final playlistItemIds = <String>{};
      for (final p in allPlaylists.take(5)) {
        // Top 5 playlists
        final items = await _db.playlistItemsDao.getItems(p.id);
        for (final item in items.take(20)) {
          playlistItemIds.add(item.itemId);
          candidates.add(item.itemId);
        }
      }

      // 2. Score the candidates and add to drift
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final itemId in candidates) {
        double score = 0;

        // Queue score (+500)
        if (queueItemIds.contains(itemId)) {
          score += 500;
        }

        // Favorites score (+200)
        if (favoriteItemIds.contains(itemId)) {
          score += 200;
        }

        // Playlist score (+100)
        if (playlistItemIds.contains(itemId)) {
          score += 100;
        }

        // Recency decay (+1000 * exp(-days/7))
        int lastPlayed = 0;
        try {
          final rpEntry = recentPlays.firstWhere((r) => r.itemId == itemId);
          lastPlayed = rpEntry.playedAt;
        } catch (_) {}

        if (lastPlayed > 0) {
          final daysSince = (nowMs - lastPlayed) / (1000 * 60 * 60 * 24);
          if (daysSince >= 0) {
            score += 1000 * exp(-daysSince / 7);
          }
        }

        // Ensure item still exists locally
        final parsedId = int.tryParse(itemId);
        if (parsedId != null) {
          final localItem = await _db.assetsDao.getAssetById(parsedId);
          if (localItem != null) {
            final entry = await _db.audioCacheDao.getEntry(itemId);
            if (entry == null) {
              // Insert new candidate
              await _db.audioCacheDao.upsertEntry(AudioCacheCompanion.insert(
                itemId: itemId,
                status: 0,
                lastPlayedAt: Value(lastPlayed),
                cacheScore: Value(score),
                updatedAt: nowMs,
              ));
            } else {
              await _db.audioCacheDao.updateScore(itemId, score);
              if (lastPlayed > entry.lastPlayedAt && lastPlayed > 0) {
                await _db.audioCacheDao.upsertEntry(
                    entry.copyWith(lastPlayedAt: lastPlayed).toCompanion(true));
              }
            }
          }
        }
      }

      // 3. Eviction
      int totalBytes = await _db.audioCacheDao.totalCachedBytes();
      if (totalBytes > maxBytes) {
        final cachedItems =
            await _db.audioCacheDao.listCachedOrderedByScoreAsc();
        for (final item in cachedItems) {
          if (totalBytes <= maxBytes * 0.9) break; // target 90% once we hit max

          if (item.localPath != null) {
            final file = File(item.localPath!);
            if (await file.exists()) {
              await file.delete();
            }
          }
          totalBytes -= (item.fileBytes ?? 0);
          await _db.audioCacheDao.remove(item.itemId);
        }
      }

      // 4. Download top candidates
      final missing =
          await _db.audioCacheDao.listTargetsNotCached(_downloadsPerRun * 2);
      int downloadedThisRun = 0;

      final wifiOnly = prefs.getBool('autoCacheWifiOnly') ?? true;
      if (wifiOnly && missing.isNotEmpty) {
        final isWifi = await _networkService.isWifi();
        if (!isWifi) {
          // Pause downloads on cellular instead of erroring
          for (final item in missing) {
            await _db.audioCacheDao.upsertEntry(item
                .copyWith(status: 4, error: const Value('pausedOnCellular'))
                .toCompanion(true));
          }
          return;
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(appDir.path, 'audio_cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      for (final item in missing) {
        if (downloadedThisRun >= _downloadsPerRun) break;
        if (totalBytes >= maxBytes) break;

        final parsedId = int.tryParse(item.itemId);
        if (parsedId == null) continue;
        final dbAsset = await _db.assetsDao.getAssetById(parsedId);
        if (dbAsset == null || dbAsset.parentId == null) continue;

        // Mark downloading
        await _db.audioCacheDao.upsertEntry(item
            .copyWith(status: 2, error: const Value(null))
            .toCompanion(true));

        try {
          final domainItem = Item(
             id: dbAsset.id.toString(),
             title: dbAsset.name,
             assetFolderId: dbAsset.parentId,
             audioUrl: dbAsset.storagePath ?? '',
             collectionId: dbAsset.parentId?.toString(),
          );
          final downloadUrl = await _resolver.resolveUrlForItem(domainItem);
          if (downloadUrl == null) throw Exception("Failed to resolve URL");

          final ext = p.extension(downloadUrl).split('?').first.isEmpty
              ? '.mp3'
              : p.extension(downloadUrl).split('?').first;
          final savePath = p.join(cacheDir.path, '${item.itemId}$ext');

          final response = await _dio.download(downloadUrl, savePath);
          if (response.statusCode == 200) {
            final file = File(savePath);
            final size = await file.length();

            await _db.audioCacheDao.upsertEntry(item
                .copyWith(
                  status: 3,
                  localPath: Value(savePath),
                  fileBytes: Value(size),
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                )
                .toCompanion(true));

            totalBytes += size;
            downloadedThisRun++;
          } else {
            throw Exception("HTTP ${response.statusCode}");
          }
        } catch (e) {
          await _db.audioCacheDao.upsertEntry(item
              .copyWith(status: 4, error: Value(e.toString()))
              .toCompanion(true));
        }
      }
    } catch (e) {
      // Background loop errors should be swallowed or logged
    } finally {
      _isRunning = false;
    }
  }
}
