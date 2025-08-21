import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/expense.dart';
import '../core/services/expense_api.dart';
import '../core/models/income.dart';
import '../core/services/income_api.dart';

enum _ViewType { all, expense, income }

class ExpenseTab extends StatefulWidget {
  const ExpenseTab({super.key});
  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab> {
  late DateTime _from;
  late DateTime _to;
  late Future<_MonthData> _future;
  _ViewType _view = _ViewType.all;

  final _n = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
  final _dPretty = DateFormat('M월 d일(E)', 'ko_KR');
  final _t = DateFormat('HH:mm');
  final _monthFmt = DateFormat('yyyy년 M월', 'ko_KR');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    _future = _load();
  }

  Future<_MonthData> _load() async {
    final ex = await ExpenseApi.list(_from, _to);
    final inc = await IncomeApi.list(_from, _to);
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget.${_from.year}${_from.month.toString().padLeft(2, '0')}';
    final budget = prefs.getDouble(key) ?? 0.0;
    return _MonthData(ex, inc, budget);
  }

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
    final next = DateTime(_from.year, _from.month + delta, 1);
    setState(() {
      _from = next;
      _to = DateTime(next.year, next.month + 1, 0);
    });
    await _reload();
  }

  void _goPrevMonth() => _goPrevNextMonth(-1);
  void _goNextMonth() => _goPrevNextMonth(1);

  String _expenseLabel(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.FOOD: return '식비';
      case ExpenseCategory.TRANSPORT: return '교통';
      case ExpenseCategory.HEALTH: return '건강';
      case ExpenseCategory.ENTERTAINMENT: return '여가';
      case ExpenseCategory.EDUCATION: return '교육';
      case ExpenseCategory.SHOPPING: return '쇼핑';
      case ExpenseCategory.TRAVEL: return '여행';
      case ExpenseCategory.TAXES: return '세금/보험';
      case ExpenseCategory.OTHER: return '기타';
    }
  }

  IconData _expenseIcon(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.FOOD: return Icons.fastfood;
      case ExpenseCategory.TRANSPORT: return Icons.directions_subway_filled;
      case ExpenseCategory.HEALTH: return Icons.local_hospital;
      case ExpenseCategory.ENTERTAINMENT: return Icons.movie_filter;
      case ExpenseCategory.EDUCATION: return Icons.school;
      case ExpenseCategory.SHOPPING: return Icons.shopping_bag;
      case ExpenseCategory.TRAVEL: return Icons.flight_takeoff;
      case ExpenseCategory.TAXES: return Icons.receipt_long;
      case ExpenseCategory.OTHER: return Icons.more_horiz;
    }
  }

  String _incomeLabel(IncomeCategory c) {
    switch (c) {
      case IncomeCategory.SALARY: return '급여';
      case IncomeCategory.ALLOWANCE: return '용돈';
      case IncomeCategory.BONUS: return '상여/보너스';
      case IncomeCategory.INVEST: return '투자수익';
      case IncomeCategory.REFUND: return '환급/환불';
      case IncomeCategory.OTHER: return '기타수입';
    }
  }

  IconData _incomeIcon(IncomeCategory c) {
    switch (c) {
      case IncomeCategory.SALARY: return Icons.payments;
      case IncomeCategory.ALLOWANCE: return Icons.card_giftcard;
      case IncomeCategory.BONUS: return Icons.workspace_premium;
      case IncomeCategory.INVEST: return Icons.trending_up;
      case IncomeCategory.REFUND: return Icons.autorenew;
      case IncomeCategory.OTHER: return Icons.savings;
    }
  }

  Future<void> _openEditExpense(Expense x) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(
        labelExpense: _expenseLabel,
        labelIncome: _incomeLabel,
        editExpense: x,
        onAdded: (_) async {},
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _openEditIncome(Income x) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(
        labelExpense: _expenseLabel,
        labelIncome: _incomeLabel,
        editIncome: x,
        onAdded: (_) async {},
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  Color _expenseColor(BuildContext ctx) => Colors.redAccent;
  Color _incomeColor(BuildContext ctx) => Theme.of(ctx).colorScheme.primary;

  // 하루별 묶기
  Map<DateTime, _DayBucket> _groupByDate(_MonthData data) {
    final map = <DateTime, _DayBucket>{};
    for (final e in data.expenses) {
      final k = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(k, () => _DayBucket()).expenses.add(e);
    }
    for (final i in data.incomes) {
      final k = DateTime(i.date.year, i.date.month, i.date.day);
      map.putIfAbsent(k, () => _DayBucket()).incomes.add(i);
    }
    final list = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return {for (final e in list) e.key: e.value};
  }

  // 예산 설정
  Future<void> _editBudget(double current) async {
    final ctrl = TextEditingController(text: current > 0 ? current.toStringAsFixed(0) : '');
    final v = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('월 목표 소비금액'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: '예: 800000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text) ?? 0), child: const Text('저장')),
        ],
      ),
    );
    if (v == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget.${_from.year}${_from.month.toString().padLeft(2, '0')}';
    if (v <= 0) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, v);
    }
    await _reload();
  }

  // 간단한 인사이트
  String _insight(_MonthData d) {
    final daysInMonth = DateTime(_from.year, _from.month + 1, 0).day.toDouble();
    final elapsed = DateTime.now().isBefore(_to)
        ? (DateTime.now().difference(_from).inDays + 1).clamp(1, daysInMonth.toInt()).toDouble()
        : daysInMonth;

    final totalExp = d.totalExpense;
    final totalInc = d.totalIncome;
    if (totalExp <= 0 && totalInc <= 0) return '이번 달 내역이 거의 없어요. 작은 금액이라도 기록해보면 패턴을 빨리 찾을 수 있어요.';

    final buf = <String>[];

    if (d.budget > 0) {
      final pace = totalExp / max(1.0, elapsed);
      final targetPace = d.budget / daysInMonth;
      final diffPct = ((pace / targetPace) - 1) * 100;
      if (diffPct > 8) {
        buf.add('소비 속도가 예산보다 +${diffPct.toStringAsFixed(0)}% 빨라요. 남은 기간은 고정비 외 카드 사용을 조금 줄여보는 건 어떨까요?');
      } else if (diffPct < -8) {
        buf.add('예산 대비 -${diffPct.abs().toStringAsFixed(0)}%로 안정적이에요. 저축이나 투자로 일부 이체해두면 더 안전해요.');
      } else {
        buf.add('예산 페이스가 적절해요. 주말 외식/여가만 과하지 않게 관리하면 충분히 달성 가능합니다.');
      }
    } else {
      buf.add('이번 달 목표 소비금액을 설정해 두면 페이스 관리가 쉬워져요.');
    }

    final byCat = <String, double>{};
    for (final e in d.expenses) {
      final k = _expenseLabel(e.category);
      byCat.update(k, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    if (byCat.isNotEmpty) {
      final top = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final (k, v) = (top.first.key, top.first.value);
      final share = (v / max(1.0, totalExp)) * 100;
      if (share >= 45) {
        buf.add('이번 달은 $k 비중이 ${share.toStringAsFixed(0)}%로 매우 높아요. 일주일에 1~2회만 줄여도 체감됩니다.');
      } else {
        buf.add('가장 큰 지출 항목은 $k이며, 비중은 ${share.toStringAsFixed(0)}% 입니다.');
      }
    }

    final net = totalInc - totalExp;
    if (net < 0) {
      buf.add('현재 수입보다 지출이 많아요(잔액 ${_n.format(net)}). 고정비 점검을 권장해요.');
    } else {
      buf.add('수입이 지출을 앞서고 있어요(여유 ${_n.format(net)}). 남는 금액을 안전자산에 적립해보세요.');
    }

    return buf.join(' ');
  }

  // 추가 시트 열기
  Future<void> _openAddSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(
        onAdded: (isIncome) async {},
        labelExpense: _expenseLabel,
        labelIncome: _incomeLabel,
      ),
    );
    if (created == true && mounted) await _reload(); // ← 꼭 await
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: GestureDetector(
          onTap: _pickMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_monthFmt.format(_from), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        onPressed: _openAddSheet,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<_MonthData>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('로드 실패: ${snap.error}'));
          }
          final d = snap.data ?? _MonthData(const [], const [], 0);
          final grouped = _groupByDate(d);

          // 같은 날짜 내에서 등록시간(createdAt) 기준 최신순 정렬
          grouped.forEach((_, bucket) {
            bucket.expenses.sort((a, b) => b.date.compareTo(a.date));

            bucket.incomes .sort((a, b) => b.date.compareTo(a.date));

          });


          final elapsedDays = DateTime.now().isBefore(_to)
              ? (DateTime.now().difference(_from).inDays + 1)
              : (_to.difference(_from).inDays + 1);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _SummaryCard(
                  monthLabel: _monthFmt.format(_from),
                  totalExpense: d.totalExpense,
                  totalIncome: d.totalIncome,
                  budget: d.budget,
                  elapsedDays: elapsedDays,
                  daysInMonth: _to.day,
                  n: _n,
                  onEditBudget: () => _editBudget(d.budget),
                ),
                const SizedBox(height: 10),
                _InsightBox(text: _insight(d)),
                const SizedBox(height: 6),

                // 보기 토글
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('전체'),
                      selected: _view == _ViewType.all,
                      onSelected: (_) => setState(() => _view = _ViewType.all),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('지출'),
                      selected: _view == _ViewType.expense,
                      onSelected: (_) => setState(() => _view = _ViewType.expense),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('수입'),
                      selected: _view == _ViewType.income,
                      onSelected: (_) => setState(() => _view = _ViewType.income),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (grouped.isEmpty)
                  _EmptyView(onQuickAdd: _openAddSheet)
                else
                  ...grouped.entries.map((e) {
                    final day = e.key;
                    final bucket = e.value;
                    final expSum = bucket.expenses.fold<double>(0, (p, x) => p + x.amount);
                    final incSum = bucket.incomes.fold<double>(0, (p, x) => p + x.amount);

                    final rows = <Widget>[];
                    if (_view != _ViewType.income) {
                      rows.addAll(bucket.expenses.map((x) {
                        final timeText = _t.format(x.date.toLocal()); // ★ createdAt 말고 date
                        return _EntryTile(
                          key: ValueKey('exp_${x.id}'),
                          title: x.memo ?? _expenseLabel(x.category),
                          subtitle: _expenseLabel(x.category),
                          timeText: timeText,
                          amountText: _n.format(x.amount),
                          color: _expenseColor(context),
                          icon: _expenseIcon(x.category),
                          onDelete: () async {
                            await ExpenseApi.deleteById(x.id);
                            await _reload(); // ★ 삭제 후 즉시 새로고침
                          },
                          onTap: () => _openEditExpense(x),
                        );
                      }));
                    }
                    if (_view != _ViewType.expense) {
                      rows.addAll(bucket.incomes.map((x) {
                        final timeText = _t.format(x.date.toLocal()); // ★ 00:00 방지
                        return _EntryTile(
                          key: ValueKey('inc_${x.id}'),
                          title: x.memo ?? _incomeLabel(x.category),
                          subtitle: _incomeLabel(x.category),
                          timeText: timeText,
                          amountText: _n.format(x.amount),
                          color: _incomeColor(context),
                          icon: _incomeIcon(x.category),
                          onDelete: () async {
                            await IncomeApi.deleteById(x.id);
                            await _reload();
                          },
                          onTap: () => _openEditIncome(x),
                        );
                      }));
                    }

                    if (rows.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dPretty.format(day),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Row(
                                children: [
                                  if (_view != _ViewType.income)
                                    Text('지출 ${_n.format(expSum)}',
                                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  if (_view == _ViewType.all) const SizedBox(width: 10),
                                  if (_view != _ViewType.expense)
                                    Text('수입 ${_n.format(incSum)}',
                                        style: TextStyle(color: _incomeColor(context), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ...rows,
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

/* ======= 모델/뷰 보조 ======= */

class _MonthData {
  final List<Expense> expenses;
  final List<Income> incomes;
  final double budget; // 목표 소비금액 (0이면 미설정)

  _MonthData(this.expenses, this.incomes, this.budget);

  double get totalExpense => expenses.fold(0.0, (p, e) => p + e.amount);
  double get totalIncome  => incomes.fold(0.0, (p, e) => p + e.amount);
}

class _DayBucket {
  final List<Expense> expenses = [];
  final List<Income> incomes = [];
}

/* ======= 위젯들 ======= */

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.monthLabel,
    required this.totalExpense,
    required this.totalIncome,
    required this.budget,
    required this.elapsedDays,
    required this.daysInMonth,
    required this.n,
    required this.onEditBudget,
  });

  final String monthLabel;
  final double totalExpense;
  final double totalIncome;
  final double budget;
  final int elapsedDays;
  final int daysInMonth;
  final NumberFormat n;
  final VoidCallback onEditBudget;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remainDays = max(1, daysInMonth - elapsedDays);
    final avgDaily = totalExpense / max(1, elapsedDays);
    final needDaily = budget > 0 ? max(0.0, (budget - totalExpense) / remainDays) : 0.0;
    final ratio = budget > 0 ? (totalExpense / budget).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$monthLabel 요약', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statTile('총지출', n.format(totalExpense), Colors.redAccent, Icons.arrow_downward),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile('총수입', n.format(totalIncome), cs.primary, Icons.arrow_upward),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (budget > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: onEditBudget, // 탭으로 예산 재설정
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '예산 ${n.format(budget)}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Text('${(ratio * 100).toStringAsFixed(0)}%', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (totalExpense / budget).clamp(0, 1),
                minHeight: 10,
                color: Colors.redAccent,
                backgroundColor: Colors.redAccent.withOpacity(.12),
              ),
            ),
            const SizedBox(height: 6),
            Text('지금까지 일 평균 ${n.format(avgDaily)}, 남은 ${remainDays}일은 하루 ${n.format(needDaily)} 이내면 목표 달성!',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ] else
            TextButton.icon(onPressed: onEditBudget, icon: const Icon(Icons.flag_outlined), label: const Text('월 목표 소비금액 설정')),
        ],
      ),
    );
  }

  Widget _statTile(String title, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InsightBox extends StatelessWidget {
  const _InsightBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.timeText,
    required this.amountText,
    required this.color,
    required this.icon,
    required this.onDelete,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? timeText;
  final String amountText;
  final Color color;
  final IconData icon;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = (timeText != null && timeText!.isNotEmpty) ? '${timeText!} • $subtitle' : subtitle;

    return Dismissible(
      key: key ?? ValueKey('$title$amountText$sub'),
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
            content: const Text('이 항목을 삭제할까요?'),
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
          onTap: onTap,
          leading: CircleAvatar(backgroundColor: color.withOpacity(.18), child: Icon(icon, color: color)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub),
          trailing: Text(amountText, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
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
    return Container(
      height: 360,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: cs.outline),
          const SizedBox(height: 8),
          Text('해당 월의 내역이 없습니다.', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onQuickAdd, icon: const Icon(Icons.add), label: const Text('항목 추가')),
        ],
      ),
    );
  }
}

/* ======= 추가: 수입/지출 입력/수정 시트 ======= */

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({
    required this.onAdded,
    required this.labelExpense,
    required this.labelIncome,
    this.editExpense,
    this.editIncome,
  });

  final Future<void> Function(bool isIncome) onAdded;
  final String Function(ExpenseCategory) labelExpense;
  final String Function(IncomeCategory) labelIncome;
  final Expense? editExpense;
  final Income? editIncome;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _form = GlobalKey<FormState>();
  bool _isIncome = false;

  DateTime _date = DateTime.now();
  final _amountCtrl = TextEditingController();
  String _currency = 'KRW';
  ExpenseCategory _expCat = ExpenseCategory.FOOD;
  IncomeCategory _incCat = IncomeCategory.SALARY;
  final _memoCtrl = TextEditingController();
  bool _submitting = false;
  final _n = NumberFormat('#,###');

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editExpense;
    final i = widget.editIncome;
    if (e != null) {
      _isIncome = false;
      _date = DateTime(e.date.year, e.date.month, e.date.day);
      _amountCtrl.text = _n.format(e.amount.toInt());
      _currency = e.currency;
      _expCat = e.category;
      _memoCtrl.text = e.memo ?? '';
    } else if (i != null) {
      _isIncome = true;
      _date = DateTime(i.date.year, i.date.month, i.date.day);
      _amountCtrl.text = _n.format(i.amount.toInt());
      _currency = i.currency;
      _incCat = i.category;
      _memoCtrl.text = i.memo ?? '';
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
      DateTime _compose(DateTime base, {DateTime? keep}) {
        final src = keep ?? DateTime.now();
        return DateTime(base.year, base.month, base.day, src.hour, src.minute);
      }

      if (widget.editExpense != null) {
        final dt = _compose(_date, keep: widget.editExpense!.date);
        await ExpenseApi.update(
          widget.editExpense!.id,
          date: dt, // ← 날짜+시각
          amount: amount,
          currency: _currency,
          category: _expCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        );
      } else if (widget.editIncome != null) {
        final dt = _compose(_date, keep: widget.editIncome!.date);
        await IncomeApi.update(
          widget.editIncome!.id,
          date: dt,
          amount: amount,
          currency: _currency,
          category: _incCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        );
      } else if (_isIncome) {
        final dt = _compose(_date); // 신규는 현재 시각
        await IncomeApi.create(Income(
          id: '',
          date: dt,
          amount: amount,
          currency: _currency,
          category: _incCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        ));
      } else {
        final dt = _compose(_date);
        await ExpenseApi.create(Expense(
          id: '',
          date: dt,
          amount: amount,
          currency: _currency,
          category: _expCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        ));
      }

      if (mounted) Navigator.pop(context, true); // 닫히면 부모가 즉시 _reload
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnBar('저장 실패: $e'));
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
        ScaffoldMessenger.of(context).showSnackBar(SnBar('삭제 실패: $e'));
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
              child: Container(
                height: 4,
                width: 48,
                margin: const EdgeInsets.only(bottom: 12),
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
                  onSelectionChanged: (widget.editExpense != null || widget.editIncome != null)
                      ? null
                      : (s) => setState(() => _isIncome = s.first),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('yyyy-MM-dd').format(_date)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: '금액'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                TextInputFormatter.withFunction((oldV, newV) {
                  final raw = newV.text.replaceAll(',', '');
                  if (raw.isEmpty) return newV.copyWith(text: '');
                  final parsed = int.tryParse(raw);
                  if (parsed == null) return oldV;
                  final pretty = _n.format(parsed);
                  return TextEditingValue(text: pretty, selection: TextSelection.collapsed(offset: pretty.length));
                }),
              ],
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
                    .map((c) => DropdownMenuItem(value: c, child: Text(widget.labelExpense(c))))
                    .toList(),
                onChanged: (v) => setState(() => _expCat = v ?? ExpenseCategory.FOOD),
                decoration: const InputDecoration(labelText: '지출 카테고리'),
              )
            else
              DropdownButtonFormField<IncomeCategory>(
                value: _incCat,
                items: IncomeCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(widget.labelIncome(c))))
                    .toList(),
                onChanged: (v) => setState(() => _incCat = v ?? IncomeCategory.SALARY),
                decoration: const InputDecoration(labelText: '수입 카테고리'),
              ),

            const SizedBox(height: 8),
            TextFormField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '메모(선택)', hintText: '예) 점심/교통/보너스 메모'),
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
}

/* ===== 유틸 ===== */

SnackBar SnBar(String s) => SnackBar(content: Text(s));
