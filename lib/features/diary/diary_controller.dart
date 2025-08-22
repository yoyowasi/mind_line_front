// lib/features/diary/diary_controller.dart
import 'package:flutter/material.dart';
import 'diary_model.dart';
import 'diary_service.dart';

class DiaryController extends ChangeNotifier {
  bool _loading = false;
  List<DiaryEntry> _entries = <DiaryEntry>[];
  DiaryEntry? _latest;
  ({DateTime date, String summary})? _latestSummary;

  bool get isLoading => _loading;
  List<DiaryEntry> get entries => List.unmodifiable(_entries);
  DiaryEntry? get latest => _latest;
  ({DateTime date, String summary})? get latestSummary => _latestSummary;

  /// 앱 시작/탭 진입 시 초기 로딩
  Future<void> loadInitial({int recentDays = 60}) async {
    _setLoading(true);
    try {
      // 병렬 요청
      final latestF  = DiaryService.getLatestDiary();
      final summaryF = DiaryService.getLatestSummary();
      final listF    = DiaryService.listRecent(days: recentDays);

      final results = await Future.wait([
        latestF.catchError((_) => null),
        summaryF.catchError((_) => null),
        listF.catchError((_) => <DiaryEntry>[]),
      ]);

      _latest        = results[0] as DiaryEntry?;
      _latestSummary = results[1] as ({DateTime date, String summary})?;
      _entries       = (results[2] as List<DiaryEntry>)
        ..sort((a, b) => b.date.compareTo(a.date)); // 최신순 정렬
    } finally {
      _setLoading(false);
    }
  }

  /// 최근만 다시 긁어와서 갱신 (간단 새로고침)
  Future<void> refresh({int recentDays = 60}) async {
    _setLoading(true);
    try {
      final list = await DiaryService.listRecent(days: recentDays);
      _entries = list..sort((a, b) => b.date.compareTo(a.date));
      // 최신/요약도 가볍게 갱신
      try { _latest = await DiaryService.getLatestDiary(); } catch (_) {}
      try { _latestSummary = await DiaryService.getLatestSummary(); } catch (_) {}
    } finally {
      _setLoading(false);
    }
  }

  /// 특정 월 구간을 새로고침하고 싶을 때(서비스에 range가 없을 수도 있으므로 listRecent로 대체)
  Future<void> refreshRange(DateTime from, DateTime to) async {
    final days = to.difference(from).inDays + 1;
    _setLoading(true);
    try {
      final list = await DiaryService.listRecent(days: days + 5); // 버퍼 포함
      // 컨트롤러 단계에서 구간 필터링
      bool inRange(DateTime d) =>
          !d.isBefore(DateTime(from.year, from.month, from.day)) &&
              !d.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59));
      _entries = list.where((e) => inRange(e.date)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } finally {
      _setLoading(false);
    }
  }

  /// 생성/수정(업서트)
  Future<void> saveDiary({
    required DateTime date,
    String? content,
    String? legacyText,
    required String mood,
  }) async {
    _setLoading(true);
    try {
      final saved = await DiaryService.upsertDiary(
        date: _stripTime(date),
        content: content,
        legacyText: legacyText,
        mood: mood,
      );

      // 최신 갱신
      if (_latest == null || saved.date.isAfter(_latest!.date)) {
        _latest = saved;
      }

      // 목록에 동일 날짜 있으면 교체, 없으면 맨 앞 삽입
      final i = _entries.indexWhere((e) => _sameDate(e.date, saved.date));
      if (i >= 0) {
        _entries[i] = saved;
      } else {
        _entries.insert(0, saved);
      }

      // 최신 요약 재조회(있는 경우에만; 에러는 무시)
      try { _latestSummary = await DiaryService.getLatestSummary(); } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// 날짜로 삭제(네 UI가 이 메서드 호출)
  Future<void> deleteByDate(DateTime date) async {
    _setLoading(true);
    try {
      await DiaryService.deleteByDate(_stripTime(date));
      _entries.removeWhere((e) => _sameDate(e.date, date));

      if (_latest != null && _sameDate(_latest!.date, date)) {
        _latest = _entries.isEmpty
            ? null
            : _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      }

      // 최신 요약도 혹시 바뀌었을 수 있으니 다시 조회(실패 무시)
      try { _latestSummary = await DiaryService.getLatestSummary(); } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// id로 삭제가 필요할 때 UI에서 선택적으로 사용
  Future<void> deleteById(String id) async {
    _setLoading(true);
    try {
      await DiaryService.deleteById(id);
      _entries.removeWhere((e) => e.id == id);

      if (_latest?.id == id) {
        _latest = _entries.isEmpty
            ? null
            : _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      }

      try { _latestSummary = await DiaryService.getLatestSummary(); } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// 최신만 별도로
  Future<void> refreshLatest() async {
    try {
      _latest = await DiaryService.getLatestDiary();
      notifyListeners();
    } catch (_) {}
  }

  /// 최신 요약만 별도로
  Future<void> refreshLatestSummary() async {
    try {
      _latestSummary = await DiaryService.getLatestSummary();
      notifyListeners();
    } catch (_) {}
  }

  // ─────────── 유틸 ───────────
  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  void _setLoading(bool v) {
    if (_loading == v) return;
    _loading = v;
    notifyListeners();
  }
}
