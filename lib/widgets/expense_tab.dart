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
      _date = e.dateTime; // ✅ date -> dateTime
      _amountCtrl.text = _n.format(e.amount.toInt());
      _currency = e.currency;
      _expCat = e.category;
      _memoCtrl.text = e.memo ?? '';
    } else if (i != null) {
      _isIncome = true;
      _date = i.dateTime; // ✅ date -> dateTime
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
        await IncomeApi.create(Income( // ✅ create 호출 부분 수정
          id: '',
          dateTime: _date,
          amount: amount,
          currency: _currency,
          category: _incCat,
          memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        ));
      } else {
        await ExpenseApi.create(Expense( // ✅ create 호출 부분 수정
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
                      _date = pickedDate.copyWith(
                        hour: pickedTime?.hour ?? _date.hour,
                        minute: pickedTime?.minute ?? _date.minute,
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