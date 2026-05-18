import 'dart:convert';
import 'package:flutter/material.dart';
import '../constants.dart';

class ChoreographyConfigEvent {
  final String key;
  final dynamic value;

  ChoreographyConfigEvent(this.key, this.value);
}

class ChoreographyConfigGroup {
  final int timeMs;
  final List<ChoreographyConfigEvent> events;

  ChoreographyConfigGroup({required this.timeMs, required this.events});
}

class ChoreographyConfigValueParser {
  static int? parseTimecode(dynamic val) {
    if (val == null) return null;
    final str = val.toString();
    final match = RegExp(r'(\d{2}):(\d{2})\.(\d{2,3})').firstMatch(str);
    if (match != null) {
      final m = int.parse(match.group(1)!);
      final s = int.parse(match.group(2)!);
      String msStr = match.group(3)!;
      if (msStr.length == 2) msStr += '0';
      return (m * 60 * 1000) + (s * 1000) + int.parse(msStr);
    }
    if (val is int) return val;
    final asInt = int.tryParse(str);
    if (asInt != null) return asInt;
    return null;
  }

  static Color? parseColor(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();

    // Support standard web rgba(r, g, b, a) strings
    if (str.toLowerCase().startsWith('rgba')) {
      final match = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\)')
          .firstMatch(str);
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        final a = double.parse(match.group(4)!);
        return Color.fromRGBO(r, g, b, a);
      }
    }

    // Support standard web rgb(r, g, b) strings
    if (str.toLowerCase().startsWith('rgb')) {
      final match = RegExp(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)').firstMatch(str);
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        return Color.fromRGBO(r, g, b, 1.0);
      }
    }

    // Support standard hex codes
    final hexStr = str.replaceAll('#', '').toUpperCase();
    if (hexStr.length == 6) {
      // RRGGBB -> AARRGGBB (Solid)
      return Color(int.parse('FF$hexStr', radix: 16));
    } else if (hexStr.length == 8) {
      // AARRGGBB (Flutter native format exported from .toRadixString)
      return Color(int.parse(hexStr, radix: 16));
    }
    return null;
  }

  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }

  static double? parseAlpha(dynamic val) {
    if (val is num) {
      if (val > 1.0) return (val / 255.0).clamp(0.0, 1.0);
      return val.toDouble().clamp(0.0, 1.0);
    }
    final str = val?.toString();
    if (str != null) {
      final parsed = double.tryParse(str);
      if (parsed != null) {
        if (parsed > 1.0) return (parsed / 255.0).clamp(0.0, 1.0);
        return parsed.clamp(0.0, 1.0);
      }
    }
    return null;
  }

  static double? parseUnit01(dynamic val) {
    if (val is num) return val.toDouble().clamp(0.0, 1.0);
    final str = val?.toString();
    if (str != null) {
      final parsed = double.tryParse(str);
      if (parsed != null) return parsed.clamp(0.0, 1.0);
    }
    return null;
  }

  static double? parseNumber(dynamic val) {
    if (val is num) return val.toDouble();
    if (val != null) return double.tryParse(val.toString());
    return null;
  }

  static int? parseInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val != null) return int.tryParse(val.toString());
    return null;
  }

  static String? parseString(dynamic val) {
    return val?.toString();
  }

  static bool? parseBool(dynamic val) {
    if (val is bool) return val;
    final str = val?.toString().toLowerCase();
    if (str == 'true' || str == '1') return true;
    if (str == 'false' || str == '0') return false;
    return null;
  }

  static LyricsStyle parseLyricStyle(dynamic val) {
    if (val == null) return LyricsStyle.standard;
    final str = val.toString().toUpperCase();
    if (str == 'TYPEWRITER') {
      return LyricsStyle.typewriter;
    }
    return LyricsStyle.standard;
  }

  static LyricEffect parseLyricEffect(dynamic val) {
    if (val == null) return LyricEffect.none;
    final str = val.toString().toUpperCase();
    if (str == 'FLICKER') return LyricEffect.flicker;
    if (str == 'COLORIZE') return LyricEffect.colorize;
    return LyricEffect.none;
  }

  static VisualizerType? parseVisualizerType(dynamic val) {
    if (val == null) return null;
    final str = val.toString().toUpperCase();
    if (str == 'BAR') return VisualizerType.bar;
    if (str == 'CIRCULAR') return VisualizerType.circular;
    if (str == 'LINE') return VisualizerType.line;
    if (str == 'MULTI_WAVE') return VisualizerType.multiWave;
    if (str == 'RAINBOW') return VisualizerType.rainbow;
    if (str == 'NONE' || str == 'OFF') return VisualizerType.none;
    return null;
  }

  static AudioVisualizerMode? parseVisualizerMode(dynamic val) {
    if (val == null) return null;
    final str = val.toString().toUpperCase();
    if (str == 'BASS') return AudioVisualizerMode.bass;
    if (str == 'VOCALS') return AudioVisualizerMode.vocals;
    if (str == 'STANDARD') return AudioVisualizerMode.standard;
    if (str == 'BEAT') return AudioVisualizerMode.beat;
    return null;
  }

  static AudioVisualizerColorStyle? parseVisualizerColorStyle(dynamic val) {
    if (val == null) return null;
    final str = val.toString().toUpperCase();
    if (str == 'SOLID') return AudioVisualizerColorStyle.solid;
    if (str == 'GRADIENT') return AudioVisualizerColorStyle.gradient;
    if (str == 'RAINBOW') return AudioVisualizerColorStyle.rainbow;
    return null;
  }

  static EasingMethod? parseEasingMethod(dynamic val) {
    if (val == null) return null;
    final str = val.toString().toUpperCase();
    if (str == 'LINEAR') return EasingMethod.linear;
    if (str == 'EASE_IN_OUT') return EasingMethod.easeInOut;
    if (str == 'EASE_IN') return EasingMethod.easeIn;
    if (str == 'EASE_OUT') return EasingMethod.easeOut;
    if (str == 'ELASTIC_IN') return EasingMethod.elasticIn;
    if (str == 'ELASTIC_OUT') return EasingMethod.elasticOut;
    if (str == 'ELASTIC_IN_OUT') return EasingMethod.elasticInOut;
    if (str == 'BOUNCE_IN') return EasingMethod.bounceIn;
    if (str == 'BOUNCE_OUT') return EasingMethod.bounceOut;
    if (str == 'BOUNCE_IN_OUT') return EasingMethod.bounceInOut;
    return null;
  }

  static ParticleType? parseParticleType(dynamic val) {
    if (val == null) return null;
    final str = val.toString().toUpperCase();
    if (str == 'SNOW') return ParticleType.snow;
    if (str == 'STARS') return ParticleType.stars;
    if (str == 'CONFETTI') return ParticleType.confetti;
    if (str == 'FIREFLIES') return ParticleType.fireflies;
    if (str == 'SMOKE') return ParticleType.smoke;
    if (str == 'NONE' || str == 'OFF') return ParticleType.none;
    return null;
  }
}

class ChoreographyConfigParser {
  static String _stripComments(String jsonString) {
    // Matches strings OR block comments OR line comments
    // Group 1: String `"..."` (ignoring escaped quotes)
    // Group 2: Block comment `/* ... */`
    // Group 3: Line comment `// ...`
    final RegExp regex = RegExp(
      r'("(?:\\.|[^"\\])*")|(\/\*[\s\S]*?\*\/)|(\/\/.*)',
      multiLine: true,
    );
    return jsonString.replaceAllMapped(regex, (match) {
      if (match.group(1) != null) {
        return match.group(1)!; // Keep the string
      } else {
        return ''; // Remove the comment
      }
    });
  }

  static List<ChoreographyConfigGroup> parse(String jsonString) {
    final List<ChoreographyConfigGroup> groups = [];
    int currentTimeMs = 0;
    List<ChoreographyConfigEvent> currentEvents = [];

    try {
      final String cleanJson = _stripComments(jsonString);
      final Map<String, dynamic> root = jsonDecode(cleanJson);
      final List<dynamic> rawList = root['events'] ?? [];

      for (final raw in rawList) {
        if (raw is Map<String, dynamic>) {
          // Pre-process unified global variables (combines VARIABLE_GLOBAL and VARIABLE_VALUE)
          if (raw.containsKey('VARIABLE_GLOBAL') &&
              raw.containsKey('VARIABLE_VALUE')) {
            raw[raw['VARIABLE_GLOBAL'].toString()] = raw['VARIABLE_VALUE'];
          }
          for (final entry in raw.entries) {
            if (entry.key == 'Time') {
              final parsedTime = ChoreographyConfigValueParser.parseTimecode(
                entry.value,
              );
              if (parsedTime != null) {
                if (currentEvents.isNotEmpty) {
                  groups.add(
                    ChoreographyConfigGroup(
                      timeMs: currentTimeMs,
                      events: List.from(currentEvents),
                    ),
                  );
                  if (AppDebugConfig.debugMode) {
                    debugPrint(
                        '--- Parsed Lyric Config Group at ${currentTimeMs}ms ---');
                    for (var e in currentEvents) {
                      debugPrint('  [JSON] ${e.key}: ${e.value}');
                    }
                  }
                  currentEvents.clear();
                }
                currentTimeMs = parsedTime;
              }
            } else {
              currentEvents.add(ChoreographyConfigEvent(entry.key, entry.value));
            }
          }
        }
      }

      if (currentEvents.isNotEmpty) {
        groups.add(
          ChoreographyConfigGroup(timeMs: currentTimeMs, events: currentEvents),
        );
        if (AppDebugConfig.debugMode) {
          debugPrint('--- Parsed Lyric Config Group at ${currentTimeMs}ms ---');
          for (var e in currentEvents) {
            debugPrint('  [JSON] ${e.key}: ${e.value}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing lyric config json: $e');
    }

    groups.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return groups;
  }
}
