import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/api_service.dart';
import 'diary_model.dart';

class DiaryService {
  /// 일기 텍스트를 서버에 전송 → 감정 분석 결과 포함된 DiaryEntry 응답 받음
  static Future<DiaryEntry> postDiary(String text) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/diary'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DiaryEntry.fromJson(data);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
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
      final List list = jsonDecode(response.body);
      return list.map((e) => DiaryEntry.fromJson(e)).toList();
    } else {
      throw Exception('불러오기 실패: ${response.statusCode}');
    }
  }
}
