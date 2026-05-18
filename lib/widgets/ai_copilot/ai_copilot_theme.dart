import 'package:flutter/material.dart';

class AiCopilotTheme {
  final Color background;
  final Color panelBackground;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color danger;
  final double cornerRadius;
  final double rootFontSize;
  final double smallFontSize;
  final double headerFontSize;
  final bool parentLabelsUppercase;
  final bool parentLabelsBold;
  final bool childLabelsUppercase;
  final bool childLabelsBold;

  const AiCopilotTheme({
    this.background = const Color(0xFF1E1E1E),
    this.panelBackground = const Color(0xFF252526),
    this.borderSubtle = const Color(0xFF333333),
    this.textPrimary = const Color(0xFFE0E0E0),
    this.textSecondary = const Color(0xFFAAAAAA),
    this.textMuted = const Color(0xFF757575),
    this.accent = const Color(0xFF007ACC),
    this.danger = const Color(0xFFF44336),
    this.cornerRadius = 8.0,
    this.rootFontSize = 14.0,
    this.smallFontSize = 12.0,
    this.headerFontSize = 18.0,
    this.parentLabelsUppercase = true,
    this.parentLabelsBold = true,
    this.childLabelsUppercase = false,
    this.childLabelsBold = false,
  });
}
