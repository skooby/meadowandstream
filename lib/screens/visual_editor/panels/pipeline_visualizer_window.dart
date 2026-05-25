import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../services/state_machine_models.dart';
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
          onPanDown: (_) {
            if (VisualEditorScreen.activeWindowNotifier.value != 'pipeline_visualizer') {
              widget.onFocus?.call();
            }
          },
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
                      onPanDown: (_) {
                        if (VisualEditorScreen.activeWindowNotifier.value != 'pipeline_visualizer') {
                          widget.onFocus?.call();
                        }
                      },
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
                        onTapDown: (_) {
                          if (VisualEditorScreen.activeWindowNotifier.value != 'pipeline_visualizer') {
                            widget.onFocus?.call();
                          }
                        },
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
        final stateNode = aiService.stateMachine.visualController.getNode(visualState.activeStateId);
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
                  
                  // Add Custom Node Button
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.purpleAccent.withOpacity(0.12),
                      foregroundColor: Colors.purpleAccent,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 13),
                    label: const Text(
                      'Add Node',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showAddNodeDialog(context, aiService.stateMachine.visualController),
                  ),
                  const SizedBox(width: 8),
                  
                  // Process Notes Button
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.amberAccent.withOpacity(0.12),
                      foregroundColor: Colors.amberAccent,
                    ),
                    icon: const Icon(Icons.psychology_outlined, size: 13),
                    label: const Text(
                      'Process Notes',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _processNotes(context, aiService.stateMachine.visualController),
                  ),
                  const SizedBox(width: 8),

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
            
            // Central Graph Viewport & Notes Sidebar
            Expanded(
              child: Row(
                children: [
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
                  _buildNoteSidebar(context, aiService.stateMachine.visualController),
                ],
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

  void _showAddNodeDialog(BuildContext context, StateMachineController controller) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final noteController = TextEditingController();
    Color selectedColor = Colors.purpleAccent;

    final colorOptions = [
      Colors.purpleAccent,
      Colors.deepPurpleAccent,
      Colors.blueAccent,
      Colors.cyanAccent,
      Colors.tealAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.redAccent,
      Colors.pinkAccent,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white10),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_box_outlined, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add Custom Pipeline Node',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Node Name/Label',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Database Error',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.purpleAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Description',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Tracks failures in the SQLite schema integrity',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.purpleAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Initial Note (Optional)',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Schema mismatch on migrations table...',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.purpleAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Node Color',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colorOptions.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Node label cannot be empty.')),
                      );
                      return;
                    }
                    
                    final nodeId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                    final newNode = StateNodeConfig(
                      id: nodeId,
                      label: nameController.text.trim(),
                      description: descController.text.trim(),
                      color: selectedColor,
                      position: const Offset(300, 200), // Default position
                    );
                    
                    controller.addCustomNode(newNode);
                    
                    if (noteController.text.trim().isNotEmpty) {
                      controller.setNodeNote(nodeId, noteController.text.trim());
                    }

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added node "${newNode.label}" to visualizer.')),
                    );
                  },
                  child: const Text('Add Node'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _processNotes(BuildContext context, StateMachineController controller) {
    final Map<String, String> notes = controller.nodeNotes;
    final activeNotes = notes.entries.where((e) => e.value.trim().isNotEmpty).toList();

    if (activeNotes.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: const Text('No Notes Found', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Please select a node, add some diagnostic notes describing what is going on, and then press Process Notes.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(color: Colors.purpleAccent)),
              ),
            ],
          );
        },
      );
      return;
    }

    // Compile notes into a prompt
    final sb = StringBuffer();
    sb.writeln('Please analyze the following state machine nodes and notes to identify the issues and suggest/implement fixes:');
    sb.writeln();

    for (final entry in activeNotes) {
      final node = controller.getNode(entry.key);
      final nodeLabel = node?.label ?? entry.key;
      sb.writeln('* Node: $nodeLabel (${entry.key})');
      sb.writeln('  Note: ${entry.value}');
      sb.writeln();
    }

    sb.writeln('Please investigate the codebase to resolve the described issues.');

    final prompt = sb.toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: const Text('Send Notes to LLM?', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following prompt will be sent to the LLM agent queue:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    prompt,
                    style: const TextStyle(color: Colors.white60, fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Send to LLM
                await AiBridgeService.instance.sendToQueue(prompt, true);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Successfully queued node notes to LLM for analysis.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Send to LLM'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoteSidebar(BuildContext context, StateMachineController controller) {
    final selectedId = controller.selectedNodeId;
    if (selectedId == null) {
      return _GlobalInputsSidebar(controller: controller);
    }

    final node = controller.getNode(selectedId);
    if (node == null) {
      return const SizedBox.shrink();
    }

    final isCustom = true;
    final noteText = controller.nodeNotes[selectedId] ?? '';
    final baseColor = node.color;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        border: Border(left: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(node.icon ?? Icons.label_outline, size: 14, color: baseColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 14, color: Colors.white38),
                  onPressed: () {
                    controller.selectNode(null);
                  },
                ),
              ],
            ),
          ),
          
          // Sidebar Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info block
                  if (node.description.isNotEmpty) ...[
                    Text(
                      node.description,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                  ],
                  
                  // Note field title
                  Row(
                    children: [
                      const Icon(Icons.edit_note, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        'DIAGNOSTIC NOTE',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Note textarea
                  _SidebarNoteTextField(
                    nodeId: selectedId,
                    initialValue: noteText,
                    controller: controller,
                  ),
                  const SizedBox(height: 12),
                  
                  // Actions: Clear note
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white12),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: const Icon(Icons.clear_all, size: 13, color: Colors.white70),
                          label: const Text(
                            'Clear Note',
                            style: TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                          onPressed: () {
                            controller.clearNodeNote(selectedId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cleared note for ${node.label}.')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  // If it is a custom node, show "Delete Node"
                  if (isCustom) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent, width: 0.5),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              backgroundColor: Colors.redAccent.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                            label: const Text(
                              'Delete Node',
                              style: TextStyle(fontSize: 10, color: Colors.redAccent),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E24),
                                    title: const Text('Delete Node?', style: TextStyle(color: Colors.white)),
                                    content: Text(
                                      'Are you sure you want to delete node "${node.label}"?',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          controller.removeNode(selectedId);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Deleted node "${node.label}".')),
                                          );
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  _SidebarNodeActionsEditor(
                    selectedNodeId: selectedId,
                    controller: controller,
                  ),
                  _SidebarTransitionsEditor(
                    selectedNodeId: selectedId,
                    controller: controller,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNoteTextField extends StatefulWidget {
  final String nodeId;
  final String initialValue;
  final StateMachineController controller;

  const _SidebarNoteTextField({
    required this.nodeId,
    required this.initialValue,
    required this.controller,
  });

  @override
  State<_SidebarNoteTextField> createState() => _SidebarNoteTextFieldState();
}

class _SidebarNoteTextFieldState extends State<_SidebarNoteTextField> {
  late TextEditingController _textController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_SidebarNoteTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId) {
      _textController.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.controller.setNodeNote(widget.nodeId, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentNote = widget.controller.nodeNotes[widget.nodeId] ?? '';
    if (currentNote != _textController.text && _debounceTimer?.isActive != true) {
      _textController.text = currentNote;
    }

    return TextField(
      controller: _textController,
      maxLines: 8,
      onChanged: _onChanged,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
      decoration: InputDecoration(
        hintText: 'Describe what is going on with this pipeline state/node...',
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
        filled: true,
        fillColor: Colors.black12,
        contentPadding: const EdgeInsets.all(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.purpleAccent, width: 0.8),
        ),
      ),
    );
  }
}

class _SidebarTransitionsEditor extends StatefulWidget {
  final String selectedNodeId;
  final StateMachineController controller;

  const _SidebarTransitionsEditor({
    required this.selectedNodeId,
    required this.controller,
  });

  @override
  State<_SidebarTransitionsEditor> createState() => _SidebarTransitionsEditorState();
}

class _SidebarTransitionsEditorState extends State<_SidebarTransitionsEditor> {
  String? _selectedTargetId;
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selectedId = widget.selectedNodeId;
    final outgoing = controller.allTransitions.where((t) => t.from == selectedId).toList();
    
    // Available target nodes (all nodes except this one)
    final targetNodes = controller.allNodes.where((n) => n.id != selectedId).toList();
    
    // If selected target is no longer valid or null, select the first available
    if (_selectedTargetId == null || !targetNodes.any((n) => n.id == _selectedTargetId)) {
      _selectedTargetId = targetNodes.isNotEmpty ? targetNodes.first.id : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.alt_route, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              'OUTGOING FLOWS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // List of Outgoing transitions
        if (outgoing.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No outgoing flows.',
              style: const TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          )
        else
          ...outgoing.map((t) {
            final targetNode = controller.getNode(t.to);
            final targetLabel = targetNode?.label ?? t.to;
            
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: targetNode?.color ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetLabel,
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            if (t.label.isNotEmpty)
                              Text(
                                'trigger: ${t.label}',
                                style: const TextStyle(color: Colors.white30, fontSize: 9, fontFamily: 'monospace'),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                        onPressed: () {
                          controller.removeTransition(t.from, t.to);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Removed flow to $targetLabel.')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _TransitionConditionsList(
                    from: t.from,
                    to: t.to,
                    conditions: t.conditions,
                    controller: controller,
                  ),
                ],
              ),
            );
          }),
        
        const SizedBox(height: 12),
        const Text(
          'ADD NEW FLOW',
          style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        const SizedBox(height: 6),
        
        if (targetNodes.isEmpty)
          const Text(
            'No target nodes available.',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          )
        else ...[
          // Target Dropdown
          DropdownButtonFormField<String>(
            value: _selectedTargetId,
            dropdownColor: const Color(0xFF1E1E24),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white10),
              ),
            ),
            items: targetNodes.map((n) {
              return DropdownMenuItem<String>(
                value: n.id,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: n.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(n.label),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedTargetId = val;
              });
            },
          ),
          const SizedBox(height: 8),
          
          // Trigger label field
          TextField(
            controller: _labelController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Trigger Label (optional)',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              filled: true,
              fillColor: Colors.black26,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.purpleAccent, width: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Add button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 13),
                  label: const Text('Add Flow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (_selectedTargetId == null) return;
                    final newTransition = TransitionConfig(
                      from: selectedId,
                      to: _selectedTargetId!,
                      label: _labelController.text.trim(),
                    );
                    controller.addCustomTransition(newTransition);
                    _labelController.clear();
                    
                    final targetNode = controller.getNode(_selectedTargetId!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added flow to ${targetNode?.label ?? _selectedTargetId}.')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GlobalInputsSidebar extends StatefulWidget {
  final StateMachineController controller;

  const _GlobalInputsSidebar({required this.controller});

  @override
  State<_GlobalInputsSidebar> createState() => _GlobalInputsSidebarState();
}

class _GlobalInputsSidebarState extends State<_GlobalInputsSidebar> {
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  StateMachineInputType _selectedType = StateMachineInputType.trigger;
  String? _editingInputName;

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        border: Border(left: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 14, color: Colors.purpleAccent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'STATE MACHINE INPUTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.amberAccent),
                  tooltip: 'Ask AI to Update Flow',
                  onPressed: () {
                    _showAiUpdateDialog(context, controller);
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final inputs = controller.allInputs;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (inputs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No inputs defined. Inputs represent variables (Triggers, Booleans, Numbers) that drive conditional state flows.',
                            style: TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ...inputs.map((input) {
                          final isEditingThis = _editingInputName == input.name;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _editingInputName = input.name;
                                _nameController.text = input.name;
                                _pathController.text = input.bindFilePath ?? '';
                                _selectedType = input.type;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: isEditingThis
                                    ? Colors.purpleAccent.withOpacity(0.08)
                                    : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isEditingThis ? Colors.purpleAccent : Colors.white10,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                              children: [
                                Icon(
                                  input.type == StateMachineInputType.trigger
                                      ? Icons.flash_on
                                      : (input.type == StateMachineInputType.boolean
                                          ? Icons.toggle_on
                                          : Icons.pin),
                                  size: 14,
                                  color: Colors.purpleAccent.withOpacity(0.7),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        input.name,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        input.type.name.toUpperCase(),
                                        style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace'),
                                      ),
                                      if (input.bindFilePath != null && input.bindFilePath!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '📄 ${input.bindFilePath!.split(RegExp(r"[/\\]")).last}',
                                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, overflow: TextOverflow.ellipsis),
                                            maxLines: 1,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                if (input.type == StateMachineInputType.trigger)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    onPressed: () => controller.triggerInput(input.name),
                                    child: const Text('Fire', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  )
                                else if (input.type == StateMachineInputType.boolean)
                                  Checkbox(
                                    value: input.value as bool? ?? false,
                                    activeColor: Colors.purpleAccent,
                                    onChanged: (val) {
                                      controller.updateInputValue(input.name, val ?? false);
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  )
                                else if (input.type == StateMachineInputType.number)
                                  SizedBox(
                                    width: 50,
                                    height: 24,
                                    child: TextField(
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
                                      controller: TextEditingController(text: (input.value ?? 0.0).toString())..selection = TextSelection.collapsed(offset: (input.value ?? 0.0).toString().length),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                        filled: true,
                                        fillColor: Colors.black26,
                                      ),
                                      onSubmitted: (val) {
                                        final doubleVal = double.tryParse(val) ?? 0.0;
                                        controller.updateInputValue(input.name, doubleVal);
                                      },
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                                  onPressed: () {
                                    controller.removeInput(input.name);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      
                      const Divider(color: Colors.white10, height: 24),
                      Text(
                        _editingInputName == null ? 'CREATE INPUT' : 'EDIT INPUT',
                        style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: 'Variable Name (e.g. speed)',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      DropdownButtonFormField<StateMachineInputType>(
                        value: _selectedType,
                        dropdownColor: const Color(0xFF1E1E24),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                        ),
                        items: StateMachineInputType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      
                      TextField(
                        controller: _pathController,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: 'File Binding Path (Optional)',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      if (_editingInputName != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purpleAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.check, size: 13),
                                label: const Text('Save Changes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  final name = _nameController.text.trim();
                                  if (name.isEmpty) return;
                                  
                                  final existingInput = controller.allInputs.firstWhere((i) => i.name == _editingInputName);
                                  
                                  dynamic defaultValue = existingInput.value;
                                  if (existingInput.type != _selectedType) {
                                    if (_selectedType == StateMachineInputType.boolean) {
                                      defaultValue = false;
                                    } else if (_selectedType == StateMachineInputType.number) {
                                      defaultValue = 0.0;
                                    } else {
                                      defaultValue = null;
                                    }
                                  }

                                  controller.editInput(
                                    _editingInputName!,
                                    StateMachineInput(
                                      name: name,
                                      type: _selectedType,
                                      value: defaultValue,
                                      bindFilePath: _pathController.text.trim().isEmpty ? null : _pathController.text.trim(),
                                    ),
                                  );

                                  setState(() {
                                    _editingInputName = null;
                                    _nameController.clear();
                                    _pathController.clear();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white12),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _editingInputName = null;
                                    _nameController.clear();
                                    _pathController.clear();
                                  });
                                },
                                child: const Text('Cancel', style: TextStyle(fontSize: 10, color: Colors.white70)),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            minimumSize: const Size(double.infinity, 32),
                          ),
                          icon: const Icon(Icons.add, size: 13),
                          label: const Text('Add Input', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final name = _nameController.text.trim();
                            if (name.isEmpty) return;
                            
                            dynamic defaultValue;
                            if (_selectedType == StateMachineInputType.boolean) {
                              defaultValue = false;
                            } else if (_selectedType == StateMachineInputType.number) {
                              defaultValue = 0.0;
                            } else {
                              defaultValue = null;
                            }
                            
                            controller.addInput(StateMachineInput(
                              name: name,
                              type: _selectedType,
                              value: defaultValue,
                              bindFilePath: _pathController.text.trim().isEmpty ? null : _pathController.text.trim(),
                            ));
                            _nameController.clear();
                            _pathController.clear();
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAiUpdateDialog(BuildContext context, StateMachineController controller) {
    final promptCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 8),
              const Text('Ask AI to Update Flow', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: promptCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'e.g. Add a node called "paused" with transition from "running" when "pauseTrigger" is fired.',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final promptText = promptCtrl.text.trim();
                if (promptText.isEmpty) return;

                final nodesSummary = controller.allNodes.map((n) => '- Node: ${n.id} (${n.label}), actions: ${n.actions.map((a) => "Set ${a.inputName}=${a.value}").join(", ")}').join('\n');
                final transitionsSummary = controller.allTransitions.map((t) => '- Transition from ${t.from} to ${t.to}, conditions: ${t.conditions.map((c) => "${c.inputName} ${c.op.name} ${c.value}").join(", ")}').join('\n');
                final inputsSummary = controller.allInputs.map((i) => '- Input: ${i.name} (${i.type.name}), file: ${i.bindFilePath ?? "none"}').join('\n');

                final description = '''
Please update the State Machine design as requested by the user:
"$promptText"

Current State Machine Design:
---
NODES:
$nodesSummary

TRANSITIONS:
$transitionsSummary

INPUTS:
$inputsSummary
---

Please update the configuration files, SharedPreferences state, or code files accordingly.
''';

                AiBridgeService.instance.addTask(
                  'Update State Machine: ${promptText.length > 30 ? promptText.substring(0, 30) + "..." : promptText}',
                  description,
                  status: AiTaskStatus.open,
                );

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI task created successfully. The AI Agent will begin updating the design shortly.')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}

class _TransitionConditionsList extends StatefulWidget {
  final String from;
  final String to;
  final List<TransitionCondition> conditions;
  final StateMachineController controller;

  const _TransitionConditionsList({
    required this.from,
    required this.to,
    required this.conditions,
    required this.controller,
  });

  @override
  State<_TransitionConditionsList> createState() => _TransitionConditionsListState();
}

class _TransitionConditionsListState extends State<_TransitionConditionsList> {
  bool _showAddForm = false;
  String? _selectedInputName;
  ConditionOp _selectedOp = ConditionOp.equals;
  final _valueController = TextEditingController();
  bool _boolValue = true;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputs = widget.controller.allInputs;
    
    if ((_selectedInputName == null || !inputs.any((i) => i.name == _selectedInputName)) && inputs.isNotEmpty) {
      _selectedInputName = inputs.first.name;
    }

    final selectedInput = inputs.firstWhere(
      (i) => i.name == _selectedInputName,
      orElse: () => const StateMachineInput(name: '', type: StateMachineInputType.trigger, value: null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.conditions.isNotEmpty) ...[
          const Text(
            'Conditions (ALL must match):',
            style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...widget.conditions.asMap().entries.map((entry) {
            final idx = entry.key;
            final cond = entry.value;
            String opStr = cond.op == ConditionOp.equals ? '==' : (cond.op == ConditionOp.notEquals ? '!=' : cond.op.name);
            if (cond.op == ConditionOp.greaterThan) opStr = '>';
            if (cond.op == ConditionOp.lessThan) opStr = '<';
            if (cond.op == ConditionOp.greaterThanOrEquals) opStr = '>=';
            if (cond.op == ConditionOp.lessThanOrEquals) opStr = '<=';
            
            final valStr = cond.value != null ? ' ${cond.value}' : '';
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${cond.inputName} $opStr$valStr',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 10, color: Colors.white30),
                    onPressed: () {
                      widget.controller.removeTransitionCondition(widget.from, widget.to, idx);
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
        ],

        if (!_showAddForm)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add, size: 10, color: Colors.purpleAccent),
              label: const Text('Add Condition', style: TextStyle(color: Colors.purpleAccent, fontSize: 9)),
              onPressed: () {
                if (inputs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please define State Machine Inputs first.')),
                  );
                  return;
                }
                setState(() => _showAddForm = true);
              },
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedInputName,
                  dropdownColor: const Color(0xFF1E1E24),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  decoration: const InputDecoration(
                    labelText: 'Input Name',
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 9),
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    isDense: true,
                  ),
                  items: inputs.map((i) {
                    return DropdownMenuItem(
                      value: i.name,
                      child: Text(i.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedInputName = val;
                      _selectedOp = ConditionOp.equals;
                    });
                  },
                ),
                const SizedBox(height: 4),

                if (selectedInput.type == StateMachineInputType.trigger)
                  const Text('Operation: On Trigger', style: TextStyle(color: Colors.white54, fontSize: 9))
                else
                  DropdownButtonFormField<ConditionOp>(
                    value: _selectedOp,
                    dropdownColor: const Color(0xFF1E1E24),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    decoration: const InputDecoration(
                      labelText: 'Operator',
                      labelStyle: TextStyle(color: Colors.white38, fontSize: 9),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      isDense: true,
                    ),
                    items: (selectedInput.type == StateMachineInputType.boolean
                            ? [ConditionOp.equals, ConditionOp.notEquals]
                            : ConditionOp.values)
                        .map((op) {
                      String label = op.name;
                      if (op == ConditionOp.equals) label = '== (Equals)';
                      if (op == ConditionOp.notEquals) label = '!= (Not Equals)';
                      if (op == ConditionOp.greaterThan) label = '> (Greater)';
                      if (op == ConditionOp.lessThan) label = '< (Less)';
                      if (op == ConditionOp.greaterThanOrEquals) label = '>=';
                      if (op == ConditionOp.lessThanOrEquals) label = '<=';
                      return DropdownMenuItem(value: op, child: Text(label));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedOp = val);
                    },
                  ),
                const SizedBox(height: 4),

                if (selectedInput.type == StateMachineInputType.boolean)
                  Row(
                    children: [
                      const Text('Value:', style: TextStyle(color: Colors.white38, fontSize: 9)),
                      const SizedBox(width: 8),
                      DropdownButton<bool>(
                        value: _boolValue,
                        dropdownColor: const Color(0xFF1E1E24),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('true')),
                          DropdownMenuItem(value: false, child: Text('false')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _boolValue = val);
                        },
                      ),
                    ],
                  )
                else if (selectedInput.type == StateMachineInputType.number)
                  TextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    decoration: const InputDecoration(
                      labelText: 'Compare to Value',
                      labelStyle: TextStyle(color: Colors.white38, fontSize: 9),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      isDense: true,
                    ),
                  ),
                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() => _showAddForm = false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 9)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: () {
                        if (_selectedInputName == null) return;
                        
                        dynamic compValue;
                        if (selectedInput.type == StateMachineInputType.boolean) {
                          compValue = _boolValue;
                        } else if (selectedInput.type == StateMachineInputType.number) {
                          compValue = double.tryParse(_valueController.text) ?? 0.0;
                        } else {
                          compValue = null;
                        }

                        widget.controller.addTransitionCondition(
                          widget.from,
                          widget.to,
                          TransitionCondition(
                            inputName: _selectedInputName!,
                            op: selectedInput.type == StateMachineInputType.trigger ? ConditionOp.equals : _selectedOp,
                            value: compValue,
                          ),
                        );

                        setState(() => _showAddForm = false);
                        _valueController.clear();
                      },
                      child: const Text('Add', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SidebarNodeActionsEditor extends StatefulWidget {
  final String selectedNodeId;
  final StateMachineController controller;

  const _SidebarNodeActionsEditor({
    required this.selectedNodeId,
    required this.controller,
  });

  @override
  State<_SidebarNodeActionsEditor> createState() => _SidebarNodeActionsEditorState();
}

class _SidebarNodeActionsEditorState extends State<_SidebarNodeActionsEditor> {
  bool _showAddForm = false;
  String? _selectedInputName;
  final _valueController = TextEditingController();
  bool _boolValue = true;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final node = controller.getNode(widget.selectedNodeId);
    if (node == null) return const SizedBox.shrink();

    final inputs = controller.allInputs;
    if ((_selectedInputName == null || !inputs.any((i) => i.name == _selectedInputName)) && inputs.isNotEmpty) {
      _selectedInputName = inputs.first.name;
    }

    final selectedInput = inputs.firstWhere(
      (i) => i.name == _selectedInputName,
      orElse: () => const StateMachineInput(name: '', type: StateMachineInputType.trigger, value: null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.play_for_work, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              'ENTERING ACTIONS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (node.actions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No entering actions defined.',
              style: TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          )
        else
          ...node.actions.asMap().entries.map((entry) {
            final idx = entry.key;
            final action = entry.value;
            final valStr = action.value != null ? ' = ${action.value}' : '';
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set ${action.inputName}$valStr',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                    onPressed: () {
                      controller.removeNodeAction(node.id, idx);
                    },
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 8),
        
        if (!_showAddForm)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.add, size: 12),
            label: const Text('Add Entering Action', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            onPressed: () {
              if (inputs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please define State Machine Inputs first.')),
                );
                return;
              }
              setState(() => _showAddForm = true);
            },
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedInputName,
                  dropdownColor: const Color(0xFF1E1E24),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: const InputDecoration(
                    labelText: 'Target Input',
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 9),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  items: inputs.map((i) {
                    return DropdownMenuItem(value: i.name, child: Text(i.name));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedInputName = val);
                  },
                ),
                const SizedBox(height: 8),

                if (selectedInput.type == StateMachineInputType.boolean)
                  Row(
                    children: [
                      const Text('Set Value:', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      const SizedBox(width: 8),
                      DropdownButton<bool>(
                        value: _boolValue,
                        dropdownColor: const Color(0xFF1E1E24),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('true')),
                          DropdownMenuItem(value: false, child: Text('false')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _boolValue = val);
                        },
                      ),
                    ],
                  )
                else if (selectedInput.type == StateMachineInputType.number)
                  TextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: const InputDecoration(
                      labelText: 'Set Value',
                      labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )
                else
                  const Text('Trigger will be fired.', style: TextStyle(color: Colors.amberAccent, fontSize: 10)),

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showAddForm = false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_selectedInputName == null) return;
                        
                        dynamic compValue;
                        if (selectedInput.type == StateMachineInputType.boolean) {
                          compValue = _boolValue;
                        } else if (selectedInput.type == StateMachineInputType.number) {
                          compValue = double.tryParse(_valueController.text) ?? 0.0;
                        } else {
                          compValue = null;
                        }

                        controller.addNodeAction(
                          node.id,
                          NodeStateAction(
                            inputName: _selectedInputName!,
                            value: compValue,
                          ),
                        );
                        setState(() => _showAddForm = false);
                        _valueController.clear();
                      },
                      child: const Text('Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
