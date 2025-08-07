import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '설정',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263FA9),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('다크 모드'),
                value: false,
                onChanged: (val) {},
              ),
              const ListTile(
                leading: Icon(Icons.person),
                title: Text('계정 관리'),
              ),
              const ListTile(
                leading: Icon(Icons.notifications),
                title: Text('알림 설정'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
