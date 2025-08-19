import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainTab extends StatelessWidget {
  const MainTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.chat),
        label: const Text('DailyCircle 메인 화면 가기'),
        onPressed: () => context.go('/home'), // ✅ 홈 화면으로 이동
      ),
    );
  }
}
