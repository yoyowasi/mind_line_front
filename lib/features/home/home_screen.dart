import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 감정 일기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('일기 쓰기'),
              onPressed: () => context.push('/diary'),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.pie_chart),
              label: const Text('감정 통계 보기'),
              onPressed: () => context.push('/stats'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text('내 일기 보기'),
              onPressed: () => context.push('/diary/list'),
            ),
            /*ElevatedButton(
              child: Text("테스트"),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                final String? idToken = await user?.getIdToken(true);
                if (idToken == null) return;

                final response = await http.get(
                  Uri.parse('http://localhost:8080/api/hello'),
                  headers: {
                    'Authorization': 'Bearer $idToken',
                  },
                );
                print(response.body);
              },
            ),*/

            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
              onPressed: () async {
                await AuthService.logout();
                context.go('/login'); // 로그인 화면으로 이동
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
