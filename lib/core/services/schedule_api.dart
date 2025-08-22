import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../models/schedule.dart';
import '../../core/config.dart';

class ScheduleApi {
  static Future<String?> _token() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Config.apiBase}$path').replace(queryParameters: q);

  static Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static final _df = DateFormat('yyyy-MM-dd');
  static final _tf = DateFormat('HH:mm');

  static String _formatTime(Object t) {
    if (t is TimeOfDay) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (t is DateTime) return _tf.format(t);
    if (t is String) {
      final s = t.trim();
      final m = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(s);
      if (m != null) {
        final h = m.group(1)!.padLeft(2, '0');
        final mm = m.group(2)!.padLeft(2, '0');
        return '$h:$mm';
      }
      return s; // 이미 HH:mm이라고 가정
    }
    throw ArgumentError('time must be String/TimeOfDay/DateTime');
  }

  /// GET /api/schedules?from=yyyy-MM-dd&to=yyyy-MM-dd
  static Future<List<ScheduleItem>> list(DateTime from, DateTime to) async {
    final token = await _token();
    final res = await http.get(
      _u('/api/schedules', {'from': _df.format(from), 'to': _df.format(to)}),
      headers: _headers(token),
    );
    if (res.statusCode != 200) {
      throw Exception('list failed: ${res.statusCode} ${res.body}');
    }
    final List data = jsonDecode(res.body);
    return data.map((e) => ScheduleItem.fromJson(e)).toList();
  }

  /// POST /api/schedules  (BE는 date/time/content를 요구)
  static Future<ScheduleItem> create(ScheduleItem s) async {
    final token = await _token();

    final body = <String, dynamic>{
      'date': _df.format(s.start),
      'time': s.allDay ? null : _tf.format(s.start), // 종일이면 null
      'content': (s.title.isNotEmpty ? s.title : (s.memo ?? '')).trim(),
      // 백엔드가 무시해도 되는 기본값
      'alarmEnabled': false,
      'repeatEnabled': false,
    };

    final res = await http.post(
      _u('/api/schedules'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) {
      throw Exception('create failed: ${res.statusCode} ${res.body}');
    }
    return ScheduleItem.fromJson(jsonDecode(res.body));
  }

  /// PUT /api/schedules/:id  (부분 업데이트, 바뀐 필드만)
  static Future<ScheduleItem> updateTyped(
      String id, {
        DateTime? start,        // 변경 시 date/time로 쪼개 전송
        String? title,          // content 로 보냄
        bool? allDay,           // true면 time=null
        bool? alarmEnabled,
        bool? repeatEnabled,
      }) async {
    final token = await _token();
    final body = <String, dynamic>{};

    if (start != null) {
      body['date'] = _df.format(start);
      body['time'] = (allDay == true) ? null : _tf.format(start);
    }
    if (title != null) body['content'] = title.trim();
    if (alarmEnabled != null) body['alarmEnabled'] = alarmEnabled;
    if (repeatEnabled != null) body['repeatEnabled'] = repeatEnabled;

    final res = await http.put(
      _u('/api/schedules/$id'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('update failed: ${res.statusCode} ${res.body}');
    }
    return ScheduleItem.fromJson(jsonDecode(res.body));
  }

  /// 임의 body 전송이 필요하면 사용
  static Future<ScheduleItem> update(String id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      _u('/api/schedules/$id'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('update failed: ${res.statusCode} ${res.body}');
    }
    return ScheduleItem.fromJson(jsonDecode(res.body));
  }

  static Future<void> deleteById(String id) async {
    final token = await _token();
    final res = await http.delete(
      _u('/api/schedules/$id'),
      headers: _headers(token),
    );
    if (res.statusCode != 204) {
      throw Exception('delete failed: ${res.statusCode} ${res.body}');
    }
  }
}
