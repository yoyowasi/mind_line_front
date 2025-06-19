import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'diary_controller.dart';
import 'diary_model.dart';
import 'package:intl/intl.dart';

class DiaryListScreen extends StatelessWidget {
  const DiaryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiaryController>();
    final entries = controller.entries;

    return Scaffold(
      appBar: AppBar(title: const Text('내 일기 목록')),
      body: entries.isEmpty
          ? const Center(child: Text('아직 작성한 일기가 없습니다.'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final formattedDate =
          DateFormat('yyyy-MM-dd HH:mm').format(entry.createdAt);

          return Card(
            child: ListTile(
              title: Text(entry.text.length > 50
                  ? '${entry.text.substring(0, 50)}...'
                  : entry.text),
              subtitle: Text('감정: ${entry.emotion} • $formattedDate'),
              leading: const Icon(Icons.article_outlined),
              onTap: () {
                // TODO: 상세보기로 연결할 수 있음
              },
            ),
          );
        },
      ),
    );
  }
}
