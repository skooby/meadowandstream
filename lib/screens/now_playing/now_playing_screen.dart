import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lua_dardo/lua.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'dart:async' as async;
import 'package:just_audio/just_audio.dart' show LoopMode;
import '../../state/player_controller.dart';
import '../../constants.dart';
import '../../models/item.dart';
import '../../models/item_source.dart';
import '../../db/daos/favorites_dao.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../state/lyrics_view_controller.dart';
import '../../state/offline_cache_settings_controller.dart';
import '../../widgets/visualizer/particle_engine.dart';
import '../../services/waveform_extractor_service.dart';
import '../../widgets/visualizer/custom_audio_visualizer.dart';
import '../../widgets/visualizer/shader_layer.dart';
import '../../widgets/visualizer/rive_layer.dart';
import 'package:flutter_shader_kit/flutter_shaders.dart';
import '../../widgets/camera_view.dart';
import '../visual_editor/visual_editor_screen.dart';
import '../../engine/ui_inspector/element_registry.dart';


class NowPlayingScreen extends StatefulWidget {
  final async.StreamController<TiltStreamModel>? tiltStreamController;
  final bool isElementPreview;
  const NowPlayingScreen({super.key, this.tiltStreamController, this.isElementPreview = false});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _dragValue;
  bool _isFullScreenMedia = false;
  bool _showFullScreenControls = false;

  PlayerController? _player;
  String? _lastItemId;
  final _waveformExtractor = WaveformExtractorService();
  VisualizerType _currentVisualizer = VisualizerType.circular;

  void _cycleVisualizer() {
    setState(() {
      _currentVisualizer = VisualizerType.values[
          (_currentVisualizer.index + 1) % VisualizerType.values.length];
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_player == null) {
      _player = context.read<PlayerController>();
      _player!.addListener(_onPlayerChange);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPlayerChange());
    }
  }

  void _onPlayerChange() {
    if (!mounted) return;
    final item = _player!.currentItem;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lyricsController = context.read<LyricsViewController>();
      lyricsController.setIsPlaying(_player!.isPlaying);
      lyricsController.updatePosition(_player!.position.inMilliseconds);

      if (item != null && item.id != _lastItemId) {
        _lastItemId = item.id;
        lyricsController.loadForCurrentItem(item.id, item.source);
        _waveformExtractor.extractForItem(item);
      }
    });
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChange);
    super.dispose();
  }

  Widget _buildLyricsDisplay(
    LyricsViewController lyricsState,
    ThemeData theme,
    int lyricsLineMode,
    bool isPlaying,
  ) {
    final prevLine = lyricsState.prevLine?.text ?? '';
    final nextLine = lyricsState.nextLine?.text ?? '';
    final currentLine = lyricsState.currentLine;

    final config = lyricsState.currentConfig;

    final baseStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.bold,
      fontFamily: config.fontFamily ?? AppFonts.main,
    );

    TextStyle fillStyle(Color color, double size) {
      final shadows = <Shadow>[];
      if (config.fontShadowColor != null &&
          config.fontShadowBlur != null &&
          config.fontShadowBlur! > 0.0) {
        shadows.add(Shadow(
          color: config.fontShadowColor!,
          blurRadius: config.fontShadowBlur!,
        ));
      }
      return baseStyle!.copyWith(
        color: color,
        fontSize: size,
        shadows: shadows.isEmpty ? null : shadows,
      );
    }

    TextStyle strokeStyle(double size) {
      return baseStyle!.copyWith(
        fontSize: size,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppLyricsConfig.strokeWidth
          ..color = AppLyricsConfig.strokeColor,
      );
    }

    Widget buildStrokedLine(
        {required String text,
        required Color color,
        required double size,
        Color? effectColor,
        double effectOpacity = 1.0,
        double effectScale = 1.0}) {
      if (config.fontCase == 'UPPERCASE') text = text.toUpperCase();
      if (config.fontCase == 'LOWERCASE') text = text.toLowerCase();
      if (config.fontCase == 'TITLE' && text.isNotEmpty) {
        text = text
            .split(' ')
            .map((w) => w.isNotEmpty
                ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                : '')
            .join(' ');
      }
      if (config.fontCase == 'SENTENCE' && text.isNotEmpty) {
        text = '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
      }

      Widget textWidget = Stack(
        alignment: Alignment.center,
        children: [
          Text(text, style: strokeStyle(size), textAlign: TextAlign.center),
          Text(text,
              style: fillStyle(effectColor ?? color, size),
              textAlign: TextAlign.center),
        ],
      );

      if (effectOpacity != 1.0) {
        textWidget = Opacity(opacity: effectOpacity, child: textWidget);
      }

      if (effectScale != 1.0) {
        textWidget = Transform.scale(
          scale: effectScale,
          alignment: Alignment.center,
          child: textWidget,
        );
      }

      return textWidget;
    }

    Widget buildWordBlock(String wordText, bool isActive) {
      if (config.fontCase == 'UPPERCASE') wordText = wordText.toUpperCase();
      if (config.fontCase == 'LOWERCASE') wordText = wordText.toLowerCase();
      if (config.fontCase == 'TITLE' && wordText.isNotEmpty) {
        wordText = wordText
            .split(' ')
            .map((w) => w.isNotEmpty
                ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                : '')
            .join(' ');
      }
      if (config.fontCase == 'SENTENCE' && wordText.isNotEmpty) {
        wordText =
            '${wordText[0].toUpperCase()}${wordText.substring(1).toLowerCase()}';
      }

      var activeSize = config.fontSize ?? AppLyricsConfig.activeFontSize;
      var inactiveSize = config.fontSize ?? AppLyricsConfig.inactiveFontSize;

      final size = isActive ? activeSize : inactiveSize;

      Color color;
      bool useBg = false;

      if (isActive) {
        if (config.lyricStyle.name.toUpperCase() == 'KARAOKE' ||
            AppLyricsConfig.useWordHighlightBackground) {
          color = AppLyricsConfig.wordHighlightBackgroundTextColor;
          useBg = true;
        } else {
          color = AppLyricsConfig.wordHighlightColor;
        }
      } else {
        color = config.fontColor ?? AppLyricsConfig.fontColor;
        color = color.withValues(
            alpha: (config.fontAlpha ?? AppLyricsConfig.wordNonHighlightFade).toDouble());
      }

      final leadingStr = RegExp(r'^\s*').firstMatch(wordText)?.group(0) ?? '';
      final trailingStr = RegExp(r'\s*$').firstMatch(wordText)?.group(0) ?? '';
      final coreStr = wordText.substring(
          leadingStr.length, wordText.length - trailingStr.length);

      final widgets = <Widget>[];

      if (leadingStr.isNotEmpty) {
        widgets
            .add(Text(leadingStr, style: fillStyle(Colors.transparent, size)));
      }

      Widget coreWidget;

      if (isActive &&
          config.lyricEffect != LyricEffect.none &&
          config.effectEnabled) {
        coreWidget = _LyricEffectWrapper(
          effect: config.lyricEffect,
          isPlaying: isPlaying,
          extractor: _waveformExtractor,
          player: _player!,
          param: config.lyricEffectParam,
          builder: (context, effectColor, effectOpacity, effectScale) {
            Widget w = buildStrokedLine(
                text: coreStr,
                color: color,
                size: size,
                effectColor: effectColor,
                effectOpacity: effectOpacity,
                effectScale: effectScale);
            if (useBg && coreStr.isNotEmpty) {
              w = Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppLyricsConfig.wordBackgroundOverhang),
                decoration: BoxDecoration(
                  color: AppLyricsConfig.wordHighlightBackgroundColor,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: w,
              );
            }
            return w;
          },
        );
      } else {
        coreWidget = buildStrokedLine(text: coreStr, color: color, size: size);

        if (useBg && isActive && coreStr.isNotEmpty) {
          coreWidget = Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppLyricsConfig.wordBackgroundOverhang),
            decoration: BoxDecoration(
              color: AppLyricsConfig.wordHighlightBackgroundColor,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: coreWidget,
          );
        }
      }

      widgets.add(coreWidget);

      if (trailingStr.isNotEmpty) {
        widgets
            .add(Text(trailingStr, style: fillStyle(Colors.transparent, size)));
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: widgets,
      );
    }

    Widget currentLineWidget;

    if (currentLine == null) {
      currentLineWidget = buildStrokedLine(
          text: '...',
          color: config.fontColor ?? AppLyricsConfig.fontColor,
          size: config.fontSize ?? AppLyricsConfig.inactiveFontSize);
    } else if (config.lyricStyle == LyricsStyle.typewriter) {
      String twText = currentLine.text;
      if (config.fontCase == 'UPPERCASE') twText = twText.toUpperCase();
      if (config.fontCase == 'LOWERCASE') twText = twText.toLowerCase();

      currentLineWidget = _TypewriterLineWidget(
        key: ValueKey('typewriter_${lyricsState.currentLineIndex}'),
        text: twText,
        speedParam: config.lyricStyleParam,
        isPlaying: isPlaying,
        fillStyle: fillStyle(AppLyricsConfig.wordHighlightColor,
            config.fontSize ?? AppLyricsConfig.activeFontSize),
        strokeStyle:
            strokeStyle(config.fontSize ?? AppLyricsConfig.activeFontSize),
      );

      if (config.lyricEffect != LyricEffect.none && config.effectEnabled) {
        currentLineWidget = _LyricEffectWrapper(
          effect: config.lyricEffect,
          isPlaying: isPlaying,
          extractor: _waveformExtractor,
          player: _player!,
          param: config.lyricEffectParam,
          builder: (context, effectColor, effectOpacity, effectScale) {
            Widget w = _TypewriterLineWidget(
              key: ValueKey('typewriter_${lyricsState.currentLineIndex}'),
              text: twText,
              speedParam: config.lyricStyleParam,
              isPlaying: isPlaying,
              fillStyle: fillStyle(
                  effectColor ?? AppLyricsConfig.wordHighlightColor,
                  config.fontSize ?? AppLyricsConfig.activeFontSize),
              strokeStyle: strokeStyle(
                  config.fontSize ?? AppLyricsConfig.activeFontSize),
            );

            if (effectScale != 1.0) {
              w = Transform.scale(scale: effectScale, child: w);
            }
            if (effectOpacity != 1.0) {
              w = Opacity(opacity: effectOpacity, child: w);
            }
            return w;
          },
        );
      }
    } else if (lyricsState.hasWordTimingsForCurrent) {
      final activeWordIdx = lyricsState.currentWordIndex;
      final rows = <Widget>[];
      var currentWords = <Widget>[];

      for (int i = 0; i < currentLine.words.length; i++) {
        final wText = currentLine.words[i].text;
        final isActive = (i == activeWordIdx);

        final parts = wText.split('\n');
        for (int pIdx = 0; pIdx < parts.length; pIdx++) {
          if (pIdx > 0) {
            // We crossed a \n boundary. End the current row.
            rows.add(Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: currentWords,
            ));
            currentWords = [];
          }
          if (parts[pIdx].isNotEmpty || pIdx == 0) {
            currentWords.add(buildWordBlock(parts[pIdx], isActive));
          }
        }
      }

      if (currentWords.isNotEmpty) {
        rows.add(Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: currentWords,
        ));
      }

      currentLineWidget = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: rows,
      );
    } else {
      final rows = <Widget>[];
      final parts = currentLine.text.split('\n');
      bool hasHighlightedFirstWord = false;

      for (int pIdx = 0; pIdx < parts.length; pIdx++) {
        final text = parts[pIdx];
        if (text.isEmpty) continue;

        if (!hasHighlightedFirstWord) {
          final spaceIdx = text.indexOf(' ');
          if (spaceIdx > 0 && spaceIdx < text.length) {
            final firstWord = text.substring(0, spaceIdx);
            final rest = text.substring(spaceIdx);

            rows.add(Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildWordBlock(firstWord, true),
                buildWordBlock(rest, false),
              ],
            ));
          } else {
            rows.add(buildWordBlock(text, true));
          }
          hasHighlightedFirstWord = true;
        } else {
          rows.add(Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildWordBlock(text, false),
            ],
          ));
        }
      }

      currentLineWidget = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: rows,
      );
    }

    double maxEffectScale = 1.0;
    if (config.lyricEffect == LyricEffect.flicker && config.effectEnabled) {
      final double multiplier =
          double.tryParse(config.lyricEffectParam ?? '1.0') ?? 1.0;
      maxEffectScale = 1.0 + (0.5 * multiplier);
    }

    return FractionallySizedBox(
        widthFactor: 1.0 / maxEffectScale,
        heightFactor: 1.0 / maxEffectScale,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (lyricsLineMode == 3 && prevLine.isNotEmpty)
                buildStrokedLine(
                    text: prevLine,
                    color: (config.fontColor ?? AppLyricsConfig.fontColor)
                        .withValues(
                            alpha: config.fontAlpha ??
                                AppLyricsConfig.wordNonHighlightFade),
                    size: AppLyricsConfig.surroundingLineFontSize),
              if (lyricsLineMode == 3 && prevLine.isNotEmpty)
                const SizedBox(height: 24),
              currentLineWidget,
              if (lyricsLineMode == 3) const SizedBox(height: 24),
              if (lyricsLineMode == 3 && nextLine.isNotEmpty)
                buildStrokedLine(
                    text: nextLine,
                    color: (config.fontColor ?? AppLyricsConfig.fontColor)
                        .withValues(
                            alpha: config.fontAlpha ??
                                AppLyricsConfig.wordNonHighlightFade),
                    size: AppLyricsConfig.surroundingLineFontSize),
            ],
          ),
        ));
  }

  BoxFit _parseBoxFit(String? fit) {
    if (fit == null) return BoxFit.cover;
    switch (fit.toUpperCase()) {
      case 'FILL':
        return BoxFit.fill;
      case 'CONTAIN':
        return BoxFit.contain;
      case 'FITWIDTH':
        return BoxFit.fitWidth;
      case 'FITHEIGHT':
        return BoxFit.fitHeight;
      case 'NONE':
        return BoxFit.none;
      case 'SCALEDOWN':
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }

  BlendMode? _parseBlendMode(String? blend) {
    if (blend == null) return null;
    switch (blend.toUpperCase()) {
      case 'NORMAL':
      case 'SRCOVER':
        return BlendMode.srcOver;
      case 'SCREEN':
        return BlendMode.screen;
      case 'MULTIPLY':
        return BlendMode.multiply;
      case 'OVERLAY':
        return BlendMode.overlay;
      case 'DARKEN':
        return BlendMode.darken;
      case 'LIGHTEN':
        return BlendMode.lighten;
      case 'COLORBURN':
        return BlendMode.colorBurn;
      case 'COLORDODGE':
        return BlendMode.colorDodge;
      case 'EXCLUSION':
        return BlendMode.exclusion;
      case 'DIFFERENCE':
        return BlendMode.difference;
      case 'CLEAR':
        return BlendMode.clear;
      default:
        return null;
    }
  }

  Widget _buildUnifiedMediaDisplay({
    required BuildContext context,
    required LyricsViewController lyricsState,
    required ThemeData theme,
    required int lyricsLineMode,
    required PlayerController controller,
    required bool isFullScreen,
  }) {
    final activeVisualizer =
        lyricsState.currentConfig.audioVisualizer ?? _currentVisualizer;

    final activeVisualizerMode =
        lyricsState.currentConfig.audioVisualizerMode ??
            AudioVisualizerMode.standard;

    final activeBands = lyricsState.currentConfig.audioVisualizerBands ?? 32;

    final activeBlockHeight =
        lyricsState.currentConfig.audioVisualizerBlockHeight ?? 0;

    final colorStyle = lyricsState.currentConfig.audioVisualizerColorStyle ??
        AudioVisualizerColorStyle.solid;
    final colorStart = lyricsState.currentConfig.audioVisualizerColorStart ??
        theme.colorScheme.primary;
    final colorEnd = lyricsState.currentConfig.audioVisualizerColorEnd;

    final alphaStart = lyricsState.currentConfig.audioVisualizerAlphaStart;
    final alphaEnd = lyricsState.currentConfig.audioVisualizerAlphaEnd;

    return CameraView(
        shakeIntensity: lyricsState.currentConfig.cameraShake ?? 0.0,
        cameraZoom: lyricsState.currentConfig.cameraZoom ?? 1.0,
        cameraPanX: lyricsState.currentConfig.cameraPanX ?? 0.0,
        cameraPanY: lyricsState.currentConfig.cameraPanY ?? 0.0,
        cameraRotation: lyricsState.currentConfig.cameraRotation ?? 0.0,
        player: controller,
        extractor: _waveformExtractor,
        visualizerMode: activeVisualizerMode,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!widget.isElementPreview)
              Container(
                color: lyricsState.currentConfig.bgColor ??
                    AppLyricsConfig.backgroundColor,
              ),

            if (!widget.isElementPreview)
              const Center(
                child: Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.grey,
                ),
              ),

            if (!widget.isElementPreview && activeVisualizer != VisualizerType.none)
              IgnorePointer(
                child: RepaintBoundary(
                  child: CustomAudioVisualizer(
                    player: controller,
                    extractor: _waveformExtractor,
                    type: activeVisualizer,
                    mode: activeVisualizerMode,
                    bands: activeBands,
                    blockHeight: activeBlockHeight,
                    colorStyle: colorStyle,
                    colorStart: colorStart,
                    colorEnd: colorEnd,
                    alphaSegmentStart: alphaStart,
                    alphaSegmentEnd: alphaEnd,
                  ),
                ),
              ),

            // Draw all dynamic targetable layers bottom-to-top natively respecting hierarchies!
            ...(() {
              Set<String> processedIds = {};
              
              Widget buildEvaluatedLayer(dynamic layer, {List<Widget Function(Widget)> inheritedWrappers = const []}) {
              processedIds.add(layer.id);
              Widget layerContent = const SizedBox.shrink();

              if (layer.type == 'COLOR') {
                layerContent =
                    Container(color: layer.color ?? Colors.transparent);
              } else if (layer.type == 'VIDEO') {
                // Placeholder for future video implementation
                layerContent = Container(color: layer.color ?? Colors.black);
              } else if (layer.type == 'PARTICLES') {
                // Empty, the particles stack will be added below
                layerContent = const SizedBox.shrink();
              } else if (layer.type == 'SCRIPT') {
                layerContent = _LuaScriptWidget(script: layer.script);
              } else if ((layer.type == 'SHADER' ||
                      layer.type == 'STATIC_SHADER') &&
                  layer.path != null) {
                Map<String, dynamic> resolvedVars = {};
                if (layer.items.isNotEmpty) {
                  for (var entry in layer.items.entries) {
                    String k = entry.key.toUpperCase();
                    // Custom Shader Aliasing Pipeline
                    if (layer.path!.contains('bg_gradient')) {
                      if (k == 'SPEED') k = 'P1';
                      if (k == 'ZOOM') k = 'P2';
                      if (k == 'SHIFT_SPEED') k = 'P3';
                      if (k == 'BASE_COLOR') k = 'COLOR_1';
                      if (k == 'ACCENT_COLOR') k = 'COLOR_2';
                      if (k == 'HIGHLIGHT_COLOR') k = 'COLOR_3';
                      if (k == 'SHADOW_COLOR') k = 'COLOR_4';
                      if (k == 'WAVE_INTENSITY') k = 'AUDIO_MODULATION';
                    } else if (layer.path!.contains('audio_ring')) {
                      if (k == 'RADIUS') k = 'P1';
                      if (k == 'THICKNESS') k = 'P2';
                      if (k == 'ROT_SPEED') k = 'P3';
                      if (k == 'RING_COLOR') k = 'COLOR_1';
                      if (k == 'GLOW_COLOR') k = 'COLOR_2';
                      if (k == 'PULSE_STRENGTH') k = 'AUDIO_MODULATION';
                    } else if (layer.path!.contains('fire')) {
                      if (k == 'BURN_SPEED') k = 'P1';
                      if (k == 'INTENSITY') k = 'P2';
                      if (k == 'HEAT') k = 'P3';
                      if (k == 'CORE_COLOR') k = 'COLOR_1';
                      if (k == 'EDGE_COLOR') k = 'COLOR_2';
                      if (k == 'FLAME_BOUNCE') k = 'AUDIO_MODULATION';
                    } else if (layer.path!.contains('vignette')) {
                      if (k == 'INTENSITY') k = 'P1';
                      if (k == 'SPREAD') k = 'P2';
                      if (k == 'VIGNETTE_COLOR') k = 'COLOR_1';
                    } else if (layer.path!.contains('bg_kaleidoscope')) {
                      if (k == 'SPEED') k = 'P1';
                      if (k == 'COMPLEXITY') k = 'P2';
                      if (k == 'ZOOM') k = 'P3';
                      if (k == 'STRANDS') k = 'P4';
                      if (k == 'AUDIO_REACTIVE') k = 'AUDIO_MODULATION';
                      if (k == 'BASE_COLOR') k = 'COLOR_1';
                      if (k == 'ACCENT_COLOR') k = 'COLOR_2';
                    } else if (layer.path!.contains('cool_ocean_wave')) {
                      if (k == 'WAVE_SPEED') k = 'P1';
                      if (k == 'WAVE_HEIGHT') k = 'P2';
                      if (k == 'TIDE') k = 'P3';
                      if (k == 'SHORE_COLOR') k = 'COLOR_1';
                      if (k == 'DEEP_COLOR') k = 'COLOR_2';
                    }
                    
                    dynamic itemObj = entry.value;
                    if (itemObj != null) {
                      try {
                        resolvedVars[k] = (itemObj.runtimeType.toString() == 'PropertyItem') 
                          ? itemObj.evaluateAt(controller.position.inMilliseconds)
                          : itemObj;
                      } catch (e) {
                         resolvedVars[k] = itemObj;
                      }
                    }
                  }
                }

                Color? c1 =
                    layer.shaderColor1 ?? (resolvedVars['COLOR_1'] as Color?);
                Color? c2 =
                    layer.shaderColor2 ?? (resolvedVars['COLOR_2'] as Color?);
                Color? c3 =
                    layer.shaderColor3 ?? (resolvedVars['COLOR_3'] as Color?);
                Color? c4 =
                    layer.shaderColor4 ?? (resolvedVars['COLOR_4'] as Color?);
                double? aMod = layer.shaderAudioModulation ??
                    (resolvedVars['AUDIO_MODULATION'] as double?);

                List<double> uniformsList = [];
                // Process dynamic variables map via aliased dictionary
                if (resolvedVars.isNotEmpty) {
                  int maxKey = 0;
                  for (var k in resolvedVars.keys) {
                    if (k.startsWith('P')) {
                      int? idx = int.tryParse(k.substring(1));
                      if (idx != null && idx > maxKey) maxKey = idx;
                    } else if (k.startsWith('LAYER_SHADER_P')) {
                      int? idx = int.tryParse(k.substring(14));
                      if (idx != null && idx > maxKey) maxKey = idx;
                    }
                  }
                  if (maxKey > 0) {
                    uniformsList = List<double>.filled(maxKey, 1.0);
                    for (var k in resolvedVars.keys) {
                      if (k.startsWith('P')) {
                        int? idx = int.tryParse(k.substring(1));
                        if (idx != null && idx > 0) {
                          uniformsList[idx - 1] =
                              (resolvedVars[k] as num?)?.toDouble() ?? 1.0;
                        }
                      } else if (k.startsWith('LAYER_SHADER_P')) {
                        int? idx = int.tryParse(k.substring(14));
                        if (idx != null && idx > 0) {
                          uniformsList[idx - 1] =
                              (resolvedVars[k] as num?)?.toDouble() ?? 1.0;
                        }
                      }
                    }
                  }
                }

                layerContent = ShaderLayer(
                  assetPath: layer.path!,
                  isPlaying: layer.type == 'STATIC_SHADER'
                      ? false
                      : controller.isPlaying,
                  player: controller,
                  extractor: _waveformExtractor,
                  color1: c1,
                  color2: c2,
                  color3: c3,
                  color4: c4,
                  audioModulation: aMod,
                  customUniforms: uniformsList,
                  repaintCount: layer.repaintCount,
                );

                if (layer.type == 'STATIC_SHADER') {
                  layerContent = RepaintBoundary(child: layerContent);
                }
              } else if (layer.type == 'RIVE' && layer.path != null) {
                Map<String, dynamic> evalItems = {};
                for (var e in layer.items.entries) {
                  dynamic v = e.value;
                  evalItems[e.key] = (v != null && v.runtimeType.toString() == 'PropertyItem') 
                      ? v.evaluateAt(controller.position.inMilliseconds) 
                      : v;
                }
                layerContent = RiveLayer(
                  assetPath: layer.path!,
                  isPlaying: controller.isPlaying,
                  variables: evalItems,
                );
              } else if (layer.type == 'SHADER_KIT' && layer.path != null) {
                dynamic itemV(String key) {
                  var t = layer.items[key];
                  if (t == null) return null;
                  return (t.runtimeType.toString() == 'PropertyItem') ? t.evaluateAt(controller.position.inMilliseconds) : t;
                }
                switch (layer.path!.toUpperCase()) {
                  case 'CLOUDS':
                    layerContent = CloudShader(
                      animate: controller.isPlaying,
                      skyColor: itemV('COLOR_1') as Color?,
                      cloudColor: itemV('COLOR_2') as Color?,
                      cloudDensity: (itemV('DENSITY') as num?)?.toDouble() ?? 1.0,
                      noisiness: (itemV('NOISE') as num?)?.toDouble() ?? 0.35,
                      windSpeed: (itemV('SPEED') as num?)?.toDouble() ?? 1.0,
                      flowSpeed: (itemV('FLOW') as num?)?.toDouble() ?? 0.1,
                      child: Container(color: layer.color ?? Colors.transparent),
                    );
                    break;
                  case 'RAIN':
                    layerContent = WeatherRainLayer(
                      enabled: controller.isPlaying,
                      rainAmount: (itemV('AMOUNT') as num?)?.toDouble() ?? 0.75,
                      speed: (itemV('SPEED') as num?)?.toDouble() ?? 1.0,
                      maxBlur: (itemV('BLUR') as num?)?.toDouble() ?? 6.0,
                      child: Container(color: layer.color ?? Colors.transparent),
                    );
                    break;
                  case 'FROST':
                    layerContent = FrostBlurLayer(
                      distortion: (itemV('DISTORTION') as num?)?.toDouble() ?? 0.045,
                      noiseScale: (itemV('NOISE') as num?)?.toDouble() ?? 6.0,
                      directionalMix: (itemV('DIRECTIONAL') as num?)?.toDouble() ?? 0.25,
                      blend: (itemV('BLEND') as num?)?.toDouble() ?? 1.0,
                      child: Container(color: layer.color ?? Colors.transparent),
                    );
                    break;
                  case 'GLASS':
                    layerContent = LiquidGlassContainer(
                      glassEnabled: true,
                      child: Container(color: layer.color ?? Colors.transparent),
                    );
                    break;
                  default:
                    layerContent = const SizedBox.shrink();
                }
              } else {
                // Default to IMAGE
                if (layer.path != null) {
                  layerContent = Image.asset(
                    layer.path!,
                    fit: _parseBoxFit(layer.fit),
                    color: layer.color,
                  );
                }
              }
              
              // Hierarchical Dom mapping injection mimicking Unity
              var nestedChildren = lyricsState.currentConfig.bgLayers.values.where((l) => l.parentId == layer.id).toList();
              if (nestedChildren.isNotEmpty || layer.type == 'FOLDER') {
                 layerContent = const SizedBox.shrink(); // No nested stack! Handled recursively flat!
              }

              if ((layer.scaleX != null && layer.scaleX != 1.0) || (layer.scaleY != null && layer.scaleY != 1.0)) {
                layerContent = Transform(
                  alignment: Alignment(layer.pivotX ?? 0.0, layer.pivotY ?? 0.0),
                  transform: Matrix4.identity()..scale(layer.scaleX ?? 1.0, layer.scaleY ?? 1.0),
                  child: layerContent,
                );
              }

              if ((layer.posX != null && layer.posX != 0.0) ||
                  (layer.posY != null && layer.posY != 0.0)) {
                layerContent = FractionalTranslation(
                  translation: Offset(layer.posX ?? 0.0, layer.posY ?? 0.0),
                  child: layerContent,
                );
              }

              if ((layer.rotationX != null && layer.rotationX != 0.0) ||
                  (layer.rotationY != null && layer.rotationY != 0.0) ||
                  (layer.rotationZ != null && layer.rotationZ != 0.0)) {
                layerContent = Transform(
                  alignment: Alignment(layer.pivotX ?? 0.0, layer.pivotY ?? 0.0),
                  transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateX((layer.rotationX ?? 0.0) * (math.pi / 180.0))
                      ..rotateY((layer.rotationY ?? 0.0) * (math.pi / 180.0))
                      ..rotateZ((layer.rotationZ ?? 0.0) * (math.pi / 180.0)),
                  child: layerContent,
                );
              }

              if (layer.blur != null && layer.blur! > 0.0) {
                layerContent = ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: layer.blur!,
                    sigmaY: layer.blur!,
                  ),
                  child: layerContent,
                );
              }

              if (layer.particleType != null &&
                  layer.particleType != ParticleType.none) {
                layerContent = Stack(
                  fit: StackFit.passthrough,
                  children: [
                    layerContent,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ParticleEngine(
                          type: layer.particleType!,
                          speed: layer.particleSpeed ?? 1.0,
                          count: (layer.particleCount ?? 50.0).toInt(),
                          isPlaying: controller.isPlaying,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (layer.tiltEnabled) {
                final Widget capturedContent = layerContent; // Explicit immutable assignment blocks reactive recursion!
                layerContent = LayoutBuilder(
                  builder: (context, constraints) {
                    double overscan = 1.30; // 30% Extra padding safely buffers out all parallax yaw exposing natively
                    return OverflowBox(
                      maxWidth: constraints.maxWidth * overscan,
                      maxHeight: constraints.maxHeight * overscan,
                      child: SizedBox(
                        width: constraints.maxWidth * overscan,
                        height: constraints.maxHeight * overscan,
                        child: Tilt(
                          tiltStreamController: widget.tiltStreamController,
                          clipBehavior: Clip.none,
                          tiltConfig: TiltConfig(
                            angle: (layer.tiltDepth).clamp(0.0, 90.0),
                            enableOutsideAreaMove: true,
                            enableRevert: false,
                          ),
                          child: Center(
                             child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: capturedContent, // Render strictly inner graph safely
                             ),
                          ),
                        ),
                      ),
                    );
                  }
                );
              }

              final BlendMode? bm = _parseBlendMode(layer.blendMode);
              Widget finalLayerContext = layerContent;
              
              if (bm != null) {
                finalLayerContext = BlendMask(
                  blendMode: bm,
                  opacity: (layer.opacity ?? 1.0).clamp(0.0, 1.0),
                  child: finalLayerContext,
                );
              } else {
                if (layer.opacity != null && layer.opacity! < 1.0) {
                  finalLayerContext = Opacity(
                    opacity: layer.opacity!.clamp(0.0, 1.0),
                    child: finalLayerContext,
                  );
                }
              }

              // Apply inherited wrappers sequentially BEFORE Positioned.fill safely
              for (var wrapper in inheritedWrappers) {
                  finalLayerContext = wrapper(finalLayerContext);
              }

              return Positioned.fill(
                key: ValueKey(layer.id),
                child: finalLayerContext,
              );
              }

              List<Widget> rootWidgets = [];

              void renderLayerAndChildren(dynamic l, List<Widget Function(Widget)> inherited) {
                if (processedIds.contains(l.id)) return;
                processedIds.add(l.id);
                
                // Only FOLDER elements propagate their explicitly declared layout properties strictly evaluating down recursively mapped perfectly.
                List<Widget Function(Widget)> myWrappers = [];
                if ((l.scaleX != null && l.scaleX != 1.0) || (l.scaleY != null && l.scaleY != 1.0)) {
                  myWrappers.add((child) => Transform(
                    alignment: Alignment(l.pivotX ?? 0.0, l.pivotY ?? 0.0),
                    transform: Matrix4.identity()..scale(l.scaleX ?? 1.0, l.scaleY ?? 1.0),
                    child: child,
                  ));
                }
                if ((l.posX != null && l.posX != 0.0) || (l.posY != null && l.posY != 0.0)) {
                  myWrappers.add((child) => FractionalTranslation(
                    translation: Offset(l.posX ?? 0.0, l.posY ?? 0.0),
                    child: child,
                  ));
                }
                if ((l.rotationX != null && l.rotationX != 0.0) ||
                    (l.rotationY != null && l.rotationY != 0.0) ||
                    (l.rotationZ != null && l.rotationZ != 0.0)) {
                  myWrappers.add((child) => Transform(
                    alignment: Alignment(l.pivotX ?? 0.0, l.pivotY ?? 0.0),
                    transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // perspective
                        ..rotateX((l.rotationX ?? 0.0) * (math.pi / 180.0))
                        ..rotateY((l.rotationY ?? 0.0) * (math.pi / 180.0))
                        ..rotateZ((l.rotationZ ?? 0.0) * (math.pi / 180.0)),
                    child: child,
                  ));
                }
                if (l.opacity != null && l.opacity! < 1.0) {
                  myWrappers.add((child) => Opacity(opacity: l.opacity!.clamp(0.0, 1.0), child: child));
                }
                if (l.blur != null && l.blur! > 0.0) {
                  myWrappers.add((child) => ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: l.blur!, sigmaY: l.blur!), child: child));
                }
                
                List<Widget Function(Widget)> combined = [...myWrappers, ...inherited];
                
                rootWidgets.add(buildEvaluatedLayer(l, inheritedWrappers: inherited));
                
                var nested = lyricsState.currentConfig.bgLayers.values.where((child) => child.parentId == l.id).toList();
                for (var c in nested) {
                  // Pass the COMBINED transforms down cleanly to children organically mapped perfectly bounding constraints universally logically sequentially natively flawless!
                  renderLayerAndChildren(c, combined);
                }
              }

              final roots = lyricsState.currentConfig.bgLayers.values
                 .where((l) => l.parentId == null || !lyricsState.currentConfig.bgLayers.containsKey(l.parentId)).toList();
                 
              for (var l in roots) {
                renderLayerAndChildren(l, []);
              }
              
              // Safety fallback rendering unrendered cycle-locked elements natively at root
              for (var l in lyricsState.currentConfig.bgLayers.values) {
                if (!processedIds.contains(l.id)) {
                   renderLayerAndChildren(l, []);
                }
              }

              return rootWidgets;
            })(),
            
            // Support rendering explicitly synced timing data in Element mode.
            Center(
                child: Padding(
                  padding: EdgeInsets.all(isFullScreen ? 32.0 : 16.0),
                  child: Builder(
                    builder: (context) {
                      if (lyricsState.isLoading) {
                        return const CircularProgressIndicator(
                            color: Colors.white);
                      } else if (lyricsState.errorMessage != null ||
                          lyricsState.lines.isEmpty) {
                        return Text(
                          lyricsState.errorMessage ?? 'Lyrics not available',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: isFullScreen
                                ? Colors.black54
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                            fontWeight: FontWeight.bold,
                            fontSize: isFullScreen ? null : 16.0,
                          ),
                          textAlign: TextAlign.center,
                        );
                      }

                      return _buildLyricsDisplay(lyricsState, theme,
                          lyricsLineMode, controller.isPlaying);
                  },
                ),
              ),
            ),
          ],
        ));
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  IconData _getRepeatIcon(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return Icons.repeat;
      case LoopMode.all:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
    }
  }

  void _cycleRepeatMode(PlayerController controller) {
    LoopMode next;
    switch (controller.loopMode) {
      case LoopMode.off:
        next = LoopMode.all;
        break;
      case LoopMode.all:
        next = LoopMode.one;
        break;
      case LoopMode.one:
        next = LoopMode.off;
        break;
    }
    controller.setRepeatMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orientation = MediaQuery.of(context).orientation;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LyricsViewController>().currentOrientation = orientation;
      }
    });

    final lyricsLineMode =
        context.watch<OfflineCacheSettingsController>().lyricsLineMode;

    if (widget.isElementPreview) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: ExcludeSemantics(
          child: Consumer<PlayerController>(
             builder: (context, controller, child) {
               return Consumer<LyricsViewController>(
                 builder: (context, lyricsState, child) {
                    return _buildUnifiedMediaDisplay(
                       context: context,
                       lyricsState: lyricsState,
                       theme: theme,
                       lyricsLineMode: lyricsLineMode,
                       controller: controller,
                       isFullScreen: true,
                    );
                 }
               );
             }
          )
        )
      );
    }

    return ActiveScreenScope(
      screenName: 'Now Playing',
      child: Scaffold(
        appBar: _isFullScreenMedia
          ? null
          : AppBar(
              title: const Text('Now Playing'),
              actions: MediaQuery.of(context).size.width < 350 ? null : [
                IconButton(
                  icon: const Icon(Icons.graphic_eq),
                  tooltip: 'Cycle Visualizer',
                  onPressed: _cycleVisualizer,
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  tooltip: 'Add to Playlist',
                  onPressed: () {
                    final currentItem =
                        context.read<PlayerController>().currentItem;
                    if (currentItem != null) {
                      final domainItem = Item(
                        id: currentItem.id,
                        title: currentItem.title,
                        artist: currentItem.artist,
                        assetFolderId: null,
                        audioUrl: '',
                      );
                      showModalBottomSheet(
                        context: context,
                        builder: (context) =>
                            AddToPlaylistSheet(item: domainItem),
                      );
                    }
                  },
                ),
                Selector<PlayerController, ItemSource?>(
                  selector: (context, controller) => controller.currentItem,
                  builder: (context, currentItem, child) {
                    if (currentItem == null) return const SizedBox.shrink();
                    return StreamBuilder<bool>(
                      stream: context
                          .read<FavoritesDao>()
                          .isItemFavorited(currentItem.id),
                      builder: (context, snapshot) {
                        final isFavorited = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color:
                                isFavorited ? theme.colorScheme.primary : null,
                          ),
                          tooltip: isFavorited
                              ? 'Remove from Favorites'
                              : 'Add to Favorites',
                          onPressed: () {
                            context
                                .read<FavoritesDao>()
                                .toggleItem(currentItem.id);
                          },
                        );
                      },
                    );
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'editor') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VisualEditorScreen(),
                        ),
                      );
                    } else if (value == 'clear') {
                      context.read<PlayerController>().stopAndClear();
                      Navigator.pop(context); // Go back if we clear the player
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem(
                        value: 'editor',
                        child: Text('Open Visual Editor'),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Stop & Clear Queue'),
                      ),
                    ];
                  },
                ),
              ],
            ),

      body: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned.fill(
              child: Consumer<PlayerController>(
                builder: (context, controller, child) {
          final currentItem = controller.currentItem;
          final error = controller.error;

          if (currentItem == null) {
            return const Center(child: Text('Nothing is currently playing.'));
          }

          final durationStr = _formatDuration(controller.duration);
          final positionStr = _formatDuration(
            _dragValue != null
                ? Duration(milliseconds: _dragValue!.round())
                : controller.position,
          );

          // Guard slider values
          final durationMs =
              controller.duration?.inMilliseconds.toDouble() ?? 0.0;
          final positionMs = controller.position.inMilliseconds.toDouble();
          final sliderMax = max(durationMs, 0.0);
          final sliderValue = min(_dragValue ?? positionMs, sliderMax);

          final artworkWidget = RegisteredElement(
            id: 'now_playing_img_artwork',
            meta: const {'type': 'Image'},
            child: Hero(
              tag: 'artwork_${currentItem.id}',
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isFullScreenMedia = true;
                    _showFullScreenControls = false;
                  });
                },
                child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: Consumer<LyricsViewController>(
                      builder: (context, lyricsState, child) {
                        return _buildUnifiedMediaDisplay(
                          context: context,
                          lyricsState: lyricsState,
                          theme: theme,
                          lyricsLineMode: lyricsLineMode,
                          controller: controller,
                          isFullScreen: false,
                        );
                      },
                    ),
                  ),
                ),
              ),
              ),
            ),
          );

          final metadataWidget = RegisteredElement(
            id: 'now_playing_text_metadata',
            meta: const {'type': 'Text'},
            child: Column(
              children: [
                Text(
                  currentItem.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currentItem.artist ?? AppStrings.mockItemDescription,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );

          final scrubberWidget = RegisteredElement(
            id: 'now_playing_scrubber_bar',
            meta: const {'type': 'Toolbar'},
            child: Row(
              children: [
                Text(positionStr, style: theme.textTheme.labelMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4.0,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12.0),
                    ),
                    child: Slider(
                      value: sliderMax > 0 ? sliderValue : 0.0,
                      min: 0.0,
                      max: sliderMax > 0 ? sliderMax : 1.0,
                      onChanged: (value) {
                        if (sliderMax > 0) {
                          setState(() {
                            _dragValue = value;
                          });
                        }
                      },
                      onChangeEnd: (value) async {
                        if (sliderMax > 0) {
                          await controller
                              .seekTo(Duration(milliseconds: value.round()));
                        }
                        setState(() {
                          _dragValue = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(durationStr, style: theme.textTheme.labelMedium),
              ],
            ),
          );

          final controlsWidget = Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RegisteredElement(
                 id: 'now_playing_btn_shuffle',
                 meta: const {'type': 'Button'},
                 child: IconButton(
                   icon: Icon(
                     Icons.shuffle,
                     color: controller.isShuffled
                         ? theme.colorScheme.primary
                         : theme.colorScheme.onSurface,
                   ),
                   iconSize: 28,
                   onPressed: () => controller.toggleShuffle(),
                 )
              ),
              RegisteredElement(
                 id: 'now_playing_btn_prev',
                 meta: const {'type': 'Button'},
                 child: IconButton(
                   icon: const Icon(Icons.skip_previous),
                   iconSize: 42,
                   onPressed: controller.queue.length > 1
                       ? () => controller.previous()
                       : null,
                 )
              ),
              RegisteredElement(
                 id: 'now_playing_btn_playpause',
                 meta: const {'type': 'Button'},
                 child: IconButton(
                   icon: Icon(controller.isPlaying
                       ? Icons.pause_circle_filled
                       : Icons.play_circle_fill),
                   iconSize: 72,
                   color: theme.colorScheme.primary,
                   onPressed: () => controller.togglePlayPause(),
                 )
              ),
              RegisteredElement(
                 id: 'now_playing_btn_next',
                 meta: const {'type': 'Button'},
                 child: IconButton(
                   icon: const Icon(Icons.skip_next),
                   iconSize: 42,
                   onPressed: controller.queue.length > 1
                       ? () => controller.next()
                       : null,
                 )
              ),
              RegisteredElement(
                 id: 'now_playing_btn_repeat',
                 meta: const {'type': 'Button'},
                 child: IconButton(
                   icon: Icon(
                     _getRepeatIcon(controller.loopMode),
                     color: controller.loopMode != LoopMode.off
                         ? theme.colorScheme.primary
                         : theme.colorScheme.onSurface,
                   ),
                   iconSize: 28,
                   onPressed: () => _cycleRepeatMode(controller),
                 )
              ),
            ],
          );

          final fullScreenScrubberWidget = Row(
            children: [
              Text(positionStr,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Colors.white)),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12.0),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white38,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: sliderMax > 0 ? sliderValue : 0.0,
                    min: 0.0,
                    max: sliderMax > 0 ? sliderMax : 1.0,
                    onChanged: (value) {
                      if (sliderMax > 0) {
                        setState(() {
                          _dragValue = value;
                        });
                      }
                    },
                    onChangeEnd: (value) async {
                      if (sliderMax > 0) {
                        await controller
                            .seekTo(Duration(milliseconds: value.round()));
                      }
                      setState(() {
                        _dragValue = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(durationStr,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Colors.white)),
            ],
          );

          final fullScreenControlsWidget = Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: controller.isShuffled ? Colors.white : Colors.white54,
                ),
                iconSize: 28,
                onPressed: () => controller.toggleShuffle(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                iconSize: 42,
                onPressed: controller.queue.length > 1
                    ? () => controller.previous()
                    : null,
              ),
              IconButton(
                icon: Icon(
                  controller.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white,
                ),
                iconSize: 72,
                onPressed: () => controller.togglePlayPause(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                iconSize: 42,
                onPressed: controller.queue.length > 1
                    ? () => controller.next()
                    : null,
              ),
              IconButton(
                icon: Icon(
                  _getRepeatIcon(controller.loopMode),
                  color: controller.loopMode != LoopMode.off
                      ? Colors.white
                      : Colors.white54,
                ),
                iconSize: 28,
                onPressed: () => _cycleRepeatMode(controller),
              ),
            ],
          );

          if (_isFullScreenMedia) {
            return Stack(
              children: [
                // Media Placeholder Layer
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFullScreenControls = !_showFullScreenControls;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Consumer<LyricsViewController>(
                    builder: (context, lyricsState, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildUnifiedMediaDisplay(
                          context: context,
                          lyricsState: lyricsState,
                          theme: theme,
                          lyricsLineMode: lyricsLineMode,
                          controller: controller,
                          isFullScreen: true,
                        ),
                      );
                    },
                  ),
                ),

                // Top Action Bar Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _showFullScreenControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_showFullScreenControls,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_fullscreen,
                                    color: Colors.black),
                                tooltip: 'Exit Media Mode',
                                onPressed: () {
                                  setState(() {
                                    _isFullScreenMedia = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Controls Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _showFullScreenControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_showFullScreenControls,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: SafeArea(
                          child: Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark().copyWith(
                                primary: theme.colorScheme.primary,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  fullScreenScrubberWidget,
                                  const SizedBox(height: 8),
                                  fullScreenControlsWidget,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: OrientationBuilder(
                builder: (context, orientation) {
                  if (orientation == Orientation.landscape) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: Center(child: artworkWidget)),
                              const SizedBox(height: 16),
                              metadataWidget,
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    'Error: $error',
                                    style: const TextStyle(color: Colors.red),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(height: 32),
                              scrubberWidget,
                              const SizedBox(height: 16),
                              controlsWidget,
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Portrait
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.red),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Expanded(
                        flex: 10,
                        child: Center(child: artworkWidget),
                      ),
                      const SizedBox(height: 16),
                      metadataWidget,
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      scrubberWidget,
                      const SizedBox(height: 8),
                      controlsWidget,
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
            ), // closes SafeArea

          ],
        ); // returns the Stack
      }, // closes builder
    ), // closes Consumer
  ), // closes Positioned.fill
  ], // closes children of Stack
), // closes Stack
), // closes ExcludeSemantics
), // closes Scaffold
); // closes ActiveScreenScope
} // closes build
} // closes state


class _TypewriterLineWidget extends StatefulWidget {
  final String text;
  final TextStyle fillStyle;
  final TextStyle strokeStyle;
  final String? speedParam;
  final bool isPlaying;

  const _TypewriterLineWidget({
    super.key,
    required this.text,
    required this.fillStyle,
    required this.strokeStyle,
    this.speedParam,
    this.isPlaying = true,
  });

  @override
  State<_TypewriterLineWidget> createState() => _TypewriterLineWidgetState();
}

class _TypewriterLineWidgetState extends State<_TypewriterLineWidget> {
  Timer? _timer;
  int _visibleChars = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _TypewriterLineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _visibleChars = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.isPlaying) {
          _startTimer();
        } else {
          _timer?.cancel();
          _timer = null;
        }
      });
    } else if (widget.isPlaying != oldWidget.isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.isPlaying) {
          _startTimer();
        } else {
          _timer?.cancel();
          _timer = null;
        }
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();

    int cpm = AppLyricsConfig.typewriterCpm;
    if (widget.speedParam != null) {
      final parsed = int.tryParse(widget.speedParam!);
      if (parsed != null && parsed > 0) {
        cpm = parsed;
      }
    }

    final int msPerChar = 60000 ~/ cpm;

    _timer = Timer.periodic(Duration(milliseconds: msPerChar), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_visibleChars < widget.text.length) {
        setState(() {
          _visibleChars++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    // Ensure we don't exceed bounds if text changes rapidly
    final safeVisibleChars = _visibleChars.clamp(0, widget.text.length);
    final visibleText = widget.text.substring(0, safeVisibleChars);
    final hiddenText = widget.text.substring(safeVisibleChars);

    return Stack(
      alignment: Alignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: widget.strokeStyle,
            children: [
              TextSpan(text: visibleText),
              TextSpan(
                text: hiddenText,
                style: widget.strokeStyle.copyWith(
                  foreground: Paint()..color = Colors.transparent,
                ),
              ),
            ],
          ),
        ),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: widget.fillStyle,
            children: [
              TextSpan(text: visibleText),
              TextSpan(
                text: hiddenText,
                style: widget.fillStyle.copyWith(
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef LyricEffectBuilder = Widget Function(BuildContext context,
    Color? effectColor, double effectOpacity, double effectScale);

class _LyricEffectWrapper extends StatefulWidget {
  final LyricEffect effect;
  final bool isPlaying;
  final String? param;
  final WaveformExtractorService extractor;
  final PlayerController player;
  final LyricEffectBuilder builder;

  const _LyricEffectWrapper({
    this.param,
    required this.extractor,
    required this.player,
    required this.effect,
    required this.isPlaying,
    required this.builder,
  });

  @override
  State<_LyricEffectWrapper> createState() => _LyricEffectWrapperState();
}

class _LyricEffectWrapperState extends State<_LyricEffectWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Duration _getDuration() {
    int? ms;
    if (widget.param != null) {
      ms = int.tryParse(widget.param!);
    }

    if (widget.effect == LyricEffect.flicker) {
      return Duration(milliseconds: ms ?? 2000);
    } else {
      return Duration(milliseconds: ms ?? 2000); // 2s default
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _getDuration());

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _LyricEffectWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.effect != oldWidget.effect || widget.param != oldWidget.param) {
      _controller.duration = _getDuration();
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.effect == LyricEffect.none) {
      return widget.builder(context, null, 1.0, 1.0);
    }

    if (widget.effect == LyricEffect.flicker) {
      return StreamBuilder<Duration>(
        stream: widget.player.positionStream,
        initialData: widget.player.position,
        builder: (context, snapshot) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final position = snapshot.data ?? Duration.zero;
              final itemId = widget.player.currentItem?.id;
              final waveform = itemId != null
                  ? widget.extractor.getWaveform(itemId)
                  : null;

              double amp = 0.0;
              if (waveform != null && waveform.data.isNotEmpty) {
                int pixelIndex =
                    (position.inMilliseconds / 1000.0 * 60).floor();
                int dataIndex =
                    pixelIndex * 2 + 1; // max amplitude for this pixel
                if (dataIndex > 0 && dataIndex < waveform.data.length) {
                  int rawAmp = waveform.data[dataIndex];
                  int maxAmp = widget.extractor.getMaxAmplitude(itemId!);
                  amp = (rawAmp.abs() / maxAmp.toDouble()).clamp(0.0, 1.0);
                  amp = (amp * 1.5).clamp(0.0, 1.0); // Boost signal
                }
              }

              double multiplier = 1.0;
              if (widget.param != null) {
                multiplier = double.tryParse(widget.param!) ?? 1.0;
              }

              final double effectScale = 1.0 + (amp * 0.5 * multiplier);

              return widget.builder(context, null, 1.0, effectScale);
            },
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double opacity = 1.0;
        Color? color;

        if (widget.effect == LyricEffect.colorize) {
          final hue = _controller.value * 360.0;
          color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
        }

        return widget.builder(context, color, opacity, 1.0);
      },
    );
  }
}

class BlendMask extends SingleChildRenderObjectWidget {
  final BlendMode blendMode;
  final double opacity;

  const BlendMask({
    super.key,
    required this.blendMode,
    this.opacity = 1.0,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBlendMask(blendMode, opacity);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderBlendMask renderObject) {
    if (renderObject.blendMode != blendMode || renderObject.opacity != opacity) {
      renderObject.blendMode = blendMode;
      renderObject.opacity = opacity;
      renderObject.markNeedsPaint();
    }
  }
}

class _RenderBlendMask extends RenderProxyBox {
  BlendMode blendMode;
  double opacity;

  _RenderBlendMask(this.blendMode, this.opacity);

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    int alpha = (opacity * 255).clamp(0, 255).round();
    final Paint paint = Paint()..blendMode = blendMode;
    if (alpha != 255) {
      paint.color = Color.fromARGB(alpha, 0, 0, 0);
    }
    
    context.canvas.saveLayer(offset & size, paint);
    super.paint(context, offset);
    context.canvas.restore();
  }
}

class _LuaScriptWidget extends StatefulWidget {
  final String? script;
  const _LuaScriptWidget({this.script});

  @override
  State<_LuaScriptWidget> createState() => _LuaScriptWidgetState();
}

class _LuaScriptWidgetState extends State<_LuaScriptWidget> {
  String _output = '';

  @override
  void initState() {
    super.initState();
    _executeScript();
  }

  @override
  void didUpdateWidget(_LuaScriptWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script != oldWidget.script) {
      _executeScript();
    }
  }

  void _executeScript() {
    if (widget.script == null || widget.script!.isEmpty) {
      setState(() => _output = 'Empty Lua Script');
      return;
    }
    
    try {
      LuaState state = LuaState.newState();
      state.openLibs();
      
      final buffer = StringBuffer();
      // Overwrite the print function to capture output recursively
      state.register("print", (LuaState ls) {
        if (ls.getTop() > 0) {
          buffer.writeln(ls.toStr(1));
        }
        return 0;
      });
      
      state.loadString(widget.script!);
      state.call(0, 0);
      
      setState(() {
         // Display output, or 'Success' if it just executed silently without errors
         _output = buffer.isNotEmpty ? buffer.toString() : 'Success (No print output)';
      });
    } catch (e) {
      setState(() => _output = 'Lua Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      color: Colors.black.withOpacity(0.4),
      child: Text(
        _output,
        style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontFamily: 'monospace'),
        textAlign: TextAlign.center,
      ),
    );
  }
}
