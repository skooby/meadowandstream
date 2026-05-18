import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/waveform_extractor_service.dart';
import '../../state/player_controller.dart';
import '../../constants.dart';

class CustomAudioVisualizer extends StatefulWidget {
  final PlayerController player;
  final WaveformExtractorService extractor;
  final VisualizerType type;
  final AudioVisualizerMode mode;
  final AudioVisualizerColorStyle colorStyle;
  final Color baseColor;
  final Color? colorStart;
  final Color? colorEnd;
  final double? alphaSegmentStart;
  final double? alphaSegmentEnd;
  final int bands;
  final int blockHeight;
  final double height;
  final double width;

  const CustomAudioVisualizer({
    super.key,
    required this.player,
    required this.extractor,
    required this.type,
    this.mode = AudioVisualizerMode.standard,
    this.colorStyle = AudioVisualizerColorStyle.solid,
    this.baseColor = Colors.white,
    this.colorStart,
    this.colorEnd,
    this.alphaSegmentStart,
    this.alphaSegmentEnd,
    this.bands = 32,
    this.blockHeight = 0,
    this.height = 100,
    this.width = double.infinity,
  });

  @override
  State<CustomAudioVisualizer> createState() => _CustomAudioVisualizerState();

  /// The magic: Expands our 1-dimensional volume number into a realistic fake frequency spectrum
  static List<double> generatePseudoSpectrum(
      double masterAmp, AudioVisualizerMode mode, int bands, double timePhase) {
    List<double> spectrum = List.filled(bands, 0.0);

    // Smooth trailing decay: If amplitude is low, we don't zero it perfectly,
    // we let the natural waves idle so it looks alive even in quiet parts.
    double idleFloor = 0.1;
    double scale = math.max(idleFloor, masterAmp);

    for (int i = 0; i < bands; i++) {
      // Create organic peaks and valleys across the bands
      // Mix two sine waves with different frequencies and phases
      double pos = i / bands;

      // Remap the effective position based on the selected mode
      // so all 32 bands react, but only using the math from the target range.
      double effPos = pos;
      if (mode == AudioVisualizerMode.bass) {
        // Map 0.0 - 1.0 to just the bass range (0.0 - 0.3)
        effPos = pos * 0.3;
      } else if (mode == AudioVisualizerMode.vocals) {
        // Map 0.0 - 1.0 to just the vocal range (0.35 - 0.65)
        effPos = 0.35 + (pos * 0.3);
      } else if (mode == AudioVisualizerMode.beat) {
        // Map 0.0-0.5 to kicks (0.0-0.2) and 0.5-1.0 to snares/hats (0.8-1.0)
        if (pos < 0.5) {
          effPos = (pos * 2.0) * 0.2;
        } else {
          effPos = 0.8 + ((pos - 0.5) * 2.0 * 0.2);
        }
      }

      double wave1 = math.sin((effPos * math.pi * 4) + timePhase);
      double wave2 = math.cos((effPos * math.pi * 2) - (timePhase * 1.5));

      // Add random-looking static noise that is deterministic
      double staticNoise = math.sin((effPos * 43.0) + (masterAmp * 20.0));

      // Combine them so it looks like dancing EQ bins
      double rawVal = (wave1 * 0.4) + (wave2 * 0.4) + (staticNoise * 0.2);

      // Normalize to 0.0 - 1.0 bounds
      rawVal = (rawVal + 1.0) / 2.0;

      // Make the middle bands slightly higher naturally,
      // without artificially boosting the master amplitude
      double centerDistance =
          ((pos - 0.5) * 2.0).abs(); // 0 at center, 1 at edges
      double bellCurve = 1.0 - (centerDistance * 0.5);

      spectrum[i] = (rawVal * bellCurve * scale).clamp(0.0, 1.0);
    }
    return spectrum;
  }
}

class _CustomAudioVisualizerState extends State<CustomAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  double _timePhase = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
        vsync: this, duration: const Duration(seconds: 1000));
    _ticker.addListener(() {
      setState(() {
        _timePhase += 0.05; // Drives the sine wave animation forward
      });
    });

    if (widget.player.isPlaying) {
      _ticker.repeat();
    }
    widget.player.addListener(_onPlayerChange);
  }

  void _onPlayerChange() {
    if (widget.player.isPlaying && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!widget.player.isPlaying && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerChange);
    _ticker.dispose();
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
    if (widget.type == VisualizerType.none) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: StreamBuilder<Duration>(
        stream: widget.player.positionStream,
        builder: (context, snapshot) {
          final masterAmp = _getMasterAmplitude();
          final spectrum = CustomAudioVisualizer.generatePseudoSpectrum(
              masterAmp, widget.mode, widget.bands, _timePhase);

          CustomPainter painter;
          switch (widget.type) {
            case VisualizerType.bar:
              painter = BarVisualizerPainter(
                spectrum: spectrum,
                colorStyle: widget.colorStyle,
                colorStart: widget.colorStart ?? widget.baseColor,
                colorEnd: widget.colorEnd,
                alphaSegmentStart: widget.alphaSegmentStart,
                alphaSegmentEnd: widget.alphaSegmentEnd,
                blockHeight: widget.blockHeight,
              );
              break;
            case VisualizerType.circular:
              painter = CircularVisualizerPainter(
                spectrum: spectrum,
                colorStyle: widget.colorStyle,
                colorStart: widget.colorStart ?? widget.baseColor,
                colorEnd: widget.colorEnd,
                alphaSegmentStart: widget.alphaSegmentStart,
                alphaSegmentEnd: widget.alphaSegmentEnd,
                blockHeight: widget.blockHeight,
              );
              break;
            case VisualizerType.line:
              painter = LineVisualizerPainter(
                spectrum: spectrum,
                colorStyle: widget.colorStyle,
                colorStart: widget.colorStart ?? widget.baseColor,
                colorEnd: widget.colorEnd,
                alphaSegmentStart: widget.alphaSegmentStart,
                alphaSegmentEnd: widget.alphaSegmentEnd,
              );
              break;
            case VisualizerType.multiWave:
              painter = MultiWaveVisualizerPainter(
                  spectrum: spectrum,
                  color: widget.baseColor,
                  phase: _timePhase);
              break;
            case VisualizerType.rainbow:
              // Deprecated: Map legacy shape to Bar with Rainbow style
              painter = BarVisualizerPainter(
                spectrum: spectrum,
                colorStyle: AudioVisualizerColorStyle.rainbow,
                colorStart: widget.colorStart ?? widget.baseColor,
                colorEnd: widget.colorEnd,
                alphaSegmentStart: widget.alphaSegmentStart,
                alphaSegmentEnd: widget.alphaSegmentEnd,
                blockHeight: widget.blockHeight,
              );
              break;
            default:
              painter = BarVisualizerPainter(
                spectrum: spectrum,
                colorStyle: widget.colorStyle,
                colorStart: widget.colorStart ?? widget.baseColor,
                colorEnd: widget.colorEnd,
                alphaSegmentStart: widget.alphaSegmentStart,
                alphaSegmentEnd: widget.alphaSegmentEnd,
                blockHeight: widget.blockHeight,
              );
          }

          return CustomPaint(painter: painter);
        },
      ),
    );
  }
}

class BarVisualizerPainter extends CustomPainter {
  final List<double> spectrum;
  final AudioVisualizerColorStyle colorStyle;
  final Color colorStart;
  final Color? colorEnd;
  final double? alphaSegmentStart;
  final double? alphaSegmentEnd;
  final double gap;
  final int blockHeight;

  BarVisualizerPainter({
    required this.spectrum,
    required this.colorStyle,
    required this.colorStart,
    this.colorEnd,
    this.alphaSegmentStart,
    this.alphaSegmentEnd,
    this.gap = 2.0,
    this.blockHeight = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final barWidth = (size.width / spectrum.length) - gap;
    if (barWidth <= 0) return;

    for (int i = 0; i < spectrum.length; i++) {
      // Determine the precise color for this band column based on the style
      Color columnColor;
      switch (colorStyle) {
        case AudioVisualizerColorStyle.rainbow:
          final double hue = (i / spectrum.length) * 360.0;
          columnColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
          break;
        case AudioVisualizerColorStyle.gradient:
          if (colorEnd != null) {
            columnColor =
                Color.lerp(colorStart, colorEnd, i / spectrum.length) ??
                    colorStart;
          } else {
            columnColor = colorStart;
          }
          break;
        case AudioVisualizerColorStyle.solid:
          columnColor = colorStart;
          break;
      }

      final barHeight = spectrum[i] * size.height;
      final x = i * (barWidth + gap);

      final paint = Paint()..style = PaintingStyle.fill;

      if (alphaSegmentStart != null && alphaSegmentEnd != null) {
        // If the user specified traditional 0-255 alpha boundaries
        double aStart = alphaSegmentStart!;
        double aEnd = alphaSegmentEnd!;
        if (aStart > 1.0 || aEnd > 1.0) {
          aStart /= 255.0;
          aEnd /= 255.0;
        }

        paint.shader = ui.Gradient.linear(
          Offset(x, size.height), // Bottom
          Offset(x, size.height - barHeight), // Top
          [
            columnColor.withValues(alpha: aStart.clamp(0.0, 1.0)),
            columnColor.withValues(alpha: aEnd.clamp(0.0, 1.0))
          ],
        );
      } else {
        paint.color = columnColor;
      }

      if (blockHeight > 0) {
        // Draw segmented LED blocks
        double currentY = size.height;
        final double bHeight = blockHeight.toDouble();
        final double bGap = gap; // Gap between blocks matches horizontal gap

        while (size.height - currentY < barHeight) {
          // Draw bottom-up
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, currentY - bHeight, barWidth, bHeight),
            const Radius.circular(2.0),
          );
          canvas.drawRRect(rect, paint);
          currentY -= (bHeight + bGap);
        }
      } else {
        // Draw standard solid pillar
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
          const Radius.circular(2.0),
        );

        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarVisualizerPainter oldDelegate) => true;
}

// Deprecated: Kept structurally for mapping fallback if an old JSON file calls it.
// The engine mapping automatically redirects the JSON request to a properly styled Bar visualizer.
class RainbowVisualizerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant RainbowVisualizerPainter oldDelegate) => false;
}

class CircularVisualizerPainter extends CustomPainter {
  final List<double> spectrum;
  final AudioVisualizerColorStyle colorStyle;
  final Color colorStart;
  final Color? colorEnd;
  final double? alphaSegmentStart;
  final double? alphaSegmentEnd;
  final int blockHeight;
  final double gap;

  CircularVisualizerPainter({
    required this.spectrum,
    required this.colorStyle,
    required this.colorStart,
    this.colorEnd,
    this.alphaSegmentStart,
    this.alphaSegmentEnd,
    this.blockHeight = 0,
    this.gap = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.3;
    final maxSpike = math.min(size.width, size.height) * 0.2;

    for (int i = 0; i < spectrum.length; i++) {
      final angle = (i / spectrum.length) * 2 * math.pi;

      // Extract Color Geometry
      Color spikeColor;
      switch (colorStyle) {
        case AudioVisualizerColorStyle.rainbow:
          final double hue = (i / spectrum.length) * 360.0;
          spikeColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
          break;
        case AudioVisualizerColorStyle.gradient:
          if (colorEnd != null) {
            spikeColor =
                Color.lerp(colorStart, colorEnd, i / spectrum.length) ??
                    colorStart;
          } else {
            spikeColor = colorStart;
          }
          break;
        case AudioVisualizerColorStyle.solid:
          spikeColor = colorStart;
          break;
      }

      // Mirror the spectrum so the circle is symmetrical
      final visualIdx =
          i < (spectrum.length ~/ 2) ? i : (spectrum.length - 1 - i);
      final spikeLength = spectrum[visualIdx] * maxSpike;

      // Base length coordinates
      final innerRad = baseRadius;
      final outerRad = baseRadius + spikeLength;

      final startX = center.dx + innerRad * math.cos(angle);
      final startY = center.dy + innerRad * math.sin(angle);
      final endX = center.dx + outerRad * math.cos(angle);
      final endY = center.dy + outerRad * math.sin(angle);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      if (alphaSegmentStart != null && alphaSegmentEnd != null) {
        // If the user specified traditional 0-255 alpha boundaries
        double aStart = alphaSegmentStart!;
        double aEnd = alphaSegmentEnd!;
        if (aStart > 1.0 || aEnd > 1.0) {
          aStart /= 255.0;
          aEnd /= 255.0;
        }

        paint.shader = ui.Gradient.linear(
          Offset(startX, startY),
          Offset(endX, endY),
          [
            spikeColor.withValues(alpha: aStart.clamp(0.0, 1.0)),
            spikeColor.withValues(alpha: aEnd.clamp(0.0, 1.0))
          ],
        );
      } else {
        paint.color = spikeColor;
      }

      if (blockHeight > 0) {
        // Draw segmented LED blocks radially outwards
        double currentRad = innerRad;
        final double bHeight = blockHeight.toDouble();
        final double bGap = gap;

        while (currentRad < outerRad) {
          final segStartX = center.dx + currentRad * math.cos(angle);
          final segStartY = center.dy + currentRad * math.sin(angle);

          final segEndRad = math.min(currentRad + bHeight, outerRad);
          final segEndX = center.dx + segEndRad * math.cos(angle);
          final segEndY = center.dy + segEndRad * math.sin(angle);

          canvas.drawLine(
              Offset(segStartX, segStartY), Offset(segEndX, segEndY), paint);

          currentRad += (bHeight + bGap);
        }
      } else {
        // Solid continuous line
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CircularVisualizerPainter oldDelegate) => true;
}

class LineVisualizerPainter extends CustomPainter {
  final List<double> spectrum;
  final AudioVisualizerColorStyle colorStyle;
  final Color colorStart;
  final Color? colorEnd;
  final double? alphaSegmentStart;
  final double? alphaSegmentEnd;

  LineVisualizerPainter({
    required this.spectrum,
    required this.colorStyle,
    required this.colorStart,
    this.colorEnd,
    this.alphaSegmentStart,
    this.alphaSegmentEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final sliceWidth = size.width / (spectrum.length - 1);

    // Multi-style color plotting requires drawing distinct line segments
    // instead of a single contiguous path to allow lerp colorization.
    for (int i = 0; i < spectrum.length - 1; i++) {
      final x1 = i * sliceWidth;
      final y1 = size.height - (spectrum[i] * size.height);

      final x2 = (i + 1) * sliceWidth;
      final y2 = size.height - (spectrum[i + 1] * size.height);

      Color segmentColor;
      switch (colorStyle) {
        case AudioVisualizerColorStyle.rainbow:
          final double hue = (i / spectrum.length) * 360.0;
          segmentColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
          break;
        case AudioVisualizerColorStyle.gradient:
          if (colorEnd != null) {
            segmentColor =
                Color.lerp(colorStart, colorEnd, i / spectrum.length) ??
                    colorStart;
          } else {
            segmentColor = colorStart;
          }
          break;
        case AudioVisualizerColorStyle.solid:
          segmentColor = colorStart;
          break;
      }

      if (alphaSegmentStart != null && alphaSegmentEnd != null) {
        final double alphaProgress = i / (spectrum.length - 1);

        // If the user specified traditional 0-255 alpha boundaries
        double aStart = alphaSegmentStart!;
        double aEnd = alphaSegmentEnd!;
        if (aStart > 1.0 || aEnd > 1.0) {
          aStart /= 255.0;
          aEnd /= 255.0;
        }

        final double segAlpha = aStart + ((aEnd - aStart) * alphaProgress);
        segmentColor = segmentColor.withValues(alpha: segAlpha.clamp(0.0, 1.0));
      }

      final paint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant LineVisualizerPainter oldDelegate) => true;
}

class MultiWaveVisualizerPainter extends CustomPainter {
  final List<double> spectrum;
  final Color color;
  final double phase;

  MultiWaveVisualizerPainter(
      {required this.spectrum, required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final sliceWidth = size.width / (spectrum.length - 1);

    // Draw 3 layers of waves
    for (int wave = 0; wave < 3; wave++) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.3 + (wave * 0.2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round;

      final path = Path();

      for (int i = 0; i < spectrum.length; i++) {
        final x = i * sliceWidth;

        // Inject phase offsets to decouple the layers
        final layerOffset =
            math.sin((i / spectrum.length * math.pi) + phase + (wave * 1.5));
        double heightMod = spectrum[i] + (layerOffset * 0.2);
        heightMod = heightMod.clamp(0.0, 1.0);

        final y = size.height - (heightMod * size.height);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          // Cubic bezier for super smooth waves instead of sharp lines
          final prevX = (i - 1) * sliceWidth;
          final prevY = size.height -
              ((spectrum[i - 1] +
                          (math.sin(((i - 1) / spectrum.length * math.pi) +
                                  phase +
                                  (wave * 1.5)) *
                              0.2))
                      .clamp(0.0, 1.0) *
                  size.height);

          final controlX1 = prevX + (x - prevX) / 2;
          final controlX2 = prevX + (x - prevX) / 2;

          path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MultiWaveVisualizerPainter oldDelegate) => true;
}
