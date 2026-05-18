import 'package:flutter/material.dart';
import '../screens/login/login_screen.dart';
import '../screens/now_playing/now_playing_screen.dart';
import 'app.dart';
import '../widgets/loading_screen.dart';
import '../state/auth_controller.dart';
import '../screens/visual_editor/visual_editor_screen.dart';
import 'package:provider/provider.dart';
import '../screens/listen/collection_detail_screen.dart';
import '../screens/listen/playlists_screen.dart';
import '../screens/listen/playlist_detail_screen.dart';
import '../screens/settings/cache_settings_screen.dart';
import '../screens/hub/project_hub_screen.dart';
import '../db/app_database.dart' show Playlist;
import '../engine/ui_builder/ui_builder_screen.dart';

class AppRoutes {
  static const String loading = '/loading';
  static const String login = '/login';
  static const String hub = '/hub';
  static const String listen = '/listen';
  static const String nowPlaying = '/now-playing';
  static const String uiBuilder = '/ui-builder';
  static const String visualEditor = '/visual-editor';
  static const String collectionDetail = '/collection-detail';
  static const String items = '/items';
  static const String recent = '/recent';
  static const String playlists = '/playlists';
  static const String playlist = '/playlist';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String cacheSettings = '/cache';

  /// Named routing with guards. If a user is not authenticated, they can't access /listen.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        final authController = context.watch<AuthController>();

        // 1. If we are currently checking auth session, show a loading screen universally.
        if (authController.isLoading) {
          return const LoadingScreen();
        }

        // 2. Identify requested route
        final isAuthRoute = settings.name == listen || settings.name == hub;

        // 3. Routing Guard
        if (isAuthRoute && !authController.isAuthenticated) {
          // Attempting to access protected route without auth: Redirect to login.
          return const LoginScreen();
        } else if (settings.name == login && authController.isAuthenticated) {
          // Attempting to access login when already authenticated: Redirect to protected.
        }

        Widget page;
        switch (settings.name) {
          case '/':
          case loading:
            page = const LoadingScreen();
            break;
          case login:
            page = const LoginScreen();
            break;
          case hub:
            page = const ProjectHubScreen();
            break;
          case uiBuilder:
            page = const UiBuilderScreen();
            break;
          case listen:
            page = const AppScaffold();
            break;
          case nowPlaying:
            page = const NowPlayingScreen();
            break;
          case visualEditor:
            page = const VisualEditorScreen();
            break;
          case collectionDetail:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            page = CollectionDetailScreen(arguments: args);
            break;
          case playlists:
            page = const PlaylistsScreen();
            break;
          case playlist:
            final arg = settings.arguments as Playlist;
            page = PlaylistDetailScreen(playlist: arg);
            break;
          case cacheSettings:
            page = const CacheSettingsScreen();
            break;
          default:
            page = authController.isAuthenticated
                ? const AppScaffold()
                : const LoginScreen();
        }

        // Providers are now globally injected at the MaterialApp layer inside MusicApp.
        return page;
      },
    );
  }
}
