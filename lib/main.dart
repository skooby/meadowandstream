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
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added this import
import 'services/system_logs_service.dart';
import 'services/profiler_service.dart';
import 'services/control_type_registry.dart';
import 'services/sandbox_service.dart';
import 'services/ai_bridge_service.dart';
import 'services/antigravity_status_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemLogsService.instance.init();
  await ControlTypeRegistry.instance.init();
  await SandboxService.instance.init(); // Load sandbox/timeline state early so Active Tasks are populated on startup

  final originalDebugPrint = debugPrint;
  bool isLogging = false;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      if (message.contains('A KeyDownEvent is dispatched') ||
          message.contains('A KeyUpEvent is dispatched') ||
          message.contains('The document is empty') ||
          message.contains('Unable to parse JSON message')) return;
      if (isLogging || message.startsWith('[LogCategory.')) {
        if (message.startsWith('[LogCategory.DIRECT] ')) {
          originalDebugPrint(message.substring('[LogCategory.DIRECT] '.length), wrapWidth: wrapWidth);
        } else {
          originalDebugPrint(message, wrapWidth: wrapWidth);
        }
        return;
      }
      isLogging = true;
      try {
        final category = (message.contains('[AntigravityStatusService]') ||
                          message.contains('[AiBridge]'))
            ? LogCategory.SYNC
            : LogCategory.GENERAL;
        SystemLogsService.instance.addLog(message, category: category);
        final config = SystemLogsService.instance.categoryConfigs.firstWhere(
          (e) => e.category == category,
          orElse: () => LogTypeConfig(category: category),
        );
        if (config.console && category == LogCategory.GENERAL) {
          originalDebugPrint(message, wrapWidth: wrapWidth);
        }
      } finally {
        isLogging = false;
      }
    } else {
      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
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

  // CRITICAL PREVENTION of "Callback invoked after it has been deleted" Dart VM crash:
  // Disable native mpv logging so that no native logging callbacks are registered/invoked via FFI.
  JustAudioMediaKit.enableLog = false;
  JustAudioMediaKit.ensureInitialized();
  AppProfilerService.instance.init();

  // 1. Launch the loading placeholder app immediately to paint the splash screen.
  runApp(const AppInitializationPlaceholder());

  // 2. Show the native window immediately so the painted frame becomes visible.
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

  // 3. Perform the slow asynchronous initialization tasks in the background while the UI is responsive.
  await dotenv.load(fileName: ".env");
  await Env.init();
  await SupabaseService.initialize();
  await TenantService.init();

  // Spawn terminal daemon if not already running and we are in CLI bridge mode
  final prefs = await SharedPreferences.getInstance();
  final bridgeMode = prefs.getString('antigravity_bridge_mode') ?? 'sdk';
  if (bridgeMode == 'cli') {
    AntigravityStatusService.instance.ensureTerminalDaemonRunning();
  }

  // Initialize Auth Services after Supabase has successfully loaded.
  final authService = AuthService();
  final audioPlayerService = AudioPlayerService();
  final supabaseClient = Supabase.instance.client;

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<AudioPlayerService>.value(value: audioPlayerService),
        Provider<AppDatabase>(
          create: (context) {
            final db = AppDatabase();
            AiBridgeService.instance.initialize(db);
            return db;
          },
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

class AppInitializationPlaceholder extends StatelessWidget {
  const AppInitializationPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E2C), // AppColors.backgroundDark
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1E2C), // Deep Indigo-Slate
                Color(0xFF111119), // Almost Black
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing/Glassmorphic Container for the App Logo/Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE94560).withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE94560).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE94560).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.headphones_rounded,
                    size: 64,
                    color: Color(0xFFE94560),
                  ),
                ),
                const SizedBox(height: 32),
                // App Title
                const Text(
                  'MEADOW & STREAM',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'THE BIONIC MAN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 48),
                // Premium Progress Indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE94560)),
                    backgroundColor: Colors.white.withOpacity(0.08),
                  ),
                ),
                const SizedBox(height: 24),
                // Subtext
                Text(
                  'Starting up the experience...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.4),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// Triggering hot restart watcher cover again
