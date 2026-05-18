import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DraggableAlertDialog extends StatefulWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? titleBackgroundColor;

  const DraggableAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
    this.titleBackgroundColor,
  });

  @override
  State<DraggableAlertDialog> createState() => _DraggableAlertDialogState();
}

class _DraggableAlertDialogState extends State<DraggableAlertDialog> {
  Offset _dialogOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _dialogOffset,
      child: AlertDialog(
        backgroundColor: widget.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        titlePadding: const EdgeInsets.all(0),
        title: widget.title != null
            ? MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final delta = details.delta;
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _dialogOffset += delta);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 8, 16),
                    decoration: BoxDecoration(
                      color: widget.titleBackgroundColor ?? Colors.transparent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: widget.title!),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
        content: widget.content,
        actions: widget.actions,
      ),
    );
  }
}

class DialogDragWrapper extends StatefulWidget {
  final Widget child;

  const DialogDragWrapper({super.key, required this.child});

  @override
  State<DialogDragWrapper> createState() => _DialogDragWrapperState();
}

class _DialogDragWrapperState extends State<DialogDragWrapper> {
  Offset _dialogOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _dialogOffset,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 48,
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final delta = details.delta;
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _dialogOffset += delta);
                  });
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
