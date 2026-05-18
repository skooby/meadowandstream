import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../window_dock_manager.dart';
import '../../../constants.dart';


final ValueNotifier<bool> showTimelineNotifier = ValueNotifier(false);
final ValueNotifier<bool> isTimelineDockedNotifier = ValueNotifier(false);

void showTimelineWindow(BuildContext context) {
  if (showTimelineNotifier.value) return;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showTimeline'), true));
  showTimelineNotifier.value = true;
}

void hideTimelineWindow() {
  showTimelineNotifier.value = false;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showTimeline'), false));
}

class TimelineWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  final GlobalKey<TimelinePanelState>? panelKey;
  
  const TimelineWindow({super.key, required this.onClose, this.onFocus, this.panelKey, this.isDocked = false});

  @override
  State<TimelineWindow> createState() => _TimelineWindowState();
}
class _TimelineWindowState extends State<TimelineWindow> {
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

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('timeline_w')) ?? 1000;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('timeline_h')) ?? 650;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.95;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('timeline_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('timeline_dx')) ?? 100;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('timeline_dy')) ?? 100;
        _offset = Offset(dx, dy);
      });
      // NOTE: dock state is now managed by WindowDockManager, not loaded from prefs here
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('timeline_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('timeline_h'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('timeline_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('timeline_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('timeline_dy'), _offset.dy);
    await prefs.setBool(VisualEditorScreen.getPrefKey('timeline_isDocked'), isTimelineDockedNotifier.value);
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: TimelinePanel(key: widget.panelKey));
    Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: pan, onPanEnd: (_) => _savePreferences(), child: Container(color: Colors.transparent)))
    );

    return ValueListenableBuilder<bool>(
      valueListenable: isTimelineDockedNotifier,
      builder: (context, isDocked, _) {
        if (isDocked) return const SizedBox.shrink();

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
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'timeline' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                          color: AppColors.windowBackground.withValues(alpha: _bgOpacity),
                          borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                          
                        ),
                        child: Column(children: [
                          GestureDetector(
                            onPanUpdate: (details) {
                              setState(() => _offset += details.delta);
                            },
                            onPanEnd: (_) {
                              if (_offset.dy > MediaQuery.of(context).size.height - 150) {
                                isTimelineDockedNotifier.value = true;
                              }
                              _savePreferences();
                            },
                            onSecondaryTapDown: (details) {
                              showMenu(
                                context: context,
                                color: AppColors.panelBackground,
                                position: RelativeRect.fromLTRB(
                                  details.globalPosition.dx,
                                  details.globalPosition.dy,
                                  details.globalPosition.dx,
                                  details.globalPosition.dy,
                                ),
                                items: [
                                  PopupMenuItem(
                                    value: 'reset',
                                    height: 32,
                                    child: Text('Reset Window', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                                    onTap: () {
                                      final mq = MediaQuery.of(context).size;
                                      setState(() {
                                        _offset = Offset(
                                          (mq.width - _width) / 2,
                                          (mq.height - _height) / 2,
                                        );
                                      });
                                      _savePreferences();
                                    },
                                  ),
                                ],
                              );
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
                                  Icon(Icons.timeline,
                                      size: 16, color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Text(AppUIConfig.formatWindowTitle('Timeline'), style: TextStyle(
                                          color: AppColors.titleBarTextPrimary,
                                          fontSize: AppUIConfig.rootFontSize,
                                          fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),
                                  PopupMenuButton<DockPosition>(
                                    icon: const Icon(Icons.push_pin, size: 16, color: Colors.white60),
                                    tooltip: 'Dock Panel',
                                    color: AppColors.panelBackground,
                                    padding: EdgeInsets.zero,
                                    position: PopupMenuPosition.under,
                                    onSelected: (pos) {
                                       final p = WindowDockManager.instance.panels.firstWhere((p) => p.id == 'timeline');
                                       p.dock(pos);
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<DockPosition>>[
                                      PopupMenuItem<DockPosition>(
                                        value: DockPosition.left,
                                        height: 32,
                                        child: Text('Dock Left', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                                      ),
                                      PopupMenuItem<DockPosition>(
                                        value: DockPosition.right,
                                        height: 32,
                                        child: Text('Dock Right', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                                      ),
                                      PopupMenuItem<DockPosition>(
                                        value: DockPosition.bottom,
                                        height: 32,
                                        child: Text('Dock Bottom', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                                      ),
                                      PopupMenuItem<DockPosition>(
                                        value: DockPosition.top,
                                        height: 32,
                                        child: Text('Dock Top', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                                      ),
                                    ],
                                  ),
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
                              child: TimelinePanel(),
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
        });
      }
    );
  }
}


