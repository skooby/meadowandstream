import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../services/ai_bridge_service.dart';
import '../../../models/flow_node_model.dart';
import '../../../models/agent_models.dart';
import '../../../services/pipeline_execution_engine.dart';
import '../../../services/control_type_registry.dart';
import '../../../models/control_type_model.dart';
import '../visual_editor_screen.dart';
import 'project_modules_panel.dart';
import 'control_types_editor_panel.dart';
import '../../../constants.dart';
import '../../../state/global_picker_state.dart';
import 'global_color_picker_window.dart';
import 'global_icon_picker_window.dart';

final ValueNotifier<bool> showFlowEditorNotifier = ValueNotifier(false);
final ValueNotifier<bool> showControlEditorNotifier = ValueNotifier(false);

void showFlowEditorWindow(BuildContext context) {
  if (showFlowEditorNotifier.value) return;

  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showFlowEditor'), true));

  showFlowEditorNotifier.value = true;
}

void hideFlowEditorWindow() {
  showFlowEditorNotifier.value = false;
  showControlEditorNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showFlowEditor'), false));
}

void hideControlEditorWindow() {
  showControlEditorNotifier.value = false;
}

class FlowEditorContext {
  static final ValueNotifier<Map<String, dynamic>?> activeContext = ValueNotifier(null);
}

/// Measures the rendered description height using the theme's actual font metrics
double _measureDescHeight(BuildContext context, FlowNode node) {
  if (node.description.isEmpty) return 0;
  final baseStyle = DefaultTextStyle.of(context).style;
  final descStyle = baseStyle.merge(TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, height: 1.3));
  final tp = TextPainter(
    text: TextSpan(text: node.description, style: descStyle),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  );
  tp.layout(maxWidth: node.width - 20); // 10px horizontal padding each side
  return 8 + tp.height; // 8px top padding from Padding widget
}

/// Calculates the absolute minimum height required to prevent RenderFlex overflow
double _calculateMinNodeHeight(BuildContext context, FlowNode node) {
  double h = 32.0; // Header
  h += _measureDescHeight(context, node); // Description + padding
  h += 8.0; // Spacer
  for (var item in node.items) {
    if (item.type == 'gap') {
      h += (item.height ?? 22.0) + 4.0;
    } else {
      h += 26.0; // 22 height + 4 bottom margin
    }
  }
  h += 8.0; // Bottom padding
  return h;
}
class FlowEditorWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const FlowEditorWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<FlowEditorWindow> createState() => _FlowEditorWindowState();
}
class _FlowEditorWindowState extends State<FlowEditorWindow> {
  bool _isLoaded = false;
  
  String _activePipelineFilename = 'default.json';
  List<String> _availablePipelines = [];

  double _width = 1000;
  double _height = 800;
  double _bgOpacity = 0.5;
  Offset _offset = const Offset(150, 150);

  // Canvas State
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  bool _snapToGrid = false;
  double _gridSize = 40.0;

  String? _editingGroupId;
  String? _editingNodeId;
  final TextEditingController _editLabelCtrl = TextEditingController();
  final TextEditingController _editDescCtrl = TextEditingController();
  Color? _editSelectedColor;

  // Node Graph State
  List<FlowNode> _nodes = [];
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  static const int _maxUndoStack = 50;
  bool _isRestoringState = false;

  void _undo() {
    if (_undoStack.length <= 1) return;
    
    final currentStateStr = _undoStack.removeLast();
    _redoStack.add(currentStateStr);
    
    final previousStateStr = _undoStack.last;
    _restoreState(previousStateStr);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    
    final nextStateStr = _redoStack.removeLast();
    _undoStack.add(nextStateStr);
    
    _restoreState(nextStateStr);
  }

  void _restoreState(String stateStr) {
    try {
      final data = jsonDecode(stateStr);
      final nodesData = data['nodes'] as List<dynamic>;
      final groupsData = data['groups'] as List<dynamic>;
      
      setState(() {
        _nodes = nodesData.map((e) => FlowNode.fromJson(e as Map<String, dynamic>)).toList();
        _groups = groupsData.map((e) => FlowGroup.fromJson(e as Map<String, dynamic>)).toList();
        _selectedNodeIds.clear();
      });
      
      _isRestoringState = true;
      _savePreferences().then((_) {
        _isRestoringState = false;
      });
    } catch (_) {}
  }

  List<FlowGroup> _groups = [];
  Set<String> _selectedNodeIds = {};
  String? _connectingFromNodeId;
  bool _isConnectingMode = false;
  bool _isMiddleButtonPanning = false;
  bool _isDrawingMarquee = false;
  bool _isDraggingNodes = false;
  bool _isResizingNode = false;
  String? _resizingNodeId;
  Set<String> _resizeEdges = {}; // \'left\', \'right\', \'top\', \'bottom\'
  bool _isReorderingItem = false;
  String? _reorderNodeId;
  int _reorderItemIndex = -1;
  double _reorderAccumulatedDY = 0;
  Offset? _pointerDownPos;
  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  Offset? _mousePos;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
    PipelineExecutionEngine.instance.onStateUpdated = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    _focusNode.dispose();
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _commitConnection(String id) {
    if (_connectingFromNodeId != id) {
      if (_connectingFromNodeId!.contains('|')) {
        final parts = _connectingFromNodeId!.split('|');
        final fromNode = _nodes.firstWhere((n) => n.id == parts[0]);
        final item = fromNode.items.firstWhere((i) => i.id == parts[1]);
        if (item.connectedTo.contains(id)) {
          item.connectedTo.remove(id);
        } else {
          item.connectedTo.add(id);
        }
      } else {
        final fromNode = _nodes.firstWhere((n) => n.id == _connectingFromNodeId);
        if (fromNode.connectedTo.contains(id)) {
          fromNode.connectedTo.remove(id);
        } else {
          fromNode.connectedTo.add(id);
        }
      }
    }
    _isConnectingMode = false;
    _connectingFromNodeId = null;
    _savePreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    _activePipelineFilename = prefs.getString(VisualEditorScreen.getPrefKey('flow_editor_active_pipeline')) ?? 'default.json';
    _loadPipelineList();
    await _loadPipelineData();

    if (mounted) {
      setState(() {
        _isLoaded = true;

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_width')) ?? 1000;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_height')) ?? 800;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.5;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_dx')) ?? 150;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_dy')) ?? 150;
        _offset = Offset(dx, dy);

        double panX = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_pan_x')) ?? 0.0;
        double panY = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_pan_y')) ?? 0.0;
        _pan = Offset(panX, panY);

        _snapToGrid = prefs.getBool(VisualEditorScreen.getPrefKey('flow_editor_snap')) ?? false;
        _gridSize = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_grid_size')) ?? 40.0;
        _zoom = prefs.getDouble(VisualEditorScreen.getPrefKey('flow_editor_zoom')) ?? 1.0;
        
        if (_undoStack.isEmpty) {
          _undoStack.add(jsonEncode({
            'nodes': _nodes.map((n) => n.toJson()).toList(),
            'groups': _groups.map((g) => g.toJson()).toList(),
          }));
        }
      });
    }
  }

  Future<void> _savePreferences() async {
    if (!_isRestoringState) {
      final stateStr = jsonEncode({
        'nodes': _nodes.map((n) => n.toJson()).toList(),
        'groups': _groups.map((g) => g.toJson()).toList(),
      });
      if (_undoStack.isEmpty || _undoStack.last != stateStr) {
        _undoStack.add(stateStr);
        if (_undoStack.length > _maxUndoStack) {
          _undoStack.removeAt(0);
        }
        _redoStack.clear();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_dy'), _offset.dy);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_pan_x'), _pan.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_pan_y'), _pan.dy);
    await prefs.setString(VisualEditorScreen.getPrefKey('flow_editor_active_pipeline'), _activePipelineFilename);
    await _savePipelineData();
    await prefs.setBool(VisualEditorScreen.getPrefKey('flow_editor_snap'), _snapToGrid);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_grid_size'), _gridSize);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('flow_editor_zoom'), _zoom);
  }

  void _loadPipelineList() {
    final dir = Directory('.ai_bridge/pipelines');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _availablePipelines = dir.listSync()
        .whereType<File>()
        .where((e) => e.path.endsWith('.json'))
        .map((e) => e.path.split(Platform.pathSeparator).last)
        .toList();
        
    if (_availablePipelines.isEmpty) {
      _availablePipelines.add('default.json');
    }
  }

  Future<void> _loadPipelineData() async {
    final file = File('.ai_bridge/pipelines/$_activePipelineFilename');
    if (await file.exists()) {
      final jsonStr = await file.readAsString();
      try {
        final data = jsonDecode(jsonStr);
        final nodesData = data['nodes'] as List<dynamic>? ?? [];
        final groupsData = data['groups'] as List<dynamic>? ?? [];
        _nodes = nodesData.map((e) => FlowNode.fromJson(e as Map<String, dynamic>)).toList();
        _groups = groupsData.map((e) => FlowGroup.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        _nodes = [];
        _groups = [];
      }
    } else {
      _nodes = [];
      _groups = [];
      // Auto-create default file if missing
      await _savePipelineData();
    }
  }

  Future<void> _savePipelineData() async {
    final dir = Directory('.ai_bridge/pipelines');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('.ai_bridge/pipelines/$_activePipelineFilename');
    final data = {
      'nodes': _nodes.map((n) => n.toJson()).toList(),
      'groups': _groups.map((g) => g.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  void _updateSelectionFromMarquee() {
    if (_marqueeStart == null || _marqueeEnd == null) return;
    
    final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
    _selectedNodeIds.clear();
    
    for (var node in _nodes) {
      final nodeLeft = node.position.dx * _zoom + _pan.dx;
      final nodeTop = node.position.dy * _zoom + _pan.dy;
      final nodeRight = nodeLeft + node.width * _zoom;
      final nodeBottom = nodeTop + (node.height ?? 100) * _zoom;
      
      final nodeRect = Rect.fromLTRB(nodeLeft, nodeTop, nodeRight, nodeBottom);
      
      if (rect.overlaps(nodeRect)) {
        _selectedNodeIds.add(node.id);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return _buildFlowContent();
        Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: pan, onPanEnd: (_) => _savePreferences(), child: Container(color: Colors.transparent)))
    );

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: ValueListenableBuilder<double>(
          valueListenable: VisualEditorScreen.globalUiScale,
        builder: (context, scale, child) {
          return Transform.scale(scale: 1.0, alignment: Alignment.topLeft,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      final bool isCtrlOrCmd = HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) || 
                                               HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlRight) ||
                                               HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.metaLeft) ||
                                               HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.metaRight);
                      final bool isShift = HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.shiftLeft) ||
                                           HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.shiftRight);
                      
                      if (isCtrlOrCmd) {
                        if (event.logicalKey == LogicalKeyboardKey.keyZ) {
                          if (isShift) {
                            _redo();
                          } else {
                            _undo();
                          }
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
                          _redo();
                          return KeyEventResult.handled;
                        }
                      }
                    }

                    if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace)) {
                      if (_selectedNodeIds.isNotEmpty) {
                        setState(() {
                          _nodes.removeWhere((n) => _selectedNodeIds.contains(n.id));
                          for (var n in _nodes) {
                            n.connectedTo.removeWhere((id) => _selectedNodeIds.contains(id));
                            for (var i in n.items) {
                              i.connectedTo.removeWhere((id) => _selectedNodeIds.contains(id));
                            }
                          }
                          _selectedNodeIds.clear();
                          _savePreferences();
                        });
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Listener(
                    onPointerDown: (_) {
                      _focusNode.requestFocus();
                      widget.onFocus?.call();
                    },
                    behavior: HitTestBehavior.deferToChild,
                    child: Material(
                    color: Colors.transparent,
                    elevation: 8,
                    child: Container(
                      width: _width,
                      height: _height,
                      clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'flow_editor' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                        color: AppColors.windowBackground.withValues(alpha: _bgOpacity),
                        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                        
                      ),
                      child: Column(
                        children: [
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
                                  Icon(AppToolWindows.getDef('flow_editor').icon, size: 16, color: AppToolWindows.getDef('flow_editor').color),
                                  const SizedBox(width: 8),
                                  Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('flow_editor').name), style: TextStyle(
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
                          Expanded(child: _buildFlowContent()),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
                rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height - d.delta.dy;
                    if (nH >= 400 && nH <= 1600) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height + d.delta.dy;
                    if (nH >= 400 && nH <= 1600) { _height = nH; }
                })),
                rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx;
                    if (nW >= 600 && nW <= 2000) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                })),
                rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx;
                    if (nW >= 600 && nW <= 2000) { _width = nW; }
                })),
                rz(t: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 600 && nW <= 2000) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 400 && nH <= 1600) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(t: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 600 && nW <= 2000) { _width = nW; }
                    if (nH >= 400 && nH <= 1600) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 600 && nW <= 2000) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 400 && nH <= 1600) { _height = nH; }
                })),
                rz(b: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 600 && nW <= 2000) { _width = nW; }
                    if (nH >= 400 && nH <= 1600) { _height = nH; }
                })),
              ], // end Stack children
            ), // end Stack
          );
        },
      ),
    );
  }

  Widget _buildFlowContent() {
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              _buildToolbar(),
              Expanded(
                child: ClipRect(
                    child: Listener(
              onPointerDown: (e) {
                if (e.buttons == kMiddleMouseButton) {
                  setState(() => _isMiddleButtonPanning = true);
                }
              },
              onPointerMove: (e) {
                if (_isMiddleButtonPanning) {
                  setState(() => _pan += e.delta);
                }
              },
              onPointerUp: (e) {
                if (_isMiddleButtonPanning) {
                  setState(() => _isMiddleButtonPanning = false);
                  _savePreferences();
                }
              },
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  setState(() {
                    double zoomDelta = pointerSignal.scrollDelta.dy > 0 ? -0.05 : 0.05;
                    double newZoom = (_zoom + zoomDelta).clamp(0.2, 3.0);
                    if (newZoom != _zoom) {
                      final focalPoint = pointerSignal.localPosition;
                      final unscaledPos = (focalPoint - _pan) / _zoom;
                      _pan = focalPoint - (unscaledPos * newZoom);
                      _zoom = newZoom;
                      _savePreferences();
                    }
                  });
                }
              },
              child: Listener(
                onPointerDown: (e) {
                  if (e.buttons == kMiddleMouseButton) return; // handled above
                  final pos = e.localPosition;

                  FlowNode? hitNode;
                  for (var node in _nodes.reversed) {
                    final nL = node.position.dx * _zoom + _pan.dx;
                    final nT = node.position.dy * _zoom + _pan.dy;
                    final nR = nL + node.width * _zoom;
                    double h = node.height ?? _calculateMinNodeHeight(context, node);
                    final nB = nT + h * _zoom;
                    if (Rect.fromLTRB(nL, nT, nR, nB).contains(pos)) { hitNode = node; break; }
                  }

                  if (hitNode != null) {
                    // 1. Instantly select if needed (enables 1-motion click & drag)
                    final ctrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                                 HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft);
                    
                    if (ctrl) {
                      setState(() {
                        if (_selectedNodeIds.contains(hitNode!.id)) {
                          _selectedNodeIds.remove(hitNode.id);
                        } else {
                          _selectedNodeIds.add(hitNode.id);
                        }
                      });
                    } else {
                      if (!_selectedNodeIds.contains(hitNode.id)) {
                        setState(() {
                          if (hitNode!.groupId != null) {
                            _selectedNodeIds = _nodes.where((n) => n.groupId == hitNode!.groupId).map((n) => n.id).toSet();
                          } else {
                            _selectedNodeIds = {hitNode.id};
                          }
                        });
                      }
                    }

                    // Only proceed with drag/resize if the node is actively selected
                    if (_selectedNodeIds.contains(hitNode.id)) {
                      // Check if pointer is near any edge/corner for resize (8px threshold)
                      {
                        final nL = hitNode.position.dx * _zoom + _pan.dx;
                        final nT = hitNode.position.dy * _zoom + _pan.dy;
                        final nR = nL + hitNode.width * _zoom;
                        double h = hitNode.height ?? _calculateMinNodeHeight(context, hitNode);
                        final nB = nT + h * _zoom;
                        const edgeThreshold = 8.0;
                        final nearLeft = pos.dx <= nL + edgeThreshold;
                        final nearRight = pos.dx >= nR - edgeThreshold;
                        final nearTop = pos.dy <= nT + edgeThreshold;
                        final nearBottom = pos.dy >= nB - edgeThreshold;
                        if (nearLeft || nearRight || nearTop || nearBottom) {
                          _isResizingNode = true;
                          _resizingNodeId = hitNode.id;
                          _resizeEdges = {};
                          if (nearLeft) _resizeEdges.add('left');
                          if (nearRight) _resizeEdges.add('right');
                          if (nearTop) _resizeEdges.add('top');
                          if (nearBottom) _resizeEdges.add('bottom');
                          _pointerDownPos = pos;
                          return;
                        }
                      }
                      
                      // Check for item interactions (reorder on left, buttons on right → no drag)
                      for (var node in _nodes.where((n) => _selectedNodeIds.contains(n.id))) {
                        if (node.items.isEmpty) continue;
                        final nL = node.position.dx * _zoom + _pan.dx;
                        final nR = nL + node.width * _zoom;
                        final nT = node.position.dy * _zoom + _pan.dy;
                        final descSectionHeight = _measureDescHeight(context, node);
                        final itemsStartY = nT + (32 + descSectionHeight + 8) * _zoom;
                        double cumulativeY = 0.0;
                        for (int i = 0; i < node.items.length; i++) {
                          final item = node.items[i];
                          if (item.type == 'gap') {
                            final currentItemH = (item.height ?? 22.0) + 4.0;
                            final gapBottom = itemsStartY + (cumulativeY + currentItemH - 4.0) * _zoom;
                            // Check if pointer is on the gap drag handle (bottom 8px of the gap content area)
                            if (pos.dy >= gapBottom - 4 * _zoom && pos.dy <= gapBottom + 4 * _zoom) {
                               return; // Initiated gap resize via inner gesture, prevent node dragging natively
                            }
                            cumulativeY += currentItemH;
                          } else {
                            cumulativeY += 26.0;
                          }
                        }
                        
                        final itemsEndY = itemsStartY + cumulativeY * _zoom;
                        if (pos.dy >= itemsStartY && pos.dy <= itemsEndY) {
                          // Left 30px = drag handle for reorder
                          if (pos.dx >= nL && pos.dx <= nL + 30 * _zoom) {
                            double cy = 0.0;
                            int itemIndex = 0;
                            for (int i = 0; i < node.items.length; i++) {
                               final h = node.items[i].type == 'gap' ? ((node.items[i].height ?? 22.0) + 4.0) : 26.0;
                               if (pos.dy <= itemsStartY + (cy + h) * _zoom) {
                                  itemIndex = i;
                                  break;
                               }
                               cy += h;
                            }
                            _isReorderingItem = true;
                            _reorderNodeId = node.id;
                            _reorderItemIndex = itemIndex;
                            _reorderAccumulatedDY = 0;
                            return; // Initiated reorder, prevent dragging
                          }
                          // Right button zone (~50px from right edge) → no drag, let onPointerUp handle
                          if (pos.dx >= nR - 50 * _zoom) {
                            return; // Don't set _pointerDownPos
                          }
                        }
                      }

                      // Check header button zone (edit/delete icons on right side of header)
                      {
                        final nL = hitNode.position.dx * _zoom + _pan.dx;
                        final nT = hitNode.position.dy * _zoom + _pan.dy;
                        final nR = nL + hitNode.width * _zoom;
                        final headerBottom = nT + 32 * _zoom;
                        if (pos.dy <= headerBottom && pos.dx >= nR - 60 * _zoom) {
                          return; // Don't set _pointerDownPos, let onPointerUp handle edit/delete
                        }
                      }
                      
                      // Hit anywhere else on the selected node -> Start dragging!
                      _pointerDownPos = pos;
                    }
                    return;
                  }

                  bool hitAny = false;
                  for (var node in _nodes) {
                    final nL = node.position.dx * _zoom + _pan.dx;
                    final nT = node.position.dy * _zoom + _pan.dy;
                    final nR = nL + node.width * _zoom;
                    double h = node.height ?? _calculateMinNodeHeight(context, node);
                    final nB = nT + h * _zoom;
                    if (Rect.fromLTRB(nL, nT, nR, nB).contains(pos)) { hitAny = true; break; }
                  }
                  if (!hitAny) {
                    for (var g in _groups) {
                      final gNodes = _nodes.where((n) => n.groupId == g.id).toList();
                      if (gNodes.isEmpty) continue;
                      double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
                      for (var n in gNodes) {
                        minX = n.position.dx < minX ? n.position.dx : minX;
                        minY = n.position.dy < minY ? n.position.dy : minY;
                        maxX = n.position.dx + n.width > maxX ? n.position.dx + n.width : maxX;
                        double hh = n.height ?? _calculateMinNodeHeight(context, n);
                        maxY = n.position.dy + hh > maxY ? n.position.dy + hh : maxY;
                      }
                      if (Rect.fromLTRB((minX-24)*_zoom+_pan.dx, (minY-48)*_zoom+_pan.dy, (maxX+24)*_zoom+_pan.dx, (maxY+24)*_zoom+_pan.dy).contains(pos)) {
                        hitAny = true;
                        // Select all group nodes and enable drag
                        setState(() {
                          final ctrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                              HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft);
                          if (ctrl) {
                            _selectedNodeIds.addAll(gNodes.map((n) => n.id));
                          } else {
                            _selectedNodeIds = gNodes.map((n) => n.id).toSet();
                          }
                        });
                        _pointerDownPos = pos; // Enable drag
                        break;
                      }
                    }
                  }

                  if (!hitAny) {
                    setState(() {
                      _isDrawingMarquee = true;
                      _marqueeStart = pos;
                      _marqueeEnd = pos;
                    });
                  }
                },
                onPointerMove: (e) {
                  if (_isMiddleButtonPanning) return;
                  setState(() {
                    if (_isDrawingMarquee && _marqueeStart != null) {
                      _marqueeEnd = e.localPosition;
                      _updateSelectionFromMarquee();
                    } else if (_isReorderingItem && _reorderNodeId != null) {
                      _reorderAccumulatedDY += e.delta.dy / _zoom;
                      if (_reorderAccumulatedDY.abs() >= 26) {
                        try {
                          final n = _nodes.firstWhere((x) => x.id == _reorderNodeId);
                          final dir = _reorderAccumulatedDY > 0 ? 1 : -1;
                          final newIndex = (_reorderItemIndex + dir).clamp(0, n.items.length - 1);
                          if (newIndex != _reorderItemIndex) {
                            final item = n.items.removeAt(_reorderItemIndex);
                            n.items.insert(newIndex, item);
                            _reorderItemIndex = newIndex;
                          }
                          _reorderAccumulatedDY = 0;
                        } catch (_) {}
                      }
                    } else if (_isResizingNode && _resizingNodeId != null) {
                      try {
                        final n = _nodes.firstWhere((x) => x.id == _resizingNodeId);
                        final dx = e.delta.dx / _zoom;
                        final dy = e.delta.dy / _zoom;
                        final minHeight = _calculateMinNodeHeight(context, n);
                        n.height ??= minHeight;
                        if (_resizeEdges.contains('right')) {
                          n.width = (n.width + dx).clamp(160.0, 600.0);
                        }
                        if (_resizeEdges.contains('left')) {
                          final newWidth = (n.width - dx).clamp(160.0, 600.0);
                          final actualDx = n.width - newWidth;
                          n.position = Offset(n.position.dx + actualDx, n.position.dy);
                          n.width = newWidth;
                        }
                        if (_resizeEdges.contains('bottom')) {
                          n.height = (n.height! + dy).clamp(80.0, 800.0);
                        }
                        if (_resizeEdges.contains('top')) {
                          final newHeight = (n.height! - dy).clamp(80.0, 800.0);
                          final actualDy = n.height! - newHeight;
                          n.position = Offset(n.position.dx, n.position.dy + actualDy);
                          n.height = newHeight;
                        }
                      } catch (_) {}
                    } else if (_pointerDownPos != null && _selectedNodeIds.isNotEmpty) {
                      // Only start dragging after 4px threshold
                      if (!_isDraggingNodes) {
                        final dist = (e.localPosition - _pointerDownPos!).distance;
                        if (dist < 4) return;
                        _isDraggingNodes = true;
                      }
                      for (var nid in _selectedNodeIds) {
                        try {
                          final n = _nodes.firstWhere((x) => x.id == nid);
                          n.position += e.delta / _zoom;
                        } catch (_) {}
                      }
                    }
                  });
                },
                onPointerUp: (e) {
                  if (_isMiddleButtonPanning) return;
                  final pos = e.localPosition;

                  final wasDragging = _isDraggingNodes;
                  final wasResizing = _isResizingNode;
                  final wasReordering = _isReorderingItem;
                  final wasMarquee = _isDrawingMarquee;
                  setState(() {
                    _isDrawingMarquee = false;
                    _isDraggingNodes = false;
                    _isResizingNode = false;
                    _resizingNodeId = null;
                    _resizeEdges.clear();
                    _isReorderingItem = false;
                    _reorderNodeId = null;
                    _reorderItemIndex = -1;
                    _pointerDownPos = null;
                    _marqueeStart = null;
                    _marqueeEnd = null;
                  });

                  // If we were dragging, resizing, reordering, or marquee selecting, just save and skip selection
                  if (wasDragging || wasResizing || wasReordering || wasMarquee) {
                    _savePreferences();
                    return;
                  }

                  // Defer selection to post-frame so gesture processing completes first
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    bool hitNode = false;
                    for (var node in _nodes) {
                      final nL = node.position.dx * _zoom + _pan.dx;
                      final nT = node.position.dy * _zoom + _pan.dy;
                      final nR = nL + node.width * _zoom;
                      double h = node.height ?? _calculateMinNodeHeight(context, node);
                      final nB = nT + h * _zoom;
                      if (Rect.fromLTRB(nL, nT, nR, nB).contains(pos)) {
                        hitNode = true;

                        // Check header button zones (edit/delete) BEFORE selection
                        final headerBottom = nT + 32 * _zoom;
                        if (pos.dy <= headerBottom) {
                          // Delete button: rightmost 24px (+ 10px padding from right edge)
                          if (pos.dx >= nR - 34 * _zoom) {
                            print('[FLOW] DELETE zone hit for ${node.id}');
                            setState(() {
                              _nodes.removeWhere((n) => n.id == node.id);
                              for (var n in _nodes) {
                                n.connectedTo.remove(node.id);
                              }
                              _selectedNodeIds.remove(node.id);
                              _savePreferences();
                            });
                            return;
                          }
                          // Edit button: next 24px to the left (with 2px gap)
                          if (pos.dx >= nR - 60 * _zoom) {
                            print('[FLOW] EDIT zone hit for ${node.id}');
                            _showNodeEditDialog(node.id);
                            return;
                          }
                        }


                        // Check item button zones
                        if (node.items.isNotEmpty) {
                          final descSectionHeight = _measureDescHeight(context, node);
                          final itemsStartY = nT + (32 + descSectionHeight + 8) * _zoom;
                          final rce = nR - 14 * _zoom; // right content edge (8 margin + 6 padding)
                          double cumulativeY = 0.0;
                          for (int i = 0; i < node.items.length; i++) {
                            final item = node.items[i];
                            final currentItemH = item.type == 'gap' ? ((item.height ?? 22.0) + 4.0) : 26.0;
                            final itemTop = itemsStartY + cumulativeY * _zoom;
                            final itemBottom = itemTop + currentItemH * _zoom;
                            cumulativeY += currentItemH;
                            if (pos.dy >= itemTop && pos.dy <= itemBottom) {
                              // Close/remove button: rightmost 16px from content edge
                              if (pos.dx >= rce - 16 * _zoom && pos.dx <= rce) {
                                setState(() {
                                  node.items.removeWhere((x) => x.id == item.id);
                                  _savePreferences();
                                });
                                return;
                              }
                              // Edit item button: next 16px
                              if (pos.dx >= rce - 32 * _zoom && pos.dx <= rce - 16 * _zoom) {
                                _openEditControlWindow(node.id, item.id);
                                return;
                              }
                              // Connect button: next 16px
                              if (pos.dx >= rce - 48 * _zoom && pos.dx <= rce - 32 * _zoom) {
                                setState(() {
                                  _selectedNodeIds = {node.id};
                                  _isConnectingMode = true;
                                  _connectingFromNodeId = '${node.id}|${item.id}';
                                });
                                return;
                              }
                              // Default click anywhere on item update config context
                              _openEditControlWindow(node.id, item.id);
                              return;
                            }
                          }
                        }

                        // Default: finish selection
                        setState(() {
                          if (_isConnectingMode && _connectingFromNodeId != null) {
                            _commitConnection(node.id);
                          } else {
                            final ctrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                                HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft);
                            if (!ctrl) {
                              if (node.groupId != null) {
                                _selectedNodeIds = _nodes.where((n) => n.groupId == node.groupId).map((n) => n.id).toSet();
                              } else {
                                _selectedNodeIds = {node.id};
                              }
                            }
                          }
                        });
                        break;
                      }
                    }
                    if (!hitNode) {
                      for (var g in _groups) {
                        final gNodes = _nodes.where((n) => n.groupId == g.id).toList();
                        if (gNodes.isEmpty) continue;
                        double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
                        for (var n in gNodes) {
                          minX = n.position.dx < minX ? n.position.dx : minX;
                          minY = n.position.dy < minY ? n.position.dy : minY;
                          maxX = n.position.dx + n.width > maxX ? n.position.dx + n.width : maxX;
                          double hh = n.height ?? (32.0 + 8.0 + (n.description.isNotEmpty ? 40.0 : 0.0) + (n.items.length * 30.0) + 16.0);
                          maxY = n.position.dy + hh > maxY ? n.position.dy + hh : maxY;
                        }
                        final gL = (minX-24)*_zoom+_pan.dx;
                        final gT = (minY-48)*_zoom+_pan.dy;
                        final gR = (maxX+24)*_zoom+_pan.dx;
                        final gB = (maxY+24)*_zoom+_pan.dy;
                        if (Rect.fromLTRB(gL, gT, gR, gB).contains(pos)) {
                          hitNode = true;
                          // Check settings cog zone (top-right: right:12, top:8, padding:4, icon:20 = 28x28)
                          if (pos.dx >= gR - 40 * _zoom && pos.dy <= gT + 36 * _zoom) {
                            _showGroupEditDialog(g.id);
                            return;
                          }
                          // Check label area (top-left) for group edit
                          if (pos.dy <= gT + 36 * _zoom && pos.dx <= gL + 200 * _zoom) {
                            _showGroupEditDialog(g.id);
                            return;
                          }
                          // Default: select group
                          setState(() {
                            final ctrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                                HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft);
                            if (ctrl) {
                              _selectedNodeIds.addAll(_nodes.where((n) => n.groupId == g.id).map((n) => n.id));
                            } else {
                              _selectedNodeIds = _nodes.where((n) => n.groupId == g.id).map((n) => n.id).toSet();
                            }
                          });
                          break;
                        }
                      }
                    }
                    if (!hitNode) setState(() => _selectedNodeIds.clear());
                  });
                },
              child: MouseRegion(
                onHover: (e) => setState(() => _mousePos = e.localPosition),
                child: Container(
                  color: const Color(0xFF181818),
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      // Grid background
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridPainter(pan: _pan, zoom: _zoom, baseGridSize: _gridSize),
                        ),

                      ),

                    // Nodes layer mapped perfectly to pan and zoom
                    Positioned.fill(
                      child: Transform.translate(
                        offset: _pan,
                        child: Transform.scale(
                          scale: _zoom,
                          alignment: Alignment.topLeft,
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 0,
                            minHeight: 0,
                            maxWidth: 100000,
                            maxHeight: 100000,
                            child: SizedBox(
                              width: 100000,
                              height: 100000,
                              child: _NodeCanvas(
                                pan: Offset.zero,
                                nodes: _nodes,
                                groups: _groups,
                            selectedIds: _selectedNodeIds,
                            connectingFromId: _connectingFromNodeId,

                        onSelect: (id) {
                          setState(() {
                            if (_isConnectingMode && _connectingFromNodeId != null) {
                               _commitConnection(id);
                            } else {
                               final isShiftOrCtrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) || HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft);
                               if (isShiftOrCtrl) {
                                 if (_selectedNodeIds.contains(id)) {
                                   _selectedNodeIds.remove(id);
                                 } else {
                                   _selectedNodeIds.add(id);
                                 }
                               } else {
                                 final clickedNode = _nodes.firstWhere((n) => n.id == id);
                                 if (clickedNode.groupId != null) {
                                   if (!_selectedNodeIds.contains(id)) {
                                     _selectedNodeIds = _nodes.where((n) => n.groupId == clickedNode.groupId).map((n) => n.id).toSet();
                                   } else {
                                     _selectedNodeIds.removeAll(_nodes.where((n) => n.groupId == clickedNode.groupId).map((n) => n.id));
                                   }
                                 } else {
                                   if (!_selectedNodeIds.contains(id)) {
                                     _selectedNodeIds = {id};
                                   } else {
                                     _selectedNodeIds = {id};
                                   }
                                 }
                               }
                            }
                          });
                        },
                        onSelectGroup: (groupId) {
                          setState(() {
                            final isShiftOrCtrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) || HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft);
                            if (isShiftOrCtrl) {
                              _selectedNodeIds.addAll(_nodes.where((n) => n.groupId == groupId).map((n) => n.id));
                            } else {
                              _selectedNodeIds = _nodes.where((n) => n.groupId == groupId).map((n) => n.id).toSet();
                            }
                          });
                        },
                        onPan: (id, delta) {
                          setState(() {
                            if (!_selectedNodeIds.contains(id)) {
                              final selNode = _nodes.firstWhere((n) => n.id == id);
                              if (selNode.groupId != null) {
                                _selectedNodeIds = _nodes.where((n) => n.groupId == selNode.groupId).map((n) => n.id).toSet();
                              } else {
                                _selectedNodeIds = {id};
                              }
                            }
                            Set<String> nodesToMove = {..._selectedNodeIds};
                            for (var sid in _selectedNodeIds) {
                              final selNode = _nodes.firstWhere((n) => n.id == sid);
                              if (selNode.groupId != null) {
                                nodesToMove.addAll(_nodes.where((n) => n.groupId == selNode.groupId).map((n) => n.id));
                              }
                            }
                            for (var nid in nodesToMove) {
                              final n = _nodes.firstWhere((nx) => nx.id == nid);
                              n.position += delta; 
                            }
                          });
                        },
                        onPanEnd: (id) {
                          setState(() {
                             if (_snapToGrid) {
                                Set<String> nodesToMove = {..._selectedNodeIds};
                                for (var sid in _selectedNodeIds) {
                                  final selNode = _nodes.firstWhere((n) => n.id == sid);
                                  if (selNode.groupId != null) {
                                    nodesToMove.addAll(_nodes.where((n) => n.groupId == selNode.groupId).map((n) => n.id));
                                  }
                                }
                                for (var nid in nodesToMove) {
                                  final n = _nodes.firstWhere((nx) => nx.id == nid);
                                  n.position = Offset(
                                     (n.position.dx / _gridSize).roundToDouble() * _gridSize,
                                     (n.position.dy / _gridSize).roundToDouble() * _gridSize,
                                  );
                                }
                             }
                          });
                          _savePreferences();
                        },
                        onEdit: _showNodeEditDialog,
                        onResize: (id, w, h) {
                          setState(() {
                            final n = _nodes.firstWhere((x) => x.id == id);
                            n.width += w;
                            n.width = n.width.clamp(160.0, 600.0);
                            if (h != null) {
                              if (n.height == null) {
                                double estimatedHeight = (32.0 + 8.0 + (n.description.isNotEmpty ? 40.0 : 0.0) + (n.items.length * 30.0) + 16.0);
                                n.height = estimatedHeight;
                              }
                              n.height = (n.height!) + h;
                              n.height = n.height!.clamp(80.0, 800.0);
                            }
                          });
                        },
                        onDelete: (id) {
                          setState(() {
                            _nodes.removeWhere((n) => n.id == id);
                            for (var node in _nodes) {
                              node.connectedTo.remove(id);
                            }
                            _selectedNodeIds.remove(id);
                            _savePreferences();
                          });
                        },
                        onEditItem: _openEditControlWindow,
                        onResizeItem: (nodeId, itemId, dh) {
                          setState(() {
                            final n = _nodes.firstWhere((x) => x.id == nodeId);
                            final i = n.items.firstWhere((x) => x.id == itemId);
                            i.height = (i.height ?? 22.0) + (dh / _zoom);
                            i.height = i.height!.clamp(4.0, 400.0);
                          });
                        },
                        onResizeItemEnd: () {
                          _savePreferences();
                        },
                        onConnectItem: (nodeId, itemId) {
                          setState(() {
                            _selectedNodeIds = {nodeId};
                            _isConnectingMode = true;
                            _connectingFromNodeId = '$nodeId|$itemId';
                          });
                        },
                        onRemoveItem: (nodeId, itemId) {
                          setState(() {
                            final n = _nodes.firstWhere((n) => n.id == nodeId);
                            n.items.removeWhere((i) => i.id == itemId);
                            _savePreferences();
                          });
                        },
                        onReorderItem: (nodeId, oldIndex, newIndex) {
                          setState(() {
                            final n = _nodes.firstWhere((n) => n.id == nodeId);
                            final item = n.items.removeAt(oldIndex);
                            n.items.insert(newIndex, item);
                            _savePreferences();
                          });
                        },
                        onEditGroup: _showGroupEditDialog,
                        onUngroup: (groupId) {
                          setState(() {
                            for (var n in _nodes) {
                              if (n.groupId == groupId) n.groupId = null;
                            }
                            _groups.removeWhere((g) => g.id == groupId);
                            _savePreferences();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                ),
                ),
                // Edge Drawing layer (On Top)
                if (_nodes.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Transform.translate(
                            offset: _pan,
                            child: Transform.scale(
                               scale: _zoom,
                               alignment: Alignment.topLeft,
                               child: CustomPaint(
                                 painter: _EdgePainter(nodes: _nodes, pan: Offset.zero, zoom: 1.0, connectingFromId: _isConnectingMode ? _connectingFromNodeId : null, mousePos: _mousePos != null ? ((_mousePos! - _pan) / _zoom) : null), // Mouse pos converted to relative unscaled bounds!
                               ),
                            ),
                          )
                        ),
                      ),
                      
                // Marquee Overlay layer (Absolute Top)
                if (_marqueeStart != null && _marqueeEnd != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MarqueePainter(_marqueeStart!, _marqueeEnd!),
                      ),
                    ),
                  ),
                    ], // 1. closes Stack.children at 808
                  ),   // 2. closes Stack at 807
                ),     // 3. closes Container at 803
              ),       // 4. closes MouseRegion at 801
              ),       // 5. closes Listener at 420
              ),       // 6. closes Listener at 388
              ),       // 7. closes ClipRect at 387
              ),       // 8. closes Expanded at 386
            ],
          ),
        ),
        if (_editingGroupId != null) _buildGroupEditor(),
        if (_editingNodeId != null) _buildNodeEditor(),
      ],
    );
  }

  Future<void> _exportReferenceDocument() async {
    final StringBuffer sb = StringBuffer();
    sb.writeln('# Flow Editor Reference Document\n');
    sb.writeln('Generated on: ${DateTime.now().toIso8601String()}\n');
    sb.writeln('## Architecture & Implementation Directives\n');
    sb.writeln('This document is the authoritative structural blueprint for generating the application user interface. The AI Bridge MUST interpret these specifications strictly:\n');
    sb.writeln('1. **Nodes -> Screens/Components:** Translate each Flow Node into a dedicated distinct Flutter View, Component, or dialog layout.');
    sb.writeln('2. **Items -> Interactive Widgets:** Translate every listed Control (buttons, inputs, lists) natively into its matching UI component respecting described contextual constraints.');
    sb.writeln('3. **Connections -> Routing:** Translate defined connections natively as `Navigator` routing operations (or state transitions) structurally linking the generated components.');
    sb.writeln('4. **Design Protocol:** Employ modern, rich, clean, and responsive aesthetics leveraging standard design protocol contexts where applicable.\n');
    sb.writeln('## Groups');
    for (var g in _groups) {
      sb.writeln('### Group: ${g.label}');
      if (g.description != null && g.description!.isNotEmpty) sb.writeln(g.description);
      sb.writeln('');
    }
    sb.writeln('\n## Nodes and Controls');
    for (var node in _nodes) {
      sb.writeln('### Node: ${node.title} (${node.type})');
      if (node.description.isNotEmpty) sb.writeln(node.description);
      if (node.connectedTo.isNotEmpty) sb.writeln('Connections: ${node.connectedTo.join(', ')}');
      for (var item in node.items) {
        sb.writeln('- Control: ${item.label} [${item.type}]');
        if (item.description != null && item.description!.isNotEmpty) sb.writeln('  Description: ${item.description}');
        if (item.connectedTo.isNotEmpty) sb.writeln('  Connections: ${item.connectedTo.join(', ')}');
      }
      sb.writeln('');
    }
    try {
      final dir = Directory('.ai_bridge');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('.ai_bridge/flow_reference.md');
      await file.writeAsString(sb.toString());
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference document exported to .ai_bridge/flow_reference.md')));
      }
    } catch (e) {
      debugPrint('Export error: $e');
    }
  }
  Future<void> _openReferenceDocument() async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['.ai_bridge\\flow_reference.md']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['.ai_bridge/flow_reference.md']);
      } else {
        await Process.run('xdg-open', ['.ai_bridge/flow_reference.md']);
      }
    } catch (e) {
      debugPrint('Error opening reference document: $e');
    }
  }

  Future<void> _processReferenceToTasks() async {
    final ai = AiBridgeService.instance;
    final rootFolder = await ai.addTask('Flow Editor Implementation', 'Generated tasks for Flow Editor nodes', isFolder: true);
    
    for (var node in _nodes) {
      final nodeFolder = await ai.addTask('Node: ${node.title}', node.description, isFolder: true, parentId: rootFolder.id);
      
      for (var item in node.items) {
        String desc = item.description ?? '';
        if (item.connectedTo.isNotEmpty) {
           desc += '\nConnections: ${item.connectedTo.join(', ')}';
        }
        await ai.addTask('Implement ${item.label} [${item.type}]', desc, parentId: nodeFolder.id);
      }
      
      if (node.connectedTo.isNotEmpty) {
        await ai.addTask('Connect Node ${node.title}', 'Route to: ${node.connectedTo.join(', ')}', parentId: nodeFolder.id);
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flow Editor tasks generated successfully!')));
    }
  }

  void _showNewPipelineDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text('New Pipeline', style: TextStyle(color: AppColors.panelTextPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Pipeline Name',
            labelStyle: TextStyle(color: AppColors.panelTextSecondary),
            hintText: 'e.g., data_processing',
            hintStyle: TextStyle(color: AppColors.panelTextSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final filename = name.endsWith('.json') ? name : '$name.json';
                setState(() {
                  _activePipelineFilename = filename;
                  _nodes.clear();
                  _groups.clear();
                  _undoStack.clear();
                  _redoStack.clear();
                  if (!_availablePipelines.contains(filename)) {
                    _availablePipelines.add(filename);
                  }
                });
                await _savePipelineData();
                await _savePreferences();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF2A2A2A).withValues(alpha: _bgOpacity),
      child: Row(
        children: [
          // Pipeline File Management
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _activePipelineFilename,
              dropdownColor: const Color(0xFF333333),
              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              icon: Icon(Icons.arrow_drop_down, color: AppColors.panelTextSecondary, size: 16),
              items: _availablePipelines.map((String filename) {
                return DropdownMenuItem<String>(
                  value: filename,
                  child: Text(filename.replaceAll('.json', '')),
                );
              }).toList(),
              onChanged: (String? newValue) async {
                if (newValue != null && newValue != _activePipelineFilename) {
                  setState(() {
                    _activePipelineFilename = newValue;
                    _undoStack.clear();
                    _redoStack.clear();
                  });
                  await _loadPipelineData();
                  await _savePreferences(); // Saves active pipeline to SharedPreferences
                  if (mounted) setState(() {});
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          _toolbarButton(Icons.add_circle_outline, 'New Pipeline', () {
            _showNewPipelineDialog();
          }, color: Colors.greenAccent),
          const SizedBox(width: 16),
          VerticalDivider(width: 1, color: AppColors.borderSubtle, endIndent: 4, indent: 4),
          const SizedBox(width: 16),

          _toolbarButton(
            Icons.undo, 
            'Undo (Ctrl+Z)', 
            _undoStack.length > 1 ? _undo : () {},
            color: _undoStack.length > 1 ? AppColors.panelTextSecondary : AppColors.borderSubtle
          ),
          const SizedBox(width: 4),
          _toolbarButton(
            Icons.redo, 
            'Redo (Ctrl+Y)', 
            _redoStack.isNotEmpty ? _redo : () {},
            color: _redoStack.isNotEmpty ? AppColors.panelTextSecondary : AppColors.borderSubtle
          ),
          const SizedBox(width: 16),
          VerticalDivider(width: 1, color: AppColors.borderSubtle, endIndent: 4, indent: 4),
          const SizedBox(width: 16),

          ValueListenableBuilder<bool>(
            valueListenable: PipelineExecutionEngine.instance.isRunning,
            builder: (ctx, isRunning, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: PipelineExecutionEngine.instance.isPaused,
                builder: (ctx, isPaused, _) {
                  if (!isRunning && !isPaused) {
                    return _toolbarButton(Icons.play_arrow, 'Run Pipeline', () {
                      PipelineExecutionEngine.instance.start(_nodes, () {
                        if (mounted) setState(() {});
                      });
                    }, color: Colors.greenAccent);
                  } else if (isRunning) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toolbarButton(Icons.stop, 'Stop Pipeline', () {
                          PipelineExecutionEngine.instance.stop();
                        }, color: Colors.redAccent),
                      ],
                    );
                  } else if (isPaused) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toolbarButton(Icons.play_arrow, 'Resume Pipeline', () {
                          PipelineExecutionEngine.instance.resume();
                        }, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        _toolbarButton(Icons.stop, 'Stop Pipeline', () {
                          PipelineExecutionEngine.instance.stop();
                        }, color: Colors.redAccent),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }
              );
            }
          ),
          
          const SizedBox(width: 16),
          _toolbarButton(Icons.add_box, 'Add Screen Node', () {
            setState(() {
              _nodes.add(FlowNode(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: 'New Screen Layout',
                description: '',
                type: 'screen',
                position: Offset((_width / 2 - _pan.dx) / _zoom - 100, (_height / 2 - _pan.dy) / _zoom - 50),
              ));
              _savePreferences();
            });
          }),
          ValueListenableBuilder<AgentNode?>(
            valueListenable: AgentClipboard.copiedAgentNotifier,
            builder: (context, copiedAgent, child) {
              if (copiedAgent == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _toolbarButton(Icons.content_paste, 'Paste ${copiedAgent.title}', () {
                  setState(() {
                    _nodes.add(FlowNode(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: copiedAgent.title,
                      description: copiedAgent.description,
                      type: 'agent',
                      color: copiedAgent.color != null ? Color(copiedAgent.color!) : AppColors.accent,
                      position: Offset((_width / 2 - _pan.dx) / _zoom - 100, (_height / 2 - _pan.dy) / _zoom - 50),
                      items: [
                        FlowNodeItem(id: '${DateTime.now().millisecondsSinceEpoch}_1', label: 'Prompt', type: 'input'),
                        FlowNodeItem(id: '${DateTime.now().millisecondsSinceEpoch}_2', label: 'Run Agent', type: 'button'),
                      ],
                      agentPayload: {'agentId': copiedAgent.id},
                    ));
                    _savePreferences();
                  });
                }, color: AppColors.accent),
              );
            },
          ),
          const SizedBox(width: 8),
          _toolbarButton(
            Icons.route, 
            _isConnectingMode ? 'Cancel Connection' : 'Connect Nodes', 
            () {
              if (_selectedNodeIds.isEmpty && !_isConnectingMode) return;
              setState(() {
                _isConnectingMode = !_isConnectingMode;
                if (_isConnectingMode) {
                  _connectingFromNodeId = _selectedNodeIds.first;
                } else {
                  _connectingFromNodeId = null;
                }
              });
            },
            color: _isConnectingMode ? Colors.amber : AppColors.panelTextSecondary
          ),
          const SizedBox(width: 16),
          VerticalDivider(width: 1, color: AppColors.borderSubtle, endIndent: 4, indent: 4),
          const SizedBox(width: 16),
          _toolbarButton(Icons.copy, 'Duplicate Selected Nodes', () {
            if (_selectedNodeIds.isEmpty) return;
            setState(() {
              Set<String> newSelection = {};
              for (String id in _selectedNodeIds) {
                final src = _nodes.firstWhere((n) => n.id == id);
                final newId = '${DateTime.now().millisecondsSinceEpoch}_$id';
                
                final clonedItems = src.items.map((i) {
                  return FlowNodeItem(
                    id: '${newId}_${i.id}',
                    label: i.label,
                    type: i.type,
                    connectedTo: List.from(i.connectedTo)
                  );
                }).toList();

                _nodes.add(FlowNode(
                  id: newId,
                  title: '${src.title} (Copy)',
                  description: src.description,
                  position: Offset(src.position.dx + 40, src.position.dy + 40),
                  width: src.width,
                  height: src.height,
                  type: src.type,
                  groupId: src.groupId, // Preserve group membership
                  connectedTo: List.from(src.connectedTo),
                  items: clonedItems,
                ));
                newSelection.add(newId);
              }
              _selectedNodeIds = newSelection;
              _savePreferences();
            });
          }, color: _selectedNodeIds.isNotEmpty ? AppColors.panelTextSecondary : AppColors.borderSubtle),
          const SizedBox(width: 8),
          _toolbarButton(Icons.add_box, 'Add Control to Selected', () {
            if (_selectedNodeIds.isEmpty) return;
            setState(() {
              for (String id in _selectedNodeIds) {
                final n = _nodes.firstWhere((n) => n.id == id);
                n.items.add(FlowNodeItem(
                  id: '${DateTime.now().millisecondsSinceEpoch}_$id',
                  label: 'New Control',
                  type: 'button'
                ));
              }
              _savePreferences();
            });
          }, color: _selectedNodeIds.isNotEmpty ? AppColors.accent : AppColors.borderSubtle),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: showControlEditorNotifier,
            builder: (context, val, child) => _toolbarButton(
              Icons.settings_applications, 
              'Toggle Control Editor Configuration', 
              () => showControlEditorNotifier.value = !val, 
              color: val ? AppColors.accent : AppColors.panelTextSecondary
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: showControlTypesEditorNotifier,
            builder: (context, val, child) => _toolbarButton(
              Icons.settings_input_component, 
              'Manage Control Types', 
              () => showControlTypesEditorNotifier.value = !val, 
              color: val ? AppColors.accent : AppColors.panelTextSecondary
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: showProjectModulesNotifier,
            builder: (context, val, child) => _toolbarButton(
              Icons.view_module, 
              'Toggle Project Modules', 
              () {
                if (val) {
                  hideProjectModulesWindow();
                } else {
                  showProjectModulesWindow();
                }
              }, 
              color: val ? Colors.amberAccent : AppColors.panelTextSecondary
            ),
          ),
          const SizedBox(width: 8),
          _toolbarButton(Icons.group_work, 'Group / Ungroup Selected', () {
            if (_selectedNodeIds.isEmpty) return;
            setState(() {
              String? commonGroupId;
              bool allSameGroup = true;
              bool anyHasGroup = false;

              for (var id in _selectedNodeIds) {
                final n = _nodes.firstWhere((n) => n.id == id);
                if (n.groupId != null) {
                  anyHasGroup = true;
                  if (commonGroupId == null) {
                    commonGroupId = n.groupId;
                  } else if (commonGroupId != n.groupId) {
                    allSameGroup = false;
                  }
                } else {
                  allSameGroup = false;
                }
              }

              if (anyHasGroup && allSameGroup && commonGroupId != null) {
                // Toggle OFF -> Ungroup
                for (var id in _selectedNodeIds) {
                  final n = _nodes.firstWhere((n) => n.id == id);
                  n.groupId = null;
                }
                if (!_nodes.any((n) => n.groupId == commonGroupId)) {
                  _groups.removeWhere((g) => g.id == commonGroupId);
                }
              } else {
                // Toggle ON -> Group
                final newGroupId = DateTime.now().millisecondsSinceEpoch.toString();
                _groups.add(FlowGroup(
                  id: newGroupId,
                  label: 'New Group',
                  color: Colors.green.withValues(alpha: 0.1),
                ));
                for (String id in _selectedNodeIds) {
                  final n = _nodes.firstWhere((n) => n.id == id);
                  n.groupId = newGroupId;
                }
              }
              _savePreferences();
            });
          }, color: _selectedNodeIds.isNotEmpty ? Colors.purpleAccent : AppColors.borderSubtle),
          const SizedBox(width: 16),
          VerticalDivider(width: 1, color: AppColors.borderSubtle, endIndent: 4, indent: 4),
          const SizedBox(width: 16),
          _toolbarButton(Icons.color_lens, 'Style Guide', () {}),
          const SizedBox(width: 16),
          VerticalDivider(width: 1, color: AppColors.borderSubtle, endIndent: 4, indent: 4),
          const SizedBox(width: 16),
          _toolbarButton(Icons.text_snippet, 'Export Reference Document', _exportReferenceDocument),
          const SizedBox(width: 8),
          _toolbarButton(Icons.open_in_new, 'Open Reference Document', _openReferenceDocument, color: Colors.lightBlueAccent),
          const SizedBox(width: 8),
          _toolbarButton(Icons.add_task, 'Process Reference into Tasks', _processReferenceToTasks, color: Colors.greenAccent),
          const Spacer(),
          _toolbarButton(Icons.zoom_out, 'Zoom Out', () {
            setState(() { 
              double newZoom = (_zoom - 0.1).clamp(0.2, 3.0);
              if (newZoom != _zoom) {
                final focalPoint = Offset(_width / 2, _height / 2);
                final unscaledPos = (focalPoint - _pan) / _zoom;
                _pan = focalPoint - (unscaledPos * newZoom);
                _zoom = newZoom;
                _savePreferences(); 
              }
            });
          }),
          Text('${(_zoom * 100).toInt()}%', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
          _toolbarButton(Icons.zoom_in, 'Zoom In', () {
            setState(() { 
              double newZoom = (_zoom + 0.1).clamp(0.2, 3.0);
              if (newZoom != _zoom) {
                final focalPoint = Offset(_width / 2, _height / 2);
                final unscaledPos = (focalPoint - _pan) / _zoom;
                _pan = focalPoint - (unscaledPos * newZoom);
                _zoom = newZoom;
                _savePreferences(); 
              }
            });
          }),
          const SizedBox(width: 8),
          VerticalDivider(width: 1, color: AppColors.borderSubtle, endIndent: 4, indent: 4),
          const SizedBox(width: 8),
          _toolbarButton(
            _snapToGrid ? Icons.grid_on : Icons.grid_off, 
            'Snap to Grid', 
            () { setState(() { _snapToGrid = !_snapToGrid; _savePreferences(); }); },
            color: _snapToGrid ? Colors.amber : AppColors.panelTextSecondary
          ),
          const SizedBox(width: 8),
          DropdownButton<double>(
            value: _gridSize,
            dropdownColor: AppColors.panelBackground,
            style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: AppColors.panelTextSecondary, size: 16),
            items: [20.0, 40.0, 80.0, 100.0].map((size) => DropdownMenuItem(value: size, child: Text('${size.toInt()}px grid'))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() { _gridSize = val; _savePreferences(); });
              }
            }
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text('Export to AI Bridge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.panelTextPrimary,
              visualDensity: VisualDensity.compact,
            ),
          )
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }



  void _showGroupEditDialog(String groupId) {
    final group = _groups.firstWhere((g) => g.id == groupId);
    setState(() {
      _editingGroupId = groupId;
      _editLabelCtrl.text = group.label;
      _editDescCtrl.text = group.description ?? '';
      _editSelectedColor = group.color;
    });
  }

  Widget _buildGroupEditor() {
    final group = _groups.firstWhere((g) => g.id == _editingGroupId);
    return Positioned.fill(
      child: Container(
        color: AppColors.background.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.panelBackground,
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
              border: Border.all(color: AppColors.controlBorder),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))]
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Group Settings', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.headerFontSize, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _editLabelCtrl,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(labelText: 'Label', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _editDescCtrl,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Group Color:', style: TextStyle(color: AppColors.panelTextSecondary)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                GlobalPickerState.instance.requestColor(
                                  initialColor: _editSelectedColor ?? Colors.transparent,
                                  onColorSelected: (c) => setState(() => _editSelectedColor = c)
                                );
                                showColorPickerWindow(context);
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.windowBackground,
                                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(color: _editSelectedColor ?? Colors.transparent, shape: BoxShape.circle, border: Border.all(color: AppColors.borderSubtle)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_editSelectedColor == null ? 'None' : 'Selected', style: TextStyle(color: AppColors.panelTextPrimary)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2)),
                    onPressed: () {
                      setState(() {
                         for (var n in _nodes) {
                           if (n.groupId == _editingGroupId) n.groupId = null;
                         }
                         _groups.removeWhere((g) => g.id == _editingGroupId);
                         _editingGroupId = null;
                         _savePreferences();
                      });
                    },
                    icon: const Icon(Icons.link_off, color: Colors.redAccent),
                    label: Text('Ungroup Nodes', style: TextStyle(color: Colors.redAccent)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _editingGroupId = null),
                        child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary))
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () {
                          setState(() {
                            group.label = _editLabelCtrl.text;
                            group.description = _editDescCtrl.text;
                            group.color = _editSelectedColor;
                            _editingGroupId = null;
                          });
                          _savePreferences();
                        },
                        child: Text('Save', style: TextStyle(color: AppColors.panelTextPrimary))
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        )
      )
    );
  }

  void _showNodeEditDialog(String nodeId) {
    final node = _nodes.firstWhere((n) => n.id == nodeId);
    setState(() {
      _editingNodeId = nodeId;
      _editLabelCtrl.text = node.title;
      _editDescCtrl.text = node.description;
      _editSelectedColor = node.color;
    });
  }

  Widget _buildNodeEditor() {
    final node = _nodes.firstWhere((n) => n.id == _editingNodeId);
    return Positioned.fill(
      child: Container(
        color: AppColors.background.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.panelBackground,
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
              border: Border.all(color: AppColors.controlBorder),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))]
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Node Settings', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.headerFontSize, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _editLabelCtrl,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _editDescCtrl,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Node Color:', style: TextStyle(color: AppColors.panelTextSecondary)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                GlobalPickerState.instance.requestColor(
                                  initialColor: _editSelectedColor ?? Colors.transparent,
                                  onColorSelected: (c) => setState(() => _editSelectedColor = c)
                                );
                                showColorPickerWindow(context);
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.windowBackground,
                                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(color: _editSelectedColor ?? Colors.transparent, shape: BoxShape.circle, border: Border.all(color: AppColors.borderSubtle)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_editSelectedColor == null ? 'None' : 'Selected', style: TextStyle(color: AppColors.panelTextPrimary)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _editingNodeId = null),
                        child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary))
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () {
                          setState(() {
                            node.title = _editLabelCtrl.text;
                            node.description = _editDescCtrl.text;
                            node.color = _editSelectedColor;
                            _editingNodeId = null;
                          });
                          _savePreferences();
                        },
                        child: Text('Save', style: TextStyle(color: AppColors.panelTextPrimary))
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        )
      )
    );
  }

  void _openEditControlWindow(String nodeId, String? itemId) {
    if (_nodes.isEmpty) return;
    
    FlowNode? node;
    try { node = _nodes.firstWhere((n) => n.id == nodeId); } catch (_) {}
    if (node == null) return;

    FlowNodeItem? item;
    if (itemId != null) {
      try { item = node.items.firstWhere((i) => i.id == itemId); } catch (_) {}
    }

    FlowEditorContext.activeContext.value = {
      'node': node,
      'item': item,
      'onSave': (FlowNodeItem newItem) {
        setState(() {
          if (item == null) {
            node!.items.add(newItem);
            item = newItem; // Capture so subsequent auto-saves don't duplicate
            FlowEditorContext.activeContext.value = Map.from(FlowEditorContext.activeContext.value ?? {})..['item'] = newItem;
          }
        });
        _savePreferences();
      }
    };
    showControlEditorNotifier.value = true;
  }


}

class ControlEditorPanel extends StatefulWidget {
  final bool isDocked;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;
  const ControlEditorPanel({super.key, this.isDocked = false, this.onClose, this.onFocus});

  @override
  State<ControlEditorPanel> createState() => _ControlEditorPanelState();
}

class _ControlEditorPanelState extends State<ControlEditorPanel> {
  final TextEditingController labelCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController heightCtrl = TextEditingController();
  final Map<String, TextEditingController> _metaDataCtrls = {};
  Color? selectedColor;
  String selectedType = 'button';

  @override
  void initState() {
    super.initState();
    FlowEditorContext.activeContext.addListener(_onContextChanged);
    ControlTypeRegistry.instance.addListener(_onRegistryChanged);
    _onContextChanged();
    _loadPreferences();
  }

  void _onRegistryChanged() {
    if (mounted) setState(() {});
  }

  double _width = 750;
  double _height = 550;
  Offset _offset = const Offset(100, 100);

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _offset = Offset(prefs.getDouble('ce_dx') ?? 100, prefs.getDouble('ce_dy') ?? 100);
        _width = prefs.getDouble('ce_w') ?? 750;
        _height = prefs.getDouble('ce_h') ?? 550;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ce_dx', _offset.dx);
    await prefs.setDouble('ce_dy', _offset.dy);
    await prefs.setDouble('ce_w', _width);
    await prefs.setDouble('ce_h', _height);
  }

  void _onContextChanged() {
    final ctx = FlowEditorContext.activeContext.value;
    final item = ctx?['item'] as FlowNodeItem?;
    
    labelCtrl.removeListener(_autoSave);
    descCtrl.removeListener(_autoSave);
    heightCtrl.removeListener(_autoSave);
    for (var ctrl in _metaDataCtrls.values) {
      ctrl.removeListener(_autoSave);
    }

    setState(() {
      labelCtrl.text = item?.label ?? (item?.type == 'gap' ? '' : 'New Control');
      descCtrl.text = item?.description ?? '';
      heightCtrl.text = item?.height?.toString() ?? '22.0';
      selectedColor = item?.color ?? (item?.type == 'gap' ? Colors.transparent : null);
      final hasType = ControlTypeRegistry.instance.getType(item?.type ?? '') != null;
      selectedType = hasType ? item!.type : 'button';
      
      final selectedTypeDef = ControlTypeRegistry.instance.getType(selectedType);
      final constraints = selectedTypeDef?.constraintKeys ?? [];
      
      _metaDataCtrls.clear();
      for (var key in constraints) {
        _metaDataCtrls[key] = TextEditingController(text: item?.metaData?[key]?.toString() ?? '');
        _metaDataCtrls[key]!.addListener(_autoSave);
      }
    });

    labelCtrl.addListener(_autoSave);
    descCtrl.addListener(_autoSave);
    heightCtrl.addListener(_autoSave);
  }

  final Set<String> _expandedFolders = {};

  void _autoSave() {
    final ctx = FlowEditorContext.activeContext.value;
    if (ctx == null) return;
    final item = ctx['item'] as FlowNodeItem?;
    final onSave = ctx['onSave'] as Function(FlowNodeItem)?;
    if (onSave == null) return;

    final newItem = item ?? FlowNodeItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: labelCtrl.text,
      type: selectedType,
    );
    
    newItem.label = labelCtrl.text;
    newItem.description = descCtrl.text.isNotEmpty ? descCtrl.text : null;
    newItem.height = double.tryParse(heightCtrl.text);
    newItem.color = selectedColor;
    newItem.type = selectedType;
    
    final selectedTypeDef = ControlTypeRegistry.instance.getType(selectedType);
    final constraints = selectedTypeDef?.constraintKeys ?? [];
    
    Map<String, dynamic> metadata = {};
    for (var key in constraints) {
      if (_metaDataCtrls.containsKey(key) && _metaDataCtrls[key]!.text.isNotEmpty) {
        final text = _metaDataCtrls[key]!.text;
        final numVal = num.tryParse(text);
        metadata[key] = numVal ?? text;
      }
    }
    
    newItem.metaData = metadata.isNotEmpty ? metadata : null;

    onSave(newItem);
  }

  @override
  void dispose() {
    ControlTypeRegistry.instance.removeListener(_onRegistryChanged);
    FlowEditorContext.activeContext.removeListener(_onContextChanged);
    labelCtrl.removeListener(_autoSave);
    descCtrl.removeListener(_autoSave);
    heightCtrl.removeListener(_autoSave);
    for (var ctrl in _metaDataCtrls.values) {
      ctrl.removeListener(_autoSave);
      ctrl.dispose();
    }
    labelCtrl.dispose();
    descCtrl.dispose();
    heightCtrl.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    if (FlowEditorContext.activeContext.value == null) {
      return const SizedBox.shrink();
    }
    final selectedTypeDef = ControlTypeRegistry.instance.getType(selectedType);
    final constraints = selectedTypeDef?.constraintKeys ?? [];
    
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      width: _width,
      height: _height,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Container(
                            clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'flow_editor' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                color: AppColors.windowBackground,
                borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  // Editor Header / Drag Handle
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _offset += details.delta;
                        if (_offset.dy < 0) _offset = Offset(_offset.dx, 0);
                      });
                    },
                    onPanEnd: (_) => _savePreferences(),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.panelBackground,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
                        border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.settings, color: Colors.amberAccent, size: 14),
                          const SizedBox(width: 8),
                          Text('Control Editor Configuration', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Icon(Icons.close, color: AppColors.panelTextSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONTROL TYPE', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      ...(() {
                        final roots = ControlTypeRegistry.instance.types.where((t) => t.parentType == null).toList();
                        return roots.map((root) {
                          final children = ControlTypeRegistry.instance.types.where((t) => t.parentType == root.id).toList();
                          final isExpanded = _expandedFolders.contains(root.id);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedType = root.id;
                                    if (children.isNotEmpty) {
                                      _expandedFolders.clear();
                                      _expandedFolders.add(root.id);
                                    }
                                  });
                                  _autoSave();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: selectedType == root.id ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: selectedType == root.id ? AppColors.accent : AppColors.overlaySubtle)
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        root.icon, 
                                        size: 16, color: selectedType == root.id ? AppColors.accent : AppColors.panelTextSecondary
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(root.label, style: TextStyle(color: selectedType == root.id ? AppColors.panelTextPrimary : AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize))),
                                      if (children.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedFolders.remove(root.id);
                                              } else {
                                                _expandedFolders.clear();
                                                _expandedFolders.add(root.id);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2.0),
                                            color: Colors.transparent,
                                            child: Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 16, color: AppColors.panelTextSecondary),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded && children.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Column(
                                    children: children.map((child) => InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedType = child.id;
                                        });
                                        _autoSave();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        margin: const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: selectedType == child.id ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: selectedType == child.id ? AppColors.accent : Colors.transparent)
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(child.icon, size: 14, color: selectedType == child.id ? AppColors.accent : AppColors.panelTextSecondary),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(child.label, style: TextStyle(color: selectedType == child.id ? AppColors.panelTextPrimary : AppColors.panelTextSecondary, fontSize: 12))),
                                          ],
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
                            ],
                          );
                        });
                      }()).toList(),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GENERAL INFO', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: labelCtrl,
                        style: TextStyle(color: AppColors.panelTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Label', 
                          labelStyle: TextStyle(color: AppColors.panelTextSecondary),
                          filled: true,
                          fillColor: AppColors.windowBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        style: TextStyle(color: AppColors.panelTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Description (Tooltip)', 
                          labelStyle: TextStyle(color: AppColors.panelTextSecondary),
                          filled: true,
                          fillColor: AppColors.windowBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      if (selectedType == 'gap' || selectedType == 'divider') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: heightCtrl,
                          style: TextStyle(color: AppColors.panelTextPrimary),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Height (px)', 
                            labelStyle: TextStyle(color: AppColors.panelTextSecondary),
                            filled: true,
                            fillColor: AppColors.windowBackground,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],

                      if (constraints.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('PARAMETERS', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        ...List.generate((constraints.length / 2).ceil(), (index) {
                          final first = constraints[index * 2];
                          final second = (index * 2 + 1 < constraints.length) ? constraints[index * 2 + 1] : null;
                          
                          Widget buildField(String key) {
                            String label = key[0].toUpperCase() + key.substring(1);
                            if (key == 'maxLength') label = 'Max Length';
                            if (key == 'min') label = 'Min Value';
                            if (key == 'max') label = 'Max Value';
                            return Expanded(
                              child: TextField(
                                controller: _metaDataCtrls[key],
                                style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  labelText: label,
                                  labelStyle: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                buildField(first),
                                if (second != null) const SizedBox(width: 12),
                                if (second != null) buildField(second),
                              ],
                            ),
                          );
                        }),
                      ],


                      const SizedBox(height: 24),
                      Text('APPEARANCE', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          GlobalPickerState.instance.requestColor(
                            initialColor: selectedColor ?? Colors.transparent,
                            onColorSelected: (c) {
                              setState(() => selectedColor = c);
                              _autoSave();
                            }
                          );
                          showColorPickerWindow(context);
                        },
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.windowBackground,
                            borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(color: selectedColor ?? Colors.transparent, shape: BoxShape.circle, border: Border.all(color: AppColors.borderSubtle)),
                              ),
                              const SizedBox(width: 8),
                              Text(selectedColor == null ? 'None' : 'Selected', style: TextStyle(color: AppColors.panelTextPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ]
    ),
    ), // Container
    // Resizer
            Positioned(
              right: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _width = (_width + details.delta.dx).clamp(350.0, 1000.0);
                      _height = (_height + details.delta.dy).clamp(400.0, 1000.0);
                    });
                  },
                  onPanEnd: (_) => _savePreferences(),
                  child: Container(
                    width: 20,
                    height: 20,
                    color: Colors.transparent,
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.arrow_drop_down, color: AppColors.borderSubtle, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverableItemRow extends StatefulWidget {
  final Widget Function(bool isHovered) builder;
  const _HoverableItemRow({Key? key, required this.builder}) : super(key: key);
  @override
  State<_HoverableItemRow> createState() => _HoverableItemRowState();
}

class _HoverableItemRowState extends State<_HoverableItemRow> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isHovered = true),
        child: widget.builder(_isHovered),
      ),
    );
  }
}

class _NodeCanvas extends StatelessWidget {
  final Offset pan;
  final List<FlowNode> nodes;
  final List<FlowGroup> groups;
  final Set<String> selectedIds;
  final String? connectingFromId;
  final void Function(String) onSelect;
  final void Function(String) onSelectGroup;
  final void Function(String, Offset) onPan;
  final void Function(String) onPanEnd;
  final void Function(String) onEdit;
  final void Function(String) onDelete;
  final void Function(String, double, double?) onResize;
  final void Function(String, String, double) onResizeItem;
  final void Function() onResizeItemEnd;
  final void Function(String, String) onEditItem;
  final void Function(String, String) onConnectItem;
  final void Function(String, String) onRemoveItem;
  final void Function(String, int, int) onReorderItem;
  final void Function(String) onEditGroup;
  final void Function(String) onUngroup;

  const _NodeCanvas({
    required this.pan,
    required this.nodes,
    required this.groups,
    required this.selectedIds,
    this.connectingFromId,
    required this.onSelect,
    required this.onSelectGroup,
    required this.onPan,
    required this.onPanEnd,
    required this.onEdit,
    required this.onDelete,
    required this.onResize,
    required this.onResizeItem,
    required this.onResizeItemEnd,
    required this.onEditItem,
    required this.onConnectItem,
    required this.onRemoveItem,
    required this.onReorderItem,
    required this.onEditGroup,
    required this.onUngroup,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    // Draw Groups Behind Nodes
    for (var g in groups) {
      final groupNodes = nodes.where((n) => n.groupId == g.id).toList();
      if (groupNodes.isEmpty) continue;

      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

      for (var n in groupNodes) {
        if (n.position.dx < minX) minX = n.position.dx;
        if (n.position.dy < minY) minY = n.position.dy;
        if (n.position.dx + n.width > maxX) maxX = n.position.dx + n.width;
        if (n.position.dy + (n.height ?? 100) > maxY) maxY = n.position.dy + (n.height ?? 100);
      }

      minX -= 24; minY -= 48;
      maxX += 24; maxY += 24;

      children.add(
        Positioned(
          left: minX + pan.dx,
          top: minY + pan.dy,
          width: maxX - minX,
          height: maxY - minY,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelectGroup(g.id),
            onPanDown: (_) {}, 
            onPanUpdate: (d) {
              final firstGroupNode = nodes.firstWhere((n) => n.groupId == g.id);
              onPan(firstGroupNode.id, d.delta);
            },
            onPanEnd: (_) {
              final firstGroupNode = nodes.firstWhere((n) => n.groupId == g.id);
              onPanEnd(firstGroupNode.id);
            },
            child: Container(
              decoration: BoxDecoration(
                color: g.color ?? AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle, width: 2),
              ),
            child: Stack(
              children: [
                Positioned(
                  left: 12.0,
                  top: 8.0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onEditGroup(g.id),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.label, style: TextStyle(color: Colors.white60, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            if (g.description != null && g.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                width: maxX - minX - 40,
                                child: Text(g.description!, style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize), overflow: TextOverflow.clip),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12.0,
                  top: 8.0,
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Group Settings',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onEditGroup(g.id),
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.settings, size: 20, color: AppColors.panelTextSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          ),
        ),
      );
    }

    // Draw Nodes
    children.addAll(nodes.map((node) {
      final isSelected = selectedIds.contains(node.id);
      final isConnecting = connectingFromId == node.id;
      
      double estimatedHeight = node.height ?? _calculateMinNodeHeight(context, node);

      return Positioned(
        key: ValueKey('node_${node.id}'),
        left: node.position.dx + pan.dx - 16,
        top: node.position.dy + pan.dy - 16,
        width: node.width + 32,
        height: estimatedHeight + 32,
        child: Listener(
          onPointerDown: (e) => print('[FLOW] NODE ${node.id} Listener pointerDown at ${e.localPosition}'),
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main Interactive Background
            Positioned(
              left: 16, top: 16, right: 16, bottom: 16,
              child: Container(
                  width: node.width,
                  height: estimatedHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: node.color ?? const Color(0xFF2E2E2E),
                      borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: node.executionState != null
                           ? (node.executionState == 'queued' ? Colors.grey : node.executionState == 'running' ? Colors.blueAccent : node.executionState == 'success' ? Colors.greenAccent : node.executionState == 'failed' ? Colors.redAccent : AppColors.overlaySubtle)
                           : isConnecting ? Colors.amber 
                           : isSelected ? AppColors.accent 
                           : AppColors.overlaySubtle,
                      width: node.executionState != null ? 3 : (isSelected || isConnecting ? 2 : 1),
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                                borderRadius: BorderRadius.zero,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(node.title, style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, height: 1.1), overflow: TextOverflow.ellipsis)),
                                Icon(Icons.edit, size: 14, color: AppColors.panelTextSecondary),
                                const SizedBox(width: 6),
                                const Icon(Icons.delete, size: 14, color: Colors.redAccent),
                              ],
                            ),
                          ),
                          if (node.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                              child: Text(node.description, style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, height: 1.3)),
                            ),
                          const SizedBox(height: 8),
                          if (node.items.isNotEmpty)
                            ...node.items.asMap().entries.map((entry) {
                              final item = entry.value;
                              final nodeBgColor = node.color ?? const Color(0xFF2E2E2E);
                              final bool isNodeBright = nodeBgColor.computeLuminance() > 0.5;

                              Widget itemContent;

                              if (item.type == 'divider') {
                                itemContent = _HoverableItemRow(
                                  key: ValueKey('item_${node.id}_${item.id}'),
                                  builder: (isHovered) {
                                    final bool isConnectingFromThis = connectingFromId == '${node.id}|${item.id}';
                                    final bool showControls = isHovered || isConnectingFromThis;
                                    return Container(
                                      height: 22,
                                      margin: EdgeInsets.only(bottom: 4, left: isHovered ? 8 : 0, right: isHovered ? 8 : 0),
                                      padding: EdgeInsets.symmetric(horizontal: (item.label.isEmpty && !showControls) ? 0 : 6, vertical: 2),
                                      child: Row(
                                        children: [

                                          if (showControls) Icon(Icons.drag_indicator, size: 12, color: isNodeBright ? Colors.black38 : AppColors.textMuted),

                                          if (showControls) const SizedBox(width: 4),

                                          if (item.label.isNotEmpty) Text(item.label, style: TextStyle(color: isNodeBright ? Colors.black87 : AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize * 0.7, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),

                                          if (item.label.isNotEmpty) const SizedBox(width: 8),

                                          Expanded(child: Container(height: 1, color: item.color ?? (isNodeBright ? Colors.black26 : AppColors.borderSubtle))),

                                          if (showControls) const SizedBox(width: 8),
                                            if (showControls) Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.route, size: 12, color: isConnectingFromThis ? Colors.amber : Colors.transparent),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.edit, size: 12, color: isNodeBright ? Colors.black54 : AppColors.panelTextSecondary),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.close, size: 12, color: isNodeBright ? Colors.black54 : AppColors.panelTextSecondary),
                                                ],
                                              ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              } else if (item.type == 'gap') {
                                itemContent = _HoverableItemRow(
                                  key: ValueKey('item_${node.id}_${item.id}'),
                                  builder: (isHovered) {
                                    final bool isConnectingFromThis = connectingFromId == '${node.id}|${item.id}';
                                    final bool showControls = isHovered || isConnectingFromThis;
                                    return Container(

                                      height: item.height ?? 22.0,

                                      margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),

                                      color: item.color ?? Colors.transparent,

                                      child: Stack(

                                        clipBehavior: Clip.none,

                                        children: [

                                          Positioned(

                                            right: 0,

                                            top: ((item.height ?? 22.0) - 9) / 2,

                                            child: Opacity(

                                              opacity: showControls ? 1.0 : 0.0,

                                              child: Row(

                                                mainAxisSize: MainAxisSize.min,

                                                children: [

                                                  Icon(Icons.route, size: 12, color: isConnectingFromThis ? Colors.amber : Colors.transparent),

                                                  const SizedBox(width: 4),

                                                  Icon(Icons.edit, size: 12, color: AppColors.overlaySubtle),

                                                  const SizedBox(width: 4),

                                                  Icon(Icons.close, size: 12, color: AppColors.overlaySubtle),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: -2,
                                            left: 0,
                                            right: 0,
                                            height: 8,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.resizeUpDown,
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onPanUpdate: (d) => onResizeItem(node.id, item.id, d.delta.dy),
                                                onPanEnd: (_) => onResizeItemEnd(),
                                                child: Container(color: Colors.transparent),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              } else {
                                final bool isBright = (item.color != null && item.color != Colors.transparent) ? item.color!.computeLuminance() > 0.5 : isNodeBright;
                                final Color textColor = isBright ? Colors.black87 : AppColors.panelTextPrimary;
                                final Color iconColor = isBright ? Colors.black54 : AppColors.panelTextSecondary;
                                final Color subtleIconColor = isBright ? Colors.black45 : AppColors.panelTextSecondary;

                                itemContent = _HoverableItemRow(
                                  key: ValueKey('item_${node.id}_${item.id}'),
                                  builder: (isHovered) {
                                    final bool isConnectingFromThis = connectingFromId == '${node.id}|${item.id}';
                                    final bool showControls = isHovered || isConnectingFromThis;
                                  return Container(

                                    height: 22,

                                    margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),

                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                                    decoration: BoxDecoration(

                                      color: item.color ?? AppColors.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.zero,

                                      border: Border.all(color: item.color != null ? Colors.transparent : AppColors.accent.withValues(alpha: 0.3)),

                                    ),

                                    child: Row(

                                      children: [

                                        if (showControls) Icon(Icons.drag_indicator, size: 12, color: subtleIconColor),
                                          if (showControls) const SizedBox(width: 2),

                                        Icon(
                                          ControlTypeRegistry.instance.getType(item.type)?.icon ?? Icons.touch_app, 
                                          size: 12, color: iconColor
                                        ),

                                        const SizedBox(width: 4),

                                        Expanded(child: Text(item.label, style: TextStyle(color: textColor, fontSize: AppUIConfig.rootFontSize * 0.7, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),

                                        Opacity(

                                          opacity: showControls ? 1.0 : 0.0,

                                          child: Row(

                                            mainAxisSize: MainAxisSize.min,

                                            children: [

                                              Icon(Icons.route, size: 12, color: isConnectingFromThis ? (isBright ? Colors.blue.shade900 : Colors.amber) : (isBright ? Colors.black45 : AppColors.accent)),

                                              const SizedBox(width: 4),

                                              Icon(Icons.edit, size: 12, color: subtleIconColor),

                                              const SizedBox(width: 4),

                                              Icon(Icons.close, size: 12, color: subtleIconColor),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                              }

                              if (item.description != null && item.description!.isNotEmpty) {
                                return Tooltip(
                                  message: item.description!,
                                  waitDuration: const Duration(milliseconds: 400),
                                  child: itemContent,
                                );
                              }
                              return itemContent;
                            }),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
        );
    }).toList());

    return Stack(
      clipBehavior: Clip.none,
      children: children,
    );
  }
}

class _EdgePainter extends CustomPainter {
  final List<FlowNode> nodes;
  final Offset pan;
  final double zoom;
  final String? connectingFromId;
  final Offset? mousePos;
  
  _EdgePainter({required this.nodes, required this.pan, required this.zoom, this.connectingFromId, this.mousePos});

  double _calculateItemYOffset(FlowNode node, int index) {
      double y = 32.0; 
      if (node.description.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(text: node.description, style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
            textDirection: TextDirection.ltr,
          );
          tp.layout(maxWidth: node.width - 20);
          y += tp.size.height + 8.0; 
      }
      y += 8.0; 
      
      for (int i = 0; i < index; i++) {
        final item = node.items[i];
        if (item.type == 'gap') {
          y += (item.height ?? 22.0) + 4.0;
        } else {
          y += 26.0;
        }
      }
      
      if (index < node.items.length) {
        final targetItem = node.items[index];
        if (targetItem.type == 'gap') {
          y += (targetItem.height ?? 22.0) / 2.0;
        } else {
          y += 11.0;
        }
      } else {
        y += 11.0;
      }
      
      return y;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var node in nodes) {
      for (var targetId in node.connectedTo) {
        final target = nodes.cast<FlowNode?>().firstWhere((n) => n?.id == targetId, orElse: () => null);
        if (target != null) {
          final isTargetRight = target.position.dx > node.position.dx;
          final start = node.position + pan + Offset(isTargetRight ? node.width : 0, node.height != null ? node.height! / 2 : 40);
          final end = target.position + pan + Offset(isTargetRight ? 0 : target.width, target.height != null ? target.height! / 2 : 40);
          
          final path = Path();
          path.moveTo(start.dx, start.dy);
          path.cubicTo(
            start.dx + (isTargetRight ? 50 : -50), start.dy, 
            end.dx - (isTargetRight ? 50 : -50), end.dy, 
            end.dx, end.dy
          );
          canvas.drawPath(path, paint);
          canvas.drawCircle(end, 4, Paint()..color = AppColors.accent);
        }
      }

      var itemIndex = 0;
      for (var item in node.items) {
        for (var targetId in item.connectedTo) {
          final target = nodes.cast<FlowNode?>().firstWhere((n) => n?.id == targetId, orElse: () => null);
          if (target != null) {
            final isTargetRight = target.position.dx > node.position.dx;
            final start = node.position + pan + Offset(isTargetRight ? node.width - 8 : 8, _calculateItemYOffset(node, itemIndex));
            final end = target.position + pan + Offset(isTargetRight ? 0 : target.width, target.height != null ? target.height! / 2 : 40); 
            
            final path = Path();
            path.moveTo(start.dx, start.dy);
            path.cubicTo(
              start.dx + (isTargetRight ? 50 : -50), start.dy, 
              end.dx - (isTargetRight ? 50 : -50), end.dy, 
              end.dx, end.dy
            );
            canvas.drawPath(path, Paint()..color = AppColors.accent.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
            canvas.drawCircle(end, 4, Paint()..color = AppColors.accent);
          }
        }
        itemIndex++;
      }
    }

    if (connectingFromId != null && mousePos != null) {
       Offset? baseStart;
       double? nodeBaseX;
       double? nodeWidth;

       if (connectingFromId!.contains('|')) {
          final parts = connectingFromId!.split('|');
          final n = nodes.cast<FlowNode?>().firstWhere((n) => n?.id == parts[0], orElse: () => null);
          if (n != null) {
            nodeBaseX = n.position.dx;
            nodeWidth = n.width;
            final iIdx = n.items.indexWhere((i) => i.id == parts[1]);
            if (iIdx != -1) {
              baseStart = n.position + pan + Offset(0, _calculateItemYOffset(n, iIdx));
            }
          }
       } else {
          final n = nodes.cast<FlowNode?>().firstWhere((n) => n?.id == connectingFromId, orElse: () => null);
          if (n != null) {
            nodeBaseX = n.position.dx;
            nodeWidth = n.width;
            baseStart = n.position + pan + Offset(0, n.height != null ? n.height! / 2 : 40);
          }
       }

       if (baseStart != null && nodeBaseX != null && nodeWidth != null && connectingFromId!.contains('|')) {
          final end = mousePos!;
          final isTargetRight = end.dx > (nodeBaseX + pan.dx + nodeWidth / 2);
          
          final dynamicStart = isTargetRight
               ? Offset(nodeBaseX + pan.dx + nodeWidth - 8, baseStart.dy)
               : Offset(nodeBaseX + pan.dx + 8, baseStart.dy);

          final path = Path();
          path.moveTo(dynamicStart.dx, dynamicStart.dy);
          path.cubicTo(
            dynamicStart.dx + (isTargetRight ? 50 : -50), dynamicStart.dy, 
            end.dx - (isTargetRight ? 50 : -50), end.dy, 
            end.dx, end.dy
          );
          canvas.drawPath(path, Paint()..color = Colors.amber.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 2);
          canvas.drawCircle(end, 4, Paint()..color = Colors.amber);
       } else if (baseStart != null && nodeBaseX != null && nodeWidth != null) {
          final end = mousePos!;
          final isTargetRight = end.dx > (nodeBaseX + pan.dx + nodeWidth / 2);
          
          final dynamicStart = isTargetRight
               ? Offset(nodeBaseX + pan.dx + nodeWidth, baseStart.dy)
               : Offset(nodeBaseX + pan.dx, baseStart.dy);

          final path = Path();
          path.moveTo(dynamicStart.dx, dynamicStart.dy);
          path.cubicTo(
            dynamicStart.dx + (isTargetRight ? 50 : -50), dynamicStart.dy, 
            end.dx - (isTargetRight ? 50 : -50), end.dy, 
            end.dx, end.dy
          );
          canvas.drawPath(path, Paint()..color = Colors.amber.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 2);
          canvas.drawCircle(end, 4, Paint()..color = Colors.amber);
       }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class _MarqueePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  _MarqueePainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
      
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_MarqueePainter old) => old.start != start || old.end != end;
}

class _GridPainter extends CustomPainter {
  final Offset pan;
  final double zoom;
  final double baseGridSize;
  _GridPainter({required this.pan, required this.zoom, required this.baseGridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.panelTextPrimary.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    
    final gridSize = baseGridSize * zoom;
    final offsetX = pan.dx % gridSize;
    final offsetY = pan.dy % gridSize;

    for (double x = offsetX; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = offsetY; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.pan != pan || old.zoom != zoom;
}


