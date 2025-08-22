// /mnt/data/expense_model.dart
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
    final dynamic idField = json['id'];
    final String parsedId = (idField is Map && idField.containsKey(r'$oid'))
        ? idField[r'$oid']
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

  bool get isIncome => type == 'income';
  Color get color => isIncome ? Colors.blueAccent : Colors.redAccent;
  IconData get icon {
    switch (category) {
      case '식비':
        return Icons.fastfood_outlined;
      case '교통':
        return Icons.directions_bus_filled_outlined;
      case '급여':
        return Icons.receipt_long_outlined;
      case '간식':
        return Icons.icecream_outlined;
      case '쇼핑':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.wallet_outlined;
    }
  }
}
