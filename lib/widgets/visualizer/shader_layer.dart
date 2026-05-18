import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../state/player_controller.dart';
import '../../services/waveform_extractor_service.dart';

final Map<String, FragmentProgram> _shaderCache = {};

class ShaderLayer extends StatefulWidget {
  final String assetPath;
  final bool isPlaying;
  final PlayerController? player;
  final WaveformExtractorService? extractor;
  final Color? color1;
  final Color? color2;
  final Color? color3;
  final Color? color4;
  final double? audioModulation;
  final List<double> customUniforms;
  final int repaintCount;

  const ShaderLayer({
    super.key,
    required this.assetPath,
    this.isPlaying = true,
    this.player,
    this.extractor,
    this.color1,
    this.color2,
    this.color3,
    this.color4,
    this.audioModulation,
    this.customUniforms = const [],
    this.repaintCount = 0,
  });

  @override
  State<ShaderLayer> createState() => _ShaderLayerState();
}

class _ShaderLayerState extends State<ShaderLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  FragmentProgram? _program;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 1000));

    if (widget.isPlaying) {
      _controller.repeat();
    }

    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      if (_shaderCache.containsKey(widget.assetPath)) {
        if (mounted) {
          setState(() {
            _program = _shaderCache[widget.assetPath];
            _loadError = false;
          });
        }
        return;
      }
      
      final program = await FragmentProgram.fromAsset(widget.assetPath);
      _shaderCache[widget.assetPath] = program;
      
      if (mounted) {
        setState(() {
          _program = program;
          _loadError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shader ${widget.assetPath}: $e');
      if (mounted) {
        setState(() {
          _loadError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(ShaderLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assetPath != oldWidget.assetPath) {
      _loadShader();
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  double _getMasterAmplitude() {
    if (widget.player == null || widget.extractor == null) return 0.0;
    final itemId = widget.player!.currentItem?.id;
    if (itemId == null) return 0.0;

    final waveform = widget.extractor!.getWaveform(itemId);
    if (waveform == null || waveform.data.isEmpty) return 0.0;

    final position = widget.player!.position;
    int pixelIndex = (position.inMilliseconds / 1000.0 * 60).floor();
    int dataIndex = pixelIndex * 2 + 1; // max amplitude for pixel

    if (dataIndex > 0 && dataIndex < waveform.data.length) {
      int rawAmp = waveform.data[dataIndex];
      int maxAmp = widget.extractor!.getMaxAmplitude(itemId);
      if (maxAmp == 0) maxAmp = 1;

      double amp = (rawAmp.abs() / maxAmp.toDouble()).clamp(0.0, 1.0);
      return (amp * 1.5).clamp(0.0, 1.0); // Boost signal
    }
    return 0.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError) {
      // Return a visible indicator that the shader failed to load (for debugging)
      return Container(
        color: Colors.red.withOpacity(0.3),
        child: const Center(
          child: Text(
            'Shader Load Error',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    }

    if (_program == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final int rawMicros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
        final int throttleMicros = (Platform.isAndroid || Platform.isIOS) ? 33333 : 16666;
        final double quantizedTime = (rawMicros - (rawMicros % throttleMicros)).toDouble();

        return CustomPaint(
          painter: _ShaderPainter(
            shader: _program!.fragmentShader(),
            time: quantizedTime,
            amplitude: _getMasterAmplitude() * (widget.audioModulation ?? 1.0),
            color1: widget.color1 ?? Colors.transparent,
            color2: widget.color2 ?? Colors.transparent,
            color3: widget.color3 ?? Colors.transparent,
            color4: widget.color4 ?? Colors.transparent,
            customUniforms: widget.customUniforms,
            repaintCount: widget.repaintCount,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  final double amplitude;
  final Color color1;
  final Color color2;
  final Color color3;
  final Color color4;
  final List<double> customUniforms;
  final int repaintCount;

  _ShaderPainter({
    required this.shader,
    required this.time,
    required this.amplitude,
    required this.color1,
    required this.color2,
    required this.color3,
    required this.color4,
    required this.customUniforms,
    required this.repaintCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Basic convention for Shadertoy / generic Flutter shaders:
    // uniform vec2 u_resolution; // (size.width, size.height) indices 0,1
    // uniform float u_time;      // time in seconds           index 2
    // uniform float u_amplitude; // Audio reacting master amp index 3
    // followed by dynamic custom uniforms floats              index 4+

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time / 1000000.0); // convert microseconds to seconds
    shader.setFloat(3, amplitude);

    // Write Color 1 (R, G, B, A) -> Float 4, 5, 6, 7
    shader.setFloat(4, color1.red / 255.0);
    shader.setFloat(5, color1.green / 255.0);
    shader.setFloat(6, color1.blue / 255.0);
    shader.setFloat(7, color1.alpha / 255.0);

    // Write Color 2 -> Float 8, 9, 10, 11
    shader.setFloat(8, color2.red / 255.0);
    shader.setFloat(9, color2.green / 255.0);
    shader.setFloat(10, color2.blue / 255.0);
    shader.setFloat(11, color2.alpha / 255.0);

    // Write Color 3 -> Float 12, 13, 14, 15
    shader.setFloat(12, color3.red / 255.0);
    shader.setFloat(13, color3.green / 255.0);
    shader.setFloat(14, color3.blue / 255.0);
    shader.setFloat(15, color3.alpha / 255.0);

    // Write Color 4 -> Float 16, 17, 18, 19
    shader.setFloat(16, color4.red / 255.0);
    shader.setFloat(17, color4.green / 255.0);
    shader.setFloat(18, color4.blue / 255.0);
    shader.setFloat(19, color4.alpha / 255.0);

    // Custom floats shift down sequentially beginning at index 20
    int offset = 20;
    for (int i = 0; i < customUniforms.length; i++) {
      // Only set up to the exact requested uniforms to avoid crashing the FragmentProgram
      try {
        shader.setFloat(offset + i, customUniforms[i]);
      } catch (e) {/* ignore overbound floats if shader doesn't declare them */}
    }

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) {
    if (oldDelegate.repaintCount != repaintCount) {
      return true;
    }
    if (oldDelegate.time != time || oldDelegate.amplitude != amplitude) {
      return true;
    }
    if (oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.color3 != color3 ||
        oldDelegate.color4 != color4) {
      return true;
    }
    if (oldDelegate.customUniforms.length != customUniforms.length) {
      return true;
    }
    for (int i = 0; i < customUniforms.length; i++) {
      if (oldDelegate.customUniforms[i] != customUniforms[i]) {
        return true;
      }
    }
    return false;
  }
}
