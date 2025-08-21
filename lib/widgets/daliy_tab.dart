import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/diary/diary_controller.dart';
import '../features/diary/diary_list_screen.dart';

class DaliyTab extends StatelessWidget {
  const DaliyTab({super.key});

  @override
  Widget build(BuildContext context) {
    // DiaryController를 Provider를 통해 가져옵니다.
    final controller = context.watch<DiaryController>();

    return Scaffold(
      // 키보드가 올라올 때 화면이 밀리는 것을 방지하기 위해 SingleChildScrollView 사용
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 페이지 제목과 목록 보기 버튼
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
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 12),

            // 일기 입력 텍스트 필드
            TextField(
              controller: controller.textController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '여기에 오늘의 이야기를 들려주세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // 분석하고 저장하기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: controller.isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.auto_awesome),
                label: Text(controller.isLoading ? '분석 중...' : '분석하고 저장하기'),
                onPressed: controller.isLoading ? null : controller.submitDiary,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 분석 결과 표시 영역
            const Text(
              '최근 분석 결과',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // 로딩 중이거나, 분석 결과가 있을 때만 Card를 표시
            if (controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (controller.entries.isNotEmpty)
              Card(
                elevation: 2,
                color: const Color(0xFFE8F0FE),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '감정: ${controller.entries.first.emotion}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '신뢰도: ${(controller.entries.first.confidence * 100).toStringAsFixed(1)}%',
                      ),
                      const Divider(height: 20),
                      Text(controller.entries.first.text),
                    ],
                  ),
                ),
              )
            else
              const Center(
                child: Text('일기를 작성하고 분석해보세요!'),
              ),
          ],
        ),
      ),
    );
  }
}