import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants.dart';

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;
  double phase;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.life,
    required this.phase,
  });
}

class ParticleEngine extends StatefulWidget {
  final ParticleType type;
  final double speed;
  final int count;
  final bool isPlaying;

  const ParticleEngine({
    super.key,
    required this.type,
    this.speed = 1.0,
    this.count = 50,
    this.isPlaying = true,
  });

  @override
  State<ParticleEngine> createState() => _ParticleEngineState();
}

class _ParticleEngineState extends State<ParticleEngine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();
  ParticleType _lastType = ParticleType.none;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _controller.addListener(_updateParticles);
    _lastCount = widget.count;

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ParticleEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != _lastType || widget.count != _lastCount) {
      _lastType = widget.type;
      _lastCount = widget.count;
      _particles.clear();
      if (mounted) {
        _initializeParticles(MediaQuery.of(context).size);
      }
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

  void _initializeParticles(Size size) {
    if (widget.type == ParticleType.none || widget.count <= 0) return;
    for (int i = 0; i < widget.count; i++) {
      _particles.add(_createParticle(size, initial: true));
    }
  }

  Particle _createParticle(Size size, {bool initial = false}) {
    double x = _random.nextDouble() * size.width;
    double y = initial ? _random.nextDouble() * size.height : -20.0;
    double vx = 0;
    double vy = 0;
    double sizeP = 1.0;
    Color color = Colors.white;
    double life = 1.0;

    switch (widget.type) {
      case ParticleType.snow:
        vx = (_random.nextDouble() - 0.5) * 20;
        vy = _random.nextDouble() * 30 + 20;
        sizeP = _random.nextDouble() * 4 + 2;
        color = Colors.white.withOpacity(_random.nextDouble() * 0.5 + 0.5);
        break;
      case ParticleType.stars:
        y = _random.nextDouble() *
            size.height; // Stars always span entire screen
        vx = (_random.nextDouble() - 0.5) * 5;
        vy = (_random.nextDouble() - 0.5) * 5;
        sizeP = _random.nextDouble() * 3 + 1;
        color = Colors.yellow.withOpacity(_random.nextDouble());
        life = _random.nextDouble() * math.pi * 2; // used for twinkling phase
        break;
      case ParticleType.confetti:
        vx = (_random.nextDouble() - 0.5) * 50;
        vy = _random.nextDouble() * 100 + 50;
        sizeP = _random.nextDouble() * 8 + 4;
        color = HSVColor.fromAHSV(1.0, _random.nextDouble() * 360, 1.0, 1.0)
            .toColor();
        break;
      case ParticleType.fireflies:
        if (!initial) y = size.height + 20; // Flow upward
        vx = (_random.nextDouble() - 0.5) * 15;
        vy = (_random.nextDouble() * -20) - 10;
        sizeP = _random.nextDouble() * 4 + 2;
        color = Colors.lightGreenAccent
            .withOpacity(_random.nextDouble() * 0.6 + 0.4);
        life = _random.nextDouble() * math.pi * 2;
        break;
      case ParticleType.smoke:
        if (!initial) y = size.height + size.height * 0.1;
        vx = (_random.nextDouble() - 0.5) * 15;
        vy = (_random.nextDouble() * -30) - 15;
        sizeP = _random.nextDouble() * 30 + 40;
        color = Colors.white.withOpacity(_random.nextDouble() * 0.1 + 0.05);
        life = 1.0;
        break;
      default:
        break;
    }

    return Particle(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      size: sizeP,
      color: color,
      life: life,
      phase: _random.nextDouble() * math.pi * 2,
    );
  }

  void _updateParticles() {
    if (widget.type == ParticleType.none || _particles.isEmpty) return;

    final size = MediaQuery.of(context).size;
    final dt = 0.016 * widget.speed; // approx 60fps delta

    for (int i = 0; i < _particles.length; i++) {
      var p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.phase += dt;

      if (widget.type == ParticleType.stars) {
        p.life += dt * 2; // fast twinkle
      } else if (widget.type == ParticleType.fireflies) {
        p.life += dt * 3;
        p.vx += (_random.nextDouble() - 0.5) * 10 * dt;
        p.vy += (_random.nextDouble() - 0.5) * 10 * dt;
        // limit speed
        p.vx = p.vx.clamp(-30.0, 30.0);
        p.vy = p.vy.clamp(-40.0, 10.0);
      } else if (widget.type == ParticleType.snow ||
          widget.type == ParticleType.confetti) {
        p.x += math.sin(p.phase) * 20 * dt; // sway
      } else if (widget.type == ParticleType.smoke) {
        p.life -= dt * 0.05; // slowly fade out relative to speed
        p.size += dt * 10; // slowly expand
        p.x += math.sin(p.phase * 0.5) * 10 * dt; // slight drift
      }

      bool respawn = false;
      if (widget.type == ParticleType.fireflies) {
        if (p.y < -50 || p.x < -50 || p.x > size.width + 50) respawn = true;
      } else if (widget.type == ParticleType.smoke) {
        if (p.life <= 0 ||
            p.y < -p.size ||
            p.x < -p.size ||
            p.x > size.width + p.size) {
          respawn = true;
        }
      } else {
        if (p.y > size.height + 50 || p.x < -50 || p.x > size.width + 50) {
          respawn = true;
        }
      }

      if (respawn) {
        _particles[i] = _createParticle(size);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == ParticleType.none || widget.count <= 0) {
      return const SizedBox.shrink();
    }
    if (_particles.isEmpty && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _particles.isEmpty) {
          _initializeParticles(MediaQuery.of(context).size);
        }
      });
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(_particles, widget.type),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final ParticleType type;

  _ParticlePainter(this.particles, this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      if (type == ParticleType.stars || type == ParticleType.fireflies) {
        double opacity = (math.sin(p.life) + 1.0) / 2.0;
        paint.color = p.color.withOpacity(opacity * p.color.opacity);

        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);

        if (type == ParticleType.fireflies) {
          final glowPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = p.color.withOpacity(opacity * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
          canvas.drawCircle(Offset(p.x, p.y), p.size * 3, glowPaint);
        }
      } else if (type == ParticleType.confetti) {
        paint.color = p.color;
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.phase * 2);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 1.5),
            paint);
        canvas.restore();
      } else if (type == ParticleType.smoke) {
        paint.color =
            p.color.withOpacity(p.color.opacity * math.max(0.0, p.life));
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.5);
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      } else {
        // snow
        paint.color = p.color;
        paint.maskFilter = null;
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
