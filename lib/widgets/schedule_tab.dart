import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/schedule.dart';
import '../../core/services/schedule_api.dart';

final _dPretty = DateFormat('M월 d일(E)', 'ko_KR');
final _monthFmt = DateFormat('yyyy년 M월', 'ko_KR');
final _t = DateFormat('HH:mm');

IconData _typeIcon(ScheduleType t) {
  switch (t) {
    case ScheduleType.meeting: return Icons.groups_2;
    case ScheduleType.appointment: return Icons.event_available;
    case ScheduleType.personal: return Icons.person;
    case ScheduleType.travel: return Icons.flight_takeoff;
    case ScheduleType.workout: return Icons.fitness_center;
    case ScheduleType.other: return Icons.star_border;
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

/// ── 탭 ────────────────────────────────────────────────────────────────────────
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});
  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  late DateTime _from;
  late DateTime _to;
  late Future<List<ScheduleItem>> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    _future = _load();
  }

  Future<List<ScheduleItem>> _load() async => ScheduleApi.list(_from, _to);
  Future<void> _reload() async => setState(() => _future = _load());

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
    final m = DateTime(_from.year, _from.month + delta, 1);
    setState(() {
      _from = m;
      _to = DateTime(m.year, m.month + 1, 0);
    });
    await _reload();
  }

  void _goPrevMonth() => _goPrevNextMonth(-1);
  void _goNextMonth() => _goPrevNextMonth(1);

  Map<DateTime, List<ScheduleItem>> _groupByDate(List<ScheduleItem> list) {
    final map = <DateTime, List<ScheduleItem>>{};
    for (final x in list) {
      final k = DateTime(x.start.year, x.start.month, x.start.day);
      map.putIfAbsent(k, () => []).add(x);
    }
    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      e.value.sort((a, b) => a.start.compareTo(b.start)); // 같은날은 시작시간순
    }
    return { for (final e in entries) e.key : e.value };
  }

  Future<void> _openAdd([ScheduleItem? edit]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(item: edit),
    );
    if (ok == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 110, // ← 64 → 110 정도로 넓혀줌
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '일정',                 // ← 공백 제거해서 더 컴팩트
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
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<ScheduleItem>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('로드 실패: ${snap.error}'));
          }
          final list = snap.data ?? const <ScheduleItem>[];
          if (list.isEmpty) return _EmptyView(onQuickAdd: () => _openAdd());

          final grouped = _groupByDate(list);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _SummaryCard(total: list.length),
                const SizedBox(height: 10),
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
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '오늘',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...items.map(
                            (x) => _ScheduleTile(
                          item: x,
                          onEdit: () => _openAdd(x),
                          onDelete: () async {
                            await ScheduleApi.deleteById(x.id);
                            await _reload();
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ── 위젯들 ───────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const Expanded(child: Text('이번 달 일정', style: TextStyle(fontWeight: FontWeight.w700))),
          Text('$total 건', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  bool _isAllDayLike(DateTime s, DateTime? e, bool flag) {
    return flag || (e == null && s.hour == 0 && s.minute == 0);
  }

  String _timeText() {
    if (_isAllDayLike(item.start, item.end, item.allDay)) return '종일';
    final s = _t.format(item.start);
    final e = item.end != null ? _t.format(item.end!) : null;
    return e != null ? '$s ~ $e' : s;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
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
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListTile(
          onTap: onEdit,
          leading: CircleAvatar(
            backgroundColor: cs.primary.withOpacity(.12),
            child: Icon(_typeIcon(item.type), color: cs.primary),
          ),
          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            '${_timeText()} • ${item.location}\n${_typeLabel(item.type)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: cs.outline),
          const SizedBox(height: 8),
          Text('해당 월의 일정이 없습니다.', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onQuickAdd, icon: const Icon(Icons.add), label: const Text('일정 추가')),
        ],
      ),
    );
  }
}

/// ── 추가/수정 바텀시트 ────────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  const _EditSheet({this.item});
  final ScheduleItem? item;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
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

  bool _isAllDayLike(DateTime s, DateTime? e, bool flag) {
    return flag || (e == null && s.hour == 0 && s.minute == 0);
  }

  DateTime _roundTo15(DateTime t) {
    final q = ((t.minute + 7) ~/ 15) * 15; // 근처 15분으로 반올림
    final mm = (q >= 60) ? 0 : q;
    return DateTime(t.year, t.month, t.day, t.hour, mm);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.item == null) {
      _start = _roundTo15(now.add(const Duration(minutes: 10)));
      _end = _start.add(const Duration(hours: 1));
      _titleCtrl.text = '';
      _locCtrl.text = '';
      _allDay = false;
      _type = ScheduleType.meeting;
      _alarmEnabled = false;
    } else {
      final x = widget.item!;
      _titleCtrl.text = x.title;
      _locCtrl.text = x.location;
      _memoCtrl.text = x.memo ?? '';
      _start = x.start;
      _end = x.end;
      _allDay = _isAllDayLike(x.start, x.end, x.allDay);
      _type = x.type;
      // 알람 값은 서버/모델에 맞춰 필요시 초기화
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시각이 시작보다 같거나 빠릅니다.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.item == null) {
        // 생성
        final created = await ScheduleApi.create(
          ScheduleItem(
            id: '',
            title: _titleCtrl.text.trim(),
            start: _allDay ? DateTime(_start.year, _start.month, _start.day) : _start,
            end: _allDay ? null : _end,
            location: _locCtrl.text.trim(),
            type: _type,
            memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
            allDay: _allDay,
          ),
        );

        // 생성 직후 알람 반영 (서버 스펙에 맞춰 부분 업데이트)
        if (created.id.isNotEmpty) {
          await ScheduleApi.updateTyped(
            created.id,
            alarmEnabled: _alarmEnabled,
          );
        }

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        // 수정
        final original = widget.item!;
        final newTitle = _titleCtrl.text.trim();
        final newStart = _allDay
            ? DateTime(_start.year, _start.month, _start.day)
            : _start;

        final wasAllDay = _isAllDayLike(original.start, original.end, original.allDay);
        final startChanged =
            !newStart.isAtSameMomentAs(original.start) || (_allDay != wasAllDay);
        final titleChanged = newTitle != original.title;

        await ScheduleApi.updateTyped(
          original.id,
          title: titleChanged ? newTitle : null,
          start: startChanged ? newStart : null,
          allDay: startChanged ? _allDay : null, // time null/HH:mm 결정에 필요
          alarmEnabled: _alarmEnabled,
        );

        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
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
      await ScheduleApi.deleteById(widget.item!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final isEdit = widget.item != null;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 48,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '제목'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locCtrl,
                decoration: const InputDecoration(labelText: '장소'),
              ),
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
                onChanged: (v) => setState(() {
                  _allDay = v;
                  if (v) _end = null; // 종일이면 종료시간 비움
                }),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('알람'),
                subtitle: const Text('앱 내 알림'),
                value: _alarmEnabled,
                onChanged: (v) => setState(() => _alarmEnabled = v),
              ),
              const SizedBox(height: 4),

              // 시작/종료
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text('시작  ${_allDay ? DateFormat('yyyy-MM-dd').format(_start) : timeLabel(_start)}'),
                      onPressed: () async {
                        final picked = await _pickDateTime(context, _start);
                        if (picked != null) setState(() => _start = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_allDay)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.timer_outlined),
                        label: Text('종료  ${_end == null ? '설정 안함' : timeLabel(_end!)}'),
                        onPressed: () async {
                          final base = _end ?? _maxDate(_start.add(const Duration(hours: 1)), _start);
                          final picked = await _pickDateTime(context, base);
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
                  ],
                ),

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
            ],
          ),
        ),
      ),
    );
  }

  // 간단 유틸: 둘 중 더 늦은 시간
  DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
}
