import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'diary_controller.dart';

class DiaryListScreen extends StatelessWidget {
  const DiaryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider를 통해 컨트롤러의 인스턴스를 가져옵니다.
    final controller = context.watch<DiaryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 일기 목록'),
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.entries.isEmpty
          ? const Center(child: Text('작성된 일기가 없습니다.'))
          : ListView.builder(
        itemCount: controller.entries.length,
        itemBuilder: (context, index) {
          final entry = controller.entries[index];
          return ListTile(
            title: Text(entry.content),
            subtitle: Text('${entry.date} - 감정: ${entry.mood}'),
          );
        },
      ),
    );
  }
}