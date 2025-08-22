import 'package:flutter/material.dart';

import '../core/models/expense_model.dart';
import '../core/services/expense_service.dart';

class ExpenseController extends ChangeNotifier {
  List<ExpenseItem> _items = [];
  List<ExpenseItem> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  /// ✅ [추가된 기능] UI에서 호출하여 새 내역을 추가하는 함수
  Future<bool> addExpense({
    required String category,
    required String description,
    required double amount,
    required String type,
    required DateTime time,
  }) async {
    try {
      await ExpenseService.addExpense(
        category: category,
        description: description,
        amount: amount,
        type: type,
        time: time,
      );
      // 저장이 성공하면 전체 목록을 새로고침하여 즉시 반영
      await loadExpenses();
      _lastError = null; // Clear previous error on success
      return true; // 성공 여부 반환
    } catch (e) {
      _lastError = e.toString(); // Store the error message
      print('지출/수입 추가 실패: $e');
      return false; // 실패 여부 반환
    }
  }

  /// 기존 데이터 로딩 함수
  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await ExpenseService.fetchExpenses();
    } catch (e) {
      print(e);
      _items = []; // 오류 발생 시 빈 목록으로 초기화
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}