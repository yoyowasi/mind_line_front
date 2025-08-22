// /mnt/data/expense_controller.dart
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

  /// UI에서 호출하여 새 내역을 추가
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
      // 성공 시 목록 갱신
      await loadExpenses();
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// 목록 로딩
  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await ExpenseService.fetchExpenses();
    } catch (e) {
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
