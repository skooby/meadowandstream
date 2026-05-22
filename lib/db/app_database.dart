import 'dart:io';
import '../services/profiler_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/assets_table.dart';
import 'daos/assets_dao.dart';
import 'tables/recent_plays_table.dart';
import 'daos/recent_plays_dao.dart';

import 'tables/asset_relations_table.dart';
import 'daos/asset_relations_dao.dart';
import 'tables/asset_tags_table.dart';
import 'daos/asset_tags_dao.dart';
import 'tables/playback_session_table.dart';
import 'tables/playback_queue_items_table.dart';
import 'daos/playback_dao.dart';
import 'tables/playlists_table.dart';
import 'daos/playlists_dao.dart';
import 'tables/playlist_items_table.dart';
import 'daos/playlist_items_dao.dart';
import 'tables/recent_searches_table.dart';
import 'daos/recent_searches_dao.dart';
import 'tables/favorites_collections_table.dart';
import 'tables/favorites_items_table.dart';
import 'daos/favorites_dao.dart';
import 'tables/audio_cache_table.dart';
import 'daos/audio_cache_dao.dart';
import 'tables/strings_table.dart';
import 'tables/translations_table.dart';
import 'tables/languages_table.dart';
import 'daos/i18n_dao.dart';
import 'tables/sync_queue_table.dart';
import 'daos/sync_queue_dao.dart';
import 'tables/user_preferences_table.dart';
import 'daos/user_preferences_dao.dart';
import 'tables/cheers_table.dart';
import 'daos/cheers_dao.dart';

part 'app_database.g.dart';

class ProfilerInterceptor extends QueryInterceptor {
  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) async {
    final sw = Stopwatch()..start();
    try { return await executor.runSelect(statement, args); } finally { AppProfilerService.instance.recordDbLatency(sw.elapsedMicroseconds / 1000.0); }
  }
  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) async {
    final sw = Stopwatch()..start();
    try { return await executor.runInsert(statement, args); } finally { AppProfilerService.instance.recordDbLatency(sw.elapsedMicroseconds / 1000.0); }
  }
  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) async {
    final sw = Stopwatch()..start();
    try { return await executor.runUpdate(statement, args); } finally { AppProfilerService.instance.recordDbLatency(sw.elapsedMicroseconds / 1000.0); }
  }
  @override
  Future<int> runDelete(QueryExecutor executor, String statement, List<Object?> args) async {
    final sw = Stopwatch()..start();
    try { return await executor.runDelete(statement, args); } finally { AppProfilerService.instance.recordDbLatency(sw.elapsedMicroseconds / 1000.0); }
  }
  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) async {
    final sw = Stopwatch()..start();
    try { return await executor.runCustom(statement, args); } finally { AppProfilerService.instance.recordDbLatency(sw.elapsedMicroseconds / 1000.0); }
  }
  @override
  Future<void> runBatched(QueryExecutor executor, BatchedStatements statements) async {
    final sw = Stopwatch()..start();
    try { return await executor.runBatched(statements); } finally { AppProfilerService.instance.recordDbLatency(sw.elapsedMicroseconds / 1000.0); }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'music_app_offline.sqlite'));
    final executor = NativeDatabase(file);
    return DatabaseConnection(executor).interceptWith(ProfilerInterceptor());
  });
}

@DriftDatabase(tables: [
  AssetTags,
  AssetRelations,
  RecentPlays,

  PlaybackSession,
  PlaybackQueueItems,
  Playlists,
  PlaylistItems,
  RecentSearches,
  FavoritesCollections,
  FavoritesItems,
  AudioCache,
  Strings,
  Translations,
  Languages,
  Assets,
  SyncQueue,
  UserPreferences,
  Cheers
], daos: [
  AssetTagsDao,
  AssetRelationsDao,
  RecentPlaysDao,

  PlaybackDao,
  PlaylistsDao,
  PlaylistItemsDao,
  RecentSearchesDao,
  FavoritesDao,
  AudioCacheDao,
  I18nDao,
  AssetsDao,
  SyncQueueDao,
  UserPreferencesDao,
  CheersDao
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 56;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        await customStatement('PRAGMA foreign_keys = OFF;');
        if (from < 44) {
             // Wiping obsolete legacy taxonomy and synced tables
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS item_tags;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS collection_tags;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS items;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS collections;'); } catch(_) {}
        }

        if (from < 45) {
             // Rebuilding assets without local cyclic referential check constraints breaking bulk synchronizations
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS assets;'); } catch(_) {}
             await m.createTable(assets);
        }
        if (from < 46) {
             await m.createTable(assetTags);
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS asset_tags;'); } catch(_) {}
             await m.createTable(assetTags);
        }
        if (from < 47) {
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS audio_cache;'); } catch(_) {}
             await m.createTable(audioCache);
        }
        if (from < 48) {
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS playback_queue_items;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS playback_session;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS recent_plays;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS favorites_items;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS favorites_collections;'); } catch(_) {}
             await m.createTable(playbackSession);
             await m.createTable(playbackQueueItems);
             await m.createTable(recentPlays);
             await m.createTable(favoritesItems);
             await m.createTable(favoritesCollections);
        }
        if (from < 49) {
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS sync_queue;'); } catch(_) {}
             await m.createTable(syncQueue);
        }
        if (from < 50) {
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS asset_tags;'); } catch(_) {}
             await m.createTable(assetTags);
        }
        if (from < 51) {
             await m.addColumn(strings, strings.color);
             await m.addColumn(strings, strings.parameter);
        }
        if (from < 52) {
             await m.createTable(userPreferences);
        }
        if (from < 53) {
             await m.addColumn(assets, assets.searchKeywords);
        }
        if (from < 54) {
             await m.addColumn(assets, assets.alternateVersionIds);
        }
        if (from < 55) {
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS playlist_items;'); } catch(_) {}
             try { await m.issueCustomQuery('DROP TABLE IF EXISTS playlists;'); } catch(_) {}
             await m.createTable(playlists);
             await m.createTable(playlistItems);
        }
        if (from < 56) {
             await m.createTable(cheers);
        }
        await customStatement('PRAGMA foreign_keys = ON;');
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
