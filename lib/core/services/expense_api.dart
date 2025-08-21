import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';
import '../../core/config.dart'; // Config.apiBase 존재 가정

class ExpenseApi {
  static Future<String?> _token() async =>
      await FirebaseAuth.instance.currentUser?.getIdToken();

  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Config.apiBase}$path').replace(queryParameters: q);

  static final _df = DateFormat('yyyy-MM-dd');
  static final _tf = DateFormat('HH:mm');

  /// 월 범위 목록 조회
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
      throw Exception('list failed: ${res.statusCode} ${res.body}');
    }
    final List data = jsonDecode(res.body);
    return data.map((e) => Expense.fromJson(e)).toList();
  }

  /// 생성 (date, time 분리 전송)
  static Future<Expense> create(Expense newOne) async {
    final token = await _token();
    final body = newOne.toJsonCreate(); // {"date":"YYYY-MM-DD","time":"HH:mm",...}
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

  /// 수정 (가능하면 time도 같이 보냄 - 서버는 없어도 무시됨)
  static Future<Expense> update(
      String id, {
        DateTime? date,
        double? amount,
        String? currency,
        ExpenseCategory? category,
        String? memo,
      }) async {
    final token = await _token();
    final body = <String, dynamic>{};
    if (date != null) {
      body['date'] = _df.format(date);
      body['time'] = _tf.format(date); // 서버가 사용하지 않아도 무해 (무시)
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
