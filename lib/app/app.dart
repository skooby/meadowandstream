import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cyclop/cyclop.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../constants.dart';
import 'routes.dart';
import 'theme.dart';
import '../state/theme_controller.dart';
import '../state/auth_controller.dart';
import '../state/engine_controller.dart';
import 'package:provider/provider.dart';

import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../state/player_controller.dart';
import '../services/ai_bridge_service.dart';
import '../services/audio_player_service.dart';
import '../engine/ui_inspector/element_registry.dart';
import '../screens/visual_editor/panels/ai_task_manager_panel.dart';
import '../screens/visual_editor/visual_editor_screen.dart';
import '../state/global_task_editor_state.dart';

import '../screens/listen/listen_screen.dart';
import '../screens/listen/collection_detail_screen.dart';
import '../screens/listen/mapped_albums_screen.dart';
import '../screens/listen/all_items_screen.dart';
import '../screens/listen/recently_played_screen.dart';
import '../screens/listen/playlists_screen.dart';
import '../screens/listen/playlist_detail_screen.dart';
import '../screens/settings/cache_settings_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/cheer/cheer_screen.dart';
import '../screens/now_playing/now_playing_screen.dart';
import '../db/app_database.dart' show Playlist;

final GlobalKey<NavigatorState> globalAppNavigatorKey =
    GlobalKey<NavigatorState>();

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> with WindowListener {
  // Keeping the global navigator key allows us to navigate cleanly when auth state changes
  final GlobalKey<NavigatorState> _navigatorKey = globalAppNavigatorKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final engine = context.read<EngineController>();
      auth.addListener(_onAuthStateChanged);
      engine.addListener(_onAuthStateChanged);
      _onAuthStateChanged(); // Trigger manually to catch the already-resolved initial state
    });

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMoved() {
    _saveWindowInfo();
  }

  @override
  void onWindowResized() {
    _saveWindowInfo();
  }

  @override
  void onWindowFocus() {
    super.onWindowFocus();
    if (AiBridgeService.instance.hasPendingUpdate) {
        AiBridgeService.instance.triggerPendingUpdate();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    AiBridgeService.instance.dismissUpdateCover();
  }

  void _saveWindowInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      await prefs.setDouble('window_pos_x', pos.dx);
      await prefs.setDouble('window_pos_y', pos.dy);
      await prefs.setDouble('window_width', size.width);
      await prefs.setDouble('window_height', size.height);
    } catch (_) {}
  }

  void _onAuthStateChanged() {
    final auth = context.read<AuthController>();
    final engine = context.read<EngineController>();
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    if (auth.isLoading || engine.isLoading) {
      nav.pushNamedAndRemoveUntil(AppRoutes.loading, (route) => false);
    } else if (auth.isAuthenticated) {
      // User is authenticated
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final engine = context.read<EngineController>();
        if (engine.activePayload != null) {
          nav.pushNamedAndRemoveUntil(AppRoutes.visualEditor, (route) => false);
        } else {
          nav.pushNamedAndRemoveUntil(AppRoutes.hub, (route) => false);
        }
      } else {
        nav.pushNamedAndRemoveUntil(AppRoutes.listen, (route) => false);
      }
    } else {
      // User is logged out, clear audio and go to login
      context.read<PlayerController>().stopAndClear();
      nav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final engine = context.watch<EngineController>();
    final payload = engine.activePayload;

    Widget app = MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: themeController.themeMode,
      theme: AppTheme.buildTheme(Brightness.light),
      darkTheme: AppTheme.buildTheme(Brightness.dark),
      navigatorKey: _navigatorKey,
      initialRoute: AppRoutes.loading, // Always start at loading
      onGenerateRoute: AppRoutes.onGenerateRoute,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      builder: (context, child) => EyeDrop(child: _GlobalOverlayInjector(child: child!)),
);

    if (payload != null) {
      app = MultiProvider(
        providers: payload.buildProviders(context),
        child: app,
      );
    }

    return ExcludeSemantics(child: app);
  }
}

class _GlobalOverlayInjector extends StatefulWidget {
  final Widget child;
  const _GlobalOverlayInjector({required this.child});

  @override
  State<_GlobalOverlayInjector> createState() => _GlobalOverlayInjectorState();
}

String isTextInputFocused() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus != null && focus.hasFocus && focus.parent != null) {
      if (focus.context == null) return 'NO CONTEXT';
      
      bool isTextInput = false;
      final selfType = focus.context!.widget.runtimeType.toString();
      if (selfType.contains('EditableText') || selfType.contains('TextField') || selfType.contains('TextFormField')) {
        return 'YES: $selfType';
      }

      String ancestorType = '';
      focus.context!.visitAncestorElements((element) {
        final type = element.widget.runtimeType.toString();
        if (type.contains('EditableText') || 
            type.contains('TextField') || 
            type.contains('TextFormField')) {
          isTextInput = true;
          ancestorType = type;
          return false;
        }
        return true;
      });
      
      if (isTextInput) return 'YES: Ancestor $ancestorType';
      return 'NO: $selfType';
  }
  return 'NO FOCUS';
}

final ValueNotifier<String> isTextInputFocusedNotifier = ValueNotifier('INIT');

class _GlobalOverlayInjectorState extends State<_GlobalOverlayInjector> {
  OverlayEntry? _entry;
  int? _reloadCountdown;
  DateTime _lastKeystrokeTime = DateTime.now().subtract(const Duration(days: 1));

  bool _handleKeyEvent(KeyEvent event) {
    _lastKeystrokeTime = DateTime.now();
    return false; // do not consume
  }

  bool _isSafeToReload() {
      if (GlobalTaskEditorState.instance.hasUnsavedEdits) {
          final msg = 'BLOCKED: Dirty: ${GlobalTaskEditorState.instance.unsavedReason}';
          isTextInputFocusedNotifier.value = msg;
          try { File('.ai_bridge/reload_block_reason.txt').writeAsStringSync(msg); } catch (_) {}
          return false;
      }
      // Block if ANY text input is currently focused — wait for them to click away.
      if (isTextInputFocused().startsWith('YES')) {
          isTextInputFocusedNotifier.value = 'BLOCKED: Text field is focused';
          try { File('.ai_bridge/reload_block_reason.txt').writeAsStringSync('BLOCKED: Text field is focused'); } catch (_) {}
          return false;
      }
      // Block for 1500ms after the last keystroke, even if focus was just released.
      if (DateTime.now().difference(_lastKeystrokeTime).inMilliseconds < 1500) {
          isTextInputFocusedNotifier.value = 'BLOCKED: Cooldown after typing';
          try { File('.ai_bridge/reload_block_reason.txt').writeAsStringSync('BLOCKED: Cooldown after typing'); } catch (_) {}
          return false;
      }
      isTextInputFocusedNotifier.value = 'SAFE TO RELOAD';
      try { File('.ai_bridge/reload_block_reason.txt').writeAsStringSync('SAFE TO RELOAD'); } catch (_) {}
      return true;
  }

  void _onFocusChanged() {
    final status = isTextInputFocused();
    isTextInputFocusedNotifier.value = status;
    if (!status.startsWith('YES')) {
      try { File('.ai_bridge/reload_block_reason.txt').writeAsStringSync('SAFE TO RELOAD'); } catch (_) {}
    } else {
      try { File('.ai_bridge/reload_block_reason.txt').writeAsStringSync('BLOCKED: Text field is focused'); } catch (_) {}
    }
  }
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    FocusManager.instance.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onFocusChanged();
      
       // Wire up the new automated pipeline
       AiBridgeService.instance.onAutoReloadTriggered = (type) async {
           // Step 1: Flush any pending debounced save so data is persisted.
           final flush = GlobalTaskEditorState.instance.flushPendingSave;
           if (flush != null) {
               try { await flush(); } catch (_) {}
           }

           // Step 2: If a text field is still focused, wait for focus to leave
           // using an event-driven listener (no polling loop).
           if (isTextInputFocused().startsWith('YES')) {
               final completer = Completer<void>();
               void focusListener() {
                   if (!completer.isCompleted && !isTextInputFocused().startsWith('YES')) {
                       completer.complete();
                   }
               }
               FocusManager.instance.addListener(focusListener);
               // Safety timeout: give up after 60s regardless
               await completer.future.timeout(
                   const Duration(seconds: 60),
                   onTimeout: () {},
               );
               FocusManager.instance.removeListener(focusListener);
               // Brief buffer after focus leaves for any final keystrokes to settle
               await Future.delayed(const Duration(milliseconds: 500));
           }

            if (type == UpdateCoverType.hotRestart || type == UpdateCoverType.rebuild) {
                for (int i = 3; i > 0; i--) {
                    if (mounted) setState(() { _reloadCountdown = i; });
                    await Future.delayed(const Duration(seconds: 1));
                }
                if (mounted) setState(() { _reloadCountdown = null; });
            }

            // CRITICAL PREVENTION of "Callback invoked after it has been deleted" Dart VM crash on Windows:
            // Before triggering the hot reload or restart process (which terminates/recreates the Dart isolate group),
            // we must release all native FFI C++ windows player drivers and subscriptions.
            if (!kIsWeb && Platform.isWindows) {
                try {
                    final playerService = AudioPlayerService.instance;
                    if (playerService != null) {
                        await playerService.prepareForTeardown().timeout(const Duration(seconds: 1), onTimeout: () {});
                    }
                } catch (e) {
                    debugPrint('Error tearing down AudioPlayerService during auto-reload: $e');
                }
            }

            final contextToUse = globalAppNavigatorKey.currentContext;
           if (contextToUse != null) {
               AiBridgeService.instance.dismissUpdateCover();
               if (type == UpdateCoverType.hotRestart || type == UpdateCoverType.rebuild) {
                   if (VisualEditorScreen.triggerHotRestart != null) {
                       await VisualEditorScreen.triggerHotRestart!(validateCompilation: false);
                   }
               } else {
                   if (VisualEditorScreen.triggerHotReload != null) {
                       await VisualEditorScreen.triggerHotReload!(validateCompilation: false);
                   }
               }
           } else {
               AiBridgeService.instance.showUpdateCoverFor(type);
           }
       };
      
      final overlay = globalAppNavigatorKey.currentState?.overlay;
      if (overlay != null) {
        _entry = OverlayEntry(
          builder: (context) {
            return ListenableBuilder(
              listenable: showGlobalTaskPanelNotifier,
              builder: (context, _) {
                return ListenableBuilder(
                  listenable: AiBridgeService.instance,
                  builder: (context, _) {
                    return Stack(
                      fit: StackFit.loose,
                      children: [
                        if (_reloadCountdown != null)
                          Positioned(
                            bottom: 24,
                            right: 24,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]
                                ),
                                child: Text('Restarting in $_reloadCountdown...', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        if (AiBridgeService.instance.showUpdateCover && _reloadCountdown == null)
                          Positioned(
                            bottom: 24,
                            right: 24,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
                                    ]),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AiBridgeService.instance.updateCoverType == UpdateCoverType.rebuild ? Icons.warning_amber : Icons.info_outline, color: AiBridgeService.instance.updateCoverType == UpdateCoverType.rebuild ? Colors.redAccent : Colors.blueAccent, size: 20),
                                    const SizedBox(width: 12),
                                    Text(AiBridgeService.instance.updateCoverType == UpdateCoverType.rebuild ? 'Dependencies Updated.\nRebuild App Native Binaries!' : 'Bridge State Updated.', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.2), foregroundColor: Colors.greenAccent),
                                      onPressed: () {
                                        AiBridgeService.instance.dismissUpdateCover();
                                        if (AiBridgeService.instance.updateCoverType == UpdateCoverType.hotRestart || AiBridgeService.instance.updateCoverType == UpdateCoverType.rebuild) {
                                            VisualEditorScreen.triggerHotRestart?.call();
                                        } else {
                                            VisualEditorScreen.triggerHotReload?.call();
                                        }
                                      },
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Reload UI'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.2), foregroundColor: Colors.orangeAccent),
                                      onPressed: () {
                                          AiBridgeService.instance.dismissUpdateCover();
                                          VisualEditorScreen.triggerHotRestart?.call();
                                      },
                                      icon: const Icon(Icons.restart_alt, size: 16),
                                      label: const Text('Restart VM'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                                      onPressed: AiBridgeService.instance.dismissUpdateCover,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
        overlay.insert(_entry!);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    FocusManager.instance.removeListener(_onFocusChanged);
    _entry?.remove();
    _entry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ----------------------------------------------------------------------
// Legacy Scaffolding Extracted from main.dart
// Note: Future refactoring should move this strictly into `screens/listen`
// if it's purely for the authenticated area.
// ----------------------------------------------------------------------

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends State<AppScaffold> {
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  final GlobalKey<NavigatorState> _nestedNavigatorKey =
      GlobalKey<NavigatorState>();

  bool _showMiniPlayer = true;
  bool _isScrolled = false;
  final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical) {
            final scrolled = notification.metrics.pixels > 20;
            if (scrolled != _isScrolled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _isScrolled != scrolled) {
                  setState(() => _isScrolled = scrolled);
                }
              });
            }
          }
          return false;
        },
        child: Stack(
          children: [
            Navigator(
              key: _nestedNavigatorKey,
              initialRoute: '/',
              observers: [
                _routeObserver,
                _MiniPlayerVisibilityObserver(onVisibilityChanged: (show) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _showMiniPlayer != show) {
                      setState(() => _showMiniPlayer = show);
                    }
                  });
                })
              ],
              onGenerateRoute: (settings) {
                Widget page;
                switch (settings.name) {
                  case '/':
                    page = ValueListenableBuilder<int>(
                      valueListenable: _currentIndexNotifier,
                      builder: (context, currentIndex, child) {
                        return IndexedStack(
                          index: currentIndex >= 3 ? 0 : currentIndex,
                          children: const [
                            ListenScreen(),
                            Center(child: Text('Inspire Screen')),
                            CheerScreen(),
                          ],
                        );
                      },
                    );
                    break;
                  case AppRoutes.collectionDetail:
                    final args =
                        settings.arguments as Map<String, dynamic>? ?? {};
                    page = CollectionDetailScreen(arguments: args);
                    break;
                  case AppRoutes.items:
                    page = const AllItemsScreen();
                    break;
                  case AppRoutes.recent:
                    page = const RecentlyPlayedScreen();
                    break;
                  case AppRoutes.playlists:
                    page = const PlaylistsScreen();
                    break;
                  case AppRoutes.playlist:
                    final arg = settings.arguments as Playlist;
                    page = PlaylistDetailScreen(playlist: arg);
                    break;
                  case AppRoutes.favorites:
                    page = const FavoritesScreen();
                    break;
                  case AppRoutes.search:
                    page = const SearchScreen();
                    break;
                  case AppRoutes.cacheSettings:
                    page = const CacheSettingsScreen();
                    break;
                  case '/mapped-albums':
                    page = const MappedAlbumsScreen();
                    break;
                  case AppRoutes.nowPlaying:
                    page = const NowPlayingScreen();
                    break;
                  default:
                    page = const Scaffold(
                        body: Center(child: Text('Nested route not found')));
                }
                return MaterialPageRoute(
                  builder: (context) => page,
                  settings: settings,
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _showMiniPlayer
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PlayingMiniBar(),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: _isScrolled ? 10.0 : 0.0,
                        sigmaY: _isScrolled ? 10.0 : 0.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      color: _isScrolled
                          ? Theme.of(context).cardColor.withOpacity(0.65)
                          : Theme.of(context).cardColor,
                      child: BottomNavigationBar(
                        currentIndex: _currentIndexNotifier.value >= 3
                            ? 0
                            : _currentIndexNotifier.value,
                        backgroundColor: Colors.transparent,
                        elevation:
                            0, // Shadows would render incorrectly over the blur, elevation handled by the container color/blur
                        onTap: (index) {
                          if (_currentIndexNotifier.value == index) {
                            // Pop to root of the nested navigator on double tap
                            _nestedNavigatorKey.currentState
                                ?.popUntil((route) => route.isFirst);
                          } else {
                            setState(() => _currentIndexNotifier.value = index);
                          }
                        },
                        items: const [
                          BottomNavigationBarItem(
                            icon: RegisteredElement(
                                id: 'bottom_nav_listen',
                                meta: {'type': 'Button'},
                                child: Icon(Icons.headphones)),
                            label: AppStrings.screenListen,
                          ),
                          BottomNavigationBarItem(
                            icon: RegisteredElement(
                                id: 'bottom_nav_inspire',
                                meta: {'type': 'Button'},
                                child: Icon(Icons.lightbulb_outline)),
                            label: AppStrings.screenInspire,
                          ),
                          BottomNavigationBarItem(
                            icon: RegisteredElement(
                                id: 'bottom_nav_cheer',
                                meta: {'type': 'Button'},
                                child: Icon(Icons.favorite_border)),
                            label: AppStrings.screenCheer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class PlayingMiniBar extends StatefulWidget {
  const PlayingMiniBar({super.key});

  @override
  State<PlayingMiniBar> createState() => _PlayingMiniBarState();
}

class _PlayingMiniBarState extends State<PlayingMiniBar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use Consumer to avoid rebuilding the widget tree
    return Consumer<PlayerController>(
      builder: (context, controller, child) {
        final currentItem = controller.currentItem;
        final isPlaying = controller.isPlaying;

        if (currentItem == null) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(builder: (context, constraints) {
          bool compact = constraints.maxWidth < 250;
          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.nowPlaying);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius:
                    BorderRadius.circular(AppDimensions.miniBarBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: 'artwork_${currentItem.id}',
                      child: Container(
                        width: AppDimensions.miniBarImageSize,
                        height: AppDimensions.miniBarImageSize,
                        color: Colors.grey.shade300,
                        child: currentItem.artworkAsset != null
                            ? Image.asset(currentItem.artworkAsset!,
                                fit: BoxFit.cover)
                            : const Center(
                                child:
                                    Icon(Icons.music_note, color: Colors.grey)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.error != null)
                          Text(
                            'Error: ${controller.error}',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          currentItem.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentItem.artist ?? 'Unknown Artist',
                          style:
                              theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: AppDimensions.iconSizeMedium,
                    onPressed: () async {
                      await controller.togglePlayPause();
                    },
                  ),
                  if (controller.queue.length > 1 && !compact)
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      iconSize: AppDimensions.iconSizeMedium,
                      onPressed: () => controller.next(),
                    ),
                  if (!compact)
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      iconSize: AppDimensions.iconSizeMedium,
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.nowPlaying);
                      },
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

class _MiniPlayerVisibilityObserver extends NavigatorObserver {
  final void Function(bool show) onVisibilityChanged;

  _MiniPlayerVisibilityObserver({required this.onVisibilityChanged});

  void _update(Route<dynamic>? route) {
    if (route != null && route.settings.name != null) {
      if (route.settings.name == AppRoutes.search ||
          route.settings.name == AppRoutes.cacheSettings ||
          route.settings.name == '/test-bed' ||
          route.settings.name == AppRoutes.nowPlaying) {
        onVisibilityChanged(false);
      } else {
        onVisibilityChanged(true);
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(previousRoute);
  }
}

