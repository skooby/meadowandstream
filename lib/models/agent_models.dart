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

  AgentNode copyWith({
    String? id,
    String? title,
    String? description,
    String? prompt,
    int? color,
    int? iconCodePoint,
    List<AgentNode>? children,
  }) {
    return AgentNode(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      prompt: prompt ?? this.prompt,
      color: color ?? this.color,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      children: children ?? this.children,
    );
  }

  @override
  String toString() => 'AgentNode(id: $id, title: $title, description: $description, prompt: $prompt, color: $color, iconCodePoint: $iconCodePoint, children: ${children.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgentNode &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.prompt == prompt &&
        other.color == color &&
        other.iconCodePoint == iconCodePoint &&
        listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(id, title, description, prompt, color, iconCodePoint, Object.hashAll(children));

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
