import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/emotion_chart.dart';
import 'diary_controller.dart';

class EmotionStatsScreen extends StatelessWidget {
  const EmotionStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiaryController>();

    return Scaffold(
      appBar: AppBar(title: const Text('감정 통계')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: EmotionChart(entries: controller.entries),
      ),
    );
  }
}
