// lib/tabs/analytics_tab.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/diary/diary_model.dart';
import '../features/diary/diary_service.dart';

import '../core/models/schedule.dart';
import '../core/services/schedule_api.dart';

import '../core/models/expense.dart';
import '../core/services/expense_api.dart';
import '../core/models/income.dart';
import '../core/services/income_api.dart';

/// ------------------------- 기간 선택 -------------------------
enum _Range { week, month, quarter }
extension _RangeX on _Range {
  String get label => switch (this) {
    _Range.week => '7일',
    _Range.month => '30일',
    _Range.quarter => '90일',
  };
  DateTime startFromNow(DateTime now) => switch (this) {
    _Range.week => now.subtract(const Duration(days: 7)),
    _Range.month => now.subtract(const Duration(days: 30)),
    _Range.quarter => now.subtract(const Duration(days: 90)),
  };
}

/// ------------------------- 본체 -------------------------
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _money = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
  final _day = DateFormat('M/d');
  final _yyyyMM = DateFormat('yyyyMM');

  _Range _range = _Range.month;
  bool _loading = true;
  String? _error;

  // 원본
  List<DiaryEntry> _diaries = const [];
  List<ScheduleItem> _schedules = const [];
  List<Expense> _expenses = const [];
  List<Income> _incomes = const [];

  // 파생
  double _avgMood = 0; // -1..1
  Map<DateTime, double> _moodByDay = {};
  Map<DateTime, double> _expenseByDay = {};
  Map<String, double> _expenseByCat = {};
  double _scheduleMinutesTotal = 0;
  double _budgetThisMonth = 0;
  double _budgetProgress = 0; // 0..1
  double _netBalance = 0;     // 수입-지출

  // 예측/상관/이상치
  double _forecastMonthSpend = 0;
  double _corrMoodSpend = 0;        // 기분 vs 지출
  double _corrMoodWorkload = 0;     // 기분 vs 일정시간
  List<_Outlier> _outliers = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final from = _range.startFromNow(now);
      final to = now;

      final results = await Future.wait([
        DiaryService.listRange(from, to),
        ScheduleApi.list(from, to),
        ExpenseApi.list(from, to),
        IncomeApi.list(from, to),
      ]);

      final diaries   = results[0] as List<DiaryEntry>;
      final schedules = results[1] as List<ScheduleItem>;
      final expenses  = results[2] as List<Expense>;
      final incomes   = results[3] as List<Income>;

      // 파생
      final avgMood        = _calcAvgMood(diaries);
      final moodByDay      = _groupMoodByDay(diaries);
      final expenseByDay   = _groupMoneyByDay(expenses.map((e) => (e.date, e.amount)));
      final expenseByCat   = _groupExpenseByCat(expenses);
      final scheduleByDay  = _groupScheduleByDay(schedules);
      final scheduleMinTot = scheduleByDay.values.fold<double>(0, (p, v) => p + v);
      final net            = _sum(incomes.map((x) => x.amount)) - _sum(expenses.map((x) => x.amount));

      // 예산(이번 달 진행률)
      double budget = 0, progress = 0;
      try {
        final sp = await SharedPreferences.getInstance();
        final key = 'budget.${_yyyyMM.format(now)}';
        budget = sp.getDouble(key) ?? 0.0;
        if (budget > 0) {
          final monthFrom = DateTime(now.year, now.month, 1);
          final monthTo   = DateTime(now.year, now.month + 1, 0);
          final monthExpenses = await ExpenseApi.list(monthFrom, monthTo);
          final monthSpent    = _sum(monthExpenses.map((e) => e.amount));
          progress = (monthSpent / budget).clamp(0, 1);
        }
      } catch (_) {}

      // 예측(월말 지출 = 현재까지 일평균 × 월일수)
      final forecast = _forecastSpendThisMonth(expenseByDay);

      // 상관
      final corrMoodSpend     = _pearson(moodByDay, expenseByDay);
      final corrMoodWorkload  = _pearson(moodByDay, scheduleByDay);

      // 이상치
      final outliers = _detectOutliers(moodByDay, expenseByDay, scheduleByDay);

      if (!mounted) return;
      setState(() {
        _diaries = diaries;
        _schedules = schedules;
        _expenses = expenses;
        _incomes = incomes;

        _avgMood = avgMood;
        _moodByDay = moodByDay;
        _expenseByDay = expenseByDay;
        _expenseByCat = expenseByCat;
        _scheduleMinutesTotal = scheduleMinTot;
        _netBalance = net;

        _budgetThisMonth = budget;
        _budgetProgress = progress;

        _forecastMonthSpend = forecast;
        _corrMoodSpend = corrMoodSpend;
        _corrMoodWorkload = corrMoodWorkload;
        _outliers = outliers;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  // ---------------- 계산 ----------------
  double _scoreFromMood(String? mood) {
    switch ((mood ?? 'NEUTRAL').toUpperCase()) {
      case 'VERY_GOOD': return 1.0;
      case 'GOOD':      return 0.5;
      case 'NEUTRAL':   return 0.0;
      case 'BAD':       return -0.5;
      case 'VERY_BAD':  return -1.0;
      default:          return 0.0;
    }
  }

  double _calcAvgMood(List<DiaryEntry> list) {
    if (list.isEmpty) return 0;
    final s = list.map((e) => _scoreFromMood(e.mood)).fold<double>(0, (p, v) => p + v);
    return s / list.length;
  }

  Map<DateTime, double> _groupMoodByDay(List<DiaryEntry> list) {
    final tmp = <DateTime, List<double>>{};
    for (final e in list) {
      final k = DateTime(e.date.year, e.date.month, e.date.day);
      (tmp[k] ??= []).add(_scoreFromMood(e.mood));
    }
    final out = <DateTime, double>{};
    tmp.forEach((k, v) => out[k] = v.reduce((a, b) => a + b) / v.length);
    return _sortMapByDate(out);
  }

  Map<DateTime, double> _groupMoneyByDay(Iterable<(DateTime, double)> list) {
    final map = <DateTime, double>{};
    for (final (dt, amount) in list) {
      final k = DateTime(dt.year, dt.month, dt.day);
      map[k] = (map[k] ?? 0) + amount;
    }
    return _sortMapByDate(map);
  }

  Map<String, double> _groupExpenseByCat(List<Expense> list) {
    final map = <String, double>{};
    for (final e in list) {
      final k = _expenseLabel(e.category);
      map[k] = (map[k] ?? 0) + e.amount;
    }
    return map;
  }

  Map<DateTime, double> _groupScheduleByDay(List<ScheduleItem> list) {
    final m = <DateTime, double>{};
    for (final s in list) {
      final day = DateTime(s.start.year, s.start.month, s.start.day);
      final minutes = s.allDay
          ? 8 * 60.0
          : (s.end == null ? 60.0 : max(15.0, s.end!.difference(s.start).inMinutes.toDouble()));
      m[day] = (m[day] ?? 0) + minutes;
    }
    return _sortMapByDate(m);
  }

  double _sum(Iterable<double> xs) => xs.fold<double>(0, (p, v) => p + v);

  Map<DateTime, double> _sortMapByDate(Map<DateTime, double> m) {
    final entries = m.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in entries) e.key: e.value};
  }

  double _forecastSpendThisMonth(Map<DateTime, double> expenseByDay) {
    if (expenseByDay.isEmpty) return 0;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final spent = _sum(expenseByDay.entries.where((e) => e.key.month == now.month && e.key.year == now.year).map((e) => e.value));
    final todayIndex = now.day;
    final dailyAvg = max(0.0, spent / max(1, todayIndex));
    return dailyAvg * daysInMonth;
  }

  double _pearson(Map<DateTime, double> a, Map<DateTime, double> b) {
    final keys = a.keys.toSet().intersection(b.keys.toSet()).toList()..sort();
    if (keys.length < 3) return 0;
    final xs = [for (final k in keys) a[k] ?? 0];
    final ys = [for (final k in keys) b[k] ?? 0];

    double mean(List<double> v) => v.isEmpty ? 0 : v.reduce((p, c) => p + c) / v.length;
    final mx = mean(xs), my = mean(ys);
    double num = 0, denx = 0, deny = 0;
    for (int i = 0; i < xs.length; i++) {
      final dx = xs[i] - mx, dy = ys[i] - my;
      num += dx * dy; denx += dx * dx; deny += dy * dy;
    }
    if (denx == 0 || deny == 0) return 0;
    return (num / sqrt(denx * deny)).clamp(-1.0, 1.0);
  }

  List<_Outlier> _detectOutliers(
      Map<DateTime, double> mood,
      Map<DateTime, double> expense,
      Map<DateTime, double> scheduleMin) {
    final out = <_Outlier>[];
    out.addAll(_outlierHigh(expense, label: '지출 많음', icon: Icons.trending_up, color: Colors.redAccent));
    out.addAll(_outlierLow(mood,    label: '기분 저하', icon: Icons.mood_bad,   color: Colors.orange));
    out.addAll(_outlierHigh(scheduleMin, label: '일정 과밀', icon: Icons.event_busy, color: Colors.blue));
    out.sort((a, b) => b.score.compareTo(a.score));
    return out.take(10).toList();
  }

  List<_Outlier> _outlierHigh(Map<DateTime, double> m,
      {required String label, required IconData icon, required Color color}) {
    if (m.isEmpty) return [];
    final vals = m.values.toList();
    final avg = _sum(vals) / vals.length;
    final std = sqrt(_sum(vals.map((v) => pow(v - avg, 2).toDouble())) / vals.length);
    final th = avg + 1.5 * std;
    return [
      for (final e in m.entries)
        if (e.value > th)
          _Outlier(date: e.key, title: label, value: e.value, score: (e.value - th), icon: icon, color: color)
    ];
  }

  List<_Outlier> _outlierLow(Map<DateTime, double> m,
      {required String label, required IconData icon, required Color color}) {
    if (m.isEmpty) return [];
    final vals = m.values.toList();
    final avg = _sum(vals) / vals.length;
    final std = sqrt(_sum(vals.map((v) => pow(v - avg, 2).toDouble())) / vals.length);
    final th = avg - 1.0 * std;
    return [
      for (final e in m.entries)
        if (e.value < th)
          _Outlier(date: e.key, title: label, value: e.value, score: (th - e.value), icon: icon, color: color)
    ];
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 110,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '분석',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        titleSpacing: 4,
        title: GestureDetector(
          onTap: _openRangeSheet, // 제목 탭 → 동일 옵션을 시트로 노출
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '최근 ${_range.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
        actions: [
          // ← 월 좌우 변경 버튼 자리에 "날짜 세그먼트" 배치
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: _RangePickerMini(
                value: _range,
                onChanged: (r) { setState(() => _range = r); _reload(); },
              ),
            ),
          ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('로드 실패: $_error'))
          : RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _kpiGrid(cs),

            const SizedBox(height: 14),
            const _SectionTitle('기분 ↔ 지출 트렌드'),
            _Glass(
              padding: const EdgeInsets.all(12),
              child: SizedBox(height: 240, child: _moodExpenseDualLine(cs)),
            ),

            const SizedBox(height: 14),
            const _SectionTitle('지출 상위 카테고리'),
            _Glass(
              padding: const EdgeInsets.all(12),
              child: SizedBox(height: 200, child: _expenseDonut(cs)),
            ),

            const SizedBox(height: 14),
            const _SectionTitle('기분 ↔ 지출 상관'),
            _Glass(
              padding: const EdgeInsets.all(12),
              child: SizedBox(height: 220, child: _moodSpendScatter(cs)),
            ),

            const SizedBox(height: 14),
            const _SectionTitle('이상치(Outliers)'),
            _Glass(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _outliers.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('특이한 날이 아직 없어요. 데이터가 조금 더 쌓이면 보여드릴게요.'),
              )
                  : Column(
                children: [
                  for (final o in _outliers)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: o.color.withOpacity(.15),
                        child: Icon(o.icon, color: o.color),
                      ),
                      title: Text('${_day.format(o.date)} • ${o.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(o.subtitle(_money)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const _SectionTitle('개인화 인사이트'),
            _Glass(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _insights(cs),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 상단 KPI(글씨 깨짐 방지: FittedBox + 축약표기 + Grid) ----------
  // 상단 KPI(6개) 그리드 — 고정 높이 + 반응형 컬럼
  Widget _kpiGrid(ColorScheme cs) {
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScaleFactorOf(context);

    // 화면 폭에 따라 2열/3열
    final cols = size.width < 360 ? 1 : (size.width >= 600 ? 3 : 2);

    // 폰트 확대 대비 여유 있는 타일 높이(오버플로우 방지)
    final baseH = size.width >= 600 ? 66.0 : 72.0;
    final tileH = (baseH * textScale.clamp(1.0, 1.12)).clamp(60.0, 86.0);

    final moodTxt      = _avgMood > 0.4 ? '좋음' : (_avgMood < -0.25 ? '낮음' : '보통');
    final budgetLabel  = _budgetThisMonth > 0 ? '${(_budgetProgress * 100).toStringAsFixed(0)}%' : '—';
    final schedHours   = (_scheduleMinutesTotal / 60).toStringAsFixed(1);
    final balanceShort = (_netBalance >= 0 ? '+' : '-') + _shortMoney(_netBalance.abs());
    final forecastShort = _shortMoney(_forecastMonthSpend);
    final corr = _corrMoodSpend.toStringAsFixed(2);

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 8,     // 더 촘촘하게
        mainAxisSpacing: 8,
        mainAxisExtent: tileH,   // ✨ 얇아진 카드 높이
      ),
      children: [
        _KpiTile(title: '평균 기분',     value: moodTxt,        icon: Icons.emoji_emotions),
        _KpiTile(title: '예산 진행률',   value: budgetLabel,    icon: Icons.pie_chart),
        _KpiTile(title: '일정 시간',     value: '${schedHours}h', icon: Icons.timer_outlined),
        _KpiTile(title: '순자산',       value: balanceShort,   icon: Icons.account_balance_wallet),
        _KpiTile(title: '월말 지출 예측', value: forecastShort,  icon: Icons.trending_up),
        _KpiTile(title: '상관(기분↔지출)', value: _corrMoodSpend.toStringAsFixed(2), icon: Icons.scatter_plot),
      ],
    );
  }

  /// 좌: 기분(-1..1), 우: 지출(정규화)
  Widget _moodExpenseDualLine(ColorScheme cs) {
    if (_moodByDay.isEmpty && _expenseByDay.isEmpty) {
      return const Center(child: Text('표시할 데이터가 부족해요'));
    }
    final keys = <DateTime>{..._moodByDay.keys, ..._expenseByDay.keys}.toList()..sort();
    final maxExp = _expenseByDay.values.isEmpty ? 1.0 : _expenseByDay.values.reduce(max);

    final moodSpots = <FlSpot>[
      for (int i = 0; i < keys.length; i++) FlSpot(i.toDouble(), (_moodByDay[keys[i]] ?? 0).toDouble()),
    ];
    final expSpots = <FlSpot>[
      for (int i = 0; i < keys.length; i++) FlSpot(i.toDouble(), ((_expenseByDay[keys[i]] ?? 0) / maxExp)),
    ];

    return LineChart(
      LineChartData(
        minX: 0, maxX: max(0, keys.length - 1).toDouble(),
        minY: -1, maxY: 1,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 44,
              getTitlesWidget: (v, _) {
                final real = (v.clamp(0, 1)) * maxExp;
                return Text(_shortMoney(real));
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 0.5),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (keys.length / 6).clamp(1, 10).toDouble(),
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(_day.format(keys[i])));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true, barWidth: 3, color: Colors.teal,
            dotData: const FlDotData(show: false), spots: moodSpots,
          ),
          LineChartBarData(
            isCurved: true, barWidth: 3, color: cs.primary,
            dotData: const FlDotData(show: false), spots: expSpots,
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (items) => items.map((it) {
              final i = it.x.round().clamp(0, keys.length - 1);
              final date = keys[i];
              if (it.bar.color == Colors.teal) {
                return LineTooltipItem(
                  '${_day.format(date)}\n기분 ${it.y.toStringAsFixed(2)}',
                  const TextStyle(fontWeight: FontWeight.w700),
                );
              } else {
                final real = it.y.clamp(0, 1) * maxExp;
                return LineTooltipItem(
                  '${_day.format(date)}\n지출 ${_money.format(real)}',
                  const TextStyle(fontWeight: FontWeight.w700),
                );
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _expenseDonut(ColorScheme cs) {
    if (_expenseByCat.isEmpty) return const Center(child: Text('지출 데이터가 없습니다'));
    final items = _expenseByCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = items.fold<double>(0, (p, e) => p + e.value);
    final palette = [cs.primary, Colors.teal, Colors.orange, Colors.purple, Colors.indigo, Colors.brown, Colors.cyan, Colors.deepOrange];

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4, centerSpaceRadius: 36,
              sections: [
                for (int i = 0; i < items.length && i < 8; i++)
                  PieChartSectionData(
                    value: items[i].value,
                    color: palette[i % palette.length],
                    radius: 54 - min(i * 2, 18),
                    title: '${(items[i].value / max(1, total) * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10, runSpacing: -6,
          children: [
            for (int i = 0; i < items.length && i < 8; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text('${items[i].key} ${_shortMoney(items[i].value)}'),
              ]),
          ],
        ),
      ],
    );
  }

  /// 기분↔지출 산점도 + 상관계수
  Widget _moodSpendScatter(ColorScheme cs) {
    final keys = _moodByDay.keys.toSet().intersection(_expenseByDay.keys.toSet()).toList()..sort();
    if (keys.length < 3) return const Center(child: Text('상관을 계산할 데이터가 부족해요'));
    final maxExp = _expenseByDay.values.reduce(max);

    final points = <ScatterSpot>[
      for (final k in keys)
        ScatterSpot(
          (_expenseByDay[k]! / max(1, maxExp)),
          _moodByDay[k]!,
          radius: 6,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('상관계수: ${_corrMoodSpend.toStringAsFixed(2)}  ${_corrLabel(_corrMoodSpend)}'),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: ScatterChart(
            ScatterChartData(
              minX: 0, maxX: 1, minY: -1, maxY: 1,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 0.5)),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 0.25)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              scatterSpots: points,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('x축: 지출(정규화)  y축: 기분(−1~1)', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  String _corrLabel(double r) {
    final a = r.abs();
    if (a >= 0.8) return '(매우 강함)';
    if (a >= 0.6) return '(강함)';
    if (a >= 0.4) return '(보통)';
    if (a >= 0.2) return '(약함)';
    return '(매우 약함)';
  }

  Widget _insights(ColorScheme cs) {
    final tips = <String>[];

    if (_avgMood <= -0.25 && _diaries.isNotEmpty) {
      tips.add('최근 평균 감정이 낮아요. 20분 걷기나 스트레칭으로 리셋해보세요.');
    } else if (_avgMood >= 0.4) {
      tips.add('긍정 에너지가 좋습니다. 난이도 높은 업무를 오전 집중 시간대에 배치해보세요.');
    }

    if (_budgetThisMonth > 0) {
      final pct = _budgetProgress * 100;
      if (pct >= 85) tips.add('예산 소진 속도가 빠릅니다. 남은 기간은 고정비 위주로 관리해요.');
      if (_forecastMonthSpend > _budgetThisMonth) {
        tips.add('월말 예측 지출이 예산을 초과할 가능성이 높아요(예상 ${_money.format(_forecastMonthSpend)}). 상위 1~2개 카테고리만 줄여도 효과적!');
      }
    }

    if (_expenseByCat.isNotEmpty) {
      final top = _expenseByCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final total = _expenseByCat.values.fold<double>(0, (p, v) => p + v);
      final share = (top.value / max(1, total)) * 100;
      if (share >= 45) {
        tips.add('"${top.key}" 지출 비중이 높아요(약 ${share.toStringAsFixed(0)}%). 주 1회만 줄여도 월 예산이 안정됩니다.');
      }
    }

    if (_corrMoodWorkload <= -0.4) {
      tips.add('일정 시간이 늘수록 기분이 낮아지는 경향이 있어요. 일정 사이 10분 휴식 타이머를 넣어보세요.');
    } else if (_corrMoodSpend >= 0.4) {
      tips.add('지출이 늘어나는 날 기분이 높아요. 즉흥 소비를 줄이기 위해 구매 전 24시간 룰을 시도해보세요.');
    }

    if (tips.isEmpty) tips.add('아직 데이터가 적어요. 일정/일기/가계를 조금 더 기록해 볼까요?');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in tips) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(t)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _openRangeSheet() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('기간 선택', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            _RangePicker(
              value: _range,
              onChanged: (r) { Navigator.pop(context); setState(() => _range = r); _reload(); },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 도우미 ----------------
  static String _shortMoney(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}만';
    return v.toStringAsFixed(0);
  }

  static String _expenseLabel(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.FOOD:         return '식비';
      case ExpenseCategory.TRANSPORT:    return '교통';
      case ExpenseCategory.HEALTH:       return '건강';
      case ExpenseCategory.ENTERTAINMENT:return '여가';
      case ExpenseCategory.EDUCATION:    return '교육';
      case ExpenseCategory.SHOPPING:     return '쇼핑';
      case ExpenseCategory.TRAVEL:       return '여행';
      case ExpenseCategory.TAXES:        return '세금/보험';
      case ExpenseCategory.OTHER:        return '기타';
    }
  }
}

/// ------------------------- 공용 위젯 -------------------------
class _RangePicker extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Range>(
      segments: [for (final r in _Range.values) ButtonSegment(value: r, label: Text(r.label))],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _RangePickerMini extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangePickerMini({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // AppBar actions 공간에 맞게 컴팩트 버전
    return SegmentedButton<_Range>(
      style: const ButtonStyle(visualDensity: VisualDensity(horizontal: -2, vertical: -2)),
      segments: [
        ButtonSegment(value: _Range.week, label: Text(_Range.week.label)),
        ButtonSegment(value: _Range.month, label: Text(_Range.month.label)),
        ButtonSegment(value: _Range.quarter, label: Text(_Range.quarter.label)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _KpiTile({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(.55) : Colors.white.withOpacity(.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? cs.outlineVariant.withOpacity(.24) : Colors.white.withOpacity(.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .18 : .06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, box) {
          // 카드가 낮으면(예: 작은 폰/폰트 확대) 더 컴팩트한 타이포/아이콘 사용
          final compact = box.maxHeight < 92;

          final iconSize  = compact ? 18.0 : 20.0;
          final titleSize = compact ? 12.0 : 13.0;
          final valueSize = compact ? 18.0 : 22.0;

          return Row(
            children: [
              Icon(icon, color: cs.primary, size: iconSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 값 — 한 줄로 강제, 넘치면 줄임표
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: valueSize,
                        fontWeight: FontWeight.w900,
                        height: 1.05, // 줄간격 약간 타이트
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Glass({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(.55) : Colors.white.withOpacity(.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? cs.outlineVariant.withOpacity(.26) : Colors.white.withOpacity(.66)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? .18 : .06), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

/// 이상치 모델
class _Outlier {
  final DateTime date;
  final String title;
  final double value; // 원 값
  final double score; // 임계 대비 초과/미만 정도
  final IconData icon;
  final Color color;

  _Outlier({
    required this.date,
    required this.title,
    required this.value,
    required this.score,
    required this.icon,
    required this.color,
  });

  String subtitle(NumberFormat money) {
    switch (title) {
      case '지출 많음': return '해당일 지출 ${money.format(value)}';
      case '일정 과밀': return '해당일 일정 ${(value / 60).toStringAsFixed(1)}시간';
      case '기분 저하': return '해당일 기분 ${value.toStringAsFixed(2)}';
      default:         return value.toStringAsFixed(2);
    }
  }
}
