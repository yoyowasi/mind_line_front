import 'package:flutter/material.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  // 월 포커스(해당 월의 1일)
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // 선택된 날짜
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  // 데모 이벤트 (날짜 -> 이벤트 목록)
  // 실제 앱에선 서버/DB와 연결해서 이 맵을 채워주면 됨.
  final Map<DateTime, List<String>> _events = {
    _d(DateTime.now()): ['회의 10:00', '카페 미팅 15:00'],
    _d(DateTime.now().add(const Duration(days: 2))): ['PT 19:00'],
    _d(DateTime.now().subtract(const Duration(days: 3))): ['가계부 정리'],
  };

  // 날짜 -> (연-월-일)만 남긴 표준화
  static DateTime _d(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // 월 표기
  String get _monthLabel => '${_focusedMonth.year}년 ${_focusedMonth.month}월';

  // 해당 월 시작 그리드(월요일 시작)
  DateTime _gridStartOfMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final diff = (first.weekday - DateTime.monday) % 7; // 0~6
    return first.subtract(Duration(days: diff));
  }

  // 6주(42칸) 날짜 목록
  List<DateTime> _calendarDays(DateTime month) {
    final start = _gridStartOfMonth(month);
    return List.generate(42, (i) => start.add(Duration(days: i)));
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isInFocusedMonth(DateTime day) =>
      day.year == _focusedMonth.year && day.month == _focusedMonth.month;

  void _goPrevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month);
      _selectedDate = _d(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = _calendarDays(_focusedMonth);
    final selectedEvents = _events[_d(_selectedDate)] ?? const <String>[];

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? cs.surface
          : Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 상단 헤더
              Row(
                children: [
                  Text(
                    '달력',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '이전 달',
                    onPressed: _goPrevMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    _monthLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    onPressed: _goNextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _goToday,
                    child: const Text('오늘'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 요일 헤더 (월~일)
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: const [
                    _WeekdayCell('월'),
                    _WeekdayCell('화'),
                    _WeekdayCell('수'),
                    _WeekdayCell('목'),
                    _WeekdayCell('금'),
                    _WeekdayCell('토', isWeekend: true),
                    _WeekdayCell('일', isWeekend: true),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 달력 그리드
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final day = days[i];
                    final isCurrentMonth = _isInFocusedMonth(day);
                    final isSelected = _isSameDate(day, _selectedDate);
                    final isToday = _isSameDate(day, DateTime.now());
                    final hasEvents = (_events[_d(day)] ?? const []).isNotEmpty;

                    return _DayCell(
                      day: day,
                      isCurrentMonth: isCurrentMonth,
                      isSelected: isSelected,
                      isToday: isToday,
                      hasEvents: hasEvents,
                      onTap: () {
                        setState(() => _selectedDate = _d(day));
                        // 다른 달의 날짜를 누르면 해당 달로 포커스 이동
                        if (!isCurrentMonth) {
                          setState(() {
                            _focusedMonth = DateTime(day.year, day.month);
                          });
                        }
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 선택일 이벤트 목록
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (selectedEvents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Text(
                    '이 날 일정이 없어요.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = selectedEvents[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.event, color: cs.primary),
                        title: Text(e, style: TextStyle(color: cs.onSurface)),
                        dense: true,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 요일 셀
class _WeekdayCell extends StatelessWidget {
  final String label;
  final bool isWeekend;
  const _WeekdayCell(this.label, {this.isWeekend = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isWeekend ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// 날짜 셀
class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final bool hasEvents;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.hasEvents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final textColor = isCurrentMonth
        ? cs.onSurface
        : cs.onSurface.withOpacity(0.38);

    final bg = isSelected
        ? cs.primary.withOpacity(0.12)
        : Colors.transparent;

    final border = isToday
        ? Border.all(color: cs.primary, width: 1.5)
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 날짜 숫자
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const Spacer(),
            // 이벤트 점
            if (hasEvents)
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
