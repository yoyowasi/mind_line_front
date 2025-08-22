// lib/features/diary/diary_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import 'diary_model.dart';

class DiaryService {
  static Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// 저장(업서트) - 저장은 save 컨트롤러 사용 (/api/diaries, POST)
  static Future<DiaryEntry> upsertDiary({
    required DateTime date,
    String? content,
    String? legacyText,
    required String mood, // 서버 enum 문자열
  }) async {
    final headers = await _authHeaders();
    final body = jsonEncode({
      "date": DateFormat('yyyy-MM-dd').format(date),
      if (content != null) "content": content,
      if (legacyText != null) "legacyText": legacyText,
      "mood": mood,
    });

    final res = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/diaries'),
      headers: headers,
      body: body,
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return DiaryEntry.fromJson(map);
    } else {
      throw Exception('일기 저장 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// 해당 날짜 일기 조회 - save 컨트롤러 GET (/api/diaries/{date})
  static Future<DiaryEntry> getDiaryByDate(DateTime date) async {
    final headers = await _authHeaders();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/diaries/$dateStr'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return DiaryEntry.fromJson(map);
    } else {
      throw Exception('일기 조회 실패(${dateStr}): ${res.statusCode}');
    }
  }

  /// 가장 최근 일기 - save 컨트롤러 GET (/api/diaries/latest)
  static Future<DiaryEntry> getLatestDiary() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/diaries/latest'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return DiaryEntry.fromJson(map);
    } else {
      throw Exception('최근 일기 조회 실패: ${res.statusCode}');
    }
  }

  /// 최근 분석 결과 - diaryai 컨트롤러 GET (/api/ai/diary/latest-summary)
  static Future<({DateTime date, String summary})> getLatestSummary() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/ai/diary/latest-summary'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      final summary = map['summary'] as String? ?? map['answer'] as String? ?? '';
      return (date: date, summary: summary);
    } else {
      throw Exception('최근 요약 조회 실패: ${res.statusCode}');
    }
  }

  /// 리스트 화면용: 최근 N일을 역순으로 훑으면서 존재하는 일기만 수집 (save GET 사용)
  static Future<List<DiaryEntry>> listRecent({int days = 14}) async {
    final List<DiaryEntry> list = [];
    for (int i = 0; i < days; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      try {
        final e = await getDiaryByDate(day);
        list.add(e);
      } catch (_) {
        // 없는 날은 건너뜀
      }
    }
    return list;
  }
}
