import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showTestBedNotifier = ValueNotifier(false);

void showTestBedWindow(BuildContext context) {
  if (showTestBedNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showTestBed'), true));
  showTestBedNotifier.value = true;
}

void hideTestBedWindow() {
  showTestBedNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showTestBed'), false));
}

class TestBedWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const TestBedWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});
  @override
  State<TestBedWindow> createState() => _TestBedWindowState();
}
class _TestBedWindowState extends State<TestBedWindow> {
  Color _testColor = Colors.red;
  bool _isLoaded = false;

  double _width = 400;
  double _height = 300;
  bool _isCollapsed = false;
  double _bgOpacity = 0.8;
  Offset _offset = const Offset(150, 150);

  final TextEditingController _testCommandController = TextEditingController();
  
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
    _testCommandController.dispose();
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

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('testbed_width')) ?? 400;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('testbed_height')) ?? 300;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('testbed_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('testbed_dx')) ?? 150;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('testbed_dy')) ?? 150;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testbed_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testbed_height'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('testbed_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testbed_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testbed_dy'), _offset.dy);
  }

  void _sendTestCommand() {
    final command = _testCommandController.text.trim();
    if (command.isEmpty) return;
    
    // Natively drop it as a task into the bridge natively if AiBridge framework exists
    // (We will simulate it just printing directly for now, or use AiBridgeService)
    AiBridgeService.instance.addTask(
        'TEST COMMAND',
        'Command received natively from Test Bed window.',
        notes: 'User triggered command payload: $command',
    );
    _testCommandController.clear();
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildContent());
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
                  elevation: 8,
                  child: Container(
                    width: _width,
                    height: _isCollapsed ? null : _height,
                    clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'test_bed' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppUIConfig.windowBorderRadius))),
                          child: Row(
                            children: [
                              Icon((AppToolWindows.getDef('test_bed')?.icon ?? Icons.science), size: 16, color: (AppToolWindows.getDef('test_bed')?.color ?? Colors.grey)),
                              const SizedBox(width: 8),
                              Text((AppToolWindows.getDef('test_bed')?.name ?? 'Test Bed').toUpperCase(), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18, color: AppColors.titleBarTextSecondary),
                                  onPressed: widget.onClose,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),
                        ),
                        if (!_isCollapsed)
                          Expanded(child: _buildContent()),
                      ])
                  ),
                ),
              ),
                rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height - d.delta.dy;
                    if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height + d.delta.dy;
                    if (nH >= 200 && nH <= 1200) { _height = nH; }
                })),
                rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx;
                    if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                })),
                rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx;
                    if (nW >= 200 && nW <= 1600) { _width = nW; }
                })),
                rz(t: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(t: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 200 && nW <= 1600) { _width = nW; }
                    if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 200 && nH <= 1200) { _height = nH; }
                })),
                rz(b: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 200 && nW <= 1600) { _width = nW; }
                    if (nH >= 200 && nH <= 1200) { _height = nH; }
                })),
              ],
            ),
           ),
          );
        },
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _testCommandController,
            style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
            decoration: InputDecoration(
              hintText: 'Enter command...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.panelBackground,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.accent,
            ),
            onPressed: () { _sendTestCommand(); },
            icon: Icon(Icons.send, color: AppColors.panelTextPrimary),
            label: Text('Send Command', style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


