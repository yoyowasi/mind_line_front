import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

Future<void> sendTokenToSpringBoot() async {
  try {
    // 1. Firebase 로그인된 사용자 가져오기
    final user = FirebaseAuth.instance.currentUser;

    // 2. ID 토큰 발급받기
    final idToken = await user?.getIdToken();

    // 3. Spring Boot로 POST 요청 보내기
    final response = await http.post(
      Uri.parse('http://<스프링부트서버주소>/api/auth'),  // 예: http://localhost:8080/api/auth
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      print('✅ 서버 응답 성공: ${response.body}');
    } else {
      print('❌ 서버 오류: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('❗ 오류 발생: $e');
  }
}
