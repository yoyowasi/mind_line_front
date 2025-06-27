import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // 🔐 로그인
  static Future<void> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final response = await http.post(
        Uri.parse('http://<스프링부트-서버주소>/api/auth'), // 실제 서버 주소로 변경하세요
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('✅ 서버 인증 성공: ${response.body}');
      } else {
        print('❌ 서버 인증 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❗ 로그인 또는 서버 인증 오류: $e');
      rethrow;
    }
  }

  // 📝 회원가입
  static Future<void> register(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ 회원가입 성공');
    } catch (e) {
      print('❗ 회원가입 실패: $e');
      rethrow;
    }
  }
}
