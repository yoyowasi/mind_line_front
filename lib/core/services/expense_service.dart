// /mnt/data/expense_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/api_service.dart';
import '../models/expense_model.dart';

class ExpenseService {
  /// 새로운 지출/수입 내역을 서버에 저장
  static Future<ExpenseItem> addExpense({
    required String category,
    required String description,
    required double amount,
    required String type,
    required DateTime time,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/expenses'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'category': category,
        'description': description,
        'amount': amount,
        'type': type,
        'time': time.toIso8601String(),
      }),
    );

    if (response.statusCode == 201) {
      final rawBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(rawBody);
      return ExpenseItem.fromJson(data);
    } else {
      throw Exception('저장 실패: ${response.statusCode} ${response.body}');
    }
  }

  /// 목록 조회
  static Future<List<ExpenseItem>> fetchExpenses() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/expenses'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(response.bodyBytes));
      return list.map((e) => ExpenseItem.fromJson(e)).toList();
    } else {
      throw Exception('지출/수입 내역 로딩 실패: ${response.statusCode}');
    }
  }
}
