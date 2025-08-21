import 'package:flutter/material.dart';

// 예시 데이터 모델
class ScheduleItem {
  final String title;
  final String time;
  final String location;
  final IconData icon;

  ScheduleItem({
    required this.title,
    required this.time,
    required this.location,
    required this.icon,
  });
}

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 실제로는 서버에서 가져올 예시 데이터
    final List<ScheduleItem> items = [
      ScheduleItem(title: '팀 프로젝트 회의', time: '10:00 AM - 11:30 AM', location: '온라인 (Google Meet)', icon: Icons.group),
      ScheduleItem(title: '치과 예약', time: '02:00 PM', location: '서울치과', icon: Icons.local_hospital),
      ScheduleItem(title: '저녁 약속', time: '07:00 PM', location: '강남역 2번 출구', icon: Icons.restaurant),
    ];

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.icon, color: Theme.of(context).colorScheme.primary),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.time}\n${item.location}'),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}