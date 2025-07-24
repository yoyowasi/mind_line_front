import 'package:flutter/material.dart';
import '../features/shared/app_drawer.dart';
import '../widgets/animated_gradient_background.dart';
import '../widgets/weather_particles.dart';
import '../core/services/weather_service.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final String title;


  const MainScaffold({super.key, required this.child,required this.title});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: WeatherService.fetchWeatherInfo(),
      builder: (context, snapshot) {
        final weather = snapshot.data?.weather ?? 'clear';
        final isNight = snapshot.data?.isNight ?? false;

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(120), // AppBar 높이 조정
            child: Stack(
              children: [
                const AnimatedGradientBackground(),
                WeatherParticles(weather: weather, isNight: isNight),
                AppBar(
                  title: const Text('AI 감정 일기'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
              ],
            ),
          ),
          backgroundColor: _getBaseColor(weather, isNight), // 하단 배경
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        );
      },
    );
  }

  Color _getBaseColor(String weather, bool isNight) {
    if (weather == 'snow') {
      return isNight ? Colors.blueGrey.shade900 : Colors.lightBlue.shade100;
    }
    if (weather == 'rain') {
      return isNight ? Colors.indigo.shade900 : Colors.blueGrey.shade200;
    }
    if (weather == 'clouds') {
      return isNight ? Colors.grey.shade900 : Colors.blueGrey.shade100;
    }
    if (weather == 'clear') {
      return isNight ? Colors.deepPurple.shade900 : Colors.purple.shade50;
    }
    return isNight ? Colors.grey.shade900 : Colors.grey.shade100;
  }
}
