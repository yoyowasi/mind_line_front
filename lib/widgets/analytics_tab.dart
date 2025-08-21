// lib/tabs/analytics_tab.dart
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 저장소 키들 (존재하면 읽고, 없으면 스킵)
const _kTodosKey = 'todos.v1';
const _kDiaryKey = 'diary.v1';
const _kExpenseKey = 'expenses.v1';

/* ========================== 모델 ========================== */

class _TodoLite {
  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;
  final DateTime? due;

  _TodoLite({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
    required this.due,
  });

  static _TodoLite? fromMap(Map<String, dynamic> m) {
    try {
      return _TodoLite(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        done: (m['done'] as bool?) ?? false,
        createdAt: DateTime.parse(m['createdAt'] as String),
        due: (m['due'] as String?) != null ? DateTime.parse(m['due'] as String) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class _DiaryLite {
  final String id;
  final String text;
  final DateTime createdAt;
  final String? mood;   // "아주좋음/좋음/보통/나쁨/매우나쁨" 등 자유문자
  final double? score;  // -1.0 ~ 1.0 (양수=긍정)

  _DiaryLite({
    required this.id,
    required this.text,
    required this.createdAt,
    this.mood,
    this.score,
  });

  static _DiaryLite? fromMap(Map<String, dynamic> m) {
    try {
      return _DiaryLite(
        id: m['id'] as String,
        text: (m['text'] as String?) ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
        mood: m['mood'] as String?,
        score: (m['score'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

class _ExpenseLite {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime createdAt;

  _ExpenseLite({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.createdAt,
  });


  static _ExpenseLite? fromMap(Map<String, dynamic> m) {
    try {
      return _ExpenseLite(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        category: (m['category'] as String?) ?? '기타',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/* ========================== 기간 필터 ========================== */

enum _Range { week, month, quarter, all }

extension on _Range {
  String get label {
    switch (this) {
      case _Range.week:
        return '7일';
      case _Range.month:
        return '30일';
      case _Range.quarter:
        return '90일';
      case _Range.all:
        return '전체';
    }
  }

  DateTime rangeStart(DateTime now) {
    switch (this) {
      case _Range.week:
        return now.subtract(const Duration(days: 7));
      case _Range.month:
        return now.subtract(const Duration(days: 30));
      case _Range.quarter:
        return now.subtract(const Duration(days: 90));
      case _Range.all:
        return DateTime(2000);
    }
  }
}

/* ========================== 본체 ========================== */

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _df = DateFormat('MM.dd');
  final _dmf = DateFormat('MM.dd HH:mm');

  List<_TodoLite> _todosAll = [];
  List<_DiaryLite> _diaryAll = [];
  List<_ExpenseLite> _expenseAll = [];

  _Range _range = _Range.month;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final sp = await SharedPreferences.getInstance();

    List<_TodoLite> todos = [];
    final rawTodos = sp.getString(_kTodosKey);
    if (rawTodos != null && rawTodos.isNotEmpty) {
      try {
        todos = (jsonDecode(rawTodos) as List)
            .map((e) => _TodoLite.fromMap(Map<String, dynamic>.from(e)))
            .whereType<_TodoLite>()
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } catch (_) {}
    }

    List<_DiaryLite> diaries = [];
    final rawDiary = sp.getString(_kDiaryKey);
    if (rawDiary != null && rawDiary.isNotEmpty) {
      try {
        diaries = (jsonDecode(rawDiary) as List)
            .map((e) => _DiaryLite.fromMap(Map<String, dynamic>.from(e)))
            .whereType<_DiaryLite>()
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } catch (_) {}
    }

    List<_ExpenseLite> expenses = [];
    final rawExp = sp.getString(_kExpenseKey);
    if (rawExp != null && rawExp.isNotEmpty) {
      try {
        expenses = (jsonDecode(rawExp) as List)
            .map((e) => _ExpenseLite.fromMap(Map<String, dynamic>.from(e)))
            .whereType<_ExpenseLite>()
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _todosAll = todos;
      _diaryAll = diaries;
      _expenseAll = expenses;
      _loading = false;
    });
  }

  /* ========================== 파생 데이터 ========================== */

  List<_TodoLite> get _todos {
    final start = _range.rangeStart(DateTime.now());
    return _todosAll.where((e) => e.createdAt.isAfter(start)).toList();
  }

  List<_DiaryLite> get _diaries {
    final start = _range.rangeStart(DateTime.now());
    return _diaryAll.where((e) => e.createdAt.isAfter(start)).toList();
  }

  List<_ExpenseLite> get _expenses {
    final start = _range.rangeStart(DateTime.now());
    return _expenseAll.where((e) => e.createdAt.isAfter(start)).toList();
  }

  // ---- 일정 KPI/차트 데이터
  int get _todoTotal => _todos.length;
  int get _todoDone => _todos.where((e) => e.done).length;
  int get _todoPending => _todos.where((e) => !e.done).length;
  int get _todoOverdue {
    final now = DateTime.now();
    return _todos.where((e) => !e.done && e.due != null && e.due!.isBefore(now)).length;
  }
  double get _todoCompletionRate =>
      _todoTotal == 0 ? 0 : (_todoDone / max(1, _todoTotal)) * 100.0;

  List<int> get _todoHourHist {
    final hist = List<int>.filled(24, 0);
    for (final e in _todos) hist[e.createdAt.hour]++;
    return hist;
  }

  List<int> get _todoWeekdayHist {
    final hist = List<int>.filled(7, 0);
    for (final e in _todos) hist[e.createdAt.weekday - 1]++;
    return hist;
  }

  List<MapEntry<DateTime, int>> get _todoDailyCounts {
    final map = <DateTime, int>{};
    for (final e in _todos) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      map[d] = (map[d] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted;
  }

  double get _avgLeadDays {
    final diffs = _todos
        .where((e) => e.due != null)
        .map((e) => e.due!.difference(e.createdAt).inHours / 24.0)
        .toList();
    if (diffs.isEmpty) return 0;
    return diffs.reduce((a, b) => a + b) / diffs.length;
  }

  // ---- 감정일기 지표/차트 데이터
  double _scoreFromDiary(_DiaryLite d) {
    if (d.score != null) return d.score!.clamp(-1.0, 1.0);
    final m = (d.mood ?? '').toLowerCase();
    // 대충 매핑 (원하면 커스터마이즈 가능)
    if (m.contains('아주') || m.contains('매우') || m.contains('최고')) return 0.9;
    if (m.contains('좋')) return 0.5;
    if (m.contains('보통') || m.contains('중립')) return 0.0;
    if (m.contains('나쁨') || m.contains('불안') || m.contains('우울')) return -0.5;
    return 0.0;
  }

  double get _avgMood {
    if (_diaries.isEmpty) return 0;
    final s = _diaries.map(_scoreFromDiary).fold<double>(0, (a, b) => a + b);
    return s / _diaries.length; // -1.0 ~ 1.0
  }

  Map<String, int> get _moodBuckets {
    final map = <String, int>{'긍정': 0, '중립': 0, '부정': 0};
    for (final d in _diaries) {
      final s = _scoreFromDiary(d);
      if (s >= 0.25) map['긍정'] = map['긍정']! + 1;
      else if (s <= -0.25) map['부정'] = map['부정']! + 1;
      else map['중립'] = map['중립']! + 1;
    }
    return map;
  }

  List<MapEntry<DateTime, double>> get _moodDailyAvg {
    final byDay = <DateTime, List<double>>{};
    for (final d in _diaries) {
      final key = DateTime(d.createdAt.year, d.createdAt.month, d.createdAt.day);
      byDay.putIfAbsent(key, () => []).add(_scoreFromDiary(d));
    }
    final out = <MapEntry<DateTime, double>>[];
    byDay.forEach((k, v) {
      final avg = v.reduce((a, b) => a + b) / v.length;
      out.add(MapEntry(k, avg));
    });
    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  // ---- 지출 지표/차트 데이터
  double get _expenseTotal =>
      _expenses.fold<double>(0, (a, e) => a + e.amount);

  Map<String, double> get _expenseByCat {
    final map = <String, double>{};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Map<String, double> get _expenseByWeek {
    // 주차별 합계 YYYY-Wxx 문자열 키
    final map = <String, double>{};
    for (final e in _expenses) {
      final weekKey = _weekKey(e.createdAt);
      map[weekKey] = (map[weekKey] ?? 0) + e.amount;
    }
    return map;
  }

  String _weekKey(DateTime d) {
    // 단순 주차 라벨 (월~일 기준)
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final fmt = DateFormat('MM/dd');
    return '${fmt.format(monday)}~${fmt.format(sunday)}';
    // 필요하면 ISO week로 바꿔도 됨
  }

  // ---- 아이덴티티/인사이트/습관 점수
  String get _identitySummary {
    // 활동 시간대(일정 생성)
    final hrs = _todoHourHist;
    final topHour = hrs.isEmpty ? 0 : hrs.indexWhere((v) => v == hrs.reduce(max));
    final bucket = () {
      if (topHour >= 5 && topHour <= 11) return '아침형';
      if (topHour >= 12 && topHour <= 17) return '낮형';
      if (topHour >= 18 && topHour <= 23) return '저녁형';
      return '올빼미형';
    }();

    // 계획성
    final lead = _avgLeadDays;
    final planner = lead >= 2.0 ? '계획가' : (lead >= 0.5 ? '밸런스' : '즉흥형');

    // 꾸준함 (최근 7일 일정/일기 작성일 수 합)
    final now = DateTime.now();
    int distinctDays(Iterable<DateTime> list) {
      final s = <String>{};
      for (final t in list) {
        s.add('${t.year}-${t.month}-${t.day}');
      }
      return s.length;
    }

    final last7Todos = _todosAll.where((e) => e.createdAt.isAfter(now.subtract(const Duration(days: 7)))).map((e) => e.createdAt);
    final last7Diary = _diaryAll.where((e) => e.createdAt.isAfter(now.subtract(const Duration(days: 7)))).map((e) => e.createdAt);
    final actDays = distinctDays([...last7Todos, ...last7Diary]);

    final consistency = actDays >= 5 ? '매우 꾸준' : (actDays >= 3 ? '보통' : '가끔');

    // 감정 베이스
    final moodBase = _avgMood >= 0.2
        ? '낙관적'
        : (_avgMood <= -0.2 ? '우울 경향' : '중립적');

    return '$bucket · $planner · $consistency · $moodBase';
  }

  int get _habitScore {
    // 0..100: 완료율(40) + 최근7일 활동일수/7(30) + (1-연체율)(30)
    final cr = _todoCompletionRate / 100.0;             // 0..1
    final now = DateTime.now();
    final daysSet = <String>{};
    for (final t in _todosAll.where((e) => e.createdAt.isAfter(now.subtract(const Duration(days: 7))))) {
      daysSet.add('${t.createdAt.year}-${t.createdAt.month}-${t.createdAt.day}');
    }
    for (final d in _diaryAll.where((e) => e.createdAt.isAfter(now.subtract(const Duration(days: 7))))) {
      daysSet.add('${d.createdAt.year}-${d.createdAt.month}-${d.createdAt.day}');
    }
    final activity = (daysSet.length / 7.0).clamp(0.0, 1.0);
    final overdueRate = _todoTotal == 0 ? 0.0 : _todoOverdue / _todoTotal;
    final punctual = (1.0 - overdueRate).clamp(0.0, 1.0);

    final score = (cr * 40 + activity * 30 + punctual * 30).round();
    return score.clamp(0, 100);
  }

  List<String> get _insights {
    final out = <String>[];

    if (_avgMood <= -0.25 && _diaries.isNotEmpty) {
      out.add('최근 평균 감정이 낮아요. 잠깐 산책이나 스트레칭으로 리셋해볼까요?');
    } else if (_avgMood >= 0.4) {
      out.add('긍정 베이스를 잘 유지 중! 어려운 일정을 이때 처리해보는 것도 좋아요.');
    }

    if (_todoOverdue >= 3) {
      out.add('연체된 일정이 많아요. 마감 하루 전 리마인더를 켜두면 좋아요.');
    }

    // 시간대 성향
    final hrs = _todoHourHist;
    if (hrs.isNotEmpty) {
      final topHour = hrs.indexWhere((v) => v == hrs.reduce(max));
      if (topHour >= 20 || topHour <= 5) {
        out.add('야간 생산성이 높은 편이에요. 잠깐의 저녁 루틴 설계를 추천!');
      }
      if (topHour >= 9 && topHour <= 12) {
        out.add('오전 집중력이 좋아요. 중요한 미팅/작업은 오전에 배치해봐요.');
      }
    }

    // 지출 편향
    if (_expenseByCat.isNotEmpty) {
      final total = _expenseTotal;
      final top = _expenseByCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (total > 0 && (top.value / total) >= 0.3) {
        out.add('지출이 "${top.key}"에 많이 몰려 있어요. 예산을 따로 잡아보면 좋아요.');
      }
    }

    if (out.isEmpty) out.add('아직 데이터가 적어요. 일정/일기를 조금만 더 기록해 볼까요?');
    return out;
  }

  /* ========================== UI ========================== */

@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  if (_loading) {
    return const Center(child: CircularProgressIndicator());
  }

  final hasAny = _todoTotal > 0 || _diaries.isNotEmpty || _expenses.isNotEmpty;

  // (선택) DiaryController를 사용한다면 위젯 트리 상단에 Provider가 있어야 합니다.
  // 없으면 이 줄과 EmotionChart 섹션을 제거하세요.
  // ignore: unnecessary_cast
  final DiaryController? controller =
      (context as Element).findAncestorWidgetOfExactType<Provider<DiaryController>>() != null
          ? context.watch<DiaryController>()
          : null;

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Text(
              '분석',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 24, fontWeight: FontWeight.w900, color: cs.primary),
            ),
            const Spacer(),
            _RangePicker(value: _range, onChanged: (r) => setState(() => _range = r)),
          ],
        ),
        const SizedBox(height: 12),

        // 아이덴티티 + 습관 점수
        _GlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasAny
                      ? '당신의 패턴: $_identitySummary'
                      : '아직 데이터가 없어요. 일정/일기를 기록하면 패턴을 찾아드릴게요.',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              _CircleScore(score: _habitScore),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // KPI
        SizedBox(
          height: 100,
          child: Row(
            children: [
              Expanded(child: _KpiTile(title: '완료율', value: '${_todoCompletionRate.toStringAsFixed(0)}%')),
              const SizedBox(width: 8),
              Expanded(child: _KpiTile(title: '미완료', value: '$_todoPending')),
              const SizedBox(width: 8),
              Expanded(child: _KpiTile(title: '연체', value: '$_todoOverdue')),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 본문 스크롤
        Expanded(
          child: ListView(
            children: [
              // (선택) 감정 분석 섹션: Provider가 있을 때만 표시
              if (controller != null) ...[
                const _SectionTitle('감정 분석'),
                _GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: controller.entries.isEmpty
                      ? const Center(child: Text('분석할 일기 데이터가 없습니다.'))
                      : SizedBox(
                          height: 220,
                          child: EmotionChart(entries: controller.entries),
                        ),
                ),
                const SizedBox(height: 16),
              ],

              if (_todoTotal > 0) ...[
                _SectionTitle('일정 패턴'),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 170, child: _buildTodoPie(cs)),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 180, child: _buildWeekdayBar(cs)),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 180, child: _buildHourBar(cs)),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 220, child: _buildTodoLine(cs)),
                ),
                const SizedBox(height: 16),
              ],

              if (_diaries.isNotEmpty) ...[
                const _SectionTitle('감정 일기 분석'),
                _GlassCard(
                  child: Row(
                    children: [
                      Icon(Icons.emoji_emotions, color: cs.secondary),
                      const SizedBox(width: 8),
                      Text('평균 감정: ${_avgMood.toStringAsFixed(2)}  (-1~1)', style: TextStyle(color: cs.onSurface)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 170, child: _buildMoodPie(cs)),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 220, child: _buildMoodLine(cs)),
                ),
                const SizedBox(height: 16),
              ],

              if (_expenses.isNotEmpty) ...[
                const _SectionTitle('지출 성향'),
                _GlassCard(
                  child: Row(
                    children: [
                      Icon(Icons.payments, color: cs.primary),
                      const SizedBox(width: 8),
                      Text('총 지출: ${_formatCur(_expenseTotal)}', style: TextStyle(color: cs.onSurface)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 170, child: _buildExpensePie(cs)),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 220, child: _buildExpenseTrend(cs)),
                ),
                const SizedBox(height: 16),
              ],

              const _SectionTitle('개인화 인사이트'),
              _GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final tip in _insights) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: cs.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tip)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const _SectionTitle('내보내기 (CSV 복사)'),
              _GlassCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_copy),
                      label: const Text('일정 CSV'),
                      onPressed: () => _copyCsv(_csvTodos()),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_copy),
                      label: const Text('일기 CSV'),
                      onPressed: () => _copyCsv(_csvDiary()),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_copy),
                      label: const Text('지출 CSV'),
                      onPressed: () => _copyCsv(_csvExpense()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}


  /* ========================== 차트 빌더 ========================== */

  Widget _buildTodoPie(ColorScheme cs) {
    final done = _todoDone;
    final pending = _todoPending;
    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 32,
        sections: [
          PieChartSectionData(
            value: done.toDouble(),
            title: '완료\n$done',
            radius: 56,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
            color: cs.primary,
          ),
          PieChartSectionData(
            value: pending.toDouble(),
            title: '대기\n$pending',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
            color: cs.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayBar(ColorScheme cs) {
    final data = _todoWeekdayHist;
    const labels = ['월', '화', '수', '목', '금', '토', '일'];

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i > 6) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i]),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (int i = 0; i < 7; i++)
            BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(toY: data[i].toDouble(), width: 16, color: cs.primary)],
            ),
        ],
      ),
    );
  }

  Widget _buildHourBar(ColorScheme cs) {
    final data = _todoHourHist;

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i % 3 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('$i'),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (int i = 0; i < 24; i++)
            BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(toY: data[i].toDouble(), width: 8, color: cs.secondary)],
            ),
        ],
      ),
    );
  }

  Widget _buildTodoLine(ColorScheme cs) {
    final points = _todoDailyCounts;
    if (points.isEmpty) return const Center(child: Text('데이터가 부족해요'));
    final maxY = points.map((e) => e.value).fold<int>(0, max).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0, maxY: max(1, maxY),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 6).clamp(1, 10).toDouble(),
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_df.format(points[i].key)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true, barWidth: 3, color: cs.primary,
            dotData: const FlDotData(show: false),
            spots: [
              for (int i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value.toDouble()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodPie(ColorScheme cs) {
    final m = _moodBuckets;
    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 32,
        sections: [
          PieChartSectionData(
            value: (m['긍정'] ?? 0).toDouble(),
            title: '긍정\n${m['긍정'] ?? 0}',
            radius: 56, color: Colors.teal,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          PieChartSectionData(
            value: (m['중립'] ?? 0).toDouble(),
            title: '중립\n${m['중립'] ?? 0}',
            radius: 50, color: Colors.blueGrey,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          PieChartSectionData(
            value: (m['부정'] ?? 0).toDouble(),
            title: '부정\n${m['부정'] ?? 0}',
            radius: 50, color: Colors.redAccent,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodLine(ColorScheme cs) {
    final pts = _moodDailyAvg;
    if (pts.isEmpty) return const Center(child: Text('일기 데이터가 부족해요'));
    double maxAbs = 1.0;
    return LineChart(
      LineChartData(
        minX: 0, maxX: (pts.length - 1).toDouble(),
        minY: -maxAbs, maxY: maxAbs,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (pts.length / 6).clamp(1, 10).toDouble(),
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_df.format(pts[i].key)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true, barWidth: 3, color: Colors.teal,
            dotData: const FlDotData(show: false),
            spots: [
              for (int i = 0; i < pts.length; i++)
                FlSpot(i.toDouble(), pts[i].value),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensePie(ColorScheme cs) {
    final byCat = _expenseByCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (byCat.isEmpty) return const Center(child: Text('지출 데이터 없음'));

    final colors = [
      cs.primary, cs.secondary, Colors.teal, Colors.orange, Colors.purple, Colors.indigo, Colors.brown
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 32,
        sections: [
          for (int i = 0; i < byCat.length; i++)
            PieChartSectionData(
              value: byCat[i].value,
              title: '${byCat[i].key}\n${_shortMoney(byCat[i].value)}',
              radius: 54 - min(i * 2, 16),
              color: colors[i % colors.length],
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseTrend(ColorScheme cs) {
    final byWeek = _expenseByWeek.entries.toList()
      ..sort((a, b) {
        // 정렬: 주 시작일 기준 추정
        final aStart = DateFormat('MM/dd').parse(a.key.split('~').first);
        final bStart = DateFormat('MM/dd').parse(b.key.split('~').first);
        return aStart.compareTo(bStart);
      });

    if (byWeek.isEmpty) return const Center(child: Text('지출 데이터 없음'));

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= byWeek.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(byWeek[i].key.split('~').first),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (int i = 0; i < byWeek.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: byWeek[i].value, width: 18, color: cs.primary),
              ],
            ),
        ],
      ),
    );
  }

  /* ========================== 유틸/CSV ========================== */

  String _formatCur(double v) {
    final n = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
    return n.format(v);
  }

  String _shortMoney(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}만';
    return v.toStringAsFixed(0);
  }

  Future<void> _copyCsv(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV가 클립보드에 복사됐어요.')),
    );
  }

  String _csvTodos() {
    final header = 'id,title,done,createdAt,due\n';
    final rows = _todosAll.map((t) {
      final due = t.due?.toIso8601String() ?? '';
      return '${_esc(t.id)},${_esc(t.title)},${t.done},${t.createdAt.toIso8601String()},$due';
    }).join('\n');
    return header + rows;
  }

  String _csvDiary() {
    final header = 'id,createdAt,score,mood,text\n';
    final rows = _diaryAll.map((d) {
      final s = d.score ?? _scoreFromDiary(d);
      return '${_esc(d.id)},${d.createdAt.toIso8601String()},${s.toStringAsFixed(3)},${_esc(d.mood ?? '')},${_esc(d.text)}';
    }).join('\n');
    return header + rows;
  }

  String _csvExpense() {
    final header = 'id,createdAt,title,category,amount\n';
    final rows = _expenseAll.map((e) {
      return '${_esc(e.id)},${e.createdAt.toIso8601String()},${_esc(e.title)},${_esc(e.category)},${e.amount.toStringAsFixed(0)}';
    }).join('\n');
    return header + rows;
  }

  String _esc(String s) {
    final needQuote = s.contains(',') || s.contains('\n') || s.contains('"');
    var v = s.replaceAll('"', '""');
    return needQuote ? '"$v"' : v;
  }
}

/* ========================== 작은 위젯들 ========================== */

class _RangePicker extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = _Range.values;
    return SegmentedButton<_Range>(
      segments: [for (final r in items) ButtonSegment(value: r, label: Text(r.label))],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  const _KpiTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(0.55) : Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? cs.outlineVariant.withOpacity(0.28) : Colors.white.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleScore extends StatelessWidget {
  final int score; // 0..100
  const _CircleScore({required this.score});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = (score / 100.0).clamp(0.0, 1.0);
    return SizedBox(
      width: 56, height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: v,
            strokeWidth: 6,
            color: cs.primary,
            backgroundColor: cs.primary.withOpacity(0.15),
          ),
          Text('$score', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}