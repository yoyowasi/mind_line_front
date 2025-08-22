import 'package:intl/intl.dart'; // ✅✅✅ 'package:' 빠진 부분 수정

enum ExpenseCategory {
  FOOD, TRANSPORT, HEALTH, ENTERTAINMENT, EDUCATION, SHOPPING, TRAVEL, TAXES, OTHER
}

class Expense {
  final String id;
  final DateTime dateTime;
  final double amount;
  final String currency;
  final ExpenseCategory category;
  final String? memo;

  Expense({
    required this.id,
    required this.dateTime,
    required this.amount,
    required this.currency,
    required this.category,
    this.memo,
  });

  // UI 호환성을 위해 기존 date getter는 유지합니다.
  DateTime get date => dateTime;

  factory Expense.fromJson(Map<String, dynamic> j) {
    final catStr = (j['category'] ?? 'OTHER').toString().toUpperCase();
    final cat = ExpenseCategory.values.firstWhere(
          (e) => e.name.toUpperCase() == catStr,
      orElse: () => ExpenseCategory.OTHER,
    );

    return Expense(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      // ✅ 서버에서 오는 'dateTime' 필드를 직접 파싱합니다.
      dateTime: DateTime.parse(j['dateTime'] as String),
      amount: (j['amount'] as num).toDouble(),
      currency: (j['currency'] ?? 'KRW').toString(),
      category: cat,
      memo: (j['memo'] as String?),
    );
  }

  Map<String, dynamic> toJsonCreate() {
    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');
    return {
      'date': df.format(dateTime),
      'time': tf.format(dateTime),
      'amount': amount,
      'currency': currency,
      'category': category.name,
      if (memo != null && memo!.isNotEmpty) 'memo': memo,
    };
  }
}