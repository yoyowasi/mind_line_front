import 'package:flutter/material.dart';
import 'diary_model.dart';
import 'diary_service.dart';

class DiaryController extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();
  final List<DiaryEntry> entries = [];

  bool isLoading = false;

  Future<void> submitDiary() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    isLoading = true;
    notifyListeners();

    try {
      final newEntry = await DiaryService.postDiary(text);
      entries.insert(0, newEntry);
      textController.clear();
    } catch (e) {
      // TODO: 오류 처리 (스낵바 등)
      print('일기 등록 실패: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
