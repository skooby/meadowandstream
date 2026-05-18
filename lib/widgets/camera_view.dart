import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../state/player_controller.dart';
import '../services/waveform_extractor_service.dart';
import 'visualizer/custom_audio_visualizer.dart';

class CameraView extends StatefulWidget {
  final Widget child;
  final double shakeIntensity; // 0.0 to 1.0 and beyond
  final PlayerController player;
  final WaveformExtractorService extractor;
  final AudioVisualizerMode visualizerMode;
  final double cameraZoom;
  final double cameraPanX;
  final double cameraPanY;
  final double cameraRotation;

  const CameraView({
    super.key,
    required this.child,
    required this.shakeIntensity,
    required this.player,
    required this.extractor,
    this.visualizerMode = AudioVisualizerMode.standard,
    this.cameraZoom = 1.0,
    this.cameraPanX = 0.0,
    this.cameraPanY = 0.0,
    this.cameraRotation = 0.0,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeTicker;
  final math.Random _random = math.Random();
  double _timePhase = 0.0;

  @override
  void initState() {
    super.initState();
    // Use a fast ticking controller for the shake
    _shakeTicker = AnimationController(
        vsync: this, duration: const Duration(seconds: 1000));
    _shakeTicker.addListener(() {
      setState(() {
        _timePhase += 0.05;
      });
    });

    if (widget.player.isPlaying) {
      _shakeTicker.repeat();
    }
    widget.player.addListener(_onPlayerChange);
  }

  void _onPlayerChange() {
    if (widget.player.isPlaying && !_shakeTicker.isAnimating) {
      _shakeTicker.repeat();
    } else if (!widget.player.isPlaying && _shakeTicker.isAnimating) {
      _shakeTicker.stop();
      // Ensure we re-render once to reset to 0,0
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerChange);
    _shakeTicker.dispose();
    super.dispose();
  }

  double _getMasterAmplitude() {
    final itemId = widget.player.currentItem?.id;
    if (itemId == null) return 0.0;

    final waveform = widget.extractor.getWaveform(itemId);
    if (waveform == null || waveform.data.isEmpty) return 0.0;

    final position = widget.player.position;
    int pixelIndex = (position.inMilliseconds / 1000.0 * 60).floor();
    int dataIndex = pixelIndex * 2 + 1; // max amplitude for pixel

    if (dataIndex > 0 && dataIndex < waveform.data.length) {
      int rawAmp = waveform.data[dataIndex];
      int maxAmp = widget.extractor.getMaxAmplitude(itemId);
      if (maxAmp == 0) maxAmp = 1;

      double amp = (rawAmp.abs() / maxAmp.toDouble()).clamp(0.0, 1.0);
      return (amp * 1.5).clamp(0.0, 1.0); // Boost signal
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasShake = widget.shakeIntensity > 0.0;
    final bool hasTransforms = widget.cameraZoom != 1.0 ||
        widget.cameraPanX != 0.0 ||
        widget.cameraPanY != 0.0 ||
        widget.cameraRotation != 0.0;

    if (!hasShake && !hasTransforms) {
      return widget.child;
    }

    final masterAmp = _getMasterAmplitude();

    // Process visualizer shake intensity logic
    final spectrum = CustomAudioVisualizer.generatePseudoSpectrum(
        masterAmp, widget.visualizerMode, 32, _timePhase);
    final avg = spectrum.reduce((a, b) => a + b) / spectrum.length;
    // Remove the idle floor (0.1) so it doesn't shake on silence
    final visualAmp = math.max(0.0, avg - 0.1) * 2.0;

    // Multiplier from config * current tied audio visualizer amplitude
    final maxOffset = widget.shakeIntensity * visualAmp * 50.0; // max px offset

    double offsetX = 0.0;
    double offsetY = 0.0;

    if (maxOffset > 0 && widget.player.isPlaying) {
      offsetX = (_random.nextDouble() * 2 - 1) * maxOffset;
      offsetY = (_random.nextDouble() * 2 - 1) * maxOffset;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double height = constraints.maxHeight;

        // Fallback to screen size if unconstrained (e.g. in a scroll view without bounds)
        if (width == double.infinity || height == double.infinity) {
          final size = MediaQuery.sizeOf(context);
          if (width == double.infinity) width = size.width;
          if (height == double.infinity) height = size.height;
        }

        // The absolute maximum offset this shake curve could produce globally
        // visualAmp maxes out around 2.0
        final double maxTheoreticalOffset = widget.shakeIntensity * 2.0 * 50.0;

        // Calculate scale needed to bleed the edges offscreen
        // (scale - 1) * width / 2 >= maxOffset
        double scaleX = 1.0;
        double scaleY = 1.0;

        if (width > 0) scaleX = 1.0 + ((2.0 * maxTheoreticalOffset) / width);
        if (height > 0) scaleY = 1.0 + ((2.0 * maxTheoreticalOffset) / height);

        // Take the larger scale to guarantee both axes are covered safely
        // Base scale for shake coverage
        final baseScale = math.max(scaleX, scaleY);

        // Incorporate requested zoom
        final finalScale = baseScale * widget.cameraZoom;

        Widget content = widget.child;

        // Apply constant transforms (pan, rotation) BEFORE shake offset
        // so that shake remains relative to the screen plane
        if (widget.cameraPanX != 0.0 || widget.cameraPanY != 0.0) {
          content = FractionalTranslation(
            translation: Offset(widget.cameraPanX, widget.cameraPanY),
            child: content,
          );
        }

        if (widget.cameraRotation != 0.0) {
          content = Transform.rotate(
            angle: widget.cameraRotation * (math.pi / 180.0), // degrees to rads
            child: content,
          );
        }

        return Transform.scale(
          scale: finalScale,
          child: Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: content,
          ),
        );
      },
    );
  }
}
