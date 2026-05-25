import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:music_app/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/state_machine_models.dart';

/// Interactive visualizer widget for state machines.
/// Supports panning, zooming, glowing active states, and animated transition particles.
class StateMachineVisualizer extends StatefulWidget {
  final StateMachineController controller;
  final double width;
  final double height;

  const StateMachineVisualizer({
    super.key,
    required this.controller,
    this.width = 800,
    this.height = 500,
  });

  @override
  State<StateMachineVisualizer> createState() => _StateMachineVisualizerState();
}

class _StateMachineVisualizerState extends State<StateMachineVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _transitionController;
  String? _lastAnimatedFrom;
  String? _lastAnimatedTo;

  // Node Dimensions
  static const double nodeWidth = 160.0;
  static const double nodeHeight = 76.0;

  // Movable and Sizable layout state
  final Map<String, Offset> _nodePositions = {};
  final Map<String, Size> _nodeSizes = {};
  bool _isDraggingOrResizing = false;

  // Custom Panning and Zooming layout state mimicking the Flow Window
  Offset _pan = Offset.zero;
  double _zoom = 1.0;
  bool _isMiddleButtonPanning = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    widget.controller.addListener(_handleStateChange);
    _loadLayout();
  }

  @override
  void didUpdateWidget(StateMachineVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleStateChange);
      widget.controller.addListener(_handleStateChange);
      _loadLayout();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleStateChange);
    _transitionController.dispose();
    super.dispose();
  }

  void _handleStateChange() {
    final vState = widget.controller.visualState;
    if (vState.lastActiveStateId != null &&
        vState.lastActiveStateId != vState.activeStateId) {
      setState(() {
        _lastAnimatedFrom = vState.lastActiveStateId;
        _lastAnimatedTo = vState.activeStateId;
      });
      _transitionController.forward(from: 0.0);
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load pan and zoom
      final panX = prefs.getDouble('ve_sm_pan_x') ?? 0.0;
      final panY = prefs.getDouble('ve_sm_pan_y') ?? 0.0;
      _pan = Offset(panX, panY);
      _zoom = prefs.getDouble('ve_sm_zoom') ?? 1.0;

      for (var node in widget.controller.config.nodes) {
        final posKey = 've_sm_pos_${node.id}';
        final sizeKey = 've_sm_size_${node.id}';

        final posStr = prefs.getString(posKey);
        if (posStr != null) {
          final parts = posStr.split(',');
          if (parts.length == 2) {
            final dx = double.tryParse(parts[0]);
            final dy = double.tryParse(parts[1]);
            if (dx != null && dy != null) {
              _nodePositions[node.id] = Offset(dx, dy);
            }
          }
        }

        final sizeStr = prefs.getString(sizeKey);
        if (sizeStr != null) {
          final parts = sizeStr.split(',');
          if (parts.length == 2) {
            final w = double.tryParse(parts[0]);
            final h = double.tryParse(parts[1]);
            if (w != null && h != null) {
              _nodeSizes[node.id] = Size(w, h);
            }
          }
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading state machine visualizer layout: $e');
    }
  }

  Future<void> _saveNodePosition(String nodeId, Offset position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ve_sm_pos_$nodeId', '${position.dx},${position.dy}');
    } catch (e) {
      debugPrint('Error saving node position: $e');
    }
  }

  Future<void> _saveNodeSize(String nodeId, Size size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ve_sm_size_$nodeId', '${size.width},${size.height}');
    } catch (e) {
      debugPrint('Error saving node size: $e');
    }
  }

  Future<void> _savePanZoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('ve_sm_pan_x', _pan.dx);
      await prefs.setDouble('ve_sm_pan_y', _pan.dy);
      await prefs.setDouble('ve_sm_zoom', _zoom);
    } catch (e) {
      debugPrint('Error saving state machine visualizer pan/zoom: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visualState = widget.controller.visualState;

    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF15151A), // Sleek deep background
      child: Listener(
        behavior: HitTestBehavior.opaque,
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
            _savePanZoom();
          }
        },
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            setState(() {
              double zoomDelta = pointerSignal.scrollDelta.dy > 0 ? -0.05 : 0.05;
              double newZoom = (_zoom + zoomDelta).clamp(0.4, 2.0);
              if (newZoom != _zoom) {
                final focalPoint = pointerSignal.localPosition;
                final unscaledPos = (focalPoint - _pan) / _zoom;
                _pan = focalPoint - (unscaledPos * newZoom);
                _zoom = newZoom;
                _savePanZoom();
              }
            });
          }
        },
        child: ClipRect(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, child) {
              return AnimatedBuilder(
                animation: _transitionController,
                builder: (context, child) {
                  return Transform.translate(
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
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Layer 1: Background Grid & Connectors (Custom Painter)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _StateMachinePainter(
                                    config: widget.controller.config,
                                    activeStateId: visualState.activeStateId,
                                    fromNodeId: _lastAnimatedFrom,
                                    toNodeId: _lastAnimatedTo,
                                    transitionProgress: _transitionController.value,
                                    nodeWidth: nodeWidth,
                                    nodeHeight: nodeHeight,
                                    nodePositions: _nodePositions,
                                    nodeSizes: _nodeSizes,
                                  ),
                                ),
                              ),

                              // Layer 2: Interactive Nodes
                              ...widget.controller.config.nodes.map((node) {
                                final isActive = visualState.activeStateId == node.id;
                                final isLastActive = visualState.lastActiveStateId == node.id;
                                final hasError = visualState.hasError && isActive;

                                final pos = _nodePositions[node.id] ?? node.position;
                                final size = _nodeSizes[node.id] ?? const Size(nodeWidth, nodeHeight);

                                return Positioned(
                                  left: pos.dx,
                                  top: pos.dy,
                                  width: size.width,
                                  height: size.height,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onPanStart: (_) {
                                            setState(() {
                                              _isDraggingOrResizing = true;
                                            });
                                          },
                                          onPanUpdate: (details) {
                                            setState(() {
                                              final oldPos = _nodePositions[node.id] ?? node.position;
                                              final newPos = oldPos + details.delta / _zoom;
                                              _nodePositions[node.id] = newPos;
                                            });
                                          },
                                          onPanEnd: (_) {
                                            setState(() {
                                              _isDraggingOrResizing = false;
                                            });
                                            _saveNodePosition(node.id, _nodePositions[node.id] ?? node.position);
                                          },
                                          onPanCancel: () {
                                            setState(() {
                                              _isDraggingOrResizing = false;
                                            });
                                          },
                                          child: _StateNodeWidget(
                                            node: node,
                                            isActive: isActive,
                                            isLastActive: isLastActive,
                                            hasError: hasError,
                                            statusText: isActive ? visualState.statusMessage : '',
                                            width: size.width,
                                            height: size.height,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        width: 24,
                                        height: 24,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.resizeDownRight,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (_) {
                                              setState(() {
                                                _isDraggingOrResizing = true;
                                              });
                                            },
                                            onPanUpdate: (details) {
                                              setState(() {
                                                final oldSize = _nodeSizes[node.id] ?? const Size(nodeWidth, nodeHeight);
                                                final newWidth = (oldSize.width + details.delta.dx / _zoom).clamp(120.0, 300.0);
                                                final newHeight = (oldSize.height + details.delta.dy / _zoom).clamp(70.0, 200.0);
                                                _nodeSizes[node.id] = Size(newWidth, newHeight);
                                              });
                                            },
                                            onPanEnd: (_) {
                                              setState(() {
                                                _isDraggingOrResizing = false;
                                              });
                                              _saveNodeSize(node.id, _nodeSizes[node.id] ?? const Size(nodeWidth, nodeHeight));
                                            },
                                            onPanCancel: () {
                                              setState(() {
                                                _isDraggingOrResizing = false;
                                              });
                                            },
                                            child: Container(
                                              alignment: Alignment.bottomRight,
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.south_east,
                                                size: 10,
                                                color: Colors.white.withOpacity(0.4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A single state node widget, styled as a premium glassmorphic card.
class _StateNodeWidget extends StatelessWidget {
  final StateNodeConfig node;
  final bool isActive;
  final bool isLastActive;
  final bool hasError;
  final String statusText;
  final double width;
  final double height;

  const _StateNodeWidget({
    required this.node,
    required this.isActive,
    required this.isLastActive,
    required this.hasError,
    required this.statusText,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = hasError ? Colors.redAccent : node.color;
    final displayStatus = statusText.isNotEmpty
        ? statusText
        : (isActive ? 'Active' : 'Standby');

    return Tooltip(
      message: node.description.isNotEmpty ? node.description : node.label,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Colors.white70, fontSize: 11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.black.withOpacity(0.55),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            if (isActive)
              BoxShadow(
                color: baseColor.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 2,
              ),
          ],
          border: Border.all(
            color: isActive
                ? baseColor
                : (isLastActive ? baseColor.withOpacity(0.5) : Colors.white12),
            width: isActive ? 2.0 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      // Node Icon with gradient or custom color
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: baseColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          node.icon ?? Icons.circle_outlined,
                          size: 14,
                          color: baseColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Title
                      Expanded(
                        child: Text(
                          node.label.toUpperCase(),
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Pulsing active dot
                      if (isActive)
                        _PulsingDot(color: baseColor)
                      else if (isLastActive)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: baseColor.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Status Text
                  Text(
                    displayStatus,
                    style: TextStyle(
                      color: isActive
                          ? baseColor.withOpacity(0.9)
                          : Colors.white30,
                      fontSize: 9,
                      fontFamily: 'monospace',
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Painter to draw connection paths, arrows, grid, and transition particles.
class _StateMachinePainter extends CustomPainter {
  final StateMachineConfig config;
  final String activeStateId;
  final String? fromNodeId;
  final String? toNodeId;
  final double transitionProgress;
  final double nodeWidth;
  final double nodeHeight;
  final Map<String, Offset> nodePositions;
  final Map<String, Size> nodeSizes;

  _StateMachinePainter({
    required this.config,
    required this.activeStateId,
    this.fromNodeId,
    this.toNodeId,
    required this.transitionProgress,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.nodePositions,
    required this.nodeSizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw grid background
    _paintGrid(canvas, size);

    // 2. Draw connections
    for (var transition in config.transitions) {
      final fromNode = config.getNode(transition.from);
      final toNode = config.getNode(transition.to);

      if (fromNode == null || toNode == null) continue;

      // Calculate node center ports dynamically based on custom sizes and positions
      final fromPos = nodePositions[transition.from] ?? fromNode.position;
      final fromSize = nodeSizes[transition.from] ?? Size(nodeWidth, nodeHeight);
      final toPos = nodePositions[transition.to] ?? toNode.position;
      final toSize = nodeSizes[transition.to] ?? Size(nodeWidth, nodeHeight);

      final p1 = fromPos + Offset(fromSize.width / 2, fromSize.height / 2);
      final p2 = toPos + Offset(toSize.width / 2, toSize.height / 2);

      // Check if this connection is the active transition path
      final isTransitionPath = (transition.from == fromNodeId && transition.to == toNodeId);
      final isActiveStateTarget = (transition.to == activeStateId);

      final path = _getBezierPath(p1, p2);

      // Draw shadow or glow path
      if (isTransitionPath) {
        canvas.drawPath(
          path,
          Paint()
            ..color = toNode.color.withOpacity(0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round,
        );
      }

      // Draw connection line
      final paint = Paint()
        ..color = isTransitionPath
            ? Color.lerp(fromNode.color, toNode.color, transitionProgress)!.withOpacity(0.7)
            : (isActiveStateTarget ? toNode.color.withOpacity(0.3) : Colors.white10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTransitionPath ? 2.5 : 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, paint);

      // Draw direction arrow along the curve
      _paintArrowOnPath(canvas, path, isTransitionPath ? toNode.color : Colors.white24);
    }

    // 3. Draw animated transition particle dynamically centered on custom node boundaries
    if (fromNodeId != null && toNodeId != null && transitionProgress < 1.0) {
      final fromNode = config.getNode(fromNodeId!);
      final toNode = config.getNode(toNodeId!);
      if (fromNode != null && toNode != null) {
        final fromPos = nodePositions[fromNodeId!] ?? fromNode.position;
        final fromSize = nodeSizes[fromNodeId!] ?? Size(nodeWidth, nodeHeight);
        final toPos = nodePositions[toNodeId!] ?? toNode.position;
        final toSize = nodeSizes[toNodeId!] ?? Size(nodeWidth, nodeHeight);

        final p1 = fromPos + Offset(fromSize.width / 2, fromSize.height / 2);
        final p2 = toPos + Offset(toSize.width / 2, toSize.height / 2);

        final path = _getBezierPath(p1, p2);
        _paintParticleOnPath(canvas, path, transitionProgress, toNode.color);
      }
    }
  }

  Path _getBezierPath(Offset p1, Offset p2) {
    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    final dx = (p2.dx - p1.dx).abs();
    final dy = (p2.dy - p1.dy).abs();

    if (dx > dy) {
      // Draw horizontal-centric S-curve
      final controlOffset = dx * 0.5;
      path.cubicTo(
        p1.dx + (p2.dx > p1.dx ? controlOffset : -controlOffset),
        p1.dy,
        p2.dx - (p2.dx > p1.dx ? controlOffset : -controlOffset),
        p2.dy,
        p2.dx,
        p2.dy,
      );
    } else {
      // Draw vertical-centric S-curve
      final controlOffset = dy * 0.5;
      path.cubicTo(
        p1.dx,
        p1.dy + (p2.dy > p1.dy ? controlOffset : -controlOffset),
        p2.dx,
        p2.dy - (p2.dy > p1.dy ? controlOffset : -controlOffset),
        p2.dx,
        p2.dy,
      );
    }
    return path;
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1.0;

    const spacing = 30.0;
    
    // Draw columns across a large region to prevent grid from ending when panning
    for (double x = -2000; x < size.width + 2000; x += spacing) {
      canvas.drawLine(Offset(x, -2000), Offset(x, size.height + 2000), paint);
    }
    
    // Draw rows across a large region
    for (double y = -2000; y < size.height + 2000; y += spacing) {
      canvas.drawLine(Offset(-2000, y), Offset(size.width + 2000, y), paint);
    }
  }

  void _paintArrowOnPath(Canvas canvas, Path path, Color color) {
    final metricsList = path.computeMetrics().toList();
    if (metricsList.isEmpty) return;

    final metric = metricsList.first;
    // Put arrow in the middle of the connector path
    final offset = metric.length * 0.52; 
    final tangent = metric.getTangentForOffset(offset);

    if (tangent != null) {
      final angle = tangent.angle;
      final pos = tangent.position;

      final arrowPath = Path();
      const arrowSize = 6.0;

      arrowPath.moveTo(-arrowSize, -arrowSize * 0.7);
      arrowPath.lineTo(0, 0);
      arrowPath.lineTo(-arrowSize, arrowSize * 0.7);
      arrowPath.close();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      canvas.drawPath(
        arrowPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }
  }

  void _paintParticleOnPath(
      Canvas canvas, Path path, double t, Color color) {
    final metricsList = path.computeMetrics().toList();
    if (metricsList.isEmpty) return;

    final metric = metricsList.first;
    final offset = metric.length * t;
    final tangent = metric.getTangentForOffset(offset);

    if (tangent != null) {
      final pos = tangent.position;
      
      // Draw outer pulse glow
      canvas.drawCircle(
        pos,
        6.0,
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Draw solid particle core
      canvas.drawCircle(
        pos,
        3.0,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StateMachinePainter oldDelegate) {
    return oldDelegate.activeStateId != activeStateId ||
        oldDelegate.fromNodeId != fromNodeId ||
        oldDelegate.toNodeId != toNodeId ||
        oldDelegate.transitionProgress != transitionProgress ||
        oldDelegate.nodePositions != nodePositions ||
        oldDelegate.nodeSizes != nodeSizes;
  }
}

/// Pulsing status indicator dot.
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 7 + (_pulseController.value * 3),
          height: 7 + (_pulseController.value * 3),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.4 + (_pulseController.value * 0.6)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4 * (1.0 - _pulseController.value)),
                blurRadius: 4.0 * _pulseController.value,
                spreadRadius: 2.0 * _pulseController.value,
              )
            ],
          ),
        );
      },
    );
  }
}
