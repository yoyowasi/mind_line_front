import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../core/services/api_service.dart';
import 'diary_model.dart';
import 'package:intl/intl.dart'; // 날짜 포맷을 위해 추가

class DiaryService {
  /// 일기 텍스트를 서버에 전송 → 감정 분석 결과 포함된 DiaryEntry 응답 받음
  static Future<DiaryEntry> postDiary(String text) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    // 오늘 날짜를 'YYYY-MM-DD' 형식의 문자열로 생성
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/diary'), // API 엔드포인트는 그대로 유지
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      // ✅ DiaryEntity 형식에 맞게 JSON 본문 수정
      body: jsonEncode({
        'content': text, // 'text' -> 'content'
        'date': todayDate, // 'date' 필드 추가
      }),
    );

    if (response.statusCode == 200) {
      // utf8로 디코딩하여 한글 깨짐 방지
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return DiaryEntry.fromJson(data);
    } else {
      // 오류 발생 시 서버 응답을 그대로 전달하여 원인 파악 용이하게 함
      throw Exception('서버 오류: ${response.statusCode} ${response.body}');
    }
  }

  /// 전체 일기 목록 불러오기 (차트 등에 사용)
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