import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../features/diary/diary_model.dart';

class EmotionChart extends StatelessWidget {
  final List<DiaryEntry> entries;

  const EmotionChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final emotionCount = <String, int>{};

    // 🔹 감정별 개수 세기
    for (var entry in entries) {
      emotionCount[entry.emotion] = (emotionCount[entry.emotion] ?? 0) + 1;
    }

    final total = emotionCount.values.fold<int>(0, (a, b) => a + b);

    if (emotionCount.isEmpty) {
      return const Center(child: Text('분석된 감정 데이터가 없습니다.'));
    }

    return AspectRatio(
      aspectRatio: 1.2,
      child: PieChart(
        PieChartData(
          sections: emotionCount.entries.map((e) {
            final percent = total > 0 ? (e.value / total * 100) : 0;
            final color = Color(e.key.hashCode | 0xFF000000).withOpacity(1.0);

            return PieChartSectionData(
              color: color,
              value: e.value.toDouble(),
              title: '${e.key} (${percent.toStringAsFixed(1)}%)',
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
