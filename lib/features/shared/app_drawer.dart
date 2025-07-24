import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart'; // 로그아웃 처리 함수

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text(
              '메뉴',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('홈'),
            onTap: () {
              Navigator.pop(context); // 사이드바 닫기
              context.go('/home');
            },
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart),
            title: const Text('감정 통계 보기'),
            onTap: () {
              Navigator.pop(context);
              context.go('/stats');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('내 일기 보기'),
            onTap: () {
              Navigator.pop(context);
              context.go('/diary/list');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              await AuthService.logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
