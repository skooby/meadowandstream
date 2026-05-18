import 'package:flutter/material.dart';

class FlowNodeItem {
  final String id;
  String label;
  String type;
  Color? color;
  String? description;
  double? height;
  Map<String, dynamic>? metaData;
  List<String> connectedTo;

  FlowNodeItem({
    required this.id,
    required this.label,
    required this.type,
    this.color,
    this.description,
    this.height,
    this.metaData,
    List<String>? connectedTo,
  }) : connectedTo = connectedTo ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type,
    if (description != null) 'description': description,
    if (color != null) 'color': color!.value,
    if (height != null) 'height': height,
    if (metaData != null) 'metaData': metaData,
    'connectedTo': connectedTo,
  };

  factory FlowNodeItem.fromJson(Map<String, dynamic> json) {
    return FlowNodeItem(
      id: json['id'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      height: (json['height'] as num?)?.toDouble(),
      metaData: json['metaData'] as Map<String, dynamic>?,
      color: json['color'] != null ? Color(json['color'] as int) : null,
      connectedTo: (json['connectedTo'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }
}

class FlowNode {
  final String id;
  String title;
  String description;
  Offset position;
  double width;
  double? height;
  String type;
  String? groupId;
  Color? color;
  String? executionState; // 'queued', 'running', 'success', 'failed'
  Map<String, dynamic>? agentPayload;
  final List<String> connectedTo;
  final List<FlowNodeItem> items;

  FlowNode({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    this.width = 220,
    this.height,
    this.type = 'screen',
    this.groupId,
    this.color,
    this.executionState,
    this.agentPayload,
    List<String>? connectedTo,
    List<FlowNodeItem>? items,
  }) : connectedTo = connectedTo ?? [],
       items = items ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'x': position.dx,
    'y': position.dy,
    'w': width,
    'h': height,
    'type': type,
    'groupId': groupId,
    if (color != null) 'color': color!.value,
    if (executionState != null) 'executionState': executionState,
    if (agentPayload != null) 'agentPayload': agentPayload,
    'connectedTo': connectedTo,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory FlowNode.fromJson(Map<String, dynamic> json) {
    return FlowNode(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      position: Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble()),
      width: (json['w'] as num?)?.toDouble() ?? 220.0,
      height: (json['h'] as num?)?.toDouble(),
      type: (json['type'] as String?) ?? 'screen',
      groupId: json['groupId'] as String?,
      color: json['color'] != null ? Color(json['color'] as int) : null,
      executionState: json['executionState'] as String?,
      agentPayload: json['agentPayload'] as Map<String, dynamic>?,
      connectedTo: (json['connectedTo'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      items: (json['items'] as List<dynamic>?)?.map((e) => FlowNodeItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class FlowGroup {
  final String id;
  String label;
  String? description;
  Color? color;
  FlowGroup({
    required this.id, 
    required this.label, 
    this.description,
    this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (description != null) 'description': description,
    if (color != null) 'color': color!.value,
  };

  factory FlowGroup.fromJson(Map<String, dynamic> json) {
    return FlowGroup(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      color: json['color'] != null ? Color(json['color'] as int) : null,
    );
  }
}
