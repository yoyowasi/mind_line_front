import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart'; // 충돌 방지용 api_service.dart 제거
import '../widgets/chat_tab.dart';
import '../widgets/expense_tab.dart';
import '../widgets/schedule_tab.dart';
import '../widgets/daliy_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  Widget _buildTabView() {
    switch (_selectedIndex) {
      case 3:
        return const DaliyTab();
      case 2:
        return const ExpenseTab();
      case 1:
        return const ScheduleTab();
      case 0:
      default:
        return const ChatTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF00A5D9);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'DailyCircle',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: themeColor,
        centerTitle: true,
        elevation: 2,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                // ChatTab에서 상태 초기화 구현 시 연결
              },
              tooltip: '새로고침',
            ),
        ],
      ),

      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: themeColor),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: themeColor, size: 30),
              ),
              accountName: const Text(''),
              accountEmail: Text(
                _user?.email ?? '사용자 정보 없음',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: _logout,
            ),
          ],
        ),
      ),

      body: SafeArea(child: _buildTabView()),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '내 일정'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: '지출내역'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '일기 보기'),
        ],
      ),
    );
  }
}
