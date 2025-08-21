import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/api_service.dart';
import 'diary_model.dart';
import 'package:intl/intl.dart'; // 날짜 포맷을 위해 추가

class DiaryService {
  /// 일기 텍스트를 서버에 전송 (AI 분석 없이 저장만)
  static Future<DiaryEntry> postDiary(String text) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/diary'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      // ✅ DiaryEntity 형식에 맞게 mood를 추가합니다.
      // AI 분석을 안 하므로, 'NEUTRAL' 같은 기본값을 보내줍니다.
      body: jsonEncode({
        'content': text,
        'date': todayDate,
        'mood': 'NEUTRAL', // 기본 감정 상태 추가
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // utf8로 디코딩하여 한글 깨짐 방지
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return DiaryEntry.fromJson(data);
    } else {
      // 오류 발생 시 서버 응답을 그대로 전달하여 원인 파악 용이하게 함
      throw Exception('서버 오류: ${response.statusCode} ${utf8.decode(response.bodyBytes)}');
    }
  }

  /// 특정 사용자의 전체 일기 목록 불러오기
  static Future<List<DiaryEntry>> fetchDiaryList() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/diary'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(response.bodyBytes));
      return list.map((e) => DiaryEntry.fromJson(e)).toList();
    } else {
      throw Exception('일기 목록 불러오기 실패: ${response.statusCode}');
    }
  }
}