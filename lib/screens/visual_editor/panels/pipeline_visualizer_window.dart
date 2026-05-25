import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../widgets/visualizer/state_machine_visualizer.dart';

final ValueNotifier<bool> showPipelineVisualizerNotifier = () {
  final notifier = ValueNotifier<bool>(false);
  SharedPreferences.getInstance().then((prefs) {
    if (prefs.getBool('ve_showPipelineVisualizer') == true) {
      notifier.value = true;
    }
  });
  return notifier;
}();

void showPipelineVisualizerWindow(BuildContext context) {
  if (showPipelineVisualizerNotifier.value) return;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool('ve_showPipelineVisualizer', true));
  showPipelineVisualizerNotifier.value = true;
}

void hidePipelineVisualizerWindow() {
  showPipelineVisualizerNotifier.value = false;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool('ve_showPipelineVisualizer', false));
}

void togglePipelineVisualizerWindow() async {
  showPipelineVisualizerNotifier.value = !showPipelineVisualizerNotifier.value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('ve_showPipelineVisualizer', showPipelineVisualizerNotifier.value);
}

class PipelineVisualizerWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;

  const PipelineVisualizerWindow({
    super.key,
    required this.isDocked,
    this.onClose,
    this.onFocus,
  });

  @override
  State<PipelineVisualizerWindow> createState() => _PipelineVisualizerWindowState();
}

class _PipelineVisualizerWindowState extends State<PipelineVisualizerWindow> {
  Offset _position = const Offset(150, 150);
  double _width = 750;
  double _height = 550;
  double _bgOpacity = 0.4;

  @override
  void initState() {
    super.initState();
    _loadState();
    VisualEditorScreen.currentWorkspace.addListener(_loadState);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadState);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadState);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadState);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _position = Offset(
          prefs.getDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_x')) ?? 150,
          prefs.getDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_y')) ?? 150,
        );
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_w')) ?? 750;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_h')) ?? 550;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
      });
    }
  }

  void _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_x'), _position.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_y'), _position.dy);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pipeline_visualizer_h'), _height);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDocked) {
      return const Material(
        color: Colors.transparent,
        child: PipelineVisualizerPanel(),
      );
    }

    final mq = MediaQuery.of(context).size;
    final w = _width.clamp(300.0, mq.width);
    final h = _height.clamp(200.0, mq.height);

    final dx = _position.dx.clamp(0.0, (mq.width - w).clamp(0.0, double.infinity));
    final dy = _position.dy.clamp(0.0, (mq.height - h).clamp(0.0, double.infinity));

    Widget rz({
      double? t, double? b, double? l, double? r, double? dw, double? dh,
      required MouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: dw, height: dh,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) => widget.onFocus?.call(),
          onPanUpdate: pan,
          onPanEnd: (_) => _saveState(),
          child: Container(color: Colors.transparent),
        ),
      ),
    );

    return Positioned(
      left: dx,
      top: dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: w,
            height: h,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: AppUIConfig.windowBorderWidth > 0
                      ? Border.all(
                          color: VisualEditorScreen.activeWindowNotifier.value == 'pipeline_visualizer'
                              ? AppColors.activeWindowBorder
                              : AppColors.border,
                          width: AppUIConfig.windowBorderWidth,
                        )
                      : null,
                  color: AppColors.windowBackground.withOpacity(_bgOpacity),
                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (_) => widget.onFocus?.call(),
                      onPanUpdate: (d) => setState(() => _position += d.delta),
                      onPanEnd: (_) => _saveState(),
                      child: Container(
                        height: AppUIConfig.titleBarHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.titleBarBackground.withOpacity(_bgOpacity),
                          border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppUIConfig.windowBorderRadius),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AppToolWindows.getDef('pipeline_visualizer').icon,
                              size: 16,
                              color: AppToolWindows.getDef('pipeline_visualizer').color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppUIConfig.formatWindowTitle('Pipeline Visualizer'),
                              style: TextStyle(
                                color: AppColors.titleBarTextPrimary,
                                fontSize: AppUIConfig.windowTitleFontSize,
                                fontWeight: AppUIConfig.windowTitleFontWeight,
                              ),
                            ),
                            const Spacer(),
                            if (widget.onClose != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.close,
                                    color: AppColors.titleBarTextSecondary, size: 16),
                                onPressed: widget.onClose,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (_) => widget.onFocus?.call(),
                        child: const PipelineVisualizerPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          rz(r: -5, b: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nW = _width + d.delta.dx; double nH = _height + d.delta.dy; if(nW > 300) _width = nW; if(nH > 200) _height = nH; })),
          rz(l: -5, b: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){ double nW = _width - d.delta.dx; double nH = _height + d.delta.dy; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } if(nH > 200) _height = nH; })),
          rz(r: -5, t: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){ double nW = _width + d.delta.dx; double nH = _height - d.delta.dy; if(nW > 300) _width = nW; if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } })),
          rz(l: -5, t: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nW = _width - d.delta.dx; double nH = _height - d.delta.dy; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } })),
          rz(r: -5, t: 10, b: 10, dw: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){ double nW = _width + d.delta.dx; if(nW > 300) _width = nW; })),
          rz(l: -5, t: 10, b: 10, dw: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){ double nW = _width - d.delta.dx; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } })),
          rz(b: -5, l: 10, r: 10, dh: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nH = _height + d.delta.dy; if(nH > 200) _height = nH; })),
          rz(t: -5, l: 10, r: 10, dh: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nH = _height - d.delta.dy; if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } }))
        ],
      ),
    );
  }
}

class PipelineVisualizerPanel extends StatelessWidget {
  const PipelineVisualizerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final aiService = AiBridgeService.instance;

    return ListenableBuilder(
      listenable: aiService.stateMachine.visualController,
      builder: (context, child) {
        final visualState = aiService.stateMachine.visualController.visualState;
        final stateNode = aiService.stateMachine.visualController.config.getNode(visualState.activeStateId);
        final baseColor = stateNode?.color ?? Colors.grey;

        return Column(
          children: [
            // Top Ribbon Status Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.panelBackground,
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  // Color dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: baseColor.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PIPELINE STATUS:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (stateNode?.label ?? visualState.activeStateId).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Manual Recovery Controls
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white.withOpacity(0.04),
                    ),
                    icon: const Icon(Icons.restart_alt, size: 13, color: Colors.white70),
                    label: const Text(
                      'Force Idle',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    onPressed: () {
                      aiService.stateMachine.enterIdle();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Natively reset AI Bridge state machine to IDLE.')),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Central Graph Viewport
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return StateMachineVisualizer(
                    controller: aiService.stateMachine.visualController,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  );
                },
              ),
            ),

            // Bottom Diagnostics Log outcomes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111115),
                border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notes, size: 13, color: baseColor),
                      const SizedBox(width: 6),
                      Text(
                        'ACTIVE METADATA',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Entered: ${_formatTime(visualState.enteredAt)}',
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    visualState.statusMessage.isNotEmpty
                        ? visualState.statusMessage
                        : 'No active diagnostic message.',
                    style: TextStyle(
                      color: visualState.hasError ? Colors.redAccent : Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
