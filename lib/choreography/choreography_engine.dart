import 'package:flutter/material.dart';
import '../constants.dart';
import 'choreography_parser.dart'; // We reuse parser utilities

class TimelineKeyframe {
  final int timeMs;
  final dynamic value;
  final EasingMethod easing;

  TimelineKeyframe({
    required this.timeMs,
    required this.value,
    this.easing = EasingMethod.linear,
  });

  factory TimelineKeyframe.fromJson(Map<String, dynamic> json, String dataType) {
    dynamic parsedValue = json['value'];
    if (parsedValue != null) {
      if (dataType == 'COLOR') {
        parsedValue = ChoreographyConfigValueParser.parseColor(parsedValue);
      } else if (dataType == 'NUMBER') {
        parsedValue = ChoreographyConfigValueParser.parseNumber(parsedValue);
      } else if (dataType == 'BOOLEAN') {
        parsedValue = ChoreographyConfigValueParser.parseBool(parsedValue) ??
            (parsedValue.toString().toUpperCase() == 'TRUE');
      } else if (dataType == 'TRIGGER') {
        // Triggers simply assert true existence passing exactly over time, handled in custom pipelines
        parsedValue = true;
      } else {
        parsedValue = parsedValue.toString();
      }
    }

    return TimelineKeyframe(
      timeMs: ChoreographyConfigValueParser.parseInt(json['timeMs']) ?? 0,
      value: parsedValue,
      easing: ChoreographyConfigValueParser.parseEasingMethod(json['easing']) ??
          EasingMethod.linear,
    );
  }

  Map<String, dynamic> toJson(String dataType) {
    dynamic encodedValue = value;
    if (dataType == 'COLOR') {
      encodedValue = ChoreographyConfigValueParser.colorToHex(value as Color);
    } else if (dataType == 'NUMBER') {
      encodedValue = value is num ? value.toDouble() : 0.0;
    } else if (dataType == 'BOOLEAN') {
      encodedValue = value == true || value == 'true' || value == 'TRUE';
    } else if (dataType == 'TRIGGER') {
      encodedValue = true;
    }
    
    return {
      'timeMs': timeMs,
      'value': encodedValue,
      'easing': easing.toString().split('.').last, // 'linear', 'easeInOut', etc
    };
  }
}

class PropertyItem {
  final String propertyName;
  final String dataType;
  final List<TimelineKeyframe> keyframes;

  PropertyItem({
    required this.propertyName,
    required this.dataType,
    required this.keyframes,
  }) {
    keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  }

  factory PropertyItem.fromJson(String name, Map<String, dynamic> json) {
    String type = json['type']?.toString().toUpperCase().trim() ?? 'NUMBER';
    List<TimelineKeyframe> kfs = [];
    if (json['keyframes'] is List) {
      for (var kfJson in json['keyframes']) {
        kfs.add(TimelineKeyframe.fromJson(kfJson, type));
      }
    }
    return PropertyItem(
      propertyName: name,
      dataType: type,
      keyframes: kfs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': dataType,
      'keyframes': keyframes.map((k) => k.toJson(dataType)).toList(),
    };
  }

  /// High-performance interpolation. Evaluates exactly what the property
  /// is at a given millisecond, independently interpolating against adjacent keyframes.
  dynamic evaluateAt(int positionMs) {
    if (keyframes.isEmpty) return null;
    if (positionMs <= keyframes.first.timeMs) return keyframes.first.value;
    if (positionMs >= keyframes.last.timeMs) return keyframes.last.value;

    // Binary search to find the segment bounding `positionMs`
    int low = 0;
    int high = keyframes.length - 1;
    while (low <= high) {
      int mid = (low + high) ~/ 2;
      if (keyframes[mid].timeMs <= positionMs) {
        if (mid + 1 < keyframes.length && keyframes[mid + 1].timeMs > positionMs) {
          low = mid;
          break;
        } else {
          low = mid + 1;
        }
      } else {
        high = mid - 1;
      }
    }

    final prev = keyframes[low];
    
    // Explicit discrete boundary return completely bypassing ANY mathematical float processing or index lookups to guarantee switch mapping flawlessly!
    if (dataType == 'BOOLEAN' || dataType == 'STRING' || dataType == 'TRIGGER' || prev.value is bool || prev.value is String) {
      return prev.value;
    }
    
    if (low + 1 >= keyframes.length) return prev.value;
    final next = keyframes[low + 1];

    double t = (positionMs - prev.timeMs) / (next.timeMs - prev.timeMs).toDouble();
    t = t.clamp(0.0, 1.0);

    // Dynamic Easing Injection
    Curve curve = Curves.linear;
    switch (prev.easing) {
      case EasingMethod.linear:
        curve = Curves.linear;
        break;
      case EasingMethod.easeInOut:
        curve = Curves.easeInOut;
        break;
      case EasingMethod.easeIn:
        curve = Curves.easeIn;
        break;
      case EasingMethod.easeOut:
        curve = Curves.easeOut;
        break;
      case EasingMethod.elasticIn:
        curve = Curves.elasticIn;
        break;
      case EasingMethod.elasticOut:
        curve = Curves.elasticOut;
        break;
      case EasingMethod.elasticInOut:
        curve = Curves.elasticInOut;
        break;
      case EasingMethod.bounceIn:
        curve = Curves.bounceIn;
        break;
      case EasingMethod.bounceOut:
        curve = Curves.bounceOut;
        break;
      case EasingMethod.bounceInOut:
        curve = Curves.bounceInOut;
        break;
    }
    t = curve.transform(t);

    if (dataType == 'NUMBER') {
      double pStart = prev.value is num ? (prev.value as num).toDouble() : 0.0;
      double pEnd = next.value is num ? (next.value as num).toDouble() : 0.0;
      return pStart + (pEnd - pStart) * t;
    }

    if (dataType == 'COLOR') {
      Color cStart = prev.value is Color ? prev.value : Colors.transparent;
      Color cEnd = next.value is Color ? next.value : Colors.transparent;

      // Realtime HSV projection prevents muddy crossfades during rapid color shifts
      final hsvStart = HSVColor.fromColor(cStart);
      final hsvEnd = HSVColor.fromColor(cEnd);
      return HSVColor.lerp(hsvStart, hsvEnd, t)?.toColor() ?? cEnd;
    }

    return prev.value;
  }
}

class LayerElement {
  final String targetId;
  final String type;
  final String? path;
  final bool active;
  final String blendMode;
  final Map<String, PropertyItem> items;
  String? parentId;
  bool isExpanded;
  final String? platform;
  final String? orientation;
  final String? script;

  LayerElement({
    required this.targetId,
    required this.type,
    this.path,
    this.active = true,
    this.blendMode = 'NORMAL',
    required this.items,
    this.parentId,
    this.isExpanded = true,
    this.platform,
    this.orientation,
    this.script,
  });

  factory LayerElement.fromJson(String id, Map<String, dynamic> json) {
    Map<String, PropertyItem> pItems = {};
    if (json['properties'] is Map) {
      (json['properties'] as Map<String, dynamic>).forEach((key, val) {
        if (val is Map<String, dynamic>) {
          pItems[key] = PropertyItem.fromJson(key, val);
        }
      });
    }

    // Backwards compatibility migration layer
    final String legacyBlend = pItems.containsKey('LAYER_BLEND') 
      ? pItems['LAYER_BLEND']!.keyframes.firstOrNull?.value.toString() ?? 'NORMAL'
      : 'NORMAL';
    // Clean up residual nested migration fragments if any
    pItems.remove('LAYER_BLEND');

    PropertyItem makeItem(String name, dynamic initVal, String type) => 
       PropertyItem(propertyName: name, dataType: type, keyframes: [TimelineKeyframe(timeMs: 0, value: initVal)]);

    // Auto-inject natively strictly missing bounding transform elements locally dynamically
    if (!pItems.containsKey('ACTIVE')) pItems['ACTIVE'] = makeItem('ACTIVE', json['active'] ?? true, 'BOOLEAN');
    if (!pItems.containsKey('LAYER_POS_X')) pItems['LAYER_POS_X'] = makeItem('LAYER_POS_X', 0.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_POS_Y')) pItems['LAYER_POS_Y'] = makeItem('LAYER_POS_Y', 0.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_SCALE_X')) pItems['LAYER_SCALE_X'] = makeItem('LAYER_SCALE_X', 1.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_SCALE_Y')) pItems['LAYER_SCALE_Y'] = makeItem('LAYER_SCALE_Y', 1.0, 'NUMBER');
    
    // Legacy migration to natively support 3D orientation tracking and formal Pivot terminology seamlessly
    if (pItems.containsKey('LAYER_ROTATION')) {
      pItems['LAYER_ROTATION_Z'] = PropertyItem(propertyName: 'LAYER_ROTATION_Z', dataType: 'NUMBER', keyframes: pItems['LAYER_ROTATION']!.keyframes);
      pItems.remove('LAYER_ROTATION');
    }
    if (pItems.containsKey('LAYER_ANCHOR_X')) {
      pItems['LAYER_PIVOT_X'] = PropertyItem(propertyName: 'LAYER_PIVOT_X', dataType: 'NUMBER', keyframes: pItems['LAYER_ANCHOR_X']!.keyframes);
      pItems.remove('LAYER_ANCHOR_X');
    }
    if (pItems.containsKey('LAYER_ANCHOR_Y')) {
      pItems['LAYER_PIVOT_Y'] = PropertyItem(propertyName: 'LAYER_PIVOT_Y', dataType: 'NUMBER', keyframes: pItems['LAYER_ANCHOR_Y']!.keyframes);
      pItems.remove('LAYER_ANCHOR_Y');
    }

    if (!pItems.containsKey('LAYER_ROTATION_X')) pItems['LAYER_ROTATION_X'] = makeItem('LAYER_ROTATION_X', 0.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_ROTATION_Y')) pItems['LAYER_ROTATION_Y'] = makeItem('LAYER_ROTATION_Y', 0.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_ROTATION_Z')) pItems['LAYER_ROTATION_Z'] = makeItem('LAYER_ROTATION_Z', 0.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_PIVOT_X')) pItems['LAYER_PIVOT_X'] = makeItem('LAYER_PIVOT_X', 0.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_PIVOT_Y')) pItems['LAYER_PIVOT_Y'] = makeItem('LAYER_PIVOT_Y', 0.0, 'NUMBER');
    if (!pItems.containsKey('LAYER_TILT')) pItems['LAYER_TILT'] = makeItem('LAYER_TILT', false, 'BOOLEAN');
    if (!pItems.containsKey('LAYER_TILT_DEPTH')) pItems['LAYER_TILT_DEPTH'] = makeItem('LAYER_TILT_DEPTH', 20.0, 'NUMBER');

    return LayerElement(
      targetId: id,
      type: json['type']?.toString().toUpperCase() ?? 'IMAGE',
      path: json['path']?.toString(),
      active: json['active'] ?? true,
      blendMode: json['blendMode']?.toString() ?? legacyBlend,
      items: pItems,
      parentId: json['parentId']?.toString(),
      isExpanded: json['isExpanded'] ?? true,
      platform: json['platform']?.toString(),
      orientation: json['orientation']?.toString(),
      script: json['script']?.toString(),
    );
  }
  /// Helper to grab a variable evaluation instantly safely
  dynamic getVar(String varName, int timeMs, {dynamic fallback}) {
    return items[varName]?.evaluateAt(timeMs) ?? fallback;
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> pItems = {};
    items.forEach((k, v) {
      if (k == 'LAYER_BLEND') return; // Strip legacy items out from the JSON natively!
      if (v.keyframes.isNotEmpty) {
        pItems[k] = v.toJson();
      }
    });

    final map = <String, dynamic>{
      'type': type,
      'properties': pItems,
      if (!active) 'active': false,
      if (!isExpanded) 'isExpanded': false,
      if (parentId != null) 'parentId': parentId,
      if (blendMode != 'NORMAL') 'blendMode': blendMode,
    };
    if (path != null) map['path'] = path;
    if (platform != null) map['platform'] = platform;
    if (orientation != null) map['orientation'] = orientation;
    if (script != null) map['script'] = script;
    return map;
  }
}

class EvaluatedLayer {
  final String id;
  final String type;
  final String blendMode;
  final String? path;
  final String? script;
  final Map<String, dynamic> items;
  final String? parentId;
  final bool active;

  // Aliases for NowPlayingScreen compatibility
  Color? get color => items['LAYER_COLOR'];
  double? get opacity => items['LAYER_OPACITY'] ?? 1.0;
  String? get fit => items['LAYER_FIT'];
  double? get posX => items['LAYER_POS_X'] ?? items['LAYER_POS'] ?? 0.0;
  double? get posY => items['LAYER_POS_Y'] ?? items['LAYER_POS'] ?? 0.0;
  double? get scale => items['LAYER_SCALE'] ?? 1.0;
  double? get scaleX => items['LAYER_SCALE_X'] ?? items['LAYER_SCALE'] ?? 1.0;
  double? get scaleY => items['LAYER_SCALE_Y'] ?? items['LAYER_SCALE'] ?? 1.0;
  double? get blur => items['LAYER_BLUR'] ?? 0.0;
  double? get rotationX => items['LAYER_ROTATION_X'] ?? 0.0;
  double? get rotationY => items['LAYER_ROTATION_Y'] ?? 0.0;
  double? get rotationZ => items['LAYER_ROTATION_Z'] ?? items['LAYER_ROTATION'] ?? 0.0;
  double? get pivotX => items['LAYER_PIVOT_X'] ?? items['LAYER_ANCHOR_X'] ?? 0.0;
  double? get pivotY => items['LAYER_PIVOT_Y'] ?? items['LAYER_ANCHOR_Y'] ?? 0.0;
  bool get tiltEnabled => items['LAYER_TILT'] == true;
  double get tiltDepth => items['LAYER_TILT_DEPTH'] ?? 20.0;
  int? get videoPlayCount => items['LAYER_VIDEO_PLAY_COUNT']?.toInt();
  
  ParticleType? get particleType => ChoreographyConfigValueParser.parseParticleType(items['LAYER_PARTICLE_TYPE']);
  double? get particleSpeed => items['LAYER_PARTICLE_SPEED'] ?? 1.0;
  double? get particleCount => items['LAYER_PARTICLE_COUNT'] ?? 50.0;

  Color? get shaderColor1 => items['LAYER_SHADER_COLOR_1'];
  Color? get shaderColor2 => items['LAYER_SHADER_COLOR_2'];
  Color? get shaderColor3 => items['LAYER_SHADER_COLOR_3'];
  Color? get shaderColor4 => items['LAYER_SHADER_COLOR_4'];
  double? get shaderAudioModulation => items['LAYER_SHADER_AUDIO_MODULATION'];
  
  // Custom Variables injected from external V2 triggers
  int get repaintCount => (items['COMMAND_REPAINT'] == true || items['COMMAND_REPAINT_ALL_STATIC'] == true) ? 1 : 0;
  
  EvaluatedLayer({
    required this.id,
    required this.type,
    required this.blendMode,
    this.path,
    this.script,
    required this.items,
    this.parentId,
    this.active = true,
  });
}

class EvaluatedConfig {
  final Map<String, dynamic> globalItems;
  final Map<String, EvaluatedLayer> bgLayers;

  EvaluatedConfig({
    required this.globalItems,
    required this.bgLayers,
  });

  // Aliases for NowPlayingScreen compatibility
  String? get useTemplate => globalItems['USE_TEMPLATE'];
  String? get fontFamily => globalItems['FONT_FAMILY'];
  double? get fontSize => globalItems['FONT_SIZE'];
  String? get fontCase => globalItems['FONT_CASE'];
  Color? get fontColor => globalItems['FONT_COLOR'];
  double? get fontAlpha => globalItems['FONT_ALPHA'];
  Color? get fontShadowColor => globalItems['FONT_SHADOW_COLOR'];
  double? get fontShadowBlur => globalItems['FONT_SHADOW_BLUR'];

  LyricsStyle get lyricStyle => ChoreographyConfigValueParser.parseLyricStyle(globalItems['LYRIC_STYLE']) ?? LyricsStyle.standard;
  String? get lyricStyleParam => globalItems['LYRIC_STYLE_PARAM'];
  double? get lyricActiveScale => globalItems['LYRIC_ACTIVE_SCALE'] ?? 1.0;
  LyricEffect get lyricEffect => ChoreographyConfigValueParser.parseLyricEffect(globalItems['EFFECT_TYPE']) ?? LyricEffect.none;
  bool get effectEnabled => globalItems['EFFECT_ENABLED'] ?? true;
  String? get lyricEffectParam => globalItems['EFFECT_TYPE_PARAM'];

  String? get lyricPos => globalItems['LYRIC_POS'];
  String? get custom => globalItems['CUSTOM'];

  VisualizerType? get audioVisualizer => ChoreographyConfigValueParser.parseVisualizerType(globalItems['AUDIO_VISUALIZER']);
  AudioVisualizerMode? get audioVisualizerMode => ChoreographyConfigValueParser.parseVisualizerMode(globalItems['AUDIO_VISUALIZER_MODE']);
  int? get audioVisualizerBands => globalItems['AUDIO_VISUALIZER_BANDS']?.toInt();
  int? get audioVisualizerBlockHeight => globalItems['AUDIO_VISUALIZER_BLOCK_HEIGHT']?.toInt();
  AudioVisualizerColorStyle? get audioVisualizerColorStyle => ChoreographyConfigValueParser.parseVisualizerColorStyle(globalItems['AUDIO_VISUALIZER_COLOR_STYLE']);
  Color? get audioVisualizerColorStart => globalItems['AUDIO_VISUALIZER_COLOR_START'];
  Color? get audioVisualizerColorEnd => globalItems['AUDIO_VISUALIZER_COLOR_END'];
  double? get audioVisualizerAlphaStart => globalItems['AUDIO_VISUALIZER_ALPHA_START'];
  double? get audioVisualizerAlphaEnd => globalItems['AUDIO_VISUALIZER_ALPHA_END'];

  Color? get bgColor => globalItems['BG_COLOR'];
  String? get bgType => globalItems['BG_TYPE'];
  String? get bgPath => globalItems['BG_PATH'];
  String? get bgFit => globalItems['BG_FIT'];
  double? get cameraShake => globalItems['CAMERA_SHAKE'];
  double? get cameraZoom => globalItems['CAMERA_ZOOM'] ?? 1.0;
  double? get cameraPanX => globalItems['CAMERA_PAN_X'] ?? 0.0;
  double? get cameraPanY => globalItems['CAMERA_PAN_Y'] ?? 0.0;
  double? get cameraRotation => globalItems['CAMERA_ROTATION'] ?? 0.0;
  EasingMethod? get easingMethod => ChoreographyConfigValueParser.parseEasingMethod(globalItems['EASING']);

  // UI Element Bounding Context
  double? get canvasWidth => globalItems['CANVAS_WIDTH'];
  double? get canvasHeight => globalItems['CANVAS_HEIGHT'];
}

class ChoreographyConfig {
  final int version = 2;
  // E.g., FONT_SIZE, FONT_COLOR, CAMERA_SHAKE, etc.
  final Map<String, PropertyItem> globalItems;
  // Specific initialized layers containing nested property items
  final Map<String, LayerElement> layers;

  ChoreographyConfig({
    required this.globalItems,
    required this.layers,
  });

  EvaluatedConfig evaluate(int positionMs, {String? targetPlatform, Orientation? targetOrientation}) {
    Map<String, dynamic> evalGlobals = {};
    for (var item in globalItems.values) {
      evalGlobals[item.propertyName] = item.evaluateAt(positionMs);
    }

    Map<String, EvaluatedLayer> evalLayers = {};
    for (var layer in layers.values) {
      // 1. Feature Condition Flag Bypass Filters
      if (targetPlatform != null && layer.platform != null && layer.platform != 'ANY' && layer.platform != targetPlatform) continue;
      if (targetOrientation != null && layer.orientation != null && layer.orientation != 'ANY') {
         String orientStr = targetOrientation == Orientation.portrait ? 'PORTRAIT' : 'LANDSCAPE';
         if (layer.orientation != orientStr) continue;
      }

      bool evaluatedActive = layer.active;
      if (evaluatedActive && layer.items.containsKey('ACTIVE') && layer.items['ACTIVE']!.keyframes.isNotEmpty) {
          evaluatedActive = layer.items['ACTIVE']!.evaluateAt(positionMs) == true;
      }
      
      if (!evaluatedActive) continue;
      
      // Cascade inactive bounds assessing entire parent tree deeply recursively natively
      bool parentIsInactive = false;
      String? currentParentId = layer.parentId;
      while (currentParentId != null) {
        final parentLayer = layers[currentParentId];
        if (parentLayer != null) {
           bool pActive = parentLayer.active;
           if (pActive && parentLayer.items.containsKey('ACTIVE') && parentLayer.items['ACTIVE']!.keyframes.isNotEmpty) {
               pActive = parentLayer.items['ACTIVE']!.evaluateAt(positionMs) == true;
           }
           if (!pActive) {
               parentIsInactive = true;
               break;
           }
           currentParentId = parentLayer.parentId;
        } else {
           break;
        }
      }
      if (parentIsInactive) continue;

      Map<String, dynamic> evalItems = {};
      
      // Inject global repaints onto static layers implicitly
      if (layer.type == 'STATIC_SHADER' && evalGlobals['COMMAND_REPAINT_ALL_STATIC'] == true) {
        evalItems['COMMAND_REPAINT_ALL_STATIC'] = true;
      }
      
      for (var item in layer.items.values) {
        evalItems[item.propertyName] = item.evaluateAt(positionMs);
      }
      
      evalLayers[layer.targetId] = EvaluatedLayer(
        id: layer.targetId,
        type: layer.type,
        path: layer.path,
        script: layer.script,
        blendMode: layer.blendMode,
        items: evalItems,
        parentId: layer.parentId,
        active: evaluatedActive,
      );
    }
    
    return EvaluatedConfig(
      globalItems: evalGlobals,
      bgLayers: evalLayers,
    );
  }

  factory ChoreographyConfig.fromJson(Map<String, dynamic> json) {
    Map<String, PropertyItem> globals = {};
    if (json['globalItems'] is Map) {
      (json['globalItems'] as Map<String, dynamic>).forEach((key, val) {
        if (val is Map<String, dynamic>) {
          globals[key] = PropertyItem.fromJson(key, val);
        }
      });
    }

    Map<String, LayerElement> layersMap = {};
    if (json['layers'] is Map) {
      (json['layers'] as Map<String, dynamic>).forEach((key, val) {
        if (val is Map<String, dynamic>) {
          layersMap[key] = LayerElement.fromJson(key, val);
        }
      });
    }

    return ChoreographyConfig(
      globalItems: globals,
      layers: layersMap,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> globals = {};
    globalItems.forEach((k, v) {
      if (v.keyframes.isNotEmpty) globals[k] = v.toJson();
    });

    Map<String, dynamic> mapLayers = {};
    layers.forEach((k, v) {
      mapLayers[k] = v.toJson();
    });

    return {
      'version': version,
      'globalItems': globals,
      'layers': mapLayers,
    };
  }
}

