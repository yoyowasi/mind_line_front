import 'package:intl/intl.dart';

class Income {
  final String id;
  final DateTime date;
  final double amount;
  final String currency;
  final IncomeCategory category;
  final String? memo;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Income({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    this.memo,
    this.createdAt,
    this.updatedAt,
  });

  factory Income.fromJson(Map<String, dynamic> j) {
    DateTime parseDate() {
      final d = j['date'];
      final t = j['time'];
      if (d is String && t is String) {
        // date + time 조합
        return DateTime.parse('${d}T${t.padLeft(5, '0')}:00');
      }
      if (d is String) {
        // ISO 전체가 올 수도 있음
        return DateTime.parse(d);
      }
      throw const FormatException('date/time not parsable');
    }

    final catStr = (j['category'] ?? 'OTHER').toString().toUpperCase();
    final cat = IncomeCategory.values.firstWhere(
          (e) => e.name.toUpperCase() == catStr,
      orElse: () => IncomeCategory.OTHER,
    );

    return Income(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      date: parseDate(),
      amount: (j['amount'] as num).toDouble(),
      currency: (j['currency'] ?? 'KRW').toString(),
      category: cat,
      memo: (j['memo'] as String?),
      createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : null,
      updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJsonCreate() {
    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');
    return {
      'date': df.format(date),
      'time': tf.format(date),
      'amount': amount,
      'currency': currency,
      'category': category.name,
      if (memo != null && memo!.isNotEmpty) 'memo': memo,
    };
  }
}

enum IncomeCategory { SALARY, ALLOWANCE, BONUS, INVEST, REFUND, OTHER }

IncomeCategory incomeCategoryFromString(String s) {
  final key = s.trim().toUpperCase();
  return IncomeCategory.values.firstWhere((e) => e.name == key, orElse: () => IncomeCategory.OTHER);
}
