import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/diary/diary_controller.dart';
import 'emotion_chart.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider를 통해 DiaryController의 데이터에 접근
    final controller = context.watch<DiaryController>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '감정 분석',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263FA9),
                ),
              ),
              const SizedBox(height: 16),
              // 기존에 만들어진 EmotionChart 위젯을 사용하고, 컨트롤러의 데이터를 전달
              Expanded(
                child: controller.entries.isEmpty
                    ? const Center(child: Text('분석할 일기 데이터가 없습니다.'))
                    : EmotionChart(entries: controller.entries),
              ),
            ],
          ),
        ),
      ),
    );
  }
}