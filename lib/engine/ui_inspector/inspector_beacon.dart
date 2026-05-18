import 'package:flutter/material.dart';
import 'ui_inspector_overlay.dart';

class InspectorBeacon extends StatefulWidget {
  final String id;
  final Widget child;

  const InspectorBeacon({super.key, required this.id, required this.child});

  @override
  State<InspectorBeacon> createState() => _InspectorBeaconState();
}

class _InspectorBeaconState extends State<InspectorBeacon> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the RenderBox exists before resolving
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
           UiInspectorController.registerBeacon(widget.id, _key);
       }
    });
  }

  @override
  void dispose() {
    UiInspectorController.unregisterBeacon(widget.id);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InspectorBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      UiInspectorController.unregisterBeacon(oldWidget.id);
      UiInspectorController.registerBeacon(widget.id, _key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
