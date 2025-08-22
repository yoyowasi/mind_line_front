import 'package:flutter/foundation.dart';

enum ScheduleType { meeting, appointment, personal, travel, workout, other }

/// ── 안전 파서 ─────────────────────────────────────────────────────────────────
String _asString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

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

/// 다양한 케이스: "2025-08-22T10:00:00Z" / {"$date": "..."} / {"iso":"..."} / ["yyyy","mm","dd","HH","mm"]
DateTime? _readDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.parse(v);
  if (v is List && v.isNotEmpty) {
    final y = (v[0] as num).toInt();
    final m = v.length > 1 ? (v[1] as num).toInt() : 1;
    final d = v.length > 2 ? (v[2] as num).toInt() : 1;
    final H = v.length > 3 ? (v[3] as num).toInt() : 0;
    final M = v.length > 4 ? (v[4] as num).toInt() : 0;
    final S = v.length > 5 ? (v[5] as num).toInt() : 0;
    return DateTime(y, m, d, H, M, S);
  }
  if (v is Map) {
    final cand = v[r'$date'] ?? v['date'] ?? v['iso'] ?? v['_iso'];
    if (cand is String && cand.isNotEmpty) return DateTime.parse(cand);
  }
  return null;
}

ScheduleType _typeFrom(dynamic v) {
  final s = _asString(v).trim().toLowerCase();
  return ScheduleType.values.firstWhere(
        (t) => describeEnum(t).toLowerCase() == s,
    orElse: () => ScheduleType.other,
  );
}

String _typeTo(ScheduleType t) => describeEnum(t);

/// ── 모델 ─────────────────────────────────────────────────────────────────────
class ScheduleItem {
  final String id;
  final String title;
  final DateTime start;     // 시작(로컬시간)
  final DateTime? end;      // 종료(로컬시간, 없으면 단일 일정)
  final String location;
  final ScheduleType type;
  final String? memo;
  final bool allDay;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.type,
    this.memo,
    this.allDay = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> j) {
    final id = _readId(j);
    final title = _asString(j['title'] ?? j['content']);
    DateTime? start = _readDateTime(j['start']);
    if (start == null) {
      final ds = _asString(j['date']);
      final ts = _asString(j['time']);
      if (ds.isNotEmpty && ts.isNotEmpty) {
        // "H:m" → "HH:mm" 보정
        final m = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(ts);
        final hhmm = m != null
            ? '${m.group(1)!.padLeft(2, '0')}:${m.group(2)!.padLeft(2, '0')}'
            : ts;
        start = DateTime.parse('${ds}T$hhmm:00');
      }
    }
    if (start == null) {
      throw const FormatException('start missing/invalid');
    }

    final end = _readDateTime(j['end']); // 없으면 null
    final location = _asString(j['location']);
    final type = _typeFrom(j['type']); // 없으면 other
    final memo = j['memo'] == null ? null : _asString(j['memo']);
    final allDay = j['allDay'] == true || j['allDay'] == 'true';

    return ScheduleItem(
      id: id,
      title: title,
      start: start,
      end: end,
      location: location,
      type: type,
      memo: memo,
      allDay: allDay,
      createdAt: _readDateTime(j['createdAt']),
      updatedAt: _readDateTime(j['updatedAt']),
    );
  }

  Map<String, dynamic> toJsonCreate() => {
    'title': title,
    'start': start.toIso8601String(),
    if (end != null) 'end': end!.toIso8601String(),
    'location': location,
    'type': _typeTo(type),
    'allDay': allDay,
    if (memo != null && memo!.isNotEmpty) 'memo': memo,
  };

  Map<String, dynamic> toJsonUpdate() => {
    // 부분 업데이트 시 null은 보내지 않도록 주의. 필요하면 필드개별로 선별해서 쓰기.
    'title': title,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'location': location,
    'type': _typeTo(type),
    'allDay': allDay,
    'memo': memo,
  };

  ScheduleItem copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end, // nullable을 명시적으로 null로 바꾸고 싶다면 별도 플래그 쓰세요.
    String? location,
    ScheduleType? type,
    String? memo,
    bool? allDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      location: location ?? this.location,
      type: type ?? this.type,
      memo: memo ?? this.memo,
      allDay: allDay ?? this.allDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
