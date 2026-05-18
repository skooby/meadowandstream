import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nested/nested.dart';
import '../../app/engine_payload.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../state/tag_filter_controller.dart';
import '../../state/selection_controller.dart';
import '../../state/favorites_state.dart';
import '../../state/app_search_controller.dart';
import '../../state/player_controller.dart';
import '../../state/lyrics_view_controller.dart';
import '../../state/editor_state_controller.dart';
import '../../state/item_catalog_controller.dart';
import '../../db/daos/favorites_dao.dart';
import '../../db/daos/recent_searches_dao.dart';
import '../../db/daos/playback_dao.dart';
import '../../db/daos/assets_dao.dart';
import '../../db/daos/audio_cache_dao.dart';
import '../../db/daos/recent_plays_dao.dart';
import '../../services/audio_player_service.dart';
import '../../services/auto_cache_manager.dart';
import '../../repositories/assets_sync_service.dart';
import '../../services/storage_url_resolver.dart';

/// The specific Domain Payload for the Music Application.
/// This structurally isolates the Listen UI, music providers, and audio players
/// from the core overarching Platform Framework.
class MusicAppPayload implements EnginePayload {
  @override
  String get name => 'Music App';

  @override
  String get initialRoute => '/'; // The internal route the floating simulator mounts into first.

  @override
  ThemeData? get theme => AppTheme.buildTheme(Brightness.light);

  @override
  ThemeData? get darkTheme => AppTheme.buildTheme(Brightness.dark);

  @override
  RouteFactory get onGenerateRoute => AppRoutes.onGenerateRoute;

  @override
  List<SingleChildWidget> buildProviders(BuildContext context) {
    return [
      ChangeNotifierProvider<TagFilterController>(
        create: (_) => TagFilterController(),
      ),
      ChangeNotifierProvider<SelectionController>(
        create: (_) => SelectionController(),
      ),
      ChangeNotifierProvider<FavoritesState>(
        create: (context) => FavoritesState(context.read<FavoritesDao>()),
      ),
      ChangeNotifierProvider<AppSearchController>(
        create: (context) => AppSearchController(
          context.read<RecentSearchesDao>(),
        ),
      ),
      ChangeNotifierProvider<PlayerController>(
        create: (context) => PlayerController(
          context.read<AudioPlayerService>(),
          context.read<PlaybackDao>(),
          context.read<AssetsDao>(),
          context.read<AudioCacheDao>(),
          context.read<RecentPlaysDao>(),
          context.read<AutoCacheManager>(),
        ),
      ),
      ChangeNotifierProvider<LyricsViewController>(
        create: (_) => LyricsViewController(),
      ),
      ChangeNotifierProvider<EditorStateController>(
        create: (_) => EditorStateController(),
      ),
      ChangeNotifierProvider<ItemCatalogController>(
        create: (context) => ItemCatalogController(
            context.read<AssetsDao>(),
            context.read<AssetsSyncService>(),
            context.read<StorageUrlResolver>(),
        )..start(),
      ),
    ];
  }
}
