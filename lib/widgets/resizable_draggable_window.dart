import 'package:flutter/material.dart';
import '../constants.dart';

class FloatingWindowManager {
  static final Map<String, OverlayEntry> _overlays = {};

  static void showWindow(BuildContext context, {
    required String id,
    required Widget title,
    required Widget child,
    double initialWidth = 400,
    double initialHeight = 500,
    VoidCallback? onClose,
  }) {
    if (_overlays.containsKey(id)) {
      return; // Already open
    }

    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => ResizableDraggableWindow(
        title: title,
        initialWidth: initialWidth,
        initialHeight: initialHeight,
        onClose: () {
          _overlays.remove(id);
          overlayEntry.remove();
          if (onClose != null) onClose();
        },
        child: child,
      ),
    );

    _overlays[id] = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
  }

  static void closeWindow(String id) {
    if (_overlays.containsKey(id)) {
      _overlays[id]!.remove();
      _overlays.remove(id);
    }
  }
}

class ResizableDraggableWindow extends StatefulWidget {
  final Widget title;
  final Widget child;
  final double initialWidth;
  final double initialHeight;
  final VoidCallback onClose;

  const ResizableDraggableWindow({
    Key? key,
    required this.title,
    required this.child,
    required this.onClose,
    this.initialWidth = 400,
    this.initialHeight = 500,
  }) : super(key: key);

  @override
  State<ResizableDraggableWindow> createState() => _ResizableDraggableWindowState();
}

class _ResizableDraggableWindowState extends State<ResizableDraggableWindow> {
  Offset _position = const Offset(100, 100);
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
    _height = widget.initialHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      width: _width,
      height: _height,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
        color: AppColors.panelBackground,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: AppUIConfig.windowBorderWidth),
            borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
          ),
          child: Column(
            children: [
              // Header
              MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _position += details.delta;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: widget.title),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Body
              Expanded(
                child: Stack(
                  children: [
                    widget.child,
                    // Resize Handle
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpLeftDownRight,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _width = (_width + details.delta.dx).clamp(200.0, 1200.0);
                              _height = (_height + details.delta.dy).clamp(200.0, 1200.0);
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            color: Colors.transparent,
                            child: CustomPaint(
                              painter: _ResizeHandlePainter(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResizeHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(size.width - 6, size.height - 2), Offset(size.width - 2, size.height - 6), paint);
    canvas.drawLine(Offset(size.width - 10, size.height - 2), Offset(size.width - 2, size.height - 10), paint);
    canvas.drawLine(Offset(size.width - 14, size.height - 2), Offset(size.width - 2, size.height - 14), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
