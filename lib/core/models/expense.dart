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
  /// 날짜(백엔드는 LocalDate만 주므로 시각은 00:00일 수 있음)
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
    // 1) date는 LocalDate라 여러 포맷 가능 → 안전 파서
    DateTime? dateOnly;
    if (j.containsKey('date')) {
      dateOnly = _readDate(j['date']);
    }

    // 2) time(옵션)이 있으면 합치기. 없으면 dateOnly 그대로(00:00)
    final timeStr = _asString(j['time']);
    DateTime dt;
    if (dateOnly != null && timeStr.isNotEmpty) {
      // "HH:mm"
      final hm = timeStr.split(':');
      final h = int.tryParse(hm[0]) ?? 0;
      final m = (hm.length > 1) ? int.tryParse(hm[1]) ?? 0 : 0;
      dt = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, h, m);
    } else if (dateOnly != null) {
      dt = DateTime(dateOnly.year, dateOnly.month, dateOnly.day);
    } else {
      // 서버가 date를 안 줄 경우(이례적) createdAt/updatedAt으로 보정
      dt = _readDateTimeIso(j['createdAt']) ??
          _readDateTimeIso(j['updatedAt']) ??
          DateTime.now();
    }

    return Expense(
      id: _readId(j),
      date: dt,
      amount: (j['amount'] as num).toDouble(),
      currency: _asString(j['currency']),
      category: categoryFromString(_asString(j['category'])),
      memo: j['memo'] as String?,
      createdAt: _readDateTimeIso(j['createdAt']),
      updatedAt: _readDateTimeIso(j['updatedAt']),
    );
  }

  /// 생성 요청 바디 (백엔드는 LocalDate만 받음!)
  Map<String, dynamic> toJsonCreate() => {
    'date': DateFormat('yyyy-MM-dd').format(date),
    'amount': amount,
    'currency': currency,
    'category': category.name,
    if (memo != null && memo!.isNotEmpty) 'memo': memo,
  };
}
