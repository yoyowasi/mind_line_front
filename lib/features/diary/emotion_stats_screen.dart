// lib/features/diary/emotion_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'diary_controller.dart';

class EmotionStatsScreen extends StatelessWidget {
  const EmotionStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DiaryController>();
    final counts = <String, int>{};
    for (final e in c.entries) {
      final key = e.mood ?? 'UNKNOWN';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final items = counts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: const Text('감정 통계')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          return ListTile(
            title: Text(it.key),
            trailing: Text('${it.value}회'),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
      ),
    );
  }
}
