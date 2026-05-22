import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../config/storage.dart';
import '../db/daos/assets_dao.dart';

class ResolvedAudioUrl {
  final String url;
  final DateTime? expiresAt;

  ResolvedAudioUrl({required this.url, this.expiresAt});

  bool get isValid =>
      expiresAt == null || expiresAt!.difference(DateTime.now()).inMinutes > 2;
}

class StorageUrlResolver {
  final SupabaseClient _supabase;
  final AssetsDao? _assetsDao;
  final Map<String, ResolvedAudioUrl> _cache = {};

  StorageUrlResolver(this._supabase, [this._assetsDao]);

  // Resolves a raw string (either direct URL or storage path) to a playable URL.
  Future<String?> resolvePlayableUrl(String sourceUrl) async {
    if (sourceUrl.isEmpty) return null;

    // 1. Direct URL (already playable)
    if (sourceUrl.startsWith('http://') || sourceUrl.startsWith('https://')) {
      return sourceUrl;
    }

    // 2. Local files / assets shouldn't be resolved via supabase
    if (sourceUrl.startsWith('/') ||
        sourceUrl.startsWith('C:') ||
        sourceUrl.startsWith('file:') ||
        sourceUrl.startsWith('assets/')) {
        return sourceUrl;
    }

    // 2. Storage Path (Needs resolution)
    final cacheKey = sourceUrl;

    // Check local repository mapping
    if (_assetsDao != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? baseDir = prefs.getString('project_local_repository_path');
        if (baseDir != null && baseDir.isNotEmpty) {
          baseDir = baseDir.trim();
          if (baseDir.endsWith('/') || baseDir.endsWith('\\')) {
            baseDir = baseDir.substring(0, baseDir.length - 1);
          }
          final asset = await _assetsDao!.getAssetByStoragePath(sourceUrl);
          if (asset != null) {
            String path = asset.name;
            var current = asset;
            while (current.parentId != null) {
              final parent = await _assetsDao!.getAssetById(current.parentId!);
              if (parent == null) break;
              path = '${parent.name}\\$path';
              current = parent;
            }
            final fullLocalPath = '$baseDir\\$path';
            if (await File(fullLocalPath).exists()) {
              debugPrint('StorageUrlResolver: SUCCESS - Local repository path resolved overriding cloud: \$fullLocalPath');
              _cache[cacheKey] = ResolvedAudioUrl(url: fullLocalPath);
              return fullLocalPath;
            } else {
              debugPrint('StorageUrlResolver: Local mapping attempted but file missing natively -> $fullLocalPath');
            }
          } else {
             debugPrint('StorageUrlResolver: No DB Asset found for Storage Path: $sourceUrl');
          }
        }
      } catch (e) {
        debugPrint('StorageUrlResolver ERROR: Exception parsing local target: $e');
      }
    }

    // Check Cache
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return _cache[cacheKey]!.url;
    }

    try {
      if (StorageConfig.isAudioBucketPublic) {
        final publicUrl = _supabase.storage
            .from(StorageConfig.defaultAudioBucket)
            .getPublicUrl(sourceUrl);
        _cache[cacheKey] = ResolvedAudioUrl(url: publicUrl);
        return publicUrl;
      } else {
        final signedUrl = await _supabase.storage
            .from(StorageConfig.defaultAudioBucket)
            .createSignedUrl(sourceUrl, StorageConfig.signedUrlExpirySeconds)
            .timeout(const Duration(milliseconds: 1500));

        _cache[cacheKey] = ResolvedAudioUrl(
            url: signedUrl,
            expiresAt: DateTime.now().add(
                const Duration(seconds: StorageConfig.signedUrlExpirySeconds)));

        return signedUrl;
      }
    } catch (e) {
      // Return null rather than crashing on a bad path/permission issue
      return null;
    }
  }

  // Helper method for item models
  Future<String?> resolveUrlForItem(Item item) async {
    if (item.audioUrl.isEmpty) return null;
    return resolvePlayableUrl(item.audioUrl);
  }

  // Batch resolves an entire list of items efficiently
  Future<void> resolveUrlsForItems(List<Item> items) async {
    final pathsToResolve = <String>[];

    for (var item in items) {
      final source = item.audioUrl;
      if (source.isEmpty || 
          source.startsWith('http') || 
          source.startsWith('/') || 
          source.startsWith('C:') || 
          source.startsWith('file:') || 
          source.startsWith('assets/')) {
          continue;
      }

      if (!_cache.containsKey(source) || !_cache[source]!.isValid) {
        // Double check if local mapping applies before adding to Supabase batch query
        bool foundLocal = false;
        if (_assetsDao != null) {
          try {
             final prefs = await SharedPreferences.getInstance();
             String? baseDir = prefs.getString('project_local_repository_path');
             if (baseDir != null && baseDir.isNotEmpty) {
               baseDir = baseDir.trim();
               if (baseDir.endsWith('/') || baseDir.endsWith('\\')) baseDir = baseDir.substring(0, baseDir.length - 1);
               final asset = await _assetsDao!.getAssetByStoragePath(source);
               if (asset != null) {
                 String path = asset.name;
                 var current = asset;
                 while (current.parentId != null) {
                   final parent = await _assetsDao!.getAssetById(current.parentId!);
                   if (parent == null) break;
                   path = '${parent.name}\\$path';
                   current = parent;
                 }
                 final fullLocalPath = '$baseDir\\$path';
                 if (await File(fullLocalPath).exists()) {
                   _cache[source] = ResolvedAudioUrl(url: fullLocalPath);
                   foundLocal = true;
                 }
               }
             }
          } catch(e) {}
        }
        
        if (!foundLocal) {
          pathsToResolve.add(source);
        }
      }
    }

    if (pathsToResolve.isEmpty) return;

    try {
      if (StorageConfig.isAudioBucketPublic) {
        for (var path in pathsToResolve) {
          final url = _supabase.storage
              .from(StorageConfig.defaultAudioBucket)
              .getPublicUrl(path);
          _cache[path] = ResolvedAudioUrl(url: url);
        }
      } else {
        final List<dynamic> response = await _supabase.storage
            .from(StorageConfig.defaultAudioBucket)
            .createSignedUrls(
                pathsToResolve, StorageConfig.signedUrlExpirySeconds)
            .timeout(const Duration(milliseconds: 2000), onTimeout: () => const []);

        for (var item in response) {
          final map = item as Map<String, dynamic>;
          if (map['error'] == null && map['signedURL'] != null) {
            final path = map['path'] as String;
            final url = map['signedURL'] as String;
            _cache[path] = ResolvedAudioUrl(
                url: url,
                expiresAt: DateTime.now().add(const Duration(
                    seconds: StorageConfig.signedUrlExpirySeconds)));
          }
        }
      }
    } catch (e) {
      // Silent catch to prevent UI drops, subsequent loadQueue logic handles missing entries.
    }
  }

  void clearCache() {
    _cache.clear();
  }

  String? getCachedUrl(String sourceUrl) {
    if (_cache.containsKey(sourceUrl) && _cache[sourceUrl]!.isValid) {
      return _cache[sourceUrl]!.url;
    }
    return null;
  }
}
