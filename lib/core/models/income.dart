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
    DateTime _readDate(dynamic v) {
      if (v is String) return DateTime.parse(v);
      if (v is List && v.length >= 3) return DateTime(v[0], v[1], v[2]);
      if (v is Map) {
        final s = v['date'] ?? v[r'$date'] ?? v['iso'];
        if (s is String) return DateTime.parse(s);
      }
      throw FormatException('Bad date: $v');
    }

    String _readId(Map<String, dynamic> j) {
      final v = j['id'] ?? j['_id'];
      if (v is String) return v;
      if (v is Map && v[r'$oid'] is String) return v[r'$oid'];
      return '';
    }

    return Income(
      id: j['id'] ?? j['_id'],
      date: DateTime.parse(j['date']),
      amount: (j['amount'] as num).toDouble(),
      currency: j['currency'],
      category: IncomeCategory.values.firstWhere((e) => e.name == j['category']),
      memo: j['memo'],
      createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : null,
      updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJsonCreate() => {
    'date': date.toIso8601String().substring(0, 10),
    'amount': amount,
    'currency': currency,
    'category': category.name,
    if (memo != null) 'memo': memo,
  };
}

enum IncomeCategory { SALARY, ALLOWANCE, BONUS, INVEST, REFUND, OTHER }

IncomeCategory incomeCategoryFromString(String s) {
  final key = s.trim().toUpperCase();
  return IncomeCategory.values.firstWhere((e) => e.name == key, orElse: () => IncomeCategory.OTHER);
}
