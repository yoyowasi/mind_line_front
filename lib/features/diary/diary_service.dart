// lib/features/diary/diary_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/services/api_service.dart';
import 'diary_model.dart';

class DiaryService {
  static final DateFormat _df = DateFormat('yyyy-MM-dd');

  static Future<Map<String, String>> _authHeaders() async {
    var user = FirebaseAuth.instance.currentUser;

    // 콜드스타트 보정: auth 복원 기다리기 (최대 5초)
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    // 토큰 강제 리프레시(만료/복원 직후 대비)
    final token = await user?.getIdToken(true);

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _dateStr(DateTime d) {
    // 항상 자정으로 잘라서 서버(LocalDate)와 정확히 매칭
    final t = DateTime(d.year, d.month, d.day);
    return _df.format(t);
  }

  /// 업서트 (POST /api/diaries) — 서버 SaveController 사용
  static Future<DiaryEntry> upsertDiary({
    required DateTime date,
    String? content,
    String? legacyText,
    required String mood, // 서버 enum 문자열
  }) async {
    final headers = await _authHeaders();
    final body = jsonEncode({
      'date': _dateStr(date),
      if (content != null) 'content': content,
      if (legacyText != null) 'legacyText': legacyText,
      'mood': mood,
    });

    final res = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/diaries'),
      headers: headers,
      body: body,
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return DiaryEntry.fromJson(map);
    }
    throw Exception('일기 저장 실패: ${res.statusCode} ${res.body}');
  }

  /// 해당 날짜 일기 (GET /api/diaries/{date})
  static Future<DiaryEntry> getDiaryByDate(DateTime date) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/diaries/${_dateStr(date)}'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return DiaryEntry.fromJson(map);
    }
    throw Exception('일기 조회 실패(${_dateStr(date)}): ${res.statusCode}');
  }

  /// 가장 최근 일기 (GET /api/diaries/latest)
  static Future<DiaryEntry> getLatestDiary() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/diaries/latest'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return DiaryEntry.fromJson(map);
    }
    throw Exception('최근 일기 조회 실패: ${res.statusCode}');
  }

  /// 최근 일기 요약 (GET /api/ai/diary/latest-summary)
  static Future<({DateTime date, String summary})> getLatestSummary() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/ai/diary/latest-summary'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      final summary = (map['summary'] ?? map['answer'] ?? '') as String;
      return (date: date, summary: summary);
    }
    throw Exception('최근 요약 조회 실패: ${res.statusCode}');
  }

  /// 최근 N일 안에서 존재하는 일기만 수집해서 최신순으로 반환
  /// 서버에 범위 리스트 API가 없을 때 사용
  static Future<List<DiaryEntry>> listRecent({int days = 14}) async {
    // 개별일 조회를 병렬로 돌리되, 에러는 개별 무시
    final now = DateTime.now();
    final futures = <Future<DiaryEntry?>>[];

    for (int i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      futures.add(getDiaryByDate(day).then((v) => v).catchError((_) => null));
    }

    final results = await Future.wait(futures);
    final list = results.whereType<DiaryEntry>().toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // 최신순
    return list;
  }

  /// 월/기간 조회 — 서버가 지원하면 (GET /api/diaries?from=yyyy-MM-dd&to=yyyy-MM-dd)
  /// 지원 안 하면 listRecent로 폴백
  static Future<List<DiaryEntry>> listRange(DateTime from, DateTime to) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiService.baseUrl}/api/diaries').replace(
      queryParameters: {'from': _dateStr(from), 'to': _dateStr(to)},
    );

    Future<List<DiaryEntry>> _fallbackFetchByDay() async {
      // ✅ from~to 범위를 하루씩 직접 조회 (오늘 기준 아님!)
      final start = DateTime(from.year, from.month, from.day);
      final end   = DateTime(to.year, to.month, to.day);
      final days = end.difference(start).inDays + 1;

      final futures = <Future<DiaryEntry?>>[];
      for (int i = 0; i < days; i++) {
        final day = start.add(Duration(days: i));
        futures.add(getDiaryByDate(day).then((v) => v).catchError((_) => null));
      }
      final results = await Future.wait(futures);
      final list = results.whereType<DiaryEntry>().toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    }

    final res = await http.get(uri, headers: headers);
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
          final list = data.map((e) => DiaryEntry.fromJson(e)).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          return list;
        }
        // ✅ 정말로 API가 미구현(404, 501)일 때만 일자별 폴백
        if (res.statusCode == 404 || res.statusCode == 501) {
          return _fallbackFetchByDay();
        }
        // 그 외(401/403/500 등)는 즉시 에러를 던져서 재시도/알림 루트로
        throw Exception('listRange ${res.statusCode} ${utf8.decode(res.bodyBytes)}');
  }

  /// 삭제(날짜 기준) — 서버에 아래 엔드포인트 추가 필요:
  /// DELETE /api/diaries/{date}
  static Future<void> deleteByDate(DateTime date) async {
    final headers = await _authHeaders();
    final res = await http.delete(
      Uri.parse('${ApiService.baseUrl}/api/diaries/${_dateStr(date)}'),
      headers: headers,
    );
    if (res.statusCode == 204) return;
    throw Exception('삭제 실패(${_dateStr(date)}): ${res.statusCode} ${res.body}');
  }

  /// 삭제(id 기준) — 서버에 아래 엔드포인트 추가 필요(선택):
  /// DELETE /api/diaries/id/{id}
  static Future<void> deleteById(String id) async {
    final headers = await _authHeaders();
    final res = await http.delete(
      Uri.parse('${ApiService.baseUrl}/api/diaries/id/$id'),
      headers: headers,
    );
    if (res.statusCode == 204) return;
    throw Exception('삭제 실패(id=$id): ${res.statusCode} ${res.body}');
  }
}
