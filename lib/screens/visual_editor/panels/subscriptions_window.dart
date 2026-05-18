import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showSubscriptionsNotifier = ValueNotifier(false);

void showSubscriptionsWindow(BuildContext context) {
  if (showSubscriptionsNotifier.value) return;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showSubscriptions'), true));
  showSubscriptionsNotifier.value = true;
}

void hideSubscriptionsWindow() {
  showSubscriptionsNotifier.value = false;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showSubscriptions'), false));
}

class SubscriptionsWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const SubscriptionsWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<SubscriptionsWindow> createState() => _SubscriptionsWindowState();
}
class _SubscriptionsWindowState extends State<SubscriptionsWindow> {
  bool _isLoaded = false;

  double _width = 800;
  double _height = 500;
  bool _isCollapsed = false;
  double _bgOpacity = 0.95;
  Offset _offset = const Offset(200, 200);

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

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('subs_w')) ?? 800;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('subs_h')) ?? 500;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.95;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('subs_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('subs_dx')) ?? 200;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('subs_dy')) ?? 200;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('subs_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('subs_h'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('subs_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('subs_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('subs_dy'), _offset.dy);
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildSubsList());
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
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'subscriptions' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                      color: AppColors.windowBackground.withValues(alpha: _bgOpacity),
                      borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                      
                    ),
                    child: Column(children: [
                      GestureDetector(
                        onPanUpdate: (details) {
                          setState(() => _offset += details.delta);
                        },
                        onPanEnd: (_) => _savePreferences(),
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
                              Icon(Icons.subscriptions,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle('Subscriptions & Billing'), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),
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
                              child: Center(
                                child: Text('Subscriptions integration pending.', style: TextStyle(color: AppColors.panelTextSecondary))
                              ),
                            ),
                          )
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ));
        });
  }

  Widget _buildSubsList() {
     return Center(child: Text('Subscriptions integration pending.', style: TextStyle(color: AppColors.panelTextSecondary)));
  }
}


