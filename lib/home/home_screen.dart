import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
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
  final GlobalKey<ChatTabState> _chatTabKey = GlobalKey<ChatTabState>();
  late final List<Widget> _tabWidgets;

  User? _user;
  int _selectedIndex = 0;

  final List<String> _titles = [
    '채팅',
    '내 일정',
    '지출내역',
    '일기 보기',
    '달력',
    '가계부',
    '분석',
    '설정',
  ];

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;

    _tabWidgets = [
      ChatTab(key: _chatTabKey),
      const ScheduleTab(),
      const ExpenseTab(),
      const DaliyTab(),
    ];
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  /*Widget _buildTabView() {
    switch (_selectedIndex) {
      case 0:
        return ChatTab(key: _chatTabKey);
      case 1:
        return const ScheduleTab();
      case 2:
        return const ExpenseTab();
      case 3:
        return const DaliyTab();
      default:
        return Center(child: Text('${_titles[_selectedIndex]} (미구현)'));
    }
  }*/

  void _selectFromDrawer(int index) {
    Navigator.pop(context); // 사이드바 닫기
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF00A5D9);

    return Scaffold(
      appBar: AppBar(
        title: Text('DailyCircle - ${_titles[_selectedIndex]}'),
        backgroundColor: themeColor,
        centerTitle: true,
        elevation: 2,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _chatTabKey.currentState?.resetMessages();
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
              leading: const Icon(Icons.chat),
              title: const Text('채팅'),
              onTap: () => _selectFromDrawer(0),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('달력'),
              onTap: () => _selectFromDrawer(4),
            ),
            ListTile(
              leading: const Icon(Icons.event_note),
              title: const Text('일정'),
              onTap: () => _selectFromDrawer(1),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('일기'),
              onTap: () => _selectFromDrawer(3),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('가계부'),
              onTap: () => _selectFromDrawer(5),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('분석'),
              onTap: () => _selectFromDrawer(6),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () => _selectFromDrawer(7),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: _logout,
            ),
          ],
        ),
      ),

      //body: SafeArea(child: _buildTabView()),
      body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: _tabWidgets,
          )
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex > 3 ? 0 : _selectedIndex, // 탭 범위 제한
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
