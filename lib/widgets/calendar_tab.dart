// lib/tabs/calendar_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// ▽▽ 프로젝트 경로 확인
import '../features/diary/diary_model.dart';
import '../features/diary/diary_service.dart';

import '../core/models/schedule.dart';
import '../core/services/schedule_api.dart';

import '../core/models/expense.dart';
import '../core/services/expense_api.dart';
import '../core/models/income.dart';
import '../core/services/income_api.dart';
// △△

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final _dPretty  = DateFormat('M월 d일(E)', 'ko_KR');
  final _t        = DateFormat('HH:mm');
  final _money    = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
  final _monthFmt = DateFormat('yyyy년 M월', 'ko_KR');

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late DateTime _from;
  late DateTime _to;

  bool _loading = true;
  String? _error;

  List<ScheduleItem> _schedules = const [];
  List<DiaryEntry>   _diaries   = const [];
  List<Expense>      _expenses  = const [];
  List<Income>       _incomes   = const [];

  final Set<String> _hasDataKeys = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to   = DateTime(now.year, now.month + 1, 0);
    _focusedDay  = now;
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadMonth(_from);
  }

  // ───────────── key/date utils ─────────────
  String  _keyFromDate(DateTime d) => '${d.year}-${d.month}-${d.day}';
  DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ───────────── month load ─────────────
  Future<void> _loadMonth(DateTime month) async {
    setState(() { _loading = true; _error = null; });
    final from = DateTime(month.year, month.month, 1);
    final to   = DateTime(month.year, month.month + 1, 0);

    try {
      final results = await Future.wait([
        ScheduleApi.list(from, to),
        ExpenseApi.list(from, to),
        IncomeApi.list(from, to),
        DiaryService.listRange(from, to),
      ]);

      final schedules = results[0] as List<ScheduleItem>;
      final expenses  = results[1] as List<Expense>;
      final incomes   = results[2] as List<Income>;
      final diaries   = results[3] as List<DiaryEntry>;

      final keys = <String>{};
      for (final e in schedules) { keys.add(_keyFromDate(e.start)); }
      for (final e in expenses)  { keys.add(_keyFromDate(e.date)); }
      for (final e in incomes)   { keys.add(_keyFromDate(e.date)); }
      for (final e in diaries)   { keys.add(_keyFromDate(e.date)); }

      setState(() {
        _from = from; _to = to;
        _schedules = schedules;
        _expenses  = expenses;
        _incomes   = incomes;
        _diaries   = diaries;
        _hasDataKeys..clear()..addAll(keys);
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    final m = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
    final last = DateTime(m.year, m.month + 1, 0).day;
    final keepDay = (_selectedDay?.day ?? DateTime.now().day).clamp(1, last);
    setState(() {
      _focusedDay = m;
      _selectedDay = DateTime(m.year, m.month, keepDay);
    });
    _loadMonth(m);
  }

  void _goPrevMonth() => _changeMonth(-1);
  void _goNextMonth() => _changeMonth(1);

  void _goToday() {
    final today = DateTime.now();
    setState(() {
      _focusedDay  = today;
      _selectedDay = _dateKey(today);
    });
    _loadMonth(today);
  }

  _DayBundle _bundleFor(DateTime day) {
    final d = _dateKey(day);
    final schedules = _schedules.where((x) => _sameDate(x.start, d)).toList()
      ..sort((a,b) => a.start.compareTo(b.start));
    final diaries   = _diaries.where((x) => _sameDate(x.date, d)).toList();
    final expenses  = _expenses.where((x) => _sameDate(x.date, d)).toList();
    final incomes   = _incomes.where((x) => _sameDate(x.date, d)).toList();

    return _DayBundle(day: d, schedules: schedules, diaries: diaries, expenses: expenses, incomes: incomes);
  }

  List<int> _eventLoader(DateTime day) =>
      _hasDataKeys.contains(_keyFromDate(day)) ? const [1] : const [];

  // ───────────── add menu ─────────────
  Future<void> _openAddMenu(DateTime day) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('일기 쓰기'),
              onTap: () async { Navigator.pop(context); await _openDiaryCreate(day); },
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('일정 추가'),
              onTap: () async { Navigator.pop(context); await _openScheduleCreate(day); },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('지출/수입 추가'),
              onTap: () async { Navigator.pop(context); await _openMoneyAdd(day); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ───────────── open sheets (wired) ─────────────
  Future<void> _openDiaryCreate(DateTime day) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiaryEditSheet(initialDate: day),
    );
    if (ok == true) await _loadMonth(_focusedDay);
  }

  Future<void> _openDiaryDetail(DiaryEntry entry) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiaryDetailSheet(entry: entry),
    );
    if (ok == true) await _loadMonth(_focusedDay);
  }

  Future<void> _openScheduleCreate(DateTime day) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleEditSheet(initial: day),
    );
    if (ok == true) await _loadMonth(_focusedDay);
  }

  Future<void> _openScheduleEdit(ScheduleItem item) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleEditSheet(edit: item),
    );
    if (ok == true) await _loadMonth(_focusedDay);
  }

  Future<void> _openMoneyAdd(DateTime day) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoneyEntrySheet(initialDateTime: day),
    );
    if (ok == true) await _loadMonth(_focusedDay);
  }

  Future<void> _openExpenseEdit(Expense e) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoneyEntrySheet(editExpense: e),
    );
    if (ok == true) await _loadMonth(_focusedDay);
  }

  Future<void> _openIncomeEdit(Income i) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoneyEntrySheet(editIncome: i),
    );
    if (ok == true) await _loadMonth(_focusedDay);
  }

  // ───────────── UI ─────────────
  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay ?? _focusedDay;
    final bundle   = _bundleFor(selected);

    final monthFmt  = DateFormat('yyyy년 M월', 'ko_KR');        // ← 없던 포맷 로컬 선언
    final calHeight = (MediaQuery.sizeOf(context).height * 0.66).clamp(460.0, 720.0);
    const double calHeaderH = 48.0;

    return Scaffold(
      body: SafeArea(
        top: true, bottom: false,
        child: Stack(
          children: [
            // ── 위: 달력 영역 (헤더 오버레이 + TableCalendar)
            SizedBox(
              height: calHeight,
              child: Stack(
                children: [
                  // 달력 본체(헤더 높이만큼 위 패딩)
                  Padding(
                    padding: const EdgeInsets.only(top: calHeaderH + 8),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      headerVisible: false,                         // 커스텀 헤더 사용
                      availableGestures: AvailableGestures.horizontalSwipe, // 좌우 스와이프
                      calendarFormat: CalendarFormat.month,
                      rowHeight: 58,
                      daysOfWeekHeight: 26,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                      },
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                        _loadMonth(focusedDay);
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markersAlignment: Alignment.bottomCenter,
                        markersMaxCount: 1,
                      ),
                      eventLoader: _eventLoader,
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (ctx, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              width: 18, height: 2.2,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // 오버레이 헤더(년월/이동)
                  Positioned(
                    top: 6, left: 8, right: 8, height: calHeaderH,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: _goPrevMonth,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _goToday, // 탭하면 오늘로
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface.withOpacity(.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  monthFmt.format(_focusedDay),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: _goNextMonth,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 아래: 드래그 시트(초기 낮게 시작, "추가하기" 단일 버튼)
            DraggableScrollableSheet(
              expand: true,
              initialChildSize: 0.22,
              minChildSize: 0.22,
              maxChildSize: 0.92,
              builder: (ctx, scrollController) {
                if (_loading) {
                  return _BottomContainer(
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (_error != null) {
                  return _BottomContainer(
                    child: Center(child: Text('로드 실패: $_error')),
                  );
                }

                final hasAny = !bundle.isEmpty;
                final totalCount = bundle.schedules.length
                    + bundle.diaries.length
                    + bundle.expenses.length
                    + bundle.incomes.length;

                return _BottomContainer(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _SheetHeader(
                          dayLabel: _dPretty.format(bundle.day),
                          countLabel: hasAny ? '$totalCount건' : '기록 없음',
                        ),
                      ),

                      if (bundle.schedules.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: _SectionHeader(title: '일정', icon: Icons.event)),
                        SliverList.separated(
                          itemCount: bundle.schedules.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s = bundle.schedules[i];
                            final allDay = s.allDay || (s.end == null && s.start.hour == 0 && s.start.minute == 0);
                            final time = allDay
                                ? '종일'
                                : (s.end != null ? '${_t.format(s.start)} ~ ${_t.format(s.end!)}' : _t.format(s.start));
                            return ListTile(
                              leading: Icon(_scheduleIcon(s.type), color: Theme.of(context).colorScheme.primary),
                              title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('$time • ${s.location.isEmpty ? '장소 없음' : s.location}'),
                              onTap: () => _openScheduleEdit(s),
                            );
                          },
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 6)),
                      ],

                      if (bundle.diaries.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: _SectionHeader(title: '감정일기', icon: Icons.menu_book)),
                        SliverList.separated(
                          itemCount: bundle.diaries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = bundle.diaries[i];
                            final text = (d.content ?? d.legacyText ?? '').trim();
                            return ListTile(
                              leading: const Icon(Icons.menu_book_outlined),
                              title: Text(
                                text.isEmpty ? '(내용 없음)' : _clip(text, 90),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(_moodLabel(d.mood)),
                              onTap: () => _openDiaryDetail(d),
                            );
                          },
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 6)),
                      ],

                      if (bundle.expenses.isNotEmpty || bundle.incomes.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: _SectionHeader(title: '지출 · 수입', icon: Icons.payments)),
                        SliverList.separated(
                          itemCount: bundle.expenses.length + bundle.incomes.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            if (i < bundle.expenses.length) {
                              final e = bundle.expenses[i];
                              return ListTile(
                                leading: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                title: Text(e.memo ?? _expLabel(e.category), style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(_expLabel(e.category)),
                                trailing: Text(
                                  '-${_money.format(e.amount)}',
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900),
                                ),
                                onTap: () => _openExpenseEdit(e),
                              );
                            } else {
                              final j = i - bundle.expenses.length;
                              final inc = bundle.incomes[j];
                              return ListTile(
                                leading: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
                                title: Text(inc.memo ?? _incLabel(inc.category), style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(_incLabel(inc.category)),
                                trailing: Text(
                                  '+${_money.format(inc.amount)}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onTap: () => _openIncomeEdit(inc),
                              );
                            }
                          },
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 6)),
                      ],

                      // 하단 "추가하기" 단일 버튼
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          child: FilledButton.icon(
                            onPressed: () => _openAddMenu(bundle.day),
                            icon: const Icon(Icons.add),
                            label: const Text('추가하기'),
                          ),
                        ),
                      ),

                      if (bundle.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              '이 날 기록이 없어요. 아래의 "추가하기"로 등록해 보세요.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  // ───────────── helpers for labels/icons ─────────────
  IconData _scheduleIcon(ScheduleType t) {
    switch (t) {
      case ScheduleType.meeting:     return Icons.groups_2;
      case ScheduleType.appointment: return Icons.event_available;
      case ScheduleType.personal:    return Icons.person;
      case ScheduleType.travel:      return Icons.flight_takeoff;
      case ScheduleType.workout:     return Icons.fitness_center;
      case ScheduleType.other:       return Icons.star_border;
    }
  }

  static String _moodLabel(String? mood) {
    switch ((mood ?? 'NEUTRAL').toUpperCase()) {
      case 'VERY_GOOD': return '아주 좋음';
      case 'GOOD':      return '좋음';
      case 'NEUTRAL':   return '보통';
      case 'BAD':       return '나쁨';
      case 'VERY_BAD':  return '매우 나쁨';
      default:          return '보통';
    }
  }

  static String _expLabel(ExpenseCategory c) {
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

  static String _incLabel(IncomeCategory c) {
    switch (c) {
      case IncomeCategory.SALARY:    return '급여';
      case IncomeCategory.ALLOWANCE: return '용돈';
      case IncomeCategory.BONUS:     return '상여/보너스';
      case IncomeCategory.INVEST:    return '투자수익';
      case IncomeCategory.REFUND:    return '환급/환불';
      case IncomeCategory.OTHER:     return '기타수입';
    }
  }

  static String _clip(String s, int max) => s.length > max ? '${s.substring(0, max)}…' : s;
}

/* ====================== 아래는 시트 공용 컴포넌트 ====================== */

class _BottomContainer extends StatelessWidget {
  const _BottomContainer({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.dayLabel,
    required this.countLabel,
  });
  final String dayLabel;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          Container(
            width: 44, height: 4,
            decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const Spacer(),
              Text(countLabel, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/* ====================== Diary Sheets ====================== */

class _DiaryDetailSheet extends StatelessWidget {
  const _DiaryDetailSheet({required this.entry});
  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = entry.date;
    final mood = entry.mood ?? 'NEUTRAL';
    final text = (entry.content ?? entry.legacyText ?? '');

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 18, offset: const Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              height: 4, width: 48, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.menu_book_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(DateFormat('M월 d일(E)', 'ko_KR').format(date),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Text(_moodLabel(mood), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('수정'),
                onPressed: () async {
                  final ok = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _DiaryEditSheet(edit: entry),
                  );
                  if (ok == true && context.mounted) Navigator.pop(context, true);
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
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
                  if (confirm == true) {
                    try {
                      await DiaryService.deleteByDate(date);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ]),
      ),
    );
  }

  static String _moodLabel(String mood) {
    switch (mood.toUpperCase()) {
      case 'VERY_GOOD': return '아주 좋음';
      case 'GOOD':      return '좋음';
      case 'NEUTRAL':   return '보통';
      case 'BAD':       return '나쁨';
      case 'VERY_BAD':  return '매우 나쁨';
      default:          return '보통';
    }
  }
}

class _DiaryEditSheet extends StatefulWidget {
  const _DiaryEditSheet({this.edit, this.initialDate});
  final DiaryEntry? edit;
  final DateTime? initialDate;

  @override
  State<_DiaryEditSheet> createState() => _DiaryEditSheetState();
}

class _DiaryEditSheetState extends State<_DiaryEditSheet> {
  final _form = GlobalKey<FormState>();
  final _textCtrl = TextEditingController();
  late DateTime _date;
  String _mood = 'NEUTRAL';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.edit == null) {
      final base = widget.initialDate ?? DateTime.now();
      _date = DateTime(base.year, base.month, base.day);
      _textCtrl.text = '';
      _mood = 'NEUTRAL';
    } else {
      final e = widget.edit!;
      _date = DateTime(e.date.year, e.date.month, e.date.day);
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
      await DiaryService.upsertDiary(
        date: _date,
        content: _textCtrl.text.trim(),
        mood: _mood,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final moods = const [
      ('VERY_GOOD','아주 좋음','🤩'),
      ('GOOD','좋음','🙂'),
      ('NEUTRAL','보통','😐'),
      ('BAD','나쁨','☹️'),
      ('VERY_BAD','매우 나쁨','😣'),
    ];

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
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text('날짜  ${DateFormat('yyyy-MM-dd').format(_date)}'),
                  onPressed: _pickDate,
                ),
              ),
            ]),
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
              spacing: 8, runSpacing: -6,
              children: [
                for (final m in moods)
                  ChoiceChip(
                    selected: _mood == m.$1,
                    avatar: Text(m.$3, style: const TextStyle(fontSize: 16)),
                    label: Text(m.$2),
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
                    labelStyle: TextStyle(
                      color: _mood == m.$1
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _mood == m.$1
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    onSelected: (_) => setState(() => _mood = m.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(widget.edit == null ? '저장' : '수정 저장'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/* ====================== Schedule Sheet ====================== */

class _ScheduleEditSheet extends StatefulWidget {
  const _ScheduleEditSheet({this.edit, this.initial});
  final ScheduleItem? edit;
  final DateTime? initial;

  @override
  State<_ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends State<_ScheduleEditSheet> {
  final _form = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  late DateTime _start;
  DateTime? _end;
  bool _allDay = false;
  ScheduleType _type = ScheduleType.meeting;
  bool _submitting = false;
  bool _alarmEnabled = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.edit == null) {
      final base = widget.initial ?? now;
      _start = DateTime(base.year, base.month, base.day, now.hour, (now.minute ~/ 5) * 5);
      _end = _start.add(const Duration(hours: 1));
      _titleCtrl.text = '';
      _locCtrl.text = '';
      _allDay = false;
      _type = ScheduleType.meeting;
      _alarmEnabled = false;
    } else {
      final x = widget.edit!;
      _titleCtrl.text = x.title;
      _locCtrl.text = x.location;
      _memoCtrl.text = x.memo ?? '';
      _start = x.start;
      _end = x.end;
      _allDay = x.allDay || (x.end == null && x.start.hour == 0 && x.start.minute == 0);
      _type = x.type;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2022, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: '날짜 선택',
    );
    if (d == null) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: '시간 선택',
    );
    if (t == null) return DateTime(d.year, d.month, d.day);
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_allDay && _end != null && !_start.isBefore(_end!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('종료 시각이 시작보다 같거나 빠릅니다.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      if (widget.edit == null) {
        final created = await ScheduleApi.create(
          ScheduleItem(
            id: '',
            title: _titleCtrl.text.trim(),
            start: _allDay ? DateTime(_start.year, _start.month, _start.day) : _start,
            end:   _allDay ? null : _end,
            location: _locCtrl.text.trim(),
            type: _type,
            memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
            allDay: _allDay,
          ),
        );
        if (created.id.isNotEmpty) {
          await ScheduleApi.updateTyped(created.id, alarmEnabled: _alarmEnabled);
        }
      } else {
        final o = widget.edit!;
        final newTitle = _titleCtrl.text.trim();
        final newStart = _allDay ? DateTime(_start.year, _start.month, _start.day) : _start;
        final wasAllDay = o.allDay || (o.end == null && o.start.hour == 0 && o.start.minute == 0);
        final startChanged = !newStart.isAtSameMomentAs(o.start) || (_allDay != wasAllDay);
        final titleChanged = newTitle != o.title;

        await ScheduleApi.updateTyped(
          o.id,
          title: titleChanged ? newTitle : null,
          start: startChanged ? newStart : null,
          allDay: startChanged ? _allDay : null,
          alarmEnabled: _alarmEnabled,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 일정을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _submitting = true);
    try {
      await ScheduleApi.deleteById(widget.edit!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _typeLabel(ScheduleType t) {
    switch (t) {
      case ScheduleType.meeting: return '회의';
      case ScheduleType.appointment: return '약속/예약';
      case ScheduleType.personal: return '개인';
      case ScheduleType.travel: return '이동/여행';
      case ScheduleType.workout: return '운동';
      case ScheduleType.other: return '기타';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.edit != null;

    String timeLabel(DateTime dt) => DateFormat('yyyy-MM-dd  HH:mm').format(dt);

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
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '제목'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(controller: _locCtrl, decoration: const InputDecoration(labelText: '장소')),
            const SizedBox(height: 8),
            DropdownButtonFormField<ScheduleType>(
              value: _type,
              items: ScheduleType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
              decoration: const InputDecoration(labelText: '종류'),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('종일'),
              value: _allDay,
              onChanged: (v) => setState(() { _allDay = v; if (v) _end = null; }),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('알람'),
              subtitle: const Text('앱 내 알림'),
              value: _alarmEnabled,
              onChanged: (v) => setState(() => _alarmEnabled = v),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('시작  ${_allDay ? DateFormat('yyyy-MM-dd').format(_start) : timeLabel(_start)}'),
                  onPressed: () async {
                    final picked = await _pickDateTime(_start);
                    if (picked != null) setState(() => _start = picked);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (!_allDay)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.timer_outlined),
                    label: Text('종료  ${_end == null ? '설정 안함' : timeLabel(_end!)}'),
                    onPressed: () async {
                      final base = _end ?? _start.add(const Duration(hours: 1));
                      final picked = await _pickDateTime(base);
                      if (picked != null) setState(() => _end = picked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_end != null)
                  IconButton(
                    tooltip: '종료 제거',
                    onPressed: () => setState(() => _end = null),
                    icon: const Icon(Icons.close),
                  ),
              ]),
            const SizedBox(height: 8),
            TextFormField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '메모(선택)'),
              maxLines: 3,
              minLines: 1,
              maxLength: 200,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(isEdit ? '수정 저장' : '저장'),
              ),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('삭제'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: _submitting ? null : _delete,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/* ====================== Money Entry Sheet ====================== */

class _MoneyEntrySheet extends StatefulWidget {
  const _MoneyEntrySheet({
    this.initialDateTime,
    this.editExpense,
    this.editIncome,
  });

  final DateTime? initialDateTime;
  final Expense? editExpense;
  final Income? editIncome;

  @override
  State<_MoneyEntrySheet> createState() => _MoneyEntrySheetState();
}

class _MoneyEntrySheetState extends State<_MoneyEntrySheet> {
  final _form = GlobalKey<FormState>();
  bool _isIncome = false;

  late DateTime _date;
  final _amountCtrl = TextEditingController();
  String _currency = 'KRW';
  ExpenseCategory _expCat = ExpenseCategory.FOOD;
  IncomeCategory _incCat = IncomeCategory.SALARY;
  final _memoCtrl = TextEditingController();
  bool _submitting = false;
  final _n = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    if (widget.editExpense != null) {
      final e = widget.editExpense!;
      _isIncome = false;
      _date = e.date;
      _amountCtrl.text = _n.format(e.amount.toInt());
      _currency = e.currency;
      _expCat = e.category;
      _memoCtrl.text = e.memo ?? '';
    } else if (widget.editIncome != null) {
      final i = widget.editIncome!;
      _isIncome = true;
      _date = i.date;
      _amountCtrl.text = _n.format(i.amount.toInt());
      _currency = i.currency;
      _incCat = i.category;
      _memoCtrl.text = i.memo ?? '';
    } else {
      _isIncome = false;
      final base = widget.initialDateTime ?? DateTime.now();
      _date = base;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));

      if (widget.editExpense != null) {
        await ExpenseApi.update(
          widget.editExpense!.id,
          date: _date,
          amount: amount,
          currency: _currency,
          category: _expCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        );
      } else if (widget.editIncome != null) {
        await IncomeApi.update(
          widget.editIncome!.id,
          date: _date,
          amount: amount,
          currency: _currency,
          category: _incCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        );
      } else if (_isIncome) {
        await IncomeApi.create(Income(
          id: '',
          dateTime: _date,
          amount: amount,
          currency: _currency,
          category: _incCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        ));
      } else {
        await ExpenseApi.create(Expense(
          id: '',
          dateTime: _date,
          amount: amount,
          currency: _currency,
          category: _expCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        ));
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('정말 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      if (widget.editExpense != null) {
        await ExpenseApi.deleteById(widget.editExpense!.id);
      } else if (widget.editIncome != null) {
        await IncomeApi.deleteById(widget.editIncome!.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.editExpense != null || widget.editIncome != null;

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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('지출'), icon: Icon(Icons.remove_circle_outline)),
                    ButtonSegment(value: true,  label: Text('수입'), icon: Icon(Icons.add_circle_outline)),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (isEdit) ? null : (s) => setState(() => _isIncome = s.first),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('yyyy-MM-dd HH:mm').format(_date)),
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate == null) return;
                    if (!mounted) return;

                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_date),
                    );

                    setState(() {
                      _date = DateTime(
                        pickedDate.year, pickedDate.month, pickedDate.day,
                        pickedTime?.hour ?? _date.hour,
                        pickedTime?.minute ?? _date.minute,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: '금액'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return '금액을 입력하세요';
                final d = double.tryParse(v.replaceAll(',', ''));
                if (d == null || d <= 0) return '0보다 큰 숫자';
                return null;
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _currency,
              items: const [
                DropdownMenuItem(value: 'KRW', child: Text('KRW (₩)')),
                DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                DropdownMenuItem(value: 'JPY', child: Text('JPY (¥)')),
              ],
              onChanged: (v) => setState(() => _currency = v ?? 'KRW'),
              decoration: const InputDecoration(labelText: '통화'),
            ),
            const SizedBox(height: 8),

            if (!_isIncome)
              DropdownButtonFormField<ExpenseCategory>(
                value: _expCat,
                items: ExpenseCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(_expLabel(c))))
                    .toList(),
                onChanged: (v) => setState(() => _expCat = v ?? ExpenseCategory.FOOD),
                decoration: const InputDecoration(labelText: '지출 카테고리'),
              )
            else
              DropdownButtonFormField<IncomeCategory>(
                value: _incCat,
                items: IncomeCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(_incLabel(c))))
                    .toList(),
                onChanged: (v) => setState(() => _incCat = v ?? IncomeCategory.SALARY),
                decoration: const InputDecoration(labelText: '수입 카테고리'),
              ),

            const SizedBox(height: 8),
            TextFormField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '메모(선택)'),
              maxLength: 80,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(isEdit ? '수정 저장' : '저장'),
              ),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('삭제'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: _submitting ? null : _delete,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  static String _expLabel(ExpenseCategory c) {
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

  static String _incLabel(IncomeCategory c) {
    switch (c) {
      case IncomeCategory.SALARY:    return '급여';
      case IncomeCategory.ALLOWANCE: return '용돈';
      case IncomeCategory.BONUS:     return '상여/보너스';
      case IncomeCategory.INVEST:    return '투자수익';
      case IncomeCategory.REFUND:    return '환급/환불';
      case IncomeCategory.OTHER:     return '기타수입';
    }
  }
}

/* ====================== 데이터 묶음 ====================== */

class _DayBundle {
  final DateTime day;
  final List<ScheduleItem> schedules;
  final List<DiaryEntry>   diaries;
  final List<Expense>      expenses;
  final List<Income>       incomes;
  _DayBundle({
    required this.day,
    required this.schedules,
    required this.diaries,
    required this.expenses,
    required this.incomes,
  });
  bool get isEmpty => schedules.isEmpty && diaries.isEmpty && expenses.isEmpty && incomes.isEmpty;
}
