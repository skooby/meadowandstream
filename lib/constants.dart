import 'package:music_app/constants.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum LyricsStyle { standard, typewriter }

enum LyricEffect { none, flicker, colorize }

enum ParticleType {
  none,
  snow,
  stars,
  confetti,
  fireflies,
  smoke,
}

enum VisualizerType {
  none,
  bar,
  circular,
  line,
  multiWave,
  rainbow,
}

enum AudioVisualizerMode {
  standard,
  bass,
  vocals,
  beat,
}

enum AudioVisualizerColorStyle {
  solid,
  gradient,
  rainbow,
}

enum EasingMethod {
  linear,
  easeInOut,
  easeIn,
  easeOut,
  elasticIn,
  elasticOut,
  elasticInOut,
  bounceIn,
  bounceOut,
  bounceInOut,
}

/// Centralized colors for the application.
enum DevTheme { dark, light, dracula }

class AppColors {
  // Global Base Colors
  static const Color accentLight = Color(0xFFE94560);
  static const Color accentDark = Color(0xFFE94560);
  static const Color accentDracula = Color(0xFFFF79C6);

  static const Color backgroundLight = Color(0xFFF0F2F5);
  static const Color backgroundDark = Color(0xFF1E1E2C);
  static const Color backgroundDracula = Color(0xFF282A36);

  static const Color titleBarBackgroundLight = Color(0xFFE4E6EB);
  static const Color titleBarBackgroundDark = Color(0xFF181824);
  static const Color titleBarBackgroundDracula = Color(0xFF21222C);

  static const Color windowBackgroundLight = Color(0xFFFFFFFF);
  static const Color windowBackgroundDark = Color(0xFF2A2A3D);
  static const Color windowBackgroundDracula = Color(0xFF282A36);

  static const Color toolbarBackgroundLight = Color(0xFFF8F9FA);
  static const Color toolbarBackgroundDark = Color(0xFF252536);
  static const Color toolbarBackgroundDracula = Color(0xFF44475A);

  static const Color panelBackgroundLight = Color(0xFFF0F2F5);
  static const Color panelBackgroundDark = Color(0xFF32324A);
  static const Color panelBackgroundDracula = Color(0xFF6272A4);

  static const Color borderLight = Color(0xFFDADCE0);
  static const Color borderDark = Color(0xFF3E3E5C);
  static const Color borderDracula = Color(0xFF44475A);

  static const Color textPrimaryLight = Color(0xFF202124);
  static const Color textPrimaryDark = Color(0xFFF8F8F2);
  static const Color textPrimaryDracula = Color(0xFFF8F8F2);

  static const Color textSecondaryLight = Color(0xFF5F6368);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
  static const Color textSecondaryDracula = Color(0xFF8BE9FD);

  static const Color textMutedLight = Color(0xFF80868B);
  static const Color textMutedDark = Color(0xFF6B7280);
  static const Color textMutedDracula = Color(0xFF6272A4);

  static const Color borderSubtleLight = Color(0xFFE0E0E0);
  static const Color borderSubtleDark = Color(0xFF424242);
  static const Color borderSubtleDracula = Color(0xFF44475A);

  static const Color overlaySubtleLight = Color(0x0A000000);
  static const Color overlaySubtleDark = Color(0x0AFFFFFF);
  static const Color overlaySubtleDracula = Color(0x1AFFFFFF);

  static const Color folderLight = Color(0xFFFFB300);
  static const Color folderDark = Color(0xFFFFD54F);
  static const Color folderDracula = Color(0xFFF1FA8C);

  static const Color activeTaskHighlightLight = Color(0xFFE3F2FD); // Light blue for light theme
  static const Color activeTaskHighlightDark = Color(0xFF1E3A8A); // Deep blue for dark theme
  static const Color activeTaskHighlightDracula = Color(0xFF383A59); // Dracula deep purple

  static const Color summaryLight = Color(0xFF4CAF50);
  static const Color summaryDark = Color(0xFF81C784);
  static const Color summaryDracula = Color(0xFF50FA7B);

  // Dynamic getters based on AppUIConfig.activeTheme
  static Color get background =>
      Color(AppUIConfig.activeTheme?.desktopColor ?? backgroundDark.value);
  static Color get titleBarBackground => Color(
      AppUIConfig.activeTheme?.titleBarColor ?? titleBarBackgroundDark.value);
  static Color get windowBackground =>
      Color(AppUIConfig.activeTheme?.windowColor ?? windowBackgroundDark.value);
  static Color get toolbarBackground => Color(
      AppUIConfig.activeTheme?.toolbarColor ?? toolbarBackgroundDark.value);
  static Color get panelBackground =>
      Color(AppUIConfig.activeTheme?.panelColor ?? panelBackgroundDark.value);

  static Color get border {
    if (AppUIConfig.activeTheme?.windowBorderColor != null) {
      return Color(AppUIConfig.activeTheme!.windowBorderColor!);
    }
    return borderDark;
  }

  static Color get controlBorder {
    if (AppUIConfig.activeTheme?.controlBorderColor != null) {
      return Color(AppUIConfig.activeTheme!.controlBorderColor!);
    }
    return border;
  }

  static Color get activeWindowBorder {
    if (AppUIConfig.activeTheme?.activeWindowBorderColor != null) {
      return Color(AppUIConfig.activeTheme!.activeWindowBorderColor!);
    }
    return accent;
  }

  // Adaptive getters
  static Color getAdaptiveDynamic(Color background, Color baseColor) {
    final isLight = background.computeLuminance() > 0.5;
    if (baseColor == Colors.greenAccent || baseColor == Colors.green)
      return isLight ? Colors.green.shade700 : Colors.greenAccent;
    if (baseColor == Colors.redAccent || baseColor == Colors.red)
      return isLight ? Colors.red.shade700 : Colors.redAccent;
    if (baseColor == Colors.amberAccent || baseColor == Colors.amber)
      return isLight ? Colors.amber.shade800 : Colors.amberAccent;
    if (baseColor == Colors.lightBlueAccent ||
        baseColor == Colors.blueAccent ||
        baseColor == Colors.blue)
      return isLight ? Colors.blue.shade700 : Colors.lightBlueAccent;
    if (baseColor == Colors.purpleAccent || baseColor == Colors.purple)
      return isLight ? Colors.purple.shade700 : Colors.purpleAccent;
    if (isLight) {
      final hsl = HSLColor.fromColor(baseColor);
      if (hsl.lightness > 0.4) return hsl.withLightness(0.35).toColor();
    } else {
      final hsl = HSLColor.fromColor(baseColor);
      if (hsl.lightness < 0.6) return hsl.withLightness(0.65).toColor();
    }
    return baseColor;
  }

  static Color getAdaptiveGreen(Color background) =>
      background.computeLuminance() > 0.5
          ? Colors.green.shade700
          : Colors.greenAccent;
  static Color getAdaptiveRed(Color background) =>
      background.computeLuminance() > 0.5
          ? Colors.red.shade700
          : Colors.redAccent;
  static Color getAdaptiveAmber(Color background) =>
      background.computeLuminance() > 0.5
          ? Colors.amber.shade800
          : Colors.amberAccent;
  static Color getAdaptiveBlue(Color background) =>
      background.computeLuminance() > 0.5
          ? Colors.blue.shade700
          : Colors.lightBlueAccent;
  static Color getAdaptivePurple(Color background) =>
      background.computeLuminance() > 0.5
          ? Colors.purple.shade700
          : Colors.purpleAccent;
  static Color getAdaptiveAccent(Color background) =>
      background.computeLuminance() > 0.5 ? accentLight : accentDark;

  static Color getContrastTextPrimary(Color background) =>
      background.computeLuminance() > 0.5 ? textPrimaryLight : textPrimaryDark;
  static Color getContrastTextSecondary(Color background) =>
      background.computeLuminance() > 0.5
          ? textSecondaryLight
          : textSecondaryDark;
  static Color getContrastIconMuted(Color background) =>
      background.computeLuminance() > 0.5
          ? borderSubtleLight
          : borderSubtleDark;

  static Color get titleBarTextPrimary =>
      getContrastTextPrimary(titleBarBackground);
  static Color get titleBarTextSecondary =>
      getContrastTextSecondary(titleBarBackground);
  static Color get toolbarTextPrimary =>
      getContrastTextPrimary(toolbarBackground);
  static Color get toolbarBorderSubtle =>
      getContrastIconMuted(toolbarBackground);
  static Color get toolbarTextSecondary =>
      getContrastTextSecondary(toolbarBackground);
  static Color get panelTextPrimary => getContrastTextPrimary(panelBackground);
  static Color get panelTextSecondary =>
      getContrastTextSecondary(panelBackground);

  static Color get textPrimary => getContrastTextPrimary(background);
  static const Color chipDark = Color(0xFF333344);
  static const Color chipLight = Color(0xFFE0E0E0);
  static const Color primaryDark = Color(0xFF1A1A24);
  static const Color cardDark = Color(0xFF282834);
  static const Color cardLight = Color(0xFFFFFFFF);
  static Color get textSecondary => getContrastTextSecondary(background);
  static Color get textMuted =>
      background.computeLuminance() > 0.5 ? textMutedLight : textMutedDark;
  static Color get borderSubtle => getContrastIconMuted(background);
  static Color get overlaySubtle => background.computeLuminance() > 0.5
      ? overlaySubtleLight
      : overlaySubtleDark;
  static Color get accent {
    if (AppUIConfig.activeTheme?.accentColor != null)
      return Color(AppUIConfig.activeTheme!.accentColor!);
    return getAdaptiveAccent(background);
  }

  static Color get iconMuted => getContrastIconMuted(background);
  static Color get folder =>
      background.computeLuminance() > 0.5 ? folderLight : folderDark;
  static Color get activeTaskHighlight {
    if (AppUIConfig.activeTheme?.activeTaskHighlightColor != null) {
      return Color(AppUIConfig.activeTheme!.activeTaskHighlightColor!);
    }
    return background.computeLuminance() > 0.5 ? activeTaskHighlightLight : activeTaskHighlightDark;
  }
  static Color get primary => accent;
  static Color get summary =>
      background.computeLuminance() > 0.5 ? summaryLight : summaryDark;
  static Color get note => background.computeLuminance() > 0.5
      ? Colors.blue.shade700
      : Colors.lightBlueAccent;
  static Color get error => background.computeLuminance() > 0.5
      ? Colors.red.shade700
      : Colors.redAccent;
}

class AppFonts {
  static const String main = 'Inter';
  static const String head = 'Inter';
  static const String monospaced = 'RobotoMono';
}

class AppDimensions {
  static const double cornerRadius = 8.0;
  static const double cardBorderRadius = 8.0;
  static const double chipBorderRadius = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double miniBarBorderRadius = 4.0;
  static const double miniBarImageSize = 48.0;
}

class AppDebugConfig {
  static const bool enableChoreographyLogs = false;
  static const bool debugMode = true;
  static const bool enableNetworkLogs = false;
}

class AppStrings {
  static const String appName = 'Music App';
  static const String appTitle = 'Music App';
  static const String screenInspire = 'Inspire';
  static const String screenCheer = 'Cheer';
  static const String devModeWarning = 'Developer Mode Active';
  static const String mockItemDescription = 'Loading data...';
  static const String screenListen = 'Listen';
}

class AppLyricsConfig {
  static const int defaultLineMode = 0;
  static const double strokeWidth = 1.5;
  static const Color strokeColor = Colors.black;
  static const double activeFontSize = 24.0;
  static const double inactiveFontSize = 18.0;
  static const bool useWordHighlightBackground = false;
  static const Color wordHighlightBackgroundTextColor = Colors.white;
  static const Color wordHighlightColor = Colors.blueAccent;
  static const Color fontColor = Colors.white;
  static const double wordNonHighlightFade = 0.5;
  static const double wordBackgroundOverhang = 4.0;
  static const Color wordHighlightBackgroundColor = Colors.blue;
  static const double surroundingLineFontSize = 16.0;
  static const Color backgroundColor = Colors.transparent;
  static const int typewriterCpm = 300;

  static const int maxLineLength = 50;
  static const int splitFallbackNextLineDiffMs = 1000;
  static const int maxStackedLines = 2;
  static const int defaultWordLeewayMs = 300;
  static const int minSilenceGapMs = 1000;
  static const int defaultLineLeewayMs = 500;
  static const int itemEndLeewayMs = 200;
  static const bool temporalLineSplitting = true;
  static const int minSplitEdgeChars = 5;
  static const int splitFallbackMaxDiffMs = 2000;
  static const String splitPunctuation = '.,;!?';
}

class CustomColorTheme {
  final String id;
  final String name;
  final int? desktopColor;
  final int? titleBarColor;
  final int? windowColor;
  final int? toolbarColor;
  final int? panelColor;
  final int? accentColor;
  final int? markupBackgroundColor;
  final int? markupHeaderColor;
  final int? markupBlockBackgroundColor;
  final int? markupInlineCodeColor;
  final int? markupCodeBlockBackgroundColor;
  final int? markupBlockTextColor;
  final int? markupInlineTextColor;
  final int? markupCodeBlockTextColor;
  final double? rootFontSize;
  final double? iconFontSize;
  final bool? iconFontBold;
  final double? globalActionIconSize;
  final double? windowBorderRadius;
  final double? toolWindowOpacity;

  final double? iconOutlineWidth;
  final double? textOutlineWidth;
  final int? outlineColor;
  final double? titleBarHeight;
  final double? windowBorderWidth;
  final int? windowBorderColor;
  final int? controlBorderColor;
  final int? activeWindowBorderColor;
  final int? activeTaskHighlightColor;
  final bool? windowTitleUppercase;
  final bool? windowTitleBold;

  CustomColorTheme({
    required this.id,
    required this.name,
    this.desktopColor,
    this.titleBarColor,
    this.windowColor,
    this.toolbarColor,
    this.panelColor,
    this.accentColor,
    this.markupBackgroundColor,
    this.markupHeaderColor,
    this.markupBlockBackgroundColor,
    this.markupInlineCodeColor,
    this.markupCodeBlockBackgroundColor,
    this.markupBlockTextColor,
    this.markupInlineTextColor,
    this.markupCodeBlockTextColor,
    this.rootFontSize,
    this.iconFontSize,
    this.iconFontBold,
    this.globalActionIconSize,
    this.windowBorderRadius,
    this.toolWindowOpacity,
    this.iconOutlineWidth,
    this.textOutlineWidth,
    this.outlineColor,
    this.titleBarHeight,
    this.windowBorderWidth,
    this.windowBorderColor,
    this.controlBorderColor,
    this.activeWindowBorderColor,
    this.activeTaskHighlightColor,
    this.windowTitleUppercase,
    this.windowTitleBold,
  });

  CustomColorTheme copyWith({
    String? id,
    String? name,
    int? desktopColor,
    int? titleBarColor,
    int? windowColor,
    int? toolbarColor,
    int? panelColor,
    int? accentColor,
    int? markupBackgroundColor,
    int? markupHeaderColor,
    int? markupBlockBackgroundColor,
    int? markupInlineCodeColor,
    int? markupCodeBlockBackgroundColor,
    int? markupBlockTextColor,
    int? markupInlineTextColor,
    int? markupCodeBlockTextColor,
    double? rootFontSize,
    double? iconFontSize,
    double? globalActionIconSize,
    bool? iconFontBold,
    double? windowBorderRadius,
    double? toolWindowOpacity,
    double? iconOutlineWidth,
    double? textOutlineWidth,
    int? outlineColor,
    double? titleBarHeight,
    double? windowBorderWidth,
    int? windowBorderColor,
    int? controlBorderColor,
    int? activeWindowBorderColor,
    int? activeTaskHighlightColor,
    bool? windowTitleUppercase,
    bool? windowTitleBold,
  }) {
    return CustomColorTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      desktopColor: desktopColor ?? this.desktopColor,
      titleBarColor: titleBarColor ?? this.titleBarColor,
      windowColor: windowColor ?? this.windowColor,
      toolbarColor: toolbarColor ?? this.toolbarColor,
      panelColor: panelColor ?? this.panelColor,
      accentColor: accentColor ?? this.accentColor,
      markupBackgroundColor:
          markupBackgroundColor ?? this.markupBackgroundColor,
      markupHeaderColor: markupHeaderColor ?? this.markupHeaderColor,
      markupBlockBackgroundColor:
          markupBlockBackgroundColor ?? this.markupBlockBackgroundColor,
      markupInlineCodeColor:
          markupInlineCodeColor ?? this.markupInlineCodeColor,
      markupCodeBlockBackgroundColor:
          markupCodeBlockBackgroundColor ?? this.markupCodeBlockBackgroundColor,
      markupBlockTextColor: markupBlockTextColor ?? this.markupBlockTextColor,
      markupInlineTextColor:
          markupInlineTextColor ?? this.markupInlineTextColor,
      markupCodeBlockTextColor:
          markupCodeBlockTextColor ?? this.markupCodeBlockTextColor,
      rootFontSize: rootFontSize ?? this.rootFontSize,
      iconFontSize: iconFontSize ?? this.iconFontSize,
      globalActionIconSize: globalActionIconSize ?? this.globalActionIconSize,
      iconFontBold: iconFontBold ?? this.iconFontBold,
      windowBorderRadius: windowBorderRadius ?? this.windowBorderRadius,
      toolWindowOpacity: toolWindowOpacity ?? this.toolWindowOpacity,
      iconOutlineWidth: iconOutlineWidth ?? this.iconOutlineWidth,
      textOutlineWidth: textOutlineWidth ?? this.textOutlineWidth,
      outlineColor: outlineColor ?? this.outlineColor,
      titleBarHeight: titleBarHeight ?? this.titleBarHeight,
      windowBorderWidth: windowBorderWidth ?? this.windowBorderWidth,
      windowBorderColor: windowBorderColor ?? this.windowBorderColor,
      controlBorderColor: controlBorderColor ?? this.controlBorderColor,
      activeWindowBorderColor:
          activeWindowBorderColor ?? this.activeWindowBorderColor,
      activeTaskHighlightColor:
          activeTaskHighlightColor ?? this.activeTaskHighlightColor,
      windowTitleUppercase: windowTitleUppercase ?? this.windowTitleUppercase,
      windowTitleBold: windowTitleBold ?? this.windowTitleBold,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desktopColor': desktopColor,
        'titleBarColor': titleBarColor,
        'windowColor': windowColor,
        'toolbarColor': toolbarColor,
        'panelColor': panelColor,
        'accentColor': accentColor,
        'markupBackgroundColor': markupBackgroundColor,
        'markupHeaderColor': markupHeaderColor,
        'markupBlockBackgroundColor': markupBlockBackgroundColor,
        'markupInlineCodeColor': markupInlineCodeColor,
        'markupCodeBlockBackgroundColor': markupCodeBlockBackgroundColor,
        'markupBlockTextColor': markupBlockTextColor,
        'markupInlineTextColor': markupInlineTextColor,
        'markupCodeBlockTextColor': markupCodeBlockTextColor,
        'rootFontSize': rootFontSize,
        'iconFontSize': iconFontSize,
        'iconFontBold': iconFontBold,
        'globalActionIconSize': globalActionIconSize,
        'windowBorderRadius': windowBorderRadius,
        'toolWindowOpacity': toolWindowOpacity,
        'iconOutlineWidth': iconOutlineWidth,
        'textOutlineWidth': textOutlineWidth,
        'outlineColor': outlineColor,
        'titleBarHeight': titleBarHeight,
        'windowBorderWidth': windowBorderWidth,
        'windowBorderColor': windowBorderColor,
        'controlBorderColor': controlBorderColor,
        'activeWindowBorderColor': activeWindowBorderColor,
        'activeTaskHighlightColor': activeTaskHighlightColor,
        'windowTitleUppercase': windowTitleUppercase,
        'windowTitleBold': windowTitleBold,
      };

  factory CustomColorTheme.fromJson(Map<String, dynamic> json) =>
      CustomColorTheme(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        desktopColor: json['desktopColor'],
        titleBarColor: json['titleBarColor'],
        windowColor: json['windowColor'],
        toolbarColor: json['toolbarColor'],
        panelColor: json['panelColor'],
        accentColor: json['accentColor'],
        markupBackgroundColor: json['markupBackgroundColor'],
        markupHeaderColor: json['markupHeaderColor'],
        markupBlockBackgroundColor: json['markupBlockBackgroundColor'],
        markupInlineCodeColor: json['markupInlineCodeColor'],
        markupCodeBlockBackgroundColor: json['markupCodeBlockBackgroundColor'],
        markupBlockTextColor: json['markupBlockTextColor'],
        markupInlineTextColor: json['markupInlineTextColor'],
        markupCodeBlockTextColor: json['markupCodeBlockTextColor'],
        rootFontSize: json['rootFontSize']?.toDouble(),
        iconFontSize: json['iconFontSize']?.toDouble(),
        iconFontBold: json['iconFontBold'],
        globalActionIconSize: json['globalActionIconSize']?.toDouble(),
        windowBorderRadius: json['windowBorderRadius']?.toDouble(),
        toolWindowOpacity: json['toolWindowOpacity']?.toDouble(),
        iconOutlineWidth: json['iconOutlineWidth']?.toDouble(),
        textOutlineWidth: json['textOutlineWidth']?.toDouble(),
        outlineColor: json['outlineColor'],
        titleBarHeight: json['titleBarHeight']?.toDouble(),
        windowBorderWidth: json['windowBorderWidth']?.toDouble(),
        windowBorderColor: json['windowBorderColor'],
        controlBorderColor: json['controlBorderColor'],
        activeWindowBorderColor: json['activeWindowBorderColor'],
        activeTaskHighlightColor: json['activeTaskHighlightColor'],
        windowTitleUppercase: json['windowTitleUppercase'],
        windowTitleBold: json['windowTitleBold'],
      );
}

class AppUIConfig {
  static CustomColorTheme? activeTheme;
  static List<CustomColorTheme> savedThemes = [];

  static double rootFontSize = 12.0;
  static double windowBorderRadius = 8.0;
  static double windowBorderWidth = 1.0;
  static double iconFontSize = 10.0;
  static bool iconFontBold = false;
  static double globalActionIconSize = 20.0;
  static double iconOutlineWidth = 1.5;
  static double textOutlineWidth = 1.0;
  static Color get outlineColor {
    if (activeTheme?.outlineColor != null) {
      return Color(activeTheme!.outlineColor!);
    }
    return Colors.black;
  }

  static Color get markupBackgroundColor =>
      activeTheme?.markupBackgroundColor != null
          ? Color(activeTheme!.markupBackgroundColor!)
          : Colors.transparent;

  static Color get markupHeaderColor => activeTheme?.markupHeaderColor != null
      ? Color(activeTheme!.markupHeaderColor!)
      : Colors.black;

  static Color get markupBlockBackgroundColor =>
      activeTheme?.markupBlockBackgroundColor != null
          ? Color(activeTheme!.markupBlockBackgroundColor!)
          : const Color(0xFFE3F2FD);

  static Color get markupInlineCodeColor =>
      activeTheme?.markupInlineCodeColor != null
          ? Color(activeTheme!.markupInlineCodeColor!)
          : const Color(0xFF3A3A4A);

  static Color get markupCodeBlockBackgroundColor =>
      activeTheme?.markupCodeBlockBackgroundColor != null
          ? Color(activeTheme!.markupCodeBlockBackgroundColor!)
          : const Color(0xFF1E1E2E);

  static Color get markupBlockTextColor =>
      activeTheme?.markupBlockTextColor != null
          ? Color(activeTheme!.markupBlockTextColor!)
          : Colors.black87;

  static Color get markupInlineTextColor =>
      activeTheme?.markupInlineTextColor != null
          ? Color(activeTheme!.markupInlineTextColor!)
          : Colors.white;

  static Color get markupCodeBlockTextColor =>
      activeTheme?.markupCodeBlockTextColor != null
          ? Color(activeTheme!.markupCodeBlockTextColor!)
          : Colors.white;
  static double titleBarHeight = 32.0;

  static Color? configIconColor;
  static int? configIconCodePoint;
  static Color? bridgeIconColor;
  static int? bridgeIconCodePoint;
  static Color? exitIconColor;
  static int? exitIconCodePoint;

  static Color? toolsIconColor;
  static int? toolsIconCodePoint;

  static Color? zoomInIconColor;
  static int? zoomInIconCodePoint;
  static Color? zoomOutIconColor;
  static int? zoomOutIconCodePoint;

  static Color? reloadIconColor;
  static int? reloadIconCodePoint;
  static Color? restartIconColor;
  static int? restartIconCodePoint;

  static List<Shadow> _buildStroke(double width, Color color) {
    if (width <= 0) return [];
    return [
      Shadow(offset: Offset(-width, -width), color: color),
      Shadow(offset: Offset(0, -width), color: color),
      Shadow(offset: Offset(width, -width), color: color),
      Shadow(offset: Offset(-width, 0), color: color),
      Shadow(offset: Offset(width, 0), color: color),
      Shadow(offset: Offset(-width, width), color: color),
      Shadow(offset: Offset(0, width), color: color),
      Shadow(offset: Offset(width, width), color: color),
    ];
  }

  static List<Shadow>? get textOutline => textOutlineWidth > 0
      ? _buildStroke(textOutlineWidth, outlineColor)
      : null;
  static List<Shadow>? get iconOutline => iconOutlineWidth > 0
      ? _buildStroke(iconOutlineWidth, outlineColor)
      : null;

  static double get windowTitleFontSize => rootFontSize * 1.2;
  static bool get windowTitleUppercase =>
      activeTheme?.windowTitleUppercase ?? true;
  static bool get windowTitleBold => activeTheme?.windowTitleBold ?? true;

  static String formatWindowTitle(String title) {
    return windowTitleUppercase ? title.toUpperCase() : title;
  }

  static FontWeight get windowTitleFontWeight =>
      windowTitleBold ? FontWeight.bold : FontWeight.normal;

  static double get smallFontSize => rootFontSize * 0.8;
  static double get folderFontSize => rootFontSize;
  static double get headerFontSize => rootFontSize * 1.2;

  static Future<void> loadCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('ve_customThemes');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        savedThemes = decoded.map((e) => CustomColorTheme.fromJson(e)).toList();
      } catch (_) {}
    }

    final activeId = prefs.getString('ve_activeThemeId');
    if (activeId != null && savedThemes.isNotEmpty) {
      try {
        activeTheme = savedThemes.firstWhere((t) => t.id == activeId);
      } catch (_) {
        activeTheme = savedThemes.first;
      }
    } else if (savedThemes.isNotEmpty) {
      activeTheme = savedThemes.first;
    }

    int? getIcon(String key) => prefs.getInt(key);
    Color? getColor(String key) {
      final val = prefs.getInt(key);
      return val != null ? Color(val) : null;
    }

    configIconCodePoint = getIcon('ve_configIconCodePoint');
    configIconColor = getColor('ve_configIconColor');
    bridgeIconCodePoint = getIcon('ve_bridgeIconCodePoint');
    bridgeIconColor = getColor('ve_bridgeIconColor');
    exitIconCodePoint = getIcon('ve_exitIconCodePoint');
    exitIconColor = getColor('ve_exitIconColor');
    toolsIconCodePoint = getIcon('ve_toolsIconCodePoint');
    toolsIconColor = getColor('ve_toolsIconColor');
    zoomInIconCodePoint = getIcon('ve_zoomInIconCodePoint');
    zoomInIconColor = getColor('ve_zoomInIconColor');
    zoomOutIconCodePoint = getIcon('ve_zoomOutIconCodePoint');
    zoomOutIconColor = getColor('ve_zoomOutIconColor');
    reloadIconCodePoint = getIcon('ve_reloadIconCodePoint');
    reloadIconColor = getColor('ve_reloadIconColor');
    restartIconCodePoint = getIcon('ve_restartIconCodePoint');
    restartIconColor = getColor('ve_restartIconColor');
  }

  static Future<void> saveCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final str = jsonEncode(savedThemes.map((e) => e.toJson()).toList());
    await prefs.setString('ve_customThemes', str);
  }
}

class ToolWindowDefinition {
  final String id;
  final IconData icon;
  final Color color;
  final String name;
  final String shortLabel;
  final String description;

  ToolWindowDefinition({
    required this.id,
    required this.icon,
    required this.color,
    required this.name,
    required this.shortLabel,
    this.description = '',
  });

  factory ToolWindowDefinition.fromJson(Map<String, dynamic> json) {
    return ToolWindowDefinition(
      id: json['id'] as String,
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
      color: Color(json['color'] as int),
      name: json['name'] as String,
      shortLabel: json['shortLabel'] as String,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'icon': icon.codePoint,
      'color': color.value,
      'name': name,
      'shortLabel': shortLabel,
      'description': description,
    };
  }
}

class AppToolWindows {
  static Map<String, bool> _visibleWindows = {};

  static final List<ToolWindowDefinition> initialDefaults = [
    ToolWindowDefinition(
        id: 'task_editor',
        icon: Icons.edit_note,
        color: Colors.lightBlueAccent,
        name: 'Task Editor',
        shortLabel: 'Edit'),
    ToolWindowDefinition(
        id: 'color_picker',
        icon: Icons.color_lens,
        color: Colors.pinkAccent,
        name: 'Color Picker',
        shortLabel: 'Colr'),
    ToolWindowDefinition(
        id: 'icon_picker',
        icon: Icons.emoji_emotions,
        color: Colors.orangeAccent,
        name: 'Icon Picker',
        shortLabel: 'Icon'),
    ToolWindowDefinition(
        id: 'subscriptions',
        icon: Icons.subscriptions,
        color: Colors.red,
        name: 'Subscriptions',
        shortLabel: 'Subs'),
    ToolWindowDefinition(
        id: 'layers',
        icon: Icons.layers,
        color: Colors.blue,
        name: 'Layers',
        shortLabel: 'Lyrs'),
    ToolWindowDefinition(
        id: 'properties',
        icon: Icons.settings,
        color: Colors.orange,
        name: 'Properties',
        shortLabel: 'Props'),
    ToolWindowDefinition(
        id: 'timeline',
        icon: Icons.timeline,
        color: Colors.green,
        name: 'Timeline',
        shortLabel: 'Time'),
    ToolWindowDefinition(
        id: 'karaoke_gen',
        icon: Icons.mic,
        color: Colors.purple,
        name: 'Karaoke Gen',
        shortLabel: 'KG'),
    ToolWindowDefinition(
        id: 'macro',
        icon: Icons.code,
        color: Colors.teal,
        name: 'Macro',
        shortLabel: 'Mac'),
    ToolWindowDefinition(
        id: 'macro_guide',
        icon: Icons.help,
        color: Colors.tealAccent,
        name: 'Macro Guide',
        shortLabel: 'M-G'),
    ToolWindowDefinition(
        id: 'flow_editor',
        icon: Icons.account_tree,
        color: Colors.indigo,
        name: 'Flow Editor',
        shortLabel: 'Flow'),
    ToolWindowDefinition(
        id: 'assets',
        icon: Icons.folder,
        color: Colors.amber,
        name: 'Assets',
        shortLabel: 'Asst'),
    ToolWindowDefinition(
        id: 'localization',
        icon: Icons.language,
        color: Colors.cyan,
        name: 'Localization',
        shortLabel: 'Loc'),
    ToolWindowDefinition(
        id: 'backup',
        icon: Icons.backup,
        color: Colors.brown,
        name: 'Backup',
        shortLabel: 'Bkp'),
    ToolWindowDefinition(
        id: 'cli_terminal',
        icon: Icons.terminal,
        color: Colors.grey,
        name: 'CLI Terminal',
        shortLabel: 'CLI'),
    ToolWindowDefinition(
        id: 'system_logs',
        icon: Icons.article,
        color: Colors.blueGrey,
        name: 'System Logs',
        shortLabel: 'Logs'),
    ToolWindowDefinition(
        id: 'test_bed',
        icon: Icons.science,
        color: Colors.deepPurple,
        name: 'Test Bed',
        shortLabel: 'Test'),
    ToolWindowDefinition(
        id: 'version_control',
        icon: Icons.source,
        color: Colors.teal,
        name: 'Version Control',
        shortLabel: 'Git'),
    ToolWindowDefinition(
        id: 'unit_testing',
        icon: Icons.bug_report,
        color: Colors.redAccent,
        name: 'Unit Testing',
        shortLabel: 'Unit'),
    ToolWindowDefinition(
        id: 'profiler',
        icon: Icons.speed,
        color: Colors.lightGreen,
        name: 'Profiler',
        shortLabel: 'Prof'),
    ToolWindowDefinition(
        id: 'ui_helper',
        icon: Icons.design_services,
        color: Colors.pink,
        name: 'UI Helper',
        shortLabel: 'UI'),
    ToolWindowDefinition(
        id: 'suggestion_engine',
        icon: Icons.lightbulb,
        color: Colors.amberAccent,
        name: 'Suggestion Engine',
        shortLabel: 'Sug'),
    ToolWindowDefinition(
        id: 'agents',
        icon: Icons.smart_toy,
        color: Colors.indigoAccent,
        name: 'Agents',
        shortLabel: 'Agt'),
    ToolWindowDefinition(
        id: 'notes_editor',
        icon: Icons.note,
        color: Colors.yellowAccent,
        name: 'Notes Editor',
        shortLabel: 'Note'),
    ToolWindowDefinition(
        id: 'control_types_editor',
        icon: Icons.tune,
        color: Colors.deepPurpleAccent,
        name: 'Control Types',
        shortLabel: 'Ctrl'),
    ToolWindowDefinition(
        id: 'attachment_viewer',
        icon: Icons.attachment,
        color: Colors.cyanAccent,
        name: 'Attachments',
        shortLabel: 'Atth'),
  ];

  static List<ToolWindowDefinition> available = List.from(initialDefaults);

  static Future<void> loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final strVis = prefs.getString('ve_custom_tool_windows_vis');
    if (strVis != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(strVis);
        _visibleWindows =
            decoded.map((key, value) => MapEntry(key, value == true));
      } catch (_) {}
    }

    final strDefs = prefs.getString('ve_custom_tool_windows_defs');
    if (strDefs != null) {
      try {
        final List<dynamic> decoded = jsonDecode(strDefs);
        available =
            decoded.map((e) => ToolWindowDefinition.fromJson(e)).toList();

        // Auto-add any new defaults not present in the cached list
        for (var def in initialDefaults) {
          if (!available.any((w) => w.id == def.id)) {
            available.add(def);
          }
        }
      } catch (_) {}
    } else {
      available = List.from(initialDefaults);
    }
  }

  static Future<void> saveCustom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        've_custom_tool_windows_vis', jsonEncode(_visibleWindows));
    await prefs.setString('ve_custom_tool_windows_defs',
        jsonEncode(available.map((e) => e.toJson()).toList()));
  }

  static bool isWindowVisible(String windowId, {bool defaultValue = true}) {
    return _visibleWindows[windowId] ?? defaultValue;
  }

  static void setWindowVisible(String windowId, bool visible) {
    _visibleWindows[windowId] = visible;
  }

  static ToolWindowDefinition getDef(String id) {
    for (var w in available) {
      if (w.id == id) return w;
    }
    return ToolWindowDefinition(
        id: id,
        icon: Icons.window,
        color: Colors.grey,
        name: id,
        shortLabel: id);
  }
}

class WorkspaceDefinition {
  final String id;
  final String name;
  final String shortLabel;
  final IconData icon;
  final String description;
  final bool requiresConfig;
  final int? mappedMode;
  final Color color;

  const WorkspaceDefinition({
    required this.id,
    required this.name,
    required this.shortLabel,
    required this.icon,
    required this.description,
    this.requiresConfig = false,
    this.mappedMode,
    this.color = Colors.greenAccent,
  });

  factory WorkspaceDefinition.fromJson(Map<String, dynamic> json) {
    return WorkspaceDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      shortLabel: json['shortLabel'] as String,
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
      description: json['description'] as String,
      requiresConfig: json['requiresConfig'] as bool? ?? false,
      mappedMode: json['mappedMode'] as int?,
      color: json['color'] != null
          ? Color(json['color'] as int)
          : Colors.greenAccent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortLabel': shortLabel,
      'icon': icon.codePoint,
      'description': description,
      'requiresConfig': requiresConfig,
      'mappedMode': mappedMode,
      'color': color.value,
    };
  }
}

class AppWorkspaces {
  static const List<WorkspaceDefinition> initialDefaults = [
    WorkspaceDefinition(
        id: 'Planning',
        name: 'Planning',
        shortLabel: 'Plan',
        icon: Icons.architecture,
        description: 'Project planning and overview'),
    WorkspaceDefinition(
        id: 'Database',
        name: 'Database',
        shortLabel: 'Data',
        icon: Icons.storage,
        description: 'Database and asset management',
        mappedMode: 1),
    WorkspaceDefinition(
        id: 'Development',
        name: 'Development',
        shortLabel: 'Dev',
        icon: Icons.code,
        description: 'Core application development',
        mappedMode: 9),
    WorkspaceDefinition(
        id: 'Timeline',
        name: 'Timeline',
        shortLabel: 'Time',
        icon: Icons.dashboard_customize,
        description: 'Timeline and sequence editing',
        requiresConfig: true,
        mappedMode: 0),
    WorkspaceDefinition(
        id: 'User Management',
        name: 'User Management',
        shortLabel: 'Users',
        icon: Icons.people,
        description: 'User roles and permissions'),
    WorkspaceDefinition(
        id: 'Testing',
        name: 'Testing',
        shortLabel: 'Tests',
        icon: Icons.science,
        description: 'QA, Unit testing and debugging',
        requiresConfig: true,
        mappedMode: 10),
  ];

  static List<WorkspaceDefinition> available = [];

  static Future<void> loadCustom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('ve_custom_workspaces');
      if (str != null) {
        final List<dynamic> jsonList = jsonDecode(str);
        available = jsonList.map((e) {
          var def = WorkspaceDefinition.fromJson(e);
          try {
            var initial = initialDefaults.firstWhere((w) => w.id == def.id);
            // Auto-repair missing properties from corrupted SharedPreferences saves
            if (initial.mappedMode != null && def.mappedMode == null) {
              return WorkspaceDefinition(
                  id: def.id,
                  name: def.name,
                  shortLabel: def.shortLabel,
                  icon: def.icon,
                  description: def.description,
                  color: def.color,
                  requiresConfig: initial.requiresConfig,
                  mappedMode: initial.mappedMode);
            }
          } catch (_) {}
          return def;
        }).toList();
      } else {
        available = List.from(initialDefaults);
      }
    } catch (e) {
      available = List.from(initialDefaults);
    }
  }

  static Future<void> saveCustom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(available.map((e) => e.toJson()).toList());
      await prefs.setString('ve_custom_workspaces', str);
    } catch (e) {}
  }
}
