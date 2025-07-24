import 'package:flutter/material.dart';
import 'dart:math';

class WeatherParticles extends StatefulWidget {
  final String weather; // ex: 'clear', 'rain', 'snow', 'clouds'
  final bool isNight;

  const WeatherParticles({super.key, required this.weather, required this.isNight});

  @override
  State<WeatherParticles> createState() => _WeatherParticlesState();
}

class _WeatherParticlesState extends State<WeatherParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    _particles = List.generate(80, (index) => _generateParticle());
  }

  _Particle _generateParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: _random.nextDouble() * 3 + 1,
      speed: _random.nextDouble() * 0.01 + 0.002,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.weather == 'clear' && !widget.isNight) return const SizedBox();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        for (var p in _particles) {
          p.y += p.speed;
          if (p.y > 1) {
            p.y = 0;
            p.x = _random.nextDouble();
          }
        }

        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(_particles, widget.weather, widget.isNight),
        );
      },
    );
  }
}

class _Particle {
  double x, y, size, speed;

  _Particle({required this.x, required this.y, required this.size, required this.speed});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final String weather;
  final bool isNight;

  _ParticlePainter(this.particles, this.weather, this.isNight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (weather == 'snow')
          ? Colors.white.withOpacity(0.8)
          : (weather == 'rain')
          ? Colors.blueAccent.withOpacity(0.5)
          : Colors.white.withOpacity(isNight ? 0.6 : 0.2)
      ..strokeCap = StrokeCap.round;

    for (final p in particles) {
      final dx = p.x * size.width;
      final dy = p.y * size.height;
      canvas.drawCircle(Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
