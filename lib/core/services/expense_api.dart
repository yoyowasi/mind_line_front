// /mnt/data/expense_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';
import '../../core/config.dart'; // Config.apiBase 가정

class ExpenseApi {
  static Future<String?> _token() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    print('ExpenseApi - Current user: ${user?.uid}, Token: $token');
    return token;
  }

  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Config.apiBase}$path').replace(queryParameters: q);

  static final _df = DateFormat('yyyy-MM-dd');
  static final _tf = DateFormat('HH:mm');

  /// 목록 조회 (기간)
  static Future<List<Expense>> list(DateTime from, DateTime to) async {
    final token = await _token();
    final res = await http.get(
      _u('/api/expenses', {'from': _df.format(from), 'to': _df.format(to)}),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      print('ExpenseApi.list - Error response: ${res.statusCode} ${res.body}');
      throw Exception('list failed: ${res.statusCode} ${res.body}');
    }
    final List data = jsonDecode(res.body);
    return data.map((e) => Expense.fromJson(e)).toList();
  }

  /// 생성 (date, time 분리 전송)
  static Future<Expense> create(Expense newOne) async {
    final token = await _token();
    final body = newOne.toJsonCreate();
    final res = await http.post(
      _u('/api/expenses'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) {
      throw Exception('create failed: ${res.statusCode} ${res.body}');
    }
    return Expense.fromJson(jsonDecode(res.body));
  }

  static Future<void> deleteById(String id) async {
    final token = await _token();
    final res = await http.delete(
      _u('/api/expenses/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 204) {
      throw Exception('delete failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Expense> update(
      String id, {
        DateTime? date,
        double? amount,
        String? currency,
        ExpenseCategory? category,
        String? memo,
      }) async {
    final token = await _token();
    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');

    final body = <String, dynamic>{};
    if (date != null) {
      body['date'] = df.format(date);
      body['time'] = tf.format(date);
    }
    if (amount != null) body['amount'] = amount;
    if (currency != null) body['currency'] = currency;
    if (category != null) body['category'] = category.name;
    if (memo != null) body['memo'] = memo;

    final res = await http.put(
      _u('/api/expenses/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('update failed: ${res.statusCode} ${res.body}');
    }
    return Expense.fromJson(jsonDecode(res.body));
  }
}
