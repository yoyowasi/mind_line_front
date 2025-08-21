import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/config.dart';
import '../models/income.dart';

class IncomeApi {
  static Future<String?> _token() async => FirebaseAuth.instance.currentUser?.getIdToken();

  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Config.apiBase}$path').replace(queryParameters: q);

  static Future<List<Income>> list(DateTime from, DateTime to) async {
    final token = await _token();
    final df = DateFormat('yyyy-MM-dd');
    final res = await http.get(
      _u('/api/incomes', {'from': df.format(from), 'to': df.format(to)}),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw Exception('income list failed: ${res.statusCode} ${res.body}');
    }
    final List data = jsonDecode(res.body);
    return data.map((e) => Income.fromJson(e)).toList();
  }

  static Future<Income> create(Income x) async {
    final token = await _token();
    final res = await http.post(
      _u('/api/incomes'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(x.toJsonCreate()),
    );
    if (res.statusCode != 201) {
      throw Exception('income create failed: ${res.statusCode} ${res.body}');
    }
    return Income.fromJson(jsonDecode(res.body));
  }

  static Future<void> deleteById(String id) async {
    final token = await _token();
    final res = await http.delete(_u('/api/incomes/$id'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 204) {
      throw Exception('income delete failed: ${res.statusCode} ${res.body}');
    }
  }
  static Future<Income> update(
      String id, {
        DateTime? date,
        double? amount,
        String? currency,
        IncomeCategory? category,
        String? memo,
      }) async {
    final token = await _token();
    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');

    final body = <String, dynamic>{};
    if (date != null) {
      body['date'] = df.format(date);
      body['time'] = tf.format(date); // ★ 추가: 시간도 전송
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
    return Income.fromJson(jsonDecode(res.body));
  }

}
