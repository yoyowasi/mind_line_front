import 'package:flutter/material.dart';

class ExpenseItem {
  final String id;
  final String category;
  final String description;
  final double amount;
  final String type; // "expense" 또는 "income"
  final DateTime date;

  ExpenseItem({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    // 백엔드 ObjectId 형식에 맞춰 안전하게 ID를 파싱합니다.
    final dynamic idField = json['id'];
    final String parsedId = (idField is Map && idField.containsKey('\$oid'))
        ? idField['\$oid']
        : idField.toString();

    return ExpenseItem(
      id: parsedId,
      category: json['category'] ?? '기타',
      description: json['description'] ?? '내역 없음',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      type: json['type'] ?? 'expense',
      date: DateTime.parse(json['date']),
    );
  }

  // 데이터에 따라 아이콘과 색상을 반환하는 헬퍼 getter
  bool get isIncome => type == 'income';
  Color get color => isIncome ? Colors.blueAccent : Colors.redAccent;
  IconData get icon {
    switch (category) {
      case '식비': return Icons.fastfood_outlined;
      case '교통': return Icons.directions_bus_filled_outlined;
      case '급여': return Icons.receipt_long_outlined;
      case '간식': return Icons.icecream_outlined;
      case '쇼핑': return Icons.shopping_bag_outlined;
      default: return Icons.wallet_outlined;
    }
  }
}