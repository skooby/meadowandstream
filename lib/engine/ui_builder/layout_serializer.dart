import 'package:flutter/material.dart';

/// Decodes an agnostic JSON string into a completely domain-free runtime memory Widget Tree structurally.
class LayoutSerializer {
  static Widget buildFromJson(Map<String, dynamic> json, {bool editMode = false, Function(String)? onSelectNode}) {
    if (json.isEmpty) return const SizedBox.shrink();

    final String type = json['type'] ?? 'SizedBox';
    final String id = json['id'] ?? UniqueKey().toString();
    final Map<String, dynamic> props = json['properties'] ?? {};
    final dynamic rawChild = json['child'];
    final dynamic rawChildren = json['children'];

    Widget? childWidget;
    if (rawChild != null && rawChild is Map<String, dynamic>) {
      childWidget = buildFromJson(rawChild, editMode: editMode, onSelectNode: onSelectNode);
    }
    
    List<Widget> childrenWidgets = [];
    if (rawChildren != null && rawChildren is List) {
      childrenWidgets = rawChildren.map((c) => buildFromJson(c as Map<String, dynamic>, editMode: editMode, onSelectNode: onSelectNode)).toList();
    }

    Widget result;
    switch (type) {
      case 'Container':
        result = Container(
          width: _parseDouble(props['width']),
          height: _parseDouble(props['height']),
          color: _parseColor(props['color']),
          child: childWidget,
        );
        break;
      case 'SizedBox':
        result = SizedBox(
           width: _parseDouble(props['width']),
           height: _parseDouble(props['height']),
           child: childWidget,
        );
        break;
      case 'Text':
        result = Text(
          props['text']?.toString() ?? '',
          style: TextStyle(
            color: _parseColor(props['color']),
            fontSize: _parseDouble(props['fontSize']),
          ),
        );
        break;
      case 'Column':
        result = Column(
          mainAxisAlignment: _parseMainAxisAlignment(props['mainAxisAlignment']),
          crossAxisAlignment: _parseCrossAxisAlignment(props['crossAxisAlignment']),
          children: childrenWidgets,
        );
        break;
      case 'Row':
        result = Row(
          mainAxisAlignment: _parseMainAxisAlignment(props['mainAxisAlignment']),
          crossAxisAlignment: _parseCrossAxisAlignment(props['crossAxisAlignment']),
          children: childrenWidgets,
        );
        break;
      case 'Stack':
        result = Stack(children: childrenWidgets);
        break;
      case 'Positioned':
        result = Positioned(
          left: _parseDouble(props['left']),
          top: _parseDouble(props['top']),
          right: _parseDouble(props['right']),
          bottom: _parseDouble(props['bottom']),
          child: childWidget ?? const SizedBox.shrink(),
        );
        break;
      default:
        result = const SizedBox.shrink();
        break;
    }

    if (editMode && onSelectNode != null) {
      if (type == 'Positioned') {
         // Cannot wrap Positioned in a GestureDetector directly because Positioned must be direct child of Stack.
         // Instead, wrap its *child*.
         return Positioned(
           left: _parseDouble(props['left']),
           top: _parseDouble(props['top']),
           right: _parseDouble(props['right']),
           bottom: _parseDouble(props['bottom']),
           child: _buildHitbox(childWidget ?? const SizedBox.shrink(), id, onSelectNode)
         );
      }
      return _buildHitbox(result, id, onSelectNode);
    }
    
    return result;
  }

  static Widget _buildHitbox(Widget child, String id, Function(String) onSelect) {
     return GestureDetector(
        onTap: () => onSelect(id),
        child: Container(
           decoration: BoxDecoration(
             border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 1.0, style: BorderStyle.solid)
           ),
           child: child,
        ),
     );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.startsWith('#')) {
        final hex = value.replaceAll('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
           return Color(int.parse(hex, radix: 16));
        }
      }
    }
    return null;
  }

  static MainAxisAlignment _parseMainAxisAlignment(dynamic value) {
     switch (value) {
       case 'center': return MainAxisAlignment.center;
       case 'spaceAround': return MainAxisAlignment.spaceAround;
       case 'spaceBetween': return MainAxisAlignment.spaceBetween;
       case 'spaceEvenly': return MainAxisAlignment.spaceEvenly;
       case 'end': return MainAxisAlignment.end;
       default: return MainAxisAlignment.start;
     }
  }

  static CrossAxisAlignment _parseCrossAxisAlignment(dynamic value) {
     switch (value) {
       case 'start': return CrossAxisAlignment.start;
       case 'end': return CrossAxisAlignment.end;
       case 'stretch': return CrossAxisAlignment.stretch;
       default: return CrossAxisAlignment.center;
     }
  }
}
