import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class CustomControlType {
  final String id;
  String label;
  IconData icon;
  List<String> constraintKeys;
  String? parentType;

  CustomControlType({
    required this.id,
    required this.label,
    required this.icon,
    this.constraintKeys = const [],
    this.parentType,
  });

  CustomControlType copyWith({
    String? id,
    String? label,
    IconData? icon,
    List<String>? constraintKeys,
    String? parentType,
  }) {
    return CustomControlType(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      constraintKeys: constraintKeys ?? this.constraintKeys,
      parentType: parentType ?? this.parentType,
    );
  }

  @override
  String toString() => 'CustomControlType(id: $id, label: $label, icon: $icon, constraintKeys: $constraintKeys, parentType: $parentType)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomControlType &&
        other.id == id &&
        other.label == label &&
        other.icon == icon &&
        listEquals(other.constraintKeys, constraintKeys) &&
        other.parentType == parentType;
  }

  @override
  int get hashCode => Object.hash(id, label, icon, Object.hashAll(constraintKeys), parentType);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': icon.codePoint,
    'fontFamily': icon.fontFamily,
    'fontPackage': icon.fontPackage,
    'constraintKeys': constraintKeys,
    'parentType': parentType,
  };

  factory CustomControlType.fromJson(Map<String, dynamic> json) {
    return CustomControlType(
      id: json['id'] as String,
      label: json['label'] as String,
      icon: IconData(
        json['icon'] as int,
        fontFamily: json['fontFamily'] as String?,
        fontPackage: json['fontPackage'] as String?,
      ),
      constraintKeys: List<String>.from(json['constraintKeys'] ?? []),
      parentType: json['parentType'] as String?,
    );
  }
}
