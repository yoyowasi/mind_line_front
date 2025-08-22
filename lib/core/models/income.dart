// /mnt/data/income.dart
import 'package:intl/intl.dart';

enum IncomeCategory { SALARY, ALLOWANCE, BONUS, INVEST, REFUND, OTHER }

class Income {
  final String id;
  final DateTime dateTime;
  final double amount;
  final String currency;
  final IncomeCategory category;
  final String? memo;

  Income({
    required this.id,
    required this.dateTime,
    required this.amount,
    required this.currency,
    required this.category,
    this.memo,
  });

  // UI 호환을 위해 기존 getter 유지
  DateTime get date => dateTime;

  factory Income.fromJson(Map<String, dynamic> j) {
    final catStr = (j['category'] ?? 'OTHER').toString().toUpperCase();
    final cat = IncomeCategory.values.firstWhere(
          (e) => e.name.toUpperCase() == catStr,
      orElse: () => IncomeCategory.OTHER,
    );

    return Income(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      dateTime: DateTime.parse(j['dateTime'] as String),
      amount: (j['amount'] as num).toDouble(),
      currency: (j['currency'] ?? 'KRW').toString(),
      category: cat,
      memo: (j['memo'] as String?),
    );
  }

  /// 생성 요청용 JSON (백엔드 요구 포맷: date, time 분리)
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
