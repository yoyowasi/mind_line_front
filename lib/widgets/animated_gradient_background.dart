import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key});

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _topColor;
  late Animation<Color?> _bottomColor;

  @override
  void initState() {
    super.initState();

    final scheme = _getGradientScheme();

    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat(reverse: true);

    _topColor = ColorTween(
      begin: scheme.topStart,
      end: scheme.topEnd,
    ).animate(_controller);

    _bottomColor = ColorTween(
      begin: scheme.bottomStart,
      end: scheme.bottomEnd,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_topColor.value ?? Colors.transparent, _bottomColor.value ?? Colors.transparent],
            ),
          ),
        );
      },
    );
  }

  _GradientScheme _getGradientScheme() {
    final hour = DateTime.now().hour;
    final month = DateTime.now().month;

    String season;
    if ([12, 1, 2].contains(month)) {
      season = 'winter';
    } else if ([3, 4, 5].contains(month)) {
      season = 'spring';
    } else if ([6, 7, 8].contains(month)) {
      season = 'summer';
    } else {
      season = 'autumn';
    }

    if (hour < 6 || hour >= 20) {
      return _GradientScheme.night(season);
    } else if (hour < 12) {
      return _GradientScheme.morning(season);
    } else if (hour < 17) {
      return _GradientScheme.afternoon(season);
    } else {
      return _GradientScheme.evening(season);
    }
  }
}

class _GradientScheme {
  final Color topStart;
  final Color topEnd;
  final Color bottomStart;
  final Color bottomEnd;

  _GradientScheme(this.topStart, this.topEnd, this.bottomStart, this.bottomEnd);

  factory _GradientScheme.morning(String season) {
    switch (season) {
      case 'spring':
        return _GradientScheme(
          const Color(0xFFFFE5EC), const Color(0xFFFFD6E0),
          const Color(0xFFE0F7FA), const Color(0xFFB2EBF2),
        );
      case 'summer':
        return _GradientScheme(
          const Color(0xFFFFF3B0), const Color(0xFFFFE4A8),
          const Color(0xFFB2EBF2), const Color(0xFF80DEEA),
        );
      case 'autumn':
        return _GradientScheme(
          const Color(0xFFFFD6A5), const Color(0xFFFFB085),
          const Color(0xFFFFE0B2), const Color(0xFFFFCC80),
        );
      case 'winter':
      default:
        return _GradientScheme(
          const Color(0xFFE3F2FD), const Color(0xFFBBDEFB),
          const Color(0xFFF1F8E9), const Color(0xFFC8E6C9),
        );
    }
  }

  factory _GradientScheme.afternoon(String season) {
    switch (season) {
      case 'spring':
        return _GradientScheme(
          const Color(0xFFF8BBD0), const Color(0xFFF48FB1),
          const Color(0xFFB2EBF2), const Color(0xFF80DEEA),
        );
      case 'summer':
        return _GradientScheme(
          const Color(0xFF81D4FA), const Color(0xFF4FC3F7),
          const Color(0xFFA5D6A7), const Color(0xFF81C784),
        );
      case 'autumn':
        return _GradientScheme(
          const Color(0xFFFFAB91), const Color(0xFFFF8A65),
          const Color(0xFFFFE082), const Color(0xFFFFCA28),
        );
      case 'winter':
      default:
        return _GradientScheme(
          const Color(0xFFE0F7FA), const Color(0xFFB2EBF2),
          const Color(0xFFEEEEEE), const Color(0xFFCFD8DC),
        );
    }
  }

  factory _GradientScheme.evening(String season) {
    return _GradientScheme(
      const Color(0xFFFFC1CC), const Color(0xFFB39DDB),
      const Color(0xFF9575CD), const Color(0xFF7E57C2),
    );
  }

  factory _GradientScheme.night(String season) {
    return _GradientScheme(
      const Color(0xFF3E1E68), const Color(0xFF2E2F88),
      const Color(0xFF1A1F71), const Color(0xFF0D0F36),
    );
  }
}
