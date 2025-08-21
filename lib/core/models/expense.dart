import 'package:intl/intl.dart';

enum ExpenseCategory {
  FOOD, TRANSPORT, HEALTH, ENTERTAINMENT, EDUCATION, SHOPPING, TRAVEL, TAXES, OTHER
}

// 안전 문자열
String _asString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

// 다양한 id 케이스: "id", "_id", {"$oid": "..."}
String _readId(Map<String, dynamic> j) {
  final v = j['id'] ?? j['_id'];
  if (v == null) return '';
  if (v is String) return v;
  if (v is Map && v.containsKey(r'$oid')) {
    final s = v[r'$oid'];
    if (s is String) return s;
  }
  return _asString(v);
}

// LocalDate 여러 형태 파싱: "yyyy-MM-dd" | [yyyy,mm,dd] | {"$date":"..."} 등
DateTime _readDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    // "2025-08-22" 또는 ISO8601
    return DateTime.parse(v);
  }
  if (v is List && v.length >= 3) {
    // [2025,8,22]
    return DateTime(v[0], v[1], v[2]);
  }
  if (v is Map) {
    final cand = v[r'$date'] ?? v['date'] ?? v['iso'] ?? v['_iso'];
    if (cand is String && cand.isNotEmpty) return DateTime.parse(cand);
  }
  throw FormatException('Unsupported date: $v');
}

DateTime? _readDateTimeIso(dynamic v) {
  final s = _asString(v);
  if (s.isEmpty) return null;
  return DateTime.parse(s);
}

ExpenseCategory categoryFromString(String s) {
  final key = s.trim().toUpperCase();
  return ExpenseCategory.values.firstWhere(
        (e) => e.name.toUpperCase() == key,
    orElse: () => ExpenseCategory.OTHER,
  );
}

String categoryToString(ExpenseCategory c) => c.name;

class Expense {
  final String id;
  final DateTime date;
  final double amount;
  final String currency;
  final ExpenseCategory category;
  final String? memo;

  /// 등록/수정 시각(서버 @CreatedDate/@LastModifiedDate). "시각" 표시용으로 사용!
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    this.memo,
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> j) {
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
    final cat = ExpenseCategory.values.firstWhere(
          (e) => e.name.toUpperCase() == catStr,
      orElse: () => ExpenseCategory.OTHER,
    );

    return Expense(
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
