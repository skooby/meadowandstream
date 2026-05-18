import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../visual_editor_screen.dart';
import '../window_dock_manager.dart';
import '../../../app/app.dart';
import '../../../state/player_controller.dart';
import '../../../state/app_search_controller.dart';
import '../../../state/favorites_state.dart';
import '../../../state/tag_filter_controller.dart';
import '../../../state/selection_controller.dart';


import '../../../state/editor_state_controller.dart';
import '../../../state/lyrics_view_controller.dart';
import '../../../state/auth_controller.dart';
import '../../../state/theme_controller.dart';
import '../../../state/engine_controller.dart';
import '../../../services/macro_service.dart';

import '../../now_playing/now_playing_screen.dart';
import 'dart:ui';
import '../../../app/theme.dart';
import '../../../app/routes.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'dart:async' as async;
import '../../../constants.dart';


final ValueNotifier<bool> showSimulatorNotifier = ValueNotifier(true);

void showSimulatorWindow(BuildContext context) {
  if (showSimulatorNotifier.value) return;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showSimulator'), true));
  showSimulatorNotifier.value = true;
}

void hideSimulatorWindow() {
  showSimulatorNotifier.value = false;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showSimulator'), false));
}

class SimulatorWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  
  final async.StreamController<TiltStreamModel> tiltStreamController;
  final int currentEditorMode;

  const SimulatorWindow({
    super.key,
    required this.onClose,
    this.onFocus,
    this.isDocked = false,
    required this.tiltStreamController,
    required this.currentEditorMode,
  });

  @override
  State<SimulatorWindow> createState() => SimulatorWindowState();
}
class SimulatorWindowState extends State<SimulatorWindow> {
  bool _isLoaded = false;

  late int _activeEditorMode;
  double _uiScale = 1.0;
  
  // Local Simulator Variables
  String _previewMode = 'APP'; // APP or ELEMENT
  double _previewX = 260.0;
  double _previewY = 80.0;
  double _previewWidth = 140.0;
  double _previewHeight = 248.0;
  String _previewResolution = 'Custom';
  String _previewAspectRatio = 'FREE';
  bool _isHeightPinned = false;
  String _simulatedPlatform = 'MOBILE';
  bool _isPreviewLandscape = false;
  final bool _disableVirtualKeyboard = true;

  final Map<String, Map<String, double>> _previewModeDims = {};

  Map<String, double> _getDimsFor(String mode) {
    if (!_previewModeDims.containsKey(mode)) {
       _previewModeDims[mode] = {
         'x': 260.0, 
         'y': 80.0, 
         'w': mode == 'APP' ? 800.0 : 140.0, 
         'h': mode == 'APP' ? 450.0 : 248.0
       };
    }
    return _previewModeDims[mode]!;
  }

  @override
  void initState() {
    super.initState();
    // 1. Initial State Injection
    _activeEditorMode = widget.currentEditorMode;
    _loadSimulatorPreferences();
    
    // 2. Global Workspace Sync
    // This is required so simulator bounds physically reload when the top-level 
    // dropdown (Planning, Database, Timeline) switches SharedPreferences keys.
    VisualEditorScreen.currentWorkspace.addListener(_onWorkspaceChanged);
  }

  void _onWorkspaceChanged() {
    _loadSimulatorPreferences();
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_onWorkspaceChanged);
    super.dispose();
  }



  @override
  void didUpdateWidget(SimulatorWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEditorMode != widget.currentEditorMode) {
        updateEditorMode(widget.currentEditorMode);
    }
  }

  void updateEditorMode(int newMode) {
      if (_activeEditorMode == newMode) return;
      setState(() {
         _activeEditorMode = newMode;
      });
  }

  void setPreviewMode(String newMode) {
     if (_previewMode == newMode) return;
     // Save old directly to the mode key (no editor fragmentation)
     if (_previewModeDims.containsKey(_previewMode)) {
         _previewModeDims[_previewMode]!['w'] = _previewWidth;
         _previewModeDims[_previewMode]!['h'] = _previewHeight;
         _previewModeDims[_previewMode]!['x'] = _previewX;
         _previewModeDims[_previewMode]!['y'] = _previewY;
     }
     
     // Setup new
     final dims = _getDimsFor(newMode);
     setState(() {
        _previewMode = newMode;
        _previewX = dims['x']!;
        _previewY = dims['y']!;
        _previewWidth = dims['w']!;
        _previewHeight = dims['h']!;
     });
  }

  Future<void> _loadSimulatorPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final projectSimW = prefs.getDouble('project_simulator_width') ?? 1920.0;
    final projectSimH = prefs.getDouble('project_simulator_height') ?? 1080.0;

    for (String type in ['APP', 'ELEMENT']) {
        _previewModeDims[type] = {
            'x': prefs.getDouble(VisualEditorScreen.getPrefKey('ve_previewX_$type')) ?? 260.0,
            'y': prefs.getDouble(VisualEditorScreen.getPrefKey('ve_previewY_$type')) ?? 80.0,
            'w': prefs.getDouble(VisualEditorScreen.getPrefKey('ve_previewWidth_$type')) ?? (type == 'APP' ? projectSimW : 140.0),
            'h': prefs.getDouble(VisualEditorScreen.getPrefKey('ve_previewHeight_$type')) ?? (type == 'APP' ? projectSimH : 248.0),
        };
    }

    final savedMode = prefs.getString(VisualEditorScreen.getPrefKey('ve_previewMode')) ?? 'APP';
    final dims = _getDimsFor(savedMode);

    setState(() {
        _isLoaded = true;
      _previewMode = savedMode;
      _previewX = dims['x']!;
      _previewY = dims['y']!;
      _previewWidth = dims['w']!;
      _previewHeight = dims['h']!;

      _uiScale = prefs.getDouble(VisualEditorScreen.getPrefKey('ve_uiScale')) ?? 1.0;
      
      _simulatedPlatform = prefs.getString(VisualEditorScreen.getPrefKey('ve_simulatedPlatform')) ?? 'MOBILE';
      _previewAspectRatio = prefs.getString(VisualEditorScreen.getPrefKey('ve_previewAspectRatio')) ?? 'FREE';
      _previewResolution = prefs.getString(VisualEditorScreen.getPrefKey('ve_previewResolution')) ?? 'Custom';
      _isHeightPinned = prefs.getBool(VisualEditorScreen.getPrefKey('ve_isHeightPinned')) ?? false;
      _isPreviewLandscape = prefs.getBool(VisualEditorScreen.getPrefKey('ve_isPreviewLandscape')) ?? false;
    });
  }

  Future<void> _saveSimulatorPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Sync current active dimensions map before saving
    if (_previewModeDims.containsKey(_previewMode)) {
        _previewModeDims[_previewMode]!['x'] = _previewX;
        _previewModeDims[_previewMode]!['y'] = _previewY;
        _previewModeDims[_previewMode]!['w'] = _previewWidth;
        _previewModeDims[_previewMode]!['h'] = _previewHeight;
    }

    for (String type in ['APP', 'ELEMENT']) {
        final dims = _previewModeDims[type];
        if (dims == null) continue;
        await prefs.setDouble(VisualEditorScreen.getPrefKey('ve_previewX_$type'), dims['x']!);
        await prefs.setDouble(VisualEditorScreen.getPrefKey('ve_previewY_$type'), dims['y']!);
        await prefs.setDouble(VisualEditorScreen.getPrefKey('ve_previewWidth_$type'), dims['w']!);
        await prefs.setDouble(VisualEditorScreen.getPrefKey('ve_previewHeight_$type'), dims['h']!);
    }

    await prefs.setString(VisualEditorScreen.getPrefKey('ve_simulatedPlatform'), _simulatedPlatform);
    await prefs.setString(VisualEditorScreen.getPrefKey('ve_previewAspectRatio'), _previewAspectRatio);
    await prefs.setString(VisualEditorScreen.getPrefKey('ve_previewMode'), _previewMode);
    await prefs.setString(VisualEditorScreen.getPrefKey('ve_previewResolution'), _previewResolution);
    await prefs.setBool(VisualEditorScreen.getPrefKey('ve_isHeightPinned'), _isHeightPinned);
    await prefs.setBool(VisualEditorScreen.getPrefKey('ve_isPreviewLandscape'), _isPreviewLandscape);
  }

  void _handleResize({
    double dx = 0,
    double dy = 0,
    bool isLeft = false,
    bool isTop = false,
    bool isRight = false,
    bool isBottom = false,
  }) {
    setState(() {
      double minW = 100 * _uiScale;
      double minH = 100 * _uiScale;
      double oldW = _previewWidth;
      double oldH = _previewHeight;

      double nW = _previewWidth + (isRight ? dx : 0) - (isLeft ? dx : 0);
      double nH = _previewHeight + (isBottom ? dy : 0) - (isTop ? dy : 0);

      if (_previewAspectRatio != 'FREE') {
        final parts = _previewAspectRatio.split(':');
        if (parts.length == 2) {
          double rw = double.tryParse(parts[0]) ?? 1.0;
          double rh = double.tryParse(parts[1]) ?? 1.0;
          double targetAspect = rw / rh;
          if (!_isPreviewLandscape) {
             targetAspect = 1.0 / targetAspect; 
          }

          if (dx.abs() > dy.abs() || (isLeft || isRight) && !isTop && !isBottom) {
             nH = nW / targetAspect;
          } else {
             nW = nH * targetAspect;
          }
        }
      }

      if (nW < minW) { nW = minW; if (_previewAspectRatio != 'FREE') nH = nW / (_previewWidth/_previewHeight); }
      if (nH < minH) { nH = minH; if (_previewAspectRatio != 'FREE') nW = nH * (_previewWidth/_previewHeight); }

      if (isLeft) _previewX -= (nW - oldW);
      if (isTop) _previewY -= (nH - oldH);

      _previewWidth = nW;
      _previewHeight = nH;
    });
  }

  Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(
        cursor: cursor, 
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, 
          onPanUpdate: pan, 
          onPanEnd: (_) => _saveSimulatorPreferences(), 
          child: Container(color: Colors.transparent)
        )
      )
    );
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return const SizedBox.shrink();

    return Positioned(
      left: _previewX,
      top: _previewY,
      child: Listener(
        onPointerDown: (_) => widget.onFocus?.call(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              elevation: 24,
              color: AppColors.windowBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: _previewWidth,
                height: _previewHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A. Drag Handle / Title Bar
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _previewX += details.delta.dx;
                          _previewY += details.delta.dy;
                        });
                      },
                      onPanEnd: (_) => _saveSimulatorPreferences(),
                      child: Container(
                        width: double.infinity,
                        height: 32 * _uiScale,
                        color: AppColors.controlBorder,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                padding: EdgeInsets.symmetric(horizontal: 8 * _uiScale),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                            DropdownButton<String>(
                              value: ['MOBILE', 'WEB', 'DESKTOP'].contains(_simulatedPlatform) ? _simulatedPlatform : 'MOBILE',
                              dropdownColor: AppColors.panelBackground,
                              underline: const SizedBox(),
                              icon: Icon(
                                  _simulatedPlatform == 'MOBILE'
                                      ? Icons.phone_android
                                      : (_simulatedPlatform == 'WEB'
                                          ? Icons.web
                                          : Icons.desktop_mac),
                                  size: 16 * _uiScale,
                                  color: AppColors.panelTextPrimary),
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize * _uiScale),
                              items: const [
                                DropdownMenuItem(value: 'MOBILE', child: Text('MOBILE')),
                                DropdownMenuItem(value: 'WEB', child: Text('WEB')),
                                DropdownMenuItem(value: 'DESKTOP', child: Text('DESKTOP')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _simulatedPlatform = val);
                                  _saveSimulatorPreferences();
                                }
                              },
                            ),
                            SizedBox(width: 8 * _uiScale),
                            DropdownButton<String>(
                              value: ['16:9', '16:10', '4:3', '1:1', '9:16', 'FREE'].contains(_previewAspectRatio) ? _previewAspectRatio : 'FREE',
                              dropdownColor: AppColors.panelBackground,
                              underline: const SizedBox(),
                              icon: Icon(Icons.aspect_ratio, size: 16 * _uiScale, color: AppColors.panelTextPrimary),
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize * _uiScale),
                              items: const [
                                DropdownMenuItem(value: '16:9', child: Text('16:9')),
                                DropdownMenuItem(value: '16:10', child: Text('16:10')),
                                DropdownMenuItem(value: '4:3', child: Text('4:3')),
                                DropdownMenuItem(value: '1:1', child: Text('1:1')),
                                DropdownMenuItem(value: '9:16', child: Text('9:16')),
                                DropdownMenuItem(value: 'FREE', child: Text('FREE')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _previewAspectRatio = val;
                                    if (val != 'FREE') {
                                      _previewResolution = 'Custom';
                                      double aspect = double.parse(val.split(':')[0]) / double.parse(val.split(':')[1]);
                                      if (_isPreviewLandscape) {
                                        _previewWidth = _previewHeight * aspect;
                                      } else {
                                        _previewHeight = _previewWidth * aspect;
                                      }
                                    }
                                  });
                                  _saveSimulatorPreferences();
                                }
                              },
                            ),
                            SizedBox(width: 8 * _uiScale),
                            DropdownButton<String>(
                              value: ['Custom', '390x844', '412x915', '1024x768', '1280x720', '1920x1080', '2560x1440'].contains(_previewResolution) ? _previewResolution : 'Custom',
                              dropdownColor: AppColors.panelBackground,
                              underline: const SizedBox(),
                              icon: Icon(Icons.monitor, size: 16 * _uiScale, color: AppColors.panelTextPrimary),
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize * _uiScale),
                              items: const [
                                DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                                DropdownMenuItem(value: '390x844', child: Text('390x844 (iPhone 14)')),
                                DropdownMenuItem(value: '412x915', child: Text('412x915 (Pixel 7)')),
                                DropdownMenuItem(value: '1024x768', child: Text('1024x768')),
                                DropdownMenuItem(value: '1280x720', child: Text('1280x720 (720p)')),
                                DropdownMenuItem(value: '1920x1080', child: Text('1920x1080 (1080p)')),
                                DropdownMenuItem(value: '2560x1440', child: Text('2560x1440 (1440p)')),
                              ],
                              onChanged: (val) {
                                if (val != null && val != 'Custom') {
                                  setState(() {
                                    _previewResolution = val;
                                    _previewAspectRatio = 'FREE';
                                    final parts = val.split(' ')[0].split('x');
                                    double rW = double.parse(parts[0]);
                                    double rH = double.parse(parts[1]);
                                    if (!_isPreviewLandscape && rW > rH) {
                                      _previewWidth = rH;
                                      _previewHeight = rW;
                                    } else if (_isPreviewLandscape && rH > rW) {
                                      _previewWidth = rH;
                                      _previewHeight = rW;
                                    } else {
                                      _previewWidth = rW;
                                      _previewHeight = rH;
                                    }
                                  });
                                  _saveSimulatorPreferences();
                                }
                              },
                            ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isHeightPinned = !_isHeightPinned;
                                });
                                _saveSimulatorPreferences();
                              },
                              child: Padding(
                                padding: EdgeInsets.all(4.0 * _uiScale),
                                child: Icon(_isHeightPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    size: 16 * _uiScale, color: _isHeightPinned ? AppColors.accent : AppColors.panelTextPrimary),
                              ),
                            ),
                            SizedBox(width: 8 * _uiScale),
                            if (_activeEditorMode == 10) ...[
                              SizedBox(width: 8 * _uiScale),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    VisualEditorScreen.sandboxTestingKey = GlobalKey();
                                  });
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(2.0 * _uiScale),
                                  child: Icon(Icons.refresh, size: 16 * _uiScale, color: AppColors.accent),
                                ),
                              ),
                            ],
                            SizedBox(width: 8 * _uiScale),
                            Tooltip(
                              message: _previewMode == 'APP' ? 'Switch to Element Mode' : 'Switch to App Mode',
                              child: GestureDetector(
                                onTap: () {
                                  setPreviewMode(_previewMode == 'APP' ? 'ELEMENT' : 'APP');
                                  if (_previewMode == 'APP') {
                                      setState(() {
                                        VisualEditorScreen.sandboxTestingKey = GlobalKey();
                                      });
                                  }
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(2.0 * _uiScale),
                                  child: Icon(_previewMode == 'APP' ? Icons.app_shortcut : Icons.view_timeline,
                                      size: 16 * _uiScale, color: Colors.amberAccent),
                                ),
                              ),
                            ),
                            SizedBox(width: 4 * _uiScale),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPreviewLandscape = !_isPreviewLandscape;
                                  if (_isPreviewLandscape) {
                                    _previewWidth = _previewWidth * (800.0 / 450.0);
                                  } else {
                                    _previewWidth = _previewWidth * (450.0 / 800.0);
                                  }
                                  if (_previewWidth < 420 * _uiScale) _previewWidth = 420 * _uiScale;
                                  if (_previewWidth > 1200) _previewWidth = 1200;
                                  
                                  context.read<LyricsViewController>().simulatedOrientation = 
                                      _isPreviewLandscape ? Orientation.landscape : Orientation.portrait;
                                });
                                _saveSimulatorPreferences();
                              },
                              child: Padding(
                                padding: EdgeInsets.all(2.0 * _uiScale),
                                child: Icon(Icons.screen_rotation, size: 16 * _uiScale, color: AppColors.panelTextPrimary),
                              ),
                            ),
                            SizedBox(width: 4 * _uiScale),
                            GestureDetector(
                              onTap: widget.onClose,
                              child: Padding(
                                padding: EdgeInsets.all(2.0 * _uiScale),
                                child: Icon(Icons.close, size: 16 * _uiScale, color: Colors.redAccent),
                              ),
                            ),
                            SizedBox(width: 14 * _uiScale),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: VisualEditorScreen.isSimulatorPausedNotifier,
                          builder: (context, isPaused, child) {
                            return TickerMode(
                              enabled: !isPaused,
                              child: IgnorePointer(
                                ignoring: isPaused,
                                child: _previewMode == 'APP' ? _buildAppPreview() : _buildElementPreview(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            rz(t: 0, l: 24, r: 24, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (details) => _handleResize(dy: details.delta.dy, isTop: true)),
            rz(b: 0, l: 24, r: 24, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (details) => _handleResize(dy: details.delta.dy, isBottom: true)),
            rz(l: 0, t: 24, b: 24, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (details) => _handleResize(dx: details.delta.dx, isLeft: true)),
            rz(r: 0, t: 24, b: 24, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (details) => _handleResize(dx: details.delta.dx, isRight: true)),
            rz(t: 0, l: 0, w: 24, h: 24, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (details) => _handleResize(dx: details.delta.dx, dy: details.delta.dy, isLeft: true, isTop: true)),
            rz(t: 0, r: 0, w: 24, h: 24, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (details) => _handleResize(dx: details.delta.dx, dy: details.delta.dy, isRight: true, isTop: true)),
            rz(b: 0, l: 0, w: 24, h: 24, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (details) => _handleResize(dx: details.delta.dx, dy: details.delta.dy, isLeft: true, isBottom: true)),
            rz(b: 0, r: 0, w: 24, h: 24, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (details) => _handleResize(dx: details.delta.dx, dy: details.delta.dy, isRight: true, isBottom: true)),
            Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  height: 24,
                  color: Colors.transparent,
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.open_in_full, size: 14, color: AppColors.panelTextSecondary),
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              right: 0,
              child: _SimulatorTelemetryEmitter(),
            ),
          ],
        ),
      ), // Closes Listener
    );
  }

  Widget _buildAppPreview() {
    return Container(
      color: Colors.black,
      child: ClipRect(
        child: Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) {
                return MaterialApp(
                    key: VisualEditorScreen.sandboxTestingKey,
                    debugShowCheckedModeBanner: false,
                    themeMode: context.watch<ThemeController>().themeMode,
                    theme: AppTheme.buildTheme(Brightness.light),
                    darkTheme: AppTheme.buildTheme(Brightness.dark),
                    onGenerateRoute: AppRoutes.onGenerateRoute,
                    initialRoute: AppRoutes.listen,
                    builder: (context, child) {
                      final original = MediaQuery.of(context);
                      return MediaQuery(
                        data: original.copyWith(size: Size(_previewWidth, _previewHeight)),
                        child: child!,
                      );
                    },
                    scrollBehavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.touch,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                  );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildElementPreview() {
    return Container(
      color: Colors.black,
      child: Builder(
        builder: (context) {
          final original = MediaQuery.of(context);
          return MediaQuery(
            data: original.copyWith(size: Size(_previewWidth, _previewHeight)),
            child: NowPlayingScreen(
              tiltStreamController: widget.tiltStreamController,
              isElementPreview: true,
            ),
          );
        }
      ),
    );
  }
}

class _SimulatorTelemetryEmitter extends StatefulWidget {
  const _SimulatorTelemetryEmitter();
  @override
  State<_SimulatorTelemetryEmitter> createState() => _SimulatorTelemetryEmitterState();
}

class _SimulatorTelemetryEmitterState extends State<_SimulatorTelemetryEmitter>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {});
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

