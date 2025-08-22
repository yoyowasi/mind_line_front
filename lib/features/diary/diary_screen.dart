// lib/features/diary/diary_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'diary_controller.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _textCtrl = TextEditingController();
  String _mood = 'NEUTRAL';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DiaryController>();
    final summary = c.latestSummary?.summary ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('일기 작성/요약')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('최근 요약', style: Theme.of(context).textTheme.titleMedium),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12, top: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(summary.isEmpty ? '요약 없음' : summary),
            ),
            // Diary 입력창 (DaliyTab 등)
            TextField(
              controller: _textCtrl,
              minLines: 5,
              maxLines: 10,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, // 본문 색상
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '오늘의 일기를 작성하세요...',
                hintStyle: TextStyle(
                  color: Theme.of(context).hintColor.withOpacity(0.8), // 힌트 대비 강화
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<String>(
                  value: _mood,
                  items: const [
                    DropdownMenuItem(value: 'HAPPY', child: Text('HAPPY')),
                    DropdownMenuItem(value: 'SAD', child: Text('SAD')),
                    DropdownMenuItem(value: 'ANGRY', child: Text('ANGRY')),
                    DropdownMenuItem(value: 'NEUTRAL', child: Text('NEUTRAL')),
                  ],
                  onChanged: (v) => setState(() => _mood = v ?? 'NEUTRAL'),
                ),
                const Spacer(),
                Text(DateFormat('yyyy-MM-dd').format(_date)),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: c.isLoading
                  ? null
                  : () async {
                await context.read<DiaryController>().saveDiary(
                  date: _date,
                  content: _textCtrl.text.trim(),
                  mood: _mood,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('저장했습니다.')),
                  );
                }
              },
              child: c.isLoading ? const CircularProgressIndicator() : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
