import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ✅ 이 부분을 실제 서버 IP 주소로 변경해주세요.
  static const String baseUrl = 'http://127.0.0.1:8080'; // 'http://YOUR_SERVER_URL' -> 실제 IP

  static Future<http.Response> post(String path, dynamic body) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> get(String path) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}

// AuthService는 그대로 둡니다.
class AuthService {
  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}