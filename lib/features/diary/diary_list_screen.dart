// lib/features/diary/diary_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'diary_controller.dart';

class DiaryListScreen extends StatelessWidget {
  const DiaryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DiaryController>();
    final df = DateFormat('yyyy-MM-dd');
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('일기 목록')),
      body: Builder(
        builder: (_) {
          if (c.isLoading && c.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.entries.isEmpty) {
            return const Center(child: Text('일기가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (_, i) {
              final e = c.entries[i];
              return ListTile(
                title: Text(
                  df.format(e.date),
                  style: TextStyle(color: cs.onSurface),
                ),
                subtitle: Text(
                  (e.content ?? e.legacyText ?? '').isEmpty
                      ? '(내용 없음)'
                      : (e.content ?? e.legacyText!),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  // 다크모드 하단 글자 대비 강화
                  style: TextStyle(color: cs.onSurface.withOpacity(0.80)),
                ),
                trailing: Text(
                  e.mood ?? '-',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: c.entries.length,
          );
        },
      ),
    );
  }
}
