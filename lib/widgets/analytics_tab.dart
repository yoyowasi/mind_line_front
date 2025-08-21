// lib/tabs/analytics_tab.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ScheduleTab에서 SharedPreferences에 저장한 키
const _kTodosKey = 'todos.v1';

/* ------------------------ 최소 Todo 모델 (읽기 전용) ------------------------ */
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

/* ------------------------ 기간 필터 ------------------------ */
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

/* ------------------------ 탭 본체 ------------------------ */
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _df = DateFormat('MM.dd');
  final _dtf = DateFormat('MM.dd HH:mm');

  List<_TodoLite> _all = [];
  _Range _range = _Range.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kTodosKey);
    if (!mounted) return;

    if (raw == null || raw.isEmpty) {
      setState(() => _all = []);
      return;
    }

    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => _TodoLite.fromMap(Map<String, dynamic>.from(e)))
          .whereType<_TodoLite>()
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      setState(() => _all = list);
    } catch (_) {
      setState(() => _all = []);
    }
  }

  /* ------------------------ 파생 데이터 ------------------------ */
  List<_TodoLite> get _filtered {
    final now = DateTime.now();
    final start = _range.rangeStart(now);
    return _all.where((e) => e.createdAt.isAfter(start)).toList();
  }

  int get _countTotal => _filtered.length;
  int get _countDone => _filtered.where((e) => e.done).length;
  int get _countPending => _filtered.where((e) => !e.done).length;

  int get _countOverdue {
    final now = DateTime.now();
    return _filtered.where((e) => !e.done && e.due != null && e.due!.isBefore(now)).length;
  }

  double get _completionRate =>
      _countTotal == 0 ? 0 : (_countDone / max(1, _countTotal)) * 100.0;

  /// 생성→마감까지 평균 리드타임(일)
  double get _avgLeadDays {
    final diffs = _filtered
        .where((e) => e.due != null)
        .map((e) => e.due!.difference(e.createdAt).inHours / 24.0)
        .toList();
    if (diffs.isEmpty) return 0;
    return diffs.reduce((a, b) => a + b) / diffs.length;
  }

  /// 시간대 히스토그램 (생성 기준)
  List<int> get _hourHist {
    final hist = List<int>.filled(24, 0);
    for (final e in _filtered) {
      hist[e.createdAt.hour]++;
    }
    return hist;
  }

  /// 요일 히스토그램 (생성 기준, Mon=1..Sun=7)
  List<int> get _weekdayHist {
    final hist = List<int>.filled(7, 0);
    for (final e in _filtered) {
      hist[e.createdAt.weekday - 1]++;
    }
    return hist;
  }

  /// 날짜별 생성 수 (라인차트용)
  List<MapEntry<DateTime, int>> get _dailyCounts {
    final map = <DateTime, int>{};
    for (final e in _filtered) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      map[d] = (map[d] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted;
  }

  /// “아이덴티티” 라벨링
  String get _identitySummary {
    // 활동 시간대
    final hrs = _hourHist;
    final topHour = hrs.indexWhere((v) => v == hrs.reduce(max));
    final bucket = () {
      if (topHour >= 5 && topHour <= 11) return '아침형';
      if (topHour >= 12 && topHour <= 17) return '낮형';
      if (topHour >= 18 && topHour <= 23) return '저녁형';
      return '올빼미형';
    }();

    // 계획가/즉흥형
    final lead = _avgLeadDays;
    final planner = lead >= 2.0 ? '계획가' : (lead >= 0.5 ? '밸런스' : '즉흥형');

    // 꾸준함 (최근 7일 중 작성일 수)
    final now = DateTime.now();
    final last7 = _all.where(
          (e) => e.createdAt.isAfter(now.subtract(const Duration(days: 7))),
    );
    final days = <String>{};
    for (final e in last7) {
      final d = '${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}';
      days.add(d);
    }
    final consistency = days.length >= 5
        ? '매우 꾸준'
        : (days.length >= 3 ? '보통' : '가끔');

    return '$bucket · $planner · $consistency';
  }

  /* ------------------------ 위젯 빌더 ------------------------ */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
              _RangePicker(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 아이덴티티 배지
          _GlassCard(
            child: Row(
              children: [
                Icon(Icons.insights, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _countTotal == 0
                        ? '아직 데이터가 없어요. 할 일을 추가해보세요.'
                        : '당신의 패턴: $_identitySummary',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // KPI 3종
          SizedBox(
            height: 100,
            child: Row(
              children: [
                Expanded(child: _KpiTile(title: '완료율', value: '${_completionRate.toStringAsFixed(0)}%')),
                const SizedBox(width: 8),
                Expanded(child: _KpiTile(title: '미완료', value: '$_countPending')),
                const SizedBox(width: 8),
                Expanded(child: _KpiTile(title: '연체', value: '$_countOverdue')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 차트들
          Expanded(
            child: _countTotal == 0
                ? _EmptyHint()
                : ListView(
              children: [
                _SectionTitle('완료 vs 대기'),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 180, child: _buildPie(cs)),
                ),
                const SizedBox(height: 12),

                _SectionTitle('요일별 생성'),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 180, child: _buildWeekdayBar(cs)),
                ),
                const SizedBox(height: 12),

                _SectionTitle('시간대 분포'),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 180, child: _buildHourBar(cs)),
                ),
                const SizedBox(height: 12),

                _SectionTitle('일별 추세'),
                _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: 220, child: _buildLine(cs)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------------ 차트 빌더 ------------------------ */
  Widget _buildPie(ColorScheme cs) {
    final done = _countDone;
    final pending = _countPending;

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 32,
        sections: [
          PieChartSectionData(
            value: done.toDouble(),
            title: '완료\n$done',
            radius: 58,
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
    final data = _weekdayHist;
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
    final data = _hourHist;

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

  Widget _buildLine(ColorScheme cs) {
    final points = _dailyCounts;
    if (points.isEmpty) {
      return const Center(child: Text('데이터가 부족해요'));
    }

    final minX = 0.0;
    final maxX = (points.length - 1).toDouble();
    final maxY = points.map((e) => e.value).fold<int>(0, max).toDouble();

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: max(1, maxY),
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
            isCurved: true,
            barWidth: 3,
            color: cs.primary,
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
}

/* ------------------------ 자잘한 위젯 ------------------------ */

class _RangePicker extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = _Range.values;
    return SegmentedButton<_Range>(
      segments: [
        for (final r in items) ButtonSegment(value: r, label: Text(r.label)),
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
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
      ),
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

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.area_chart, size: 56, color: cs.primary),
            const SizedBox(height: 8),
            const Text('분석할 데이터가 아직 적어요. 일정에 할 일을 추가해 보세요!'),
          ],
        ),
      ),
    );
  }
}
