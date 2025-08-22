// lib/features/diary/diary_controller.dart
import 'package:flutter/material.dart';
import 'diary_model.dart';
import 'diary_service.dart';

class DiaryController extends ChangeNotifier {
  bool _loading = false;
  bool _initialized = false;                        // ✅ 첫 로딩 완료 여부
  List<DiaryEntry> _entries = <DiaryEntry>[];
  DiaryEntry? _latest;
  ({DateTime date, String summary})? _latestSummary;

  // 현재 로드된 범위(월)
  DateTime? _loadedFrom;
  DateTime? _loadedTo;

  // 중복 호출 방지용 in-flight Future
  Future<void>? _inflightMonthLoad;
  Future<void>? _inflightMeta;


  bool get isLoading => _loading;
  bool get isInitialized => _initialized;           // ✅ 빌드에서 사용
  List<DiaryEntry> get entries => List.unmodifiable(_entries);
  DiaryEntry? get latest => _latest;
  ({DateTime date, String summary})? get latestSummary => _latestSummary;

  // ---- 신규: 같은 월 범위는 한 번만 로드 ----
  Future<void> loadMonthOnce(DateTime from, DateTime to) async {
    // 이미 같은 범위를 로드했다면 스킵
    if (_loadedFrom != null && _loadedTo != null) {
      final a = _stripTime(_loadedFrom!);
      final b = _stripTime(_loadedTo!);
      final x = _stripTime(from);
      final y = _stripTime(to);
      if (a.isAtSameMomentAs(x) && b.isAtSameMomentAs(y)) {
        return;
      }
    }

    // 이미 로딩 중이면 그 Future를 그대로 리턴 (동시 호출 합치기)
    if (_inflightMonthLoad != null) {
      return _inflightMonthLoad!;
    }

    _inflightMonthLoad = _loadMonth(from, to);
    try {
      await _inflightMonthLoad;
    } finally {
      _inflightMonthLoad = null;
    }
  }

  Future<void> _loadMonth(DateTime from, DateTime to) async {
    _setLoading(true);
    try {
      final list = await DiaryService.listRange(from, to);
      _entries = list..sort((a, b) => b.date.compareTo(a.date));
      _loadedFrom = _stripTime(from);
      _loadedTo   = _stripTime(to);
      _initialized = true;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ---- 신규: 요약/최신 메타 비동기 선로딩도 한 번만 ----
  Future<void> fetchMetaSilentlyOnce() async {
    if (_inflightMeta != null) return _inflightMeta!;
    _inflightMeta = _fetchMeta();
    try {
      await _inflightMeta;
    } finally {
      _inflightMeta = null;
    }
  }

  Future<void> _fetchMeta() async {
    try {
      final latestF  = DiaryService.getLatestDiary();
      final summaryF = DiaryService.getLatestSummary();
      final results = await Future.wait([
        latestF.catchError((_) => null),
        summaryF.catchError((_) => null),
      ]);
      _latest        = results[0] as DiaryEntry?;
      _latestSummary = results[1] as ({DateTime date, String summary})?;
      notifyListeners();
    } catch (_) {}
  }

  void _setLoading(bool v) {
    if (_loading == v) return;
    _loading = v; notifyListeners();
  }

  bool _sameDate(DateTime a, DateTime b)
  => a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  /// ✅ 첫 진입: 월 범위만 서버에서 가져와 목록 즉시 표시 (요약/최신 비차단)
  Future<void> loadMonthInitial(DateTime from, DateTime to) async {
    _initialized = false;
    _setLoading(true);
    try {
      final list = await DiaryService.listRange(from, to);
      _entries = list..sort((a, b) => b.date.compareTo(a.date));
      _initialized = true;                           // ✅ 이제 Empty 보여도 됨
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ 요약/최신은 뒤에서 따로(느려도 목록 표시 안 막음)
  Future<void> fetchMetaSilently() async {
    try { _latest        = await DiaryService.getLatestDiary();        } catch (_) {}
    try { _latestSummary = await DiaryService.getLatestSummary();      } catch (_) {}
    notifyListeners();
  }

  /// 새로고침(현재 월 범위만)
  Future<void> refreshRange(DateTime from, DateTime to) async {
    _setLoading(true);
    try {
      final list = await DiaryService.listRange(from, to);
      _entries = list..sort((a, b) => b.date.compareTo(a.date));
      _initialized = true;
      notifyListeners();
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

      if (_latest == null || saved.date.isAfter(_latest!.date)) {
        _latest = saved;
      }

      final i = _entries.indexWhere((e) => _sameDate(e.date, saved.date));
      if (i >= 0) {
        _entries[i] = saved;
      } else {
        _entries.insert(0, saved);
      }

      _initialized = true;
      notifyListeners();

      // 메타는 느긋하게
      try { _latestSummary = await DiaryService.getLatestSummary(); } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// 날짜 삭제
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

      _initialized = true;
      notifyListeners();

      try { _latestSummary = await DiaryService.getLatestSummary(); } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

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

      _initialized = true;
      notifyListeners();

      try { _latestSummary = await DiaryService.getLatestSummary(); } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }
}
