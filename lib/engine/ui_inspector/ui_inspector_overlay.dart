import 'package:music_app/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scene_graph_walker.dart';

/// Global controller to bind the Side Panel Inspector with the Full Screen Overlay
class UiInspectorController {
  static final ValueNotifier<SceneNode?> rootGraph = ValueNotifier(null);
  static final ValueNotifier<bool> isInspecting = ValueNotifier(false);
  static final ValueNotifier<bool> isFrozen = ValueNotifier(false);
  static final ValueNotifier<SceneNode?> hoveredNode = ValueNotifier(null);
  static final ValueNotifier<List<SceneNode>> hoveredZStack = ValueNotifier([]);
  static final ValueNotifier<SceneNode?> selectedNode = ValueNotifier(null);

  // --- Active Beacon Telemetry ---
  static final ValueNotifier<Map<String, GlobalKey>> activeBeacons = ValueNotifier({});

  static void registerBeacon(String id, GlobalKey key) {
    activeBeacons.value = Map.from(activeBeacons.value)..[id] = key;
  }

  static void unregisterBeacon(String id) {
    activeBeacons.value = Map.from(activeBeacons.value)..remove(id);
  }

  static void refreshGraph(BuildContext simulatedContext) {
    rootGraph.value = SceneGraphWalker.buildGraph(simulatedContext);
  }

  static List<SceneNode> hitTestAll(Offset globalPos) {
    final root = rootGraph.value;
    if (root == null) return [];

    List<SceneNode> hits = [];

    void walk(SceneNode node) {
      if (node.bounds != null && node.bounds!.contains(globalPos)) {
        hits.add(node);
      }
      for (var child in node.children) {
        walk(child);
      }
    }

    walk(root);

    // Sort by smallest area first
    hits.sort((a, b) {
      final areaA = (a.bounds?.width ?? 0) * (a.bounds?.height ?? 0);
      final areaB = (b.bounds?.width ?? 0) * (b.bounds?.height ?? 0);
      return areaA.compareTo(areaB);
    });

    // Condense visually identical bounding layers organically!
    // A Flutter tree often stacks `Padding -> SizedBox -> ConstrainedBox -> Button`
    // all sharing the identical geometry which clogs the manual picker menu.
    List<SceneNode> condensedHits = [];
    for (var node in hits) {
        if (condensedHits.isEmpty) {
            condensedHits.add(node);
            continue;
        }
        
        final last = condensedHits.last;
        if (last.bounds != null && node.bounds != null) {
            // Check if bounds vividly overlap perfectly (within 1 logical pixel constraint)
            if ((last.bounds!.width - node.bounds!.width).abs() < 1.0 &&
                (last.bounds!.height - node.bounds!.height).abs() < 1.0 &&
                (last.bounds!.left - node.bounds!.left).abs() < 1.0 &&
                (last.bounds!.top - node.bounds!.top).abs() < 1.0) {
                
                // Wrap the parent into the child's naming convention syntactically
                final combinedName = "${node.name} > ${last.name.split(' > ').first}";
                // Replace the last element maintaining the child's raw pointer ID for context mapping
                // Merge properties and retain raw children for pipeline semantic extraction
                final combinedProps = Map<String, dynamic>.from(node.properties)..addAll(last.properties);
                
                condensedHits[condensedHits.length - 1] = SceneNode(
                    name: combinedName, 
                    id: last.id, // Keeping the deepest leaf node ID for the AI to bind onto
                    bounds: last.bounds, 
                    children: [...last.children, ...node.children], // Preserve physical semantic hierarchy!
                    properties: combinedProps
                );
                continue;
            }
        }
        condensedHits.add(node);
    }

    return condensedHits;
  }
}

/// A full-screen hit-testing layer mapping geometric render rectangles
class UiInspectorOverlay extends StatefulWidget {
  const UiInspectorOverlay({super.key});

  @override
  State<UiInspectorOverlay> createState() => _UiInspectorOverlayState();
}

class _UiInspectorOverlayState extends State<UiInspectorOverlay> {

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_keyHandler);
    UiInspectorController.isInspecting.addListener(_onInspectToggled);
  }

  void _onInspectToggled() {
      if (!UiInspectorController.isInspecting.value) {
          UiInspectorController.isFrozen.value = false;
      }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    UiInspectorController.isInspecting.removeListener(_onInspectToggled);
    super.dispose();
  }

  bool _keyHandler(KeyEvent event) {
    if (UiInspectorController.isInspecting.value && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
       UiInspectorController.isFrozen.value = !UiInspectorController.isFrozen.value;
       // We do not physically block the escape event since it might be needed for closing other menus, 
       // but we inherently intercept the tracker here locally
       return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: UiInspectorController.isInspecting,
      builder: (context, isInspecting, _) {
        if (!isInspecting) return const SizedBox.shrink();

         return MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (event) {
            if (UiInspectorController.isFrozen.value) return;
            final hits = UiInspectorController.hitTestAll(event.position);
            UiInspectorController.hoveredZStack.value = hits;
            UiInspectorController.hoveredNode.value = hits.firstOrNull;
          },
          onExit: (_) {
            if (UiInspectorController.isFrozen.value) return;
            UiInspectorController.hoveredZStack.value = [];
            UiInspectorController.hoveredNode.value = null;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent, // Allow catching taps over the whole canvas
            onTapUp: (details) {
              final hits = UiInspectorController.hitTestAll(details.globalPosition);
              if (hits.isNotEmpty) {
                 showMenu<SceneNode>(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    details.globalPosition.dx,
                    details.globalPosition.dy,
                    details.globalPosition.dx + 1,
                    details.globalPosition.dy + 1,
                  ),
                  items: hits.map((node) {
                     return PopupMenuItem<SceneNode>(
                       value: node,
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(node.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                             if (node.properties['text'] != null)
                                Text("Text: '${node.properties['text']}'", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                             if (node.properties['tooltip'] != null)
                                Text("Tooltip: '${node.properties['tooltip']}'", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ]
                       )
                     );
                  }).toList(),
                ).then((picked) {
                   if (picked != null) {
                     UiInspectorController.selectedNode.value = picked;
                     UiInspectorController.isInspecting.value = false;
                   }
                });
              }
            },
            child: Builder(
              builder: (context) {
                return SizedBox.expand(
                  child: ValueListenableBuilder<SceneNode?>(
                    valueListenable: UiInspectorController.hoveredNode,
                    builder: (context, node, _) {
                      if (node == null || node.bounds == null) return const SizedBox.shrink();

                      Rect localBounds = node.bounds!;
                      final renderObj = context.findRenderObject();
                      if (renderObj is RenderBox) {
                        try {
                           final localTopLeft = renderObj.globalToLocal(localBounds.topLeft);
                           final localBottomRight = renderObj.globalToLocal(localBounds.bottomRight);
                           localBounds = Rect.fromPoints(localTopLeft, localBottomRight);
                        } catch(e) {
                          // Fallback to strict bounds if layout isn't established yet
                        }
                      }

                      return CustomPaint(
                        painter: _InspectorBoundsPainter(localBounds, node.name),
                      );
                    },
                  ),
                );
              }
            ),
          ),
        );
      },
    );
  }
}

class _InspectorBoundsPainter extends CustomPainter {
  final Rect bounds;
  final String label;

  _InspectorBoundsPainter(this.bounds, this.label);

  @override
  void paint(Canvas canvas, Size size) {
    // Determine screen boundary cuts in case element bleeds
    final paintObj = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(bounds, paintObj);
    canvas.drawRect(bounds, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: AppColors.accent, // Tag backdrop
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    
    // Draw label safely above the top left bound
    double textY = bounds.top - textPainter.height;
    if (textY < 0.0) textY = bounds.top; // prevent screen bleed
    
    // Fill the text background explicitly for contrast
    canvas.drawRect(
      Rect.fromLTWH(bounds.left, textY, textPainter.width + 4, textPainter.height),
      Paint()..color = AppColors.accent
    );

    textPainter.paint(canvas, Offset(bounds.left + 2, textY));
  }

  @override
  bool shouldRepaint(covariant _InspectorBoundsPainter old) {
    return bounds != old.bounds || label != old.label;
  }
}
