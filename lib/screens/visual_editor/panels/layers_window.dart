import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../window_dock_manager.dart';
import '../../../constants.dart';


final ValueNotifier<bool> showLayersNotifier = ValueNotifier(false);
final ValueNotifier<bool> isLayersDockedNotifier = ValueNotifier(false);

void showLayersWindow(BuildContext context) {
  if (showLayersNotifier.value) return;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showLayers'), true));
  showLayersNotifier.value = true;
}

void hideLayersWindow() {
  showLayersNotifier.value = false;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showLayers'), false));
}

class LayersWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const LayersWindow({super.key, required this.onClose, this.onFocus});

  @override
  State<LayersWindow> createState() => _LayersWindowState();
}
class _LayersWindowState extends State<LayersWindow> {
  bool _isLoaded = false;

  double _width = 1000;
  double _height = 650;
  bool _isCollapsed = false;
  double _bgOpacity = 0.95;
  Offset _offset = const Offset(100, 100);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('layers_w')) ?? 1000;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('layers_h')) ?? 650;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.95;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('layers_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('layers_dx')) ?? 100;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('layers_dy')) ?? 100;
        _offset = Offset(dx, dy);
      });
      // NOTE: dock state is now managed by WindowDockManager, not loaded from prefs here
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('layers_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('layers_h'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('layers_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('layers_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('layers_dy'), _offset.dy);
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: pan, onPanEnd: (_) => _savePreferences(), child: Container(color: Colors.transparent)))
    );
    return ValueListenableBuilder<double>(
        valueListenable: VisualEditorScreen.globalUiScale,
        builder: (context, scale, child) {
          final mq = MediaQuery.of(context).size;
          final dx = _offset.dx.clamp(0.0, (mq.width - 100).clamp(0.0, double.infinity));
          final dy = _offset.dy.clamp(0.0, (mq.height - 100).clamp(0.0, double.infinity));

          return Positioned(
            left: dx,
            top: dy,
            child: Transform.scale(scale: 1.0, alignment: Alignment.topLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Listener(
                      onPointerDown: (_) => widget.onFocus?.call(),
                      behavior: HitTestBehavior.deferToChild,
                      child: Material(
                        color: Colors.transparent,
                      elevation: 12,
                      child: Container(
                        width: _width,
                        height: _isCollapsed ? null : _height,
                        clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'layer_tree' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                          color: AppColors.windowBackground.withValues(alpha: _bgOpacity),
                          borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                          
                        ),
                        child: Column(children: [
                          GestureDetector(
                            onPanUpdate: (details) {
                              setState(() => _offset += details.delta);
                            },
                            onPanEnd: (_) {
                              _savePreferences();
                            },
                            child: Container(
                              height: AppUIConfig.titleBarHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground.withValues(alpha: _bgOpacity),
                                  border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(AppUIConfig.windowBorderRadius))),
                              child: Row(
                                children: [
                                  Icon(Icons.layers,
                                      size: 16, color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Text(AppUIConfig.formatWindowTitle('Layer Tree'), style: TextStyle(
                                          color: AppColors.titleBarTextPrimary,
                                          fontSize: AppUIConfig.rootFontSize,
                                          fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),

                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(_isCollapsed ? Icons.expand_more : Icons.expand_less,
                                      size: 18, color: AppColors.accent),
                                  onPressed: () {
                                    setState(() => _isCollapsed = !_isCollapsed);
                                    _savePreferences();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18, color: AppColors.getAdaptiveAccent(AppColors.titleBarBackground)),
                                  onPressed: widget.onClose,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),
                        ),
                        if (!_isCollapsed)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(AppUIConfig.windowBorderRadius)),
                              child: LayerTreePanel(),
                            ),
                          )
                      ]),
                    ),
                  ),
                ),
                if (!_isCollapsed) ...[
                  rz(r: -5, b: -5, w: 10, h: 10, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState(() { _width = (_width + d.delta.dx).clamp(300.0, double.infinity); _height = (_height + d.delta.dy).clamp(200.0, double.infinity); })),
                  rz(l: -5, b: -5, w: 10, h: 10, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState(() { _offset += Offset(d.delta.dx, 0); _width = (_width - d.delta.dx).clamp(300.0, double.infinity); _height = (_height + d.delta.dy).clamp(200.0, double.infinity); })),
                  rz(r: -5, t: -5, w: 10, h: 10, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState(() { _offset += Offset(0, d.delta.dy); _width = (_width + d.delta.dx).clamp(300.0, double.infinity); _height = (_height - d.delta.dy).clamp(200.0, double.infinity); })),
                  rz(l: -5, t: -5, w: 10, h: 10, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState(() { _offset += d.delta; _width = (_width - d.delta.dx).clamp(300.0, double.infinity); _height = (_height - d.delta.dy).clamp(200.0, double.infinity); })),
                  rz(r: -5, t: 5, b: 5, w: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState(() { _width = (_width + d.delta.dx).clamp(300.0, double.infinity); })),
                  rz(l: -5, t: 5, b: 5, w: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState(() { _offset += Offset(d.delta.dx, 0); _width = (_width - d.delta.dx).clamp(300.0, double.infinity); })),
                  rz(b: -5, l: 5, r: 5, h: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState(() { _height = (_height + d.delta.dy).clamp(200.0, double.infinity); })),
                  rz(t: -5, l: 5, r: 5, h: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState(() { _offset += Offset(0, d.delta.dy); _height = (_height - d.delta.dy).clamp(200.0, double.infinity); })),
                ]
              ],
            ),
          ));
        }
    );
  }
}


