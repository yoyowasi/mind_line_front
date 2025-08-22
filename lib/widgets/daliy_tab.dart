// lib/tabs/daliy_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/diary/diary_controller.dart';
import '../features/diary/diary_list_screen.dart';

class DaliyTab extends StatefulWidget {
  const DaliyTab({super.key});

  @override
  State<DaliyTab> createState() => _DaliyTabState();
}

class _DaliyTabState extends State<DaliyTab> {
  final _textCtrl = TextEditingController();
  String _mood = 'NEUTRAL';

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiaryController>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputFill = isDark ? cs.surface : Colors.white;
    final inputBorderColor = cs.primary.withOpacity(0.35);
    final inputText = cs.onSurface;
    final hintText = cs.onSurface.withOpacity(0.6);

    final cardBg = isDark ? cs.surface : const Color(0xFFE8F0FE);
    final cardText = cs.onSurface;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 전체 목록 이동
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '감정 일기',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.list_alt),
                  tooltip: '전체 일기 목록 보기',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DiaryListScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '오늘 어떤 일이 있었나요?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            // 입력창 - 다크모드 대비 강화
            TextField(
              controller: _textCtrl,
              maxLines: 8,
              cursorColor: cs.primary,
              style: TextStyle(color: inputText, height: 1.35),
              decoration: InputDecoration(
                hintText: '여기에 오늘의 이야기를 들려주세요...',
                hintStyle: TextStyle(color: hintText),
                filled: true,
                fillColor: inputFill,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: inputBorderColor, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: controller.isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save),
                label: Text(controller.isLoading ? '저장 중...' : '저장하기'),
                onPressed: controller.isLoading
                    ? null
                    : () async {
                  // ✅ 수정된 부분: 시간 정보를 제거한 날짜 객체를 생성합니다.
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  await controller.saveDiary(
                    date: today, // 수정된 today 변수를 사용합니다.
                    content: _textCtrl.text.trim(),
                    mood: _mood,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('저장 완료!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 최근 분석 결과
            const Text(
              '최근 분석 결과',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (controller.latestSummary != null)
              Card(
                elevation: 2,
                color: cardBg,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    controller.latestSummary!.summary,
                    style: TextStyle(color: cardText),
                  ),
                ),
              )
            else
              const Center(child: Text('아직 분석 결과가 없습니다.')),
          ],
        ),
      ),
    );
  }
}