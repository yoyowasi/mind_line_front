// lib/features/diary/diary_controller.dart
import 'package:flutter/material.dart';
import 'diary_model.dart';
import 'diary_service.dart';

class DiaryController extends ChangeNotifier {
  bool _loading = false;
  List<DiaryEntry> _entries = [];
  DiaryEntry? _latest;
  ({DateTime date, String summary})? _latestSummary;

  bool get isLoading => _loading;
  List<DiaryEntry> get entries => _entries;
  DiaryEntry? get latest => _latest;
  ({DateTime date, String summary})? get latestSummary => _latestSummary;

  Future<void> loadInitial() async {
    _loading = true;
    notifyListeners();
    try {
      _latest = await DiaryService.getLatestDiary();
      _latestSummary = await DiaryService.getLatestSummary();
      _entries = await DiaryService.listRecent(days: 30);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveDiary({
    required DateTime date,
    String? content,
    String? legacyText,
    required String mood,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final saved = await DiaryService.upsertDiary(
        date: date,
        content: content,
        legacyText: legacyText,
        mood: mood,
      );
      // 최신/목록 갱신
      _latest = saved.date.isAfter(_latest?.date ?? DateTime(2000)) ? saved : _latest;
      // 목록에 동일 날짜 있으면 교체, 없으면 삽입
      final idx = _entries.indexWhere((e) => _sameDate(e.date, saved.date));
      if (idx >= 0) {
        _entries[idx] = saved;
      } else {
        _entries.insert(0, saved);
      }
      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
