// lib/tabs/daliy_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/diary/diary_controller.dart';
import '../features/diary/diary_list_screen.dart';
import '../features/diary/diary_model.dart';

final _dPretty  = DateFormat('M월 d일(E)', 'ko_KR');
final _monthFmt = DateFormat('yyyy년 M월', 'ko_KR');

class DaliyTab extends StatefulWidget {
  const DaliyTab({super.key});
  @override
  State<DaliyTab> createState() => _DaliyTabState();
}

class _DaliyTabState extends State<DaliyTab> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to   = DateTime(now.year, now.month + 1, 0);

    // 탭 진입 시 한 번만 초기 로딩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<DiaryController>();
      if (c.entries.isEmpty && !c.isLoading) {
        c.loadInitial(recentDays: 90);
      }
    });
  }

  Future<void> _reload() async {
    await context.read<DiaryController>().refresh(recentDays: 90);
  }

  Future<void> _goToMonth(DateTime m) async {
    setState(() {
      _from = DateTime(m.year, m.month, 1);
      _to   = DateTime(m.year, m.month + 1, 0);
    });
    await _reload();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2022, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: '월 선택',
    );
    if (picked != null) {
      setState(() {
        _from = DateTime(picked.year, picked.month, 1);
        _to = DateTime(picked.year, picked.month + 1, 0);
      });
      await _reload();
    }
  }

  Future<void> _goPrevNextMonth(int delta) async {
    final next = DateTime(_from.year, _from.month + delta, 1);
    setState(() {
      _from = next;
      _to = DateTime(next.year, next.month + 1, 0);
    });
    await _reload();
  }

  void _goPrevMonth() => _goPrevNextMonth(-1);
  void _goNextMonth() => _goPrevNextMonth(1);

  // 현재 월의 목록 필터(최신 → 과거)
  List<DiaryEntry> _monthEntries(List<DiaryEntry> all) {
    bool inRange(DateTime d) =>
        !d.isBefore(DateTime(_from.year, _from.month, _from.day)) &&
            !d.isAfter(DateTime(_to.year, _to.month, _to.day, 23, 59, 59));

    final items = all.where((e) => inRange(e.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  // 날짜별 그룹핑 (최신 날짜가 위로)
  Map<DateTime, List<DiaryEntry>> _groupByDate(List<DiaryEntry> list) {
    final map = <DateTime, List<DiaryEntry>>{};
    for (final x in list) {
      final d = x.date;
      final k = DateTime(d.year, d.month, d.day);
      map.putIfAbsent(k, () => []).add(x);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return {for (final e in entries) e.key: e.value};
  }

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  int _filledDays(List<DiaryEntry> list) {
    final s = <String>{};
    for (final e in list) {
      final d = e.date;
      s.add('${d.year}-${d.month}-${d.day}');
    }
    return s.length;
  }

  Future<void> _openAdd([DiaryEntry? edit]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDiarySheet(entry: edit),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _openDetail(DiaryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiaryDetailSheet(entry: entry, onEdit: () => _openAdd(entry)),
    );
  }

  Future<void> _openMonthSheet(BuildContext rootCtx, List<DiaryEntry> monthList) async {
    await showModalBottomSheet<void>(
      context: rootCtx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthCalendarSheet(
        initialMonth: _from,
        entries: monthList,
        onMonthChanged: (m) => _goToMonth(m),
        onTapDay: (day) {
          final e = _findEntryByDate(monthList, day);
          final mood = e == null ? '작성 없음' : _moodLabel(e.mood ?? 'NEUTRAL');
          ScaffoldMessenger.of(rootCtx).showSnackBar(
            SnackBar(
              content: Text('${DateFormat('M월 d일(EEE)', 'ko_KR').format(day)} · $mood'),
              action: e == null
                  ? null
                  : SnackBarAction(label: '상세', onPressed: () => _openDetail(e)),
            ),
          );
        },
      ),
    );
  }

  DiaryEntry? _findEntryByDate(List<DiaryEntry> list, DateTime day) {
    for (final e in list) {
      final d = e.date;
      if (d.year == day.year && d.month == day.month && d.day == day.day) {
        return e;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c  = context.watch<DiaryController>();
    final cs = Theme.of(context).colorScheme;

    final monthList = _monthEntries(c.entries);
    final grouped   = _groupByDate(monthList);

    final totalDays   = _daysInMonth(_from);
    final writtenDays = _filledDays(monthList);
    final progress    = totalDays == 0 ? 0.0 : (writtenDays / totalDays);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 110, // ← 64 → 110 정도로 넓혀줌
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '감정일기',                 // ← 공백 제거해서 더 컴팩트
              maxLines: 1,                // ← 한 줄 고정
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,      // ← 오탈자 onSurfa → onSurface
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),

          ),
        ),
        titleSpacing: 4,
        title: GestureDetector(
          onTap: _pickMonth,
          child: Row(
            children: [
              Flexible( // ← 추가: 남은 공간 안에서 줄여서 그리기
                child: Text(
                  _monthFmt.format(_from),
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
          IconButton(onPressed: _goPrevMonth, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: _goNextMonth, icon: const Icon(Icons.chevron_right)),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        tooltip: '일기 추가',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // ── 이번 달 요약 카드 (탭하면 달력) ──────────────────────────────
            InkWell(
              onTap: () => _openMonthSheet(context, monthList),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('이번 달 일기',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text('${monthList.length} 건',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(width: 6),
                        Icon(Icons.calendar_month, color: cs.primary),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 작성률 표시
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0, 1),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$writtenDays/$totalDays일\n(${(progress * 100).toStringAsFixed(0)}%)',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── 최근 분석 결과(있을 때만) ───────────────────────────────────
            if (!c.isLoading && c.latestSummary != null) ...[
              const SizedBox(height: 12),
              _LatestAnalysisCard(text: c.latestSummary!.summary),
            ],

            if (c.isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 10),

            // ── 날짜 헤더 + 리스트 ───────────────────────────────────────────
            if (grouped.isEmpty && !c.isLoading)
              _EmptyView(onQuickAdd: () => _openAdd())
            else
              ...grouped.entries.map((e) {
                final day = e.key;
                final items = e.value;
                final isToday = DateUtils.isSameDay(day, DateTime.now());
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                      child: Row(
                        children: [
                          Text(
                            _dPretty.format(day),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('오늘',
                                  style: TextStyle(
                                      color: cs.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ...items.map((x) => _DiaryTile(
                      entry: x,
                      onOpen: () => _openDetail(x),
                      onEdit: () => _openAdd(x),
                      onDelete: () async {
                        final ok = await _confirmDelete(context);
                        if (ok != true) return;
                        try {
                          await context.read<DiaryController>().deleteByDate(x.date);
                          await _reload();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('삭제 실패: $e')),
                          );
                        }
                      },
                    )),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 일기를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
  }
}

/* ───────────────────── 달력 시트 ───────────────────── */

class _MonthCalendarSheet extends StatefulWidget {
  const _MonthCalendarSheet({
    required this.initialMonth,
    required this.entries,
    required this.onTapDay,
    required this.onMonthChanged,
  });

  final DateTime initialMonth;
  final List<DiaryEntry> entries;
  final void Function(DateTime day) onTapDay;
  final void Function(DateTime month) onMonthChanged;

  @override
  State<_MonthCalendarSheet> createState() => _MonthCalendarSheetState();
}

class _MonthCalendarSheetState extends State<_MonthCalendarSheet> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  // 월 캘린더 시작칸(월요일부터 보이도록 앞쪽 채우기)
  DateTime _firstDayOfCalendar() {
    final first = DateTime(_month.year, _month.month, 1);
    final w = first.weekday; // Mon=1..Sun=7
    return first.subtract(Duration(days: w - 1));
  }

  // 해당 날짜 일기 mood 빠르게 찾기 위해 맵 구성
  Map<String, String> _moodMapFrom(List<DiaryEntry> list) {
    String k(DateTime d) => '${d.year}-${d.month}-${d.day}';
    final m = <String, String>{};
    for (final e in list) {
      final d = e.date;
      m[k(DateTime(d.year, d.month, d.day))] = (e.mood ?? 'NEUTRAL');
    }
    return m;
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1, 1));
    widget.onMonthChanged(_month);
  }

  void _nextMonth() {
    setState(() => _month = DateTime(_month.year, _month.month + 1, 1));
    widget.onMonthChanged(_month);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    final start = _firstDayOfCalendar();
    const totalCells = 42; // 6주 * 7일

    final moodMap = _moodMapFrom(widget.entries);

    Color _bgForDay(DateTime day, bool inThisMonth, String? mood) {
      if (!inThisMonth) return cs.surfaceContainerHighest;
      if (mood == null)  return cs.surface;
      return _moodColor(context, mood).withOpacity(.22);
    }

    Color _fgForDay(bool inThisMonth) =>
        inThisMonth ? cs.onSurface : cs.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 18, offset: const Offset(0, -2))],
      ),
      // ✅ 바텀시트 높이 제한으로 오버플로우 방지
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: [
            // 핸들
            const SizedBox(height: 12),
            Container(
              height: 4, width: 48,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 12),

            // 헤더
            Row(
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthFmt.format(_month),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 6),

            // 요일 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: List.generate(7, (i) {
                  const labels = ['월', '화', '수', '목', '금', '토', '일'];
                  return Expanded(
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          color: i >= 5 ? Colors.redAccent : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),

            // ✅ 남은 공간에 그리드 배치(필요 시 스크롤) → 오버플로우 X
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (_, idx) {
                  final day = start.add(Duration(days: idx));
                  final inThisMonth = (day.month == _month.month);
                  final isToday = DateUtils.isSameDay(day, DateTime.now());

                  final key = '${day.year}-${day.month}-${day.day}';
                  final mood = moodMap[key];

                  final bg = _bgForDay(day, inThisMonth, mood);
                  final fg = _fgForDay(inThisMonth);

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => widget.onTapDay(day),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isToday ? cs.primary : Colors.transparent,
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/* ───────────────────── 보조 카드/타일 ───────────────────── */

class _LatestAnalysisCard extends StatelessWidget {
  const _LatestAnalysisCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: cs.primary.withOpacity(.12),
            foregroundColor: cs.primary,
            child: const Icon(Icons.insights_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}

class _DiaryTile extends StatelessWidget {
  const _DiaryTile({
    required this.entry,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final DiaryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _preview(String s) => s.length > 60 ? '${s.substring(0, 60)}…' : s;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String text = (entry.content ?? entry.legacyText ?? '').trim();
    final String mood = (entry.mood ?? 'NEUTRAL').toString();
    final Color  moodC = _moodColor(context, mood);
    final IconData mi  = _moodIcon(mood);

    return Dismissible(
      key: ValueKey(entry.id ?? entry.date.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('삭제'),
          content: const Text('이 일기를 삭제할까요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListTile(
          onTap: onOpen,
          leading: CircleAvatar(
            backgroundColor: moodC.withOpacity(.12),
            child: Icon(mi, color: moodC),
          ),
          title: Text(_preview(text), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_moodLabel(mood)),
          trailing: IconButton(
            tooltip: '수정',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onQuickAdd});
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        children: [
          Icon(Icons.book_outlined, size: 48, color: cs.outline),
          const SizedBox(height: 8),
          Text('해당 월의 일기가 없습니다.', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onQuickAdd, icon: const Icon(Icons.add), label: const Text('일기 추가')),
        ],
      ),
    );
  }
}

/* ───────────── 상세 & 작성 바텀시트 ───────────── */

class _DiaryDetailSheet extends StatelessWidget {
  const _DiaryDetailSheet({required this.entry, required this.onEdit});
  final DiaryEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = entry.date;
    final mood = entry.mood ?? 'NEUTRAL';
    final moodC = _moodColor(context, mood);
    final mi = _moodIcon(mood);
    final text = (entry.content ?? entry.legacyText ?? '');
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 18, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(height: 4, width: 48, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Row(
              children: [
                CircleAvatar(backgroundColor: moodC.withOpacity(.12), child: Icon(mi, color: moodC)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_dPretty.format(date),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(_moodLabel(mood), style: TextStyle(color: moodC, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('수정')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('삭제'),
                        content: const Text('이 일기를 삭제할까요?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await context.read<DiaryController>().deleteByDate(date);
                        if (context.mounted) Navigator.pop(context); // 상세 닫기
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 완료')));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('삭제'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDiarySheet extends StatefulWidget {
  const _EditDiarySheet({this.entry});
  final DiaryEntry? entry;

  @override
  State<_EditDiarySheet> createState() => _EditDiarySheetState();
}

class _EditDiarySheetState extends State<_EditDiarySheet> {
  final _form = GlobalKey<FormState>();
  final _textCtrl = TextEditingController();
  late DateTime _date;
  String _mood = 'NEUTRAL';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry == null) {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
      _textCtrl.text = '';
      _mood = 'NEUTRAL';
    } else {
      final e = widget.entry!;
      final d = e.date;
      _date = DateTime(d.year, d.month, d.day);
      _textCtrl.text = (e.content ?? e.legacyText ?? '');
      _mood = e.mood ?? 'NEUTRAL';
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2022, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: '날짜 선택',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<DiaryController>().saveDiary(
        date: _date,
        content: _textCtrl.text.trim(),
        mood: _mood,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 18, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(height: 4, width: 48, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text('날짜  ${DateFormat('yyyy-MM-dd').format(_date)}'),
                    onPressed: _pickDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _textCtrl,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(labelText: '내용'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '내용을 입력하세요' : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: -6,
              children: _moodOptions.map((m) {
                final selected = _mood == m.value;
                final color = _moodColor(context, m.value);
                return ChoiceChip(
                  selected: selected,
                  avatar: Text(m.emoji, style: const TextStyle(fontSize: 16)),
                  label: Text(m.label),
                  selectedColor: color.withOpacity(.12),
                  labelStyle: TextStyle(
                    color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(color: selected ? color : Theme.of(context).colorScheme.outlineVariant),
                  onSelected: (_) => setState(() => _mood = m.value),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(widget.entry == null ? '저장' : '수정 저장'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/* ───────────── 무드 유틸(서버와 통일) ───────────── */

String _moodLabel(String mood) {
  switch (mood.toUpperCase()) {
    case 'VERY_GOOD': return '아주 좋음';
    case 'GOOD':      return '좋음';
    case 'NEUTRAL':   return '보통';
    case 'BAD':       return '나쁨';
    case 'VERY_BAD':  return '매우 나쁨';
    default:          return '보통';
  }
}

String _moodEmoji(String mood) {
  switch (mood.toUpperCase()) {
    case 'VERY_GOOD': return '🤩';
    case 'GOOD':      return '🙂';
    case 'NEUTRAL':   return '😐';
    case 'BAD':       return '☹️';
    case 'VERY_BAD':  return '😣';
    default:          return '😐';
  }
}

IconData _moodIcon(String mood) {
  switch (mood.toUpperCase()) {
    case 'VERY_GOOD': return Icons.sentiment_very_satisfied;
    case 'GOOD':      return Icons.sentiment_satisfied_alt;
    case 'NEUTRAL':   return Icons.sentiment_neutral;
    case 'BAD':       return Icons.sentiment_dissatisfied;
    case 'VERY_BAD':  return Icons.sentiment_very_dissatisfied;
    default:          return Icons.sentiment_neutral;
  }
}

Color _moodColor(BuildContext context, String mood) {
  final cs = Theme.of(context).colorScheme;
  switch (mood.toUpperCase()) {
    case 'VERY_GOOD': return cs.primary;
    case 'GOOD':      return cs.secondary;
    case 'NEUTRAL':   return cs.tertiary;
    case 'BAD':       return Colors.deepOrange;
    case 'VERY_BAD':  return Colors.redAccent;
    default:          return cs.secondary;
  }
}

/* ───────────── 무드 옵션(선택용) ───────────── */

class _MoodOption {
  final String value; final String label; final String emoji;
  const _MoodOption(this.value, this.label, this.emoji);
}

const _moodOptions = <_MoodOption>[
  _MoodOption('VERY_GOOD', '아주 좋음', '🤩'),
  _MoodOption('GOOD',      '좋음',     '🙂'),
  _MoodOption('NEUTRAL',   '보통',     '😐'),
  _MoodOption('BAD',       '나쁨',     '☹️'),
  _MoodOption('VERY_BAD',  '매우 나쁨', '😣'),
];
