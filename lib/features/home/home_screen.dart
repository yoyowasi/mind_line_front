import 'dart:async';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _timer;
  late List<Color> _currentGradient;

  @override
  void initState() {
    super.initState();
    _currentGradient = _getGradientByTime();
    _startGradientUpdater();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startGradientUpdater() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() {
        _currentGradient = _getGradientByTime();
      });
    });
  }

  List<Color> _getGradientByTime() {
    final hour = DateTime.now().hour;

    if (hour >= 0 && hour < 6) {
      return [Colors.indigo[900]!, Colors.black];
    } else if (hour >= 6 && hour < 12) {
      return [Colors.lightBlue[100]!, Colors.blue[200]!];
    } else if (hour >= 12 && hour < 18) {
      return [Colors.white, Colors.blueGrey[50]!];
    } else if (hour >= 18 && hour < 21) {
      return [Colors.orange[200]!, Colors.deepOrange[300]!];
    } else {
      return [Colors.blueGrey[900]!, Colors.indigo[800]!];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _currentGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '오늘은 어떠신가요?',
              style: TextStyle(fontSize: 22, color: Colors.white),
            ),
            SizedBox(height: 16),
            TextField(
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '오늘 하루의 감정을 적어보세요...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
