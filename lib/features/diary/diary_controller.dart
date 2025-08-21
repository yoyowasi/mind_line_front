import 'package:flutter/material.dart';
import 'diary_model.dart';
import 'diary_service.dart';

class DiaryController extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();

  List<DiaryEntry> _entries = [];
  List<DiaryEntry> get entries => _entries;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadDiaries() async {
    _isLoading = true;
    notifyListeners();
    try {
      _entries = await DiaryService.fetchDiaryList();
    } catch (e) {
      // TODO: Log message: '일기 목록 로딩 실패: $e'
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitDiary() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      // ✅ 저장이 성공하면, 전체 목록을 다시 불러와 최신 상태를 유지
      await DiaryService.postDiary(text);
      await loadDiaries();
      textController.clear();
    } catch (e) {
      // TODO: Log message: '일기 저장 실패: $e'
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}