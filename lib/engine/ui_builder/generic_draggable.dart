import 'package:flutter/material.dart';

/// A wrapper widget that allows any generic child component to become draggable
/// within an agnostic workspace.
class EngineDraggable extends StatefulWidget {
  final Widget child;
  final String componentId;
  final Offset initialPosition;
  final Function(Offset newPosition)? onDragEnd;

  const EngineDraggable({
    Key? key,
    required this.child,
    required this.componentId,
    this.initialPosition = Offset.zero,
    this.onDragEnd,
  }) : super(key: key);

  @override
  State<EngineDraggable> createState() => _EngineDraggableState();
}

class _EngineDraggableState extends State<EngineDraggable> {
  late Offset _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentPosition.dx,
      top: _currentPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _currentPosition += details.delta;
          });
        },
        onPanEnd: (details) {
          if (widget.onDragEnd != null) {
            widget.onDragEnd!(_currentPosition);
          }
        },
        child: widget.child,
      ),
    );
  }
}
