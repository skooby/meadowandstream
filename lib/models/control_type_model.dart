import 'package:flutter/material.dart';

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
