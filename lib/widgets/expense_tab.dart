import 'package:flutter/material.dart';

// 예시 데이터 모델
class ExpenseItem {
  final IconData icon;
  final String category;
  final String description;
  final double amount;

  ExpenseItem({
    required this.icon,
    required this.category,
    required this.description,
    required this.amount,
  });
}

class ExpenseTab extends StatelessWidget {
  const ExpenseTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 실제로는 서버에서 가져올 예시 데이터
    final List<ExpenseItem> items = [
      ExpenseItem(icon: Icons.fastfood, category: '식비', description: '점심 식사 (부대찌개)', amount: -9000),
      ExpenseItem(icon: Icons.local_cafe, category: '간식', description: '아이스 아메리카노', amount: -4500),
      ExpenseItem(icon: Icons.receipt, category: '급여', description: '8월 급여', amount: 3000000),
      ExpenseItem(icon: Icons.train, category: '교통', description: '지하철 이용', amount: -1450),
    ];

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isIncome = item.amount > 0;
          final color = isIncome ? Colors.blue : Colors.red;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(item.icon, color: color),
              title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.category),
              trailing: Text(
                '${isIncome ? '+' : ''}${item.amount.toStringAsFixed(0)}원',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          );
        },
      ),
    );
  }
}