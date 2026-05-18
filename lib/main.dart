import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/env.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'state/auth_controller.dart';
import 'state/theme_controller.dart';
import 'state/offline_cache_settings_controller.dart';
import 'state/engine_controller.dart';
import 'services/audio_player_service.dart';
import 'services/storage_url_resolver.dart';
import 'scripts/tenant_service.dart';
import 'db/app_database.dart';
import 'db/daos/recent_plays_dao.dart';
import 'db/daos/i18n_dao.dart';
import 'db/daos/assets_dao.dart';
import 'db/daos/asset_tags_dao.dart';
import 'db/daos/playback_dao.dart';
import 'db/daos/playlists_dao.dart';
import 'db/daos/playlist_items_dao.dart';
import 'db/daos/recent_searches_dao.dart';
import 'db/daos/favorites_dao.dart';
import 'db/daos/audio_cache_dao.dart';
import 'db/daos/user_preferences_dao.dart';
import 'repositories/localization_sync_service.dart';
import 'repositories/assets_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auto_cache_manager.dart';
import 'services/network_service.dart';
import 'services/offline_sync_service.dart';

import 'app/app.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added this import
import 'services/system_logs_service.dart';
import 'services/profiler_service.dart';
import 'services/control_type_registry.dart';
import 'services/sandbox_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemLogsService.instance.init();
  await ControlTypeRegistry.instance.init();
  await SandboxService.instance.init(); // Load sandbox/timeline state early so Active Tasks are populated on startup

  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      if (message.contains('A KeyDownEvent is dispatched') ||
          message.contains('A KeyUpEvent is dispatched') ||
          message.contains('The document is empty') ||
          message.contains('Unable to parse JSON message')) return;
      SystemLogsService.instance.addLog(message, category: LogCategory.GENERAL);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final dump = details.exceptionAsString();
    if (dump.contains('A KeyDownEvent is dispatched') ||
        dump.contains('A KeyUpEvent is dispatched') ||
        dump.contains('HardwareKeyboard._assertEventIsRegular') ||
        dump.contains('The document is empty') ||
        dump.contains('Unable to parse JSON message')) {
      return;
    }
    SystemLogsService.instance.addLog(dump, category: LogCategory.ERROR);
    if (originalOnError != null) originalOnError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final dump = error.toString();
    if (dump.contains('The document is empty') || 
        dump.contains('Unable to parse JSON message')) {
      return true; // Handle and swallow
    }
    SystemLogsService.instance.addLog(dump, category: LogCategory.ERROR);
    return false;
  };

  JustAudioMediaKit.ensureInitialized();
  AppProfilerService.instance.init();

  await dotenv.load(fileName: ".env"); // Added this line
  // 1. Initialize our environment secrets

  await Env.init();

  // 2. Initialize Supabase globally using the secure env
  await SupabaseService.initialize();

  // 3. Initialize tenant selection
  await TenantService.init();

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    double? w = prefs.getDouble('window_width');
    double? h = prefs.getDouble('window_height');
    double? x = prefs.getDouble('window_pos_x');
    double? y = prefs.getDouble('window_pos_y');

    WindowOptions windowOptions = WindowOptions(
      size: (w != null && h != null) ? Size(w, h) : const Size(1280, 800),
      center: (x == null && y == null),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
    });
  }

  // Initialize Auth Services
  final authService = AuthService();
  final audioPlayerService = AudioPlayerService();
  final supabaseClient = Supabase.instance.client;

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<AudioPlayerService>.value(value: audioPlayerService),
        Provider<AppDatabase>(
          create: (_) => AppDatabase(),
          dispose: (_, db) => db.close(),
        ),
        Provider<I18nDao>(
          create: (context) => context.read<AppDatabase>().i18nDao,
        ),
        Provider<AssetsDao>(
          create: (context) => context.read<AppDatabase>().assetsDao,
        ),
        Provider<AssetTagsDao>(
          create: (context) => context.read<AppDatabase>().assetTagsDao,
        ),
        Provider<PlaybackDao>(
          create: (context) => context.read<AppDatabase>().playbackDao,
        ),
        Provider<PlaylistsDao>(
          create: (context) => context.read<AppDatabase>().playlistsDao,
        ),
        Provider<PlaylistItemsDao>(
          create: (context) => context.read<AppDatabase>().playlistItemsDao,
        ),
        Provider<RecentPlaysDao>(
          create: (context) => context.read<AppDatabase>().recentPlaysDao,
        ),
        Provider<RecentSearchesDao>(
          create: (context) => context.read<AppDatabase>().recentSearchesDao,
        ),
        Provider<FavoritesDao>(
          create: (context) => context.read<AppDatabase>().favoritesDao,
        ),
        Provider<AudioCacheDao>(
          create: (context) => context.read<AppDatabase>().audioCacheDao,
        ),
        Provider<UserPreferencesDao>(
          create: (context) => context.read<AppDatabase>().userPreferencesDao,
        ),
        Provider<LocalizationSyncService>(
          create: (context) => LocalizationSyncService(
              supabaseClient, context.read<AppDatabase>()),
        ),
        ChangeNotifierProvider<AssetsSyncService>(
          create: (context) => AssetsSyncService(context.read<AssetsDao>()),
        ),
        Provider<StorageUrlResolver>(
          create: (context) =>
              StorageUrlResolver(supabaseClient, context.read<AssetsDao>()),
        ),
        Provider<NetworkService>(
          create: (_) => NetworkService(),
        ),
        Provider<AutoCacheManager>(
          create: (context) => AutoCacheManager(
            context.read<AppDatabase>(),
            context.read<StorageUrlResolver>(),
            context.read<NetworkService>(),
          ),
        ),
        Provider<OfflineSyncService>(
          lazy: false,
          create: (context) {
            final service = OfflineSyncService.instance;
            service.initialize(
                context.read<AppDatabase>(), context.read<NetworkService>());
            return service;
          },
        ),
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(
            authService,
            context.read<PlaybackDao>(),
            context.read<AutoCacheManager>(),
          ),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (context) =>
              ThemeController(context.read<UserPreferencesDao>()),
        ),
        ChangeNotifierProvider<OfflineCacheSettingsController>(
          create: (_) => OfflineCacheSettingsController()..init(),
        ),
        ChangeNotifierProvider<EngineController>(
          create: (_) => EngineController()..init(),
        ),
        ChangeNotifierProvider<AppProfilerService>.value(
          value: AppProfilerService.instance,
        ),
      ],
      child: const MusicApp(),
    ),
  );
}
