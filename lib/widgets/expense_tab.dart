// lib/tabs/expense_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseTab extends StatefulWidget {
  const ExpenseTab({super.key});

  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

/* -------------------- 모델 & 저장소 -------------------- */
class ExpenseEntry {
  final String id;        // uuid-like
  final DateTime date;    // 발생일
  final int amount;       // 원화(정수)
  final String category;  // 분류
  final String memo;      // 메모

  ExpenseEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.memo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'amount': amount,
    'category': category,
    'memo': memo,
  };

  static ExpenseEntry fromMap(Map<String, dynamic> m) => ExpenseEntry(
    id: m['id'] as String,
    date: DateTime.parse(m['date'] as String),
    amount: (m['amount'] as num).toInt(),
    category: (m['category'] as String?) ?? '기타',
    memo: (m['memo'] as String?) ?? '',
  );
}

class _ExpenseStore {
  static const _key = 'expenses.v1';

  static Future<List<ExpenseEntry>> loadAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ExpenseEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<ExpenseEntry> all) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(all.map((e) => e.toMap()).toList());
    await sp.setString(_key, raw);
  }
}

/* -------------------- 화면 -------------------- */
class _ExpenseTabState extends State<ExpenseTab> {
  final _nf = NumberFormat.decimalPattern('ko');
  final _dfHeader = DateFormat('yyyy.MM', 'ko');
  final _dfDay = DateFormat('M/d (E)', 'ko');

  // 카테고리 프리셋 (원하면 나중에 설정에서 편집)
  static const _categories = <String>[
    '식비',
    '카페/간식',
    '교통',
    '쇼핑',
    '주거/통신',
    '문화/여가',
    '의료/건강',
    '교육',
    '기타',
  ];

  List<ExpenseEntry> _all = [];
  DateTime _month = _firstDayOfMonth(DateTime.now());

  static DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime _nextMonth(DateTime m) => DateTime(m.year, m.month + 1, 1);
  static DateTime _prevMonth(DateTime m) => DateTime(m.year, m.month - 1, 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _ExpenseStore.loadAll();
    setState(() {
      // 최신이 위로 보이도록 정렬(날짜 내림차순)
      all.sort((a, b) => b.date.compareTo(a.date));
      _all = all;
    });
  }

  Future<void> _save() async {
    await _ExpenseStore.saveAll(_all);
  }

  /* ------------- 월별 필터/그룹/합계 ------------- */
  Iterable<ExpenseEntry> get _monthEntries sync* {
    final start = _month;
    final end = _nextMonth(_month);
    for (final e in _all) {
      if (!e.date.isBefore(start) && e.date.isBefore(end)) yield e;
    }
  }

  int get _monthTotal {
    var sum = 0;
    for (final e in _monthEntries) sum += e.amount;
    return sum;
  }

  Map<DateTime, List<ExpenseEntry>> get _groupByDay {
    final map = <DateTime, List<ExpenseEntry>>{};
    for (final e in _monthEntries) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      (map[key] ??= []).add(e);
    }
    // 날짜 최신순으로 키 정렬
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  /* ------------- 추가/삭제 ------------- */
  Future<void> _addEntry() async {
    final created = await showModalBottomSheet<ExpenseEntry>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _AddExpenseSheet(categories: _categories),
    );
    if (created == null) return;

    setState(() {
      _all.insert(0, created);
    });
    await _save();

    // 같은 달이 아니면 그 달로 넘겨줄까? (선택)
    if (created.date.year != _month.year || created.date.month != _month.month) {
      setState(() => _month = _firstDayOfMonth(created.date));
    }
  }

  Future<void> _deleteEntry(ExpenseEntry e) async {
    final idx = _all.indexWhere((x) => x.id == e.id);
    if (idx < 0) return;
    setState(() {
      _all.removeAt(idx);
    });
    await _save();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('삭제했어요'),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () async {
            setState(() => _all.insert(idx, e));
            await _save();
          },
        ),
      ),
    );
  }

  /* ------------- UI ------------- */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = _groupByDay;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 월 이동 + 합계
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 달',
                    onPressed: () => setState(() => _month = _prevMonth(_month)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _dfHeader.format(_month),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    onPressed: () => setState(() => _month = _nextMonth(_month)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.wallet_outlined),
                    const SizedBox(width: 10),
                    const Text(
                      '이 달 지출 합계',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${_nf.format(_monthTotal)}원',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Expanded(
                child: groups.isEmpty
                    ? _EmptyState(onAdd: _addEntry)
                    : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (ctx, idx) {
                    final day = groups.keys.elementAt(idx);
                    final items = groups[day]!;
                    final dayTotal = items.fold<int>(0, (s, e) => s + e.amount);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DaySection(
                        title: _dfDay.format(day),
                        totalText: '${_nf.format(dayTotal)}원',
                        children: [
                          for (final e in items)
                            Dismissible(
                              key: ValueKey(e.id),
                              background: Container(
                                color: Colors.redAccent,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                // 바로 지우되, 스낵바에서 되돌리기 제공
                                await _deleteEntry(e);
                                return false; // 내부에서 처리했으니 ListView에게 지우지 말라
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                leading: CircleAvatar(
                                  backgroundColor: cs.secondaryContainer,
                                  child: Text(
                                    e.category.characters.first,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                title: Text(e.memo.isEmpty ? e.category : e.memo),
                                subtitle: e.memo.isEmpty ? null : Text(e.category),
                                trailing: Text(
                                  '${_nf.format(e.amount)}원',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 플로팅 "지출 추가" 버튼 (부모 Scaffold 없어도 자체 배치)
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.extended(
            onPressed: _addEntry,
            icon: const Icon(Icons.add),
            label: const Text('지출 추가'),
          ),
        ),
      ],
    );
  }
}

/* -------------------- 섹션 위젯 -------------------- */
class _DaySection extends StatelessWidget {
  final String title;
  final String totalText;
  final List<Widget> children;

  const _DaySection({
    required this.title,
    required this.totalText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              color: cs.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(
                  totalText,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 56, color: cs.primary),
          const SizedBox(height: 12),
          const Text('이 달에는 아직 기록이 없어요.'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('지출 추가'),
          ),
        ],
      ),
    );
  }
}

/* -------------------- 추가 바텀시트 -------------------- */
class _AddExpenseSheet extends StatefulWidget {
  final List<String> categories;
  const _AddExpenseSheet({required this.categories});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _amountC = TextEditingController();
  final _memoC = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = '기타';
  final _formKey = GlobalKey<FormState>();
  final _nf = NumberFormat.decimalPattern('ko');

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) _category = widget.categories.first;
  }

  @override
  void dispose() {
    _amountC.dispose();
    _memoC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  int? _parseAmount(String raw) {
    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.isEmpty) return null;
    return int.tryParse(onlyDigits);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountC.text)!;
    final memo = _memoC.text.trim();

    final e = ExpenseEntry(
      id: UniqueKey().toString(),
      date: DateTime(_date.year, _date.month, _date.day),
      amount: amount,
      category: _category,
      memo: memo,
    );

    Navigator.of(context).pop<ExpenseEntry>(e);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + insets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('지출 추가', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            // 금액
            TextFormField(
              controller: _amountC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '금액 (원)',
                prefixIcon: Icon(Icons.attach_money),
                hintText: '예) 12000',
              ),
              validator: (v) {
                final a = _parseAmount(v ?? '');
                if (a == null || a <= 0) return '금액을 입력해 주세요';
                return null;
              },
              onChanged: (v) {
                // 보기 좋게 천단위 표시(선택)
                final pos = _amountC.selection;
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isEmpty) return;
                final pretty = _nf.format(int.parse(digits));
                if (pretty != v) {
                  _amountC.value = TextEditingValue(
                    text: pretty,
                    selection: TextSelection.collapsed(offset: pretty.length),
                  );
                } else {
                  _amountC.selection = pos;
                }
              },
            ),
            const SizedBox(height: 12),

            // 카테고리
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: '카테고리',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? '기타'),
            ),
            const SizedBox(height: 12),

            // 날짜
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '날짜',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Row(
                  children: [
                    Text(DateFormat('yyyy.MM.dd (E)', 'ko').format(_date)),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 메모
            TextFormField(
              controller: _memoC,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    onPressed: _submit,
                    label: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
