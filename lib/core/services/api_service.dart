import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://YOUR_SERVER_URL';

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
class AuthService {
  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
