import 'package:flutter/foundation.dart';

class AgentNode {
  String id;
  String title;
  String description;
  String prompt;
  int? color;
  int? iconCodePoint;
  List<AgentNode> children;

  AgentNode({
    required this.id,
    required this.title,
    this.description = '',
    this.prompt = '',
    this.color,
    this.iconCodePoint,
    this.children = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'prompt': prompt,
    if (color != null) 'color': color,
    if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
    'children': children.map((e) => e.toJson()).toList(),
  };

  factory AgentNode.fromJson(Map<String, dynamic> json) => AgentNode(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    prompt: json['prompt'] as String? ?? '',
    color: json['color'] as int?,
    iconCodePoint: json['iconCodePoint'] as int?,
    children: (json['children'] as List<dynamic>?)?.map((e) => AgentNode.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class AgentClipboard {
  static AgentNode? copiedAgent;
  static final ValueNotifier<AgentNode?> copiedAgentNotifier = ValueNotifier(null);

  static void copy(AgentNode node) {
    copiedAgent = node;
    copiedAgentNotifier.value = node;
  }
}
