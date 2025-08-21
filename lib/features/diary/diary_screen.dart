import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/emotion_chart.dart';
import 'diary_controller.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DiaryController>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('감정 일기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('오늘의 일기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),

            // 🔹 연결된 텍스트 필드
            TextField(
              controller: controller.textController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '오늘 있었던 일을 입력하세요...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 전송 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isLoading ? null : controller.submitDiary,
                child: controller.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('분석하고 저장하기'),
              ),
            ),
            const SizedBox(height: 30),

            // 🔹 감정 분석 결과
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('분석 결과',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),

            if (controller.entries.isNotEmpty)
              Card(
                elevation: 2,
                color: const Color(0xFFE8F0FE),
                child: ListTile(
                  title: Text('감정: ${controller.entries.first.emotion}'),
                  subtitle: Text(
                    '내용: ${controller.entries.first.text}',
                  ),
                ),
              ),
            EmotionChart(entries: controller.entries),
          ],
        ),
      ),
    );
  }
}
