import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../features/diary/diary_model.dart';

class EmotionChart extends StatelessWidget {
  final List<DiaryEntry> entries;

  const EmotionChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    // NOTE: Using hardcoded data for debugging the rendering issue.
    return AspectRatio(
      aspectRatio: 1.2,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              //-
            },
          ),
          sectionsSpace: 2, // Add some space between sections
          centerSpaceRadius: 40, // Add a center space
          sections: [
            PieChartSectionData(
              color: Colors.blue,
              value: 40,
              title: 'Happy (40%)',
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.red,
              value: 30,
              title: 'Sad (30%)',
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.green,
              value: 30,
              title: 'Neutral (30%)',
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
