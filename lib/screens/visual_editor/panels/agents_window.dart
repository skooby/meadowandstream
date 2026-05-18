import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../constants.dart';
import '../../../widgets/ai_copilot/agents_panel.dart';
import '../../../widgets/ai_copilot/ai_copilot_theme.dart';

final ValueNotifier<bool> showAgentsNotifier = ValueNotifier(false);

void showAgentsWindow(BuildContext context) {
  if (showAgentsNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showAgents'), true));
  showAgentsNotifier.value = true;
}

void hideAgentsWindow() {
  showAgentsNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showAgents'), false));
}

class AgentsWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const AgentsWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});
  @override
  State<AgentsWindow> createState() => _AgentsWindowState();
}

class _AgentsWindowState extends State<AgentsWindow> {
  final GlobalKey<AgentsPanelState> _panelKey = GlobalKey<AgentsPanelState>();
  double _width = 450;
  double _height = 400;
  bool _isCollapsed = false;
  double _bgOpacity = 0.8;
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
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('agents_window_width')) ?? 450;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('agents_window_height')) ?? 400;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('agents_window_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('agents_window_dx')) ?? 200;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('agents_window_dy')) ?? 200;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('agents_window_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('agents_window_height'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('agents_window_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('agents_window_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('agents_window_dy'), _offset.dy);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDocked) {
      return Material(
        color: Colors.transparent, 
        child: AgentsPanel(
          key: _panelKey,
          theme: _buildTheme(),
          onDispatch: (moduleName, payload) => _handleDispatch(moduleName, payload),
        )
      );
    }

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
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'agents' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                              Icon((AppToolWindows.getDef('agents')?.icon ?? Icons.lightbulb), size: 16, color: (AppToolWindows.getDef('agents')?.color ?? Colors.amber)),
                              const SizedBox(width: 8),
                              Text((AppToolWindows.getDef('agents')?.name ?? 'Agents').replaceAll('_', ' ').toUpperCase(), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.settings, size: 16, color: Colors.white54),
                                  onPressed: () => _panelKey.currentState?.showManageSystemPromptDialog(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, size: 16, color: Colors.amberAccent),
                                  onPressed: () => _panelKey.currentState?.showEditNodeDialog(null, null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
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
                          Expanded(
                            child: AgentsPanel(
                              key: _panelKey,
                              theme: _buildTheme(),
                              onDispatch: (moduleName, payload) => _handleDispatch(moduleName, payload),
                            ),
                          ),
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

  Future<void> _handleDispatch(String moduleName, String payload) async {
    final taskName = "SUGGESTION : $moduleName";
    
    AiTask? suggestionFolder;
    try {
        suggestionFolder = AiBridgeService.instance.tasks.firstWhere((t) => t.isFolder && t.name.toUpperCase() == 'AGENTS');
    } catch (_) {}
    
    if (suggestionFolder == null) {
        suggestionFolder = await AiBridgeService.instance.addTask(
            'AGENTS',
            'AI Generated Agent Tasks',
            isFolder: true,
            highlightColor: 0xFFFFC107,
            iconBackgroundColor: 0xFFFFC107,
        );
    }
    
    final newTask = await AiBridgeService.instance.addTask(
        taskName,
        'Agent working...',
        parentId: suggestionFolder.id,
        status: AiTaskStatus.inProgress,
    );
    
    AiBridgeService.instance.sendToQueue(payload, false, taskIds: [newTask.id]);
  }

  AiCopilotTheme _buildTheme() {
    return AiCopilotTheme(
      background: AppColors.windowBackground,
      panelBackground: AppColors.panelBackground,
      borderSubtle: AppColors.borderSubtle,
      textPrimary: AppColors.panelTextPrimary,
      textSecondary: AppColors.panelTextSecondary,
      textMuted: AppColors.textMuted,
      accent: AppColors.accent,
      danger: Colors.redAccent,
      cornerRadius: AppDimensions.cornerRadius,
      rootFontSize: AppUIConfig.rootFontSize,
      smallFontSize: AppUIConfig.smallFontSize,
      headerFontSize: AppUIConfig.headerFontSize,
      parentLabelsUppercase: true,
      parentLabelsBold: true,
      childLabelsUppercase: false,
      childLabelsBold: false,
    );
  }
}
