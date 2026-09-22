import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'manage_expense_categories_screen.dart';

class _AllocRow {
  String? incomeId;
  String? paymentId;
  String inputCurrency; // 'YER' أو العملة الأصلية للدفعة
  final TextEditingController amountController;

  _AllocRow({this.incomeId, this.paymentId, this.inputCurrency = baseCurrencyCode})
      : amountController = TextEditingController();

  double toYemeniAmount(double rate) {
    final entered = double.tryParse(amountController.text.trim()) ?? 0;
    if (entered <= 0) return 0;
    if (inputCurrency == baseCurrencyCode) return entered;
    return toYemeniEquivalent(entered, inputCurrency, rate);
  }

  void dispose() => amountController.dispose();
}

class AddExpenseScreen extends StatefulWidget {
  final Expense? existing;
  final String? initialIncomeId;
  final String? initialPaymentId;
  const AddExpenseScreen(
      {super.key, this.existing, this.initialIncomeId, this.initialPaymentId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = defaultExpenseCategories.first;
  DateTime _date = DateTime.now();
  String? _walletId;
  String _paymentMethod = 'cash';
  String? _personId;
  final List<_AllocRow> _allocRows = [];
  String? _allocationError;
  bool _hideDepletedIncomes = true;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toString();
      _noteController.text = e.note ?? '';
      _category = e.category;
      _date = e.date;
      _paymentMethod = e.paymentMethod ?? 'cash';
      _personId = e.personId;
      for (final alloc in e.allocations) {
        final isDebt = alloc.debtSettlementId != null;
        _allocRows.add(_AllocRow(
          incomeId: isDebt ? FinanceProvider.debtTemporaryIncomeId : alloc.incomeId,
          paymentId: isDebt ? alloc.debtSettlementId : alloc.paymentId,
        )..amountController.text = alloc.amount.toString());
      }
      if (_paymentMethod == 'cash' && _allocRows.isEmpty) {
        _allocRows.add(_AllocRow());
      }
    } else if (widget.initialIncomeId != null) {
      _allocRows.add(_AllocRow(
        incomeId: widget.initialIncomeId,
        paymentId: widget.initialPaymentId,
      ));
    } else {
      if (_paymentMethod == 'cash' && _allocRows.isEmpty) {
        _allocRows.add(_AllocRow());
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (final row in _allocRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: AppTheme.theme.copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.expenseRed,
            surface: AppTheme.card,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _date = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _addRow() {
    setState(() {
      _allocRows.add(_AllocRow());
      _allocationError = null;
    });
  }

  void _removeRow(int index) {
    setState(() {
      _allocRows[index].dispose();
      _allocRows.removeAt(index);
      _allocationError = null;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _allocationError = null);

    final totalAmount = MoneyValue.parseInput(_amountController.text.trim())
        .minorUnits
        .toDouble();
    if (_paymentMethod == 'debt') {
      if (_personId == null) {
        setState(() => _allocationError = 'اختر الدائن (المورد أو التاجر)');
        return;
      }
      final provider = context.read<FinanceProvider>();
      final expenseId = widget.existing?.id ?? const Uuid().v4();
      final expense = widget.existing ?? Expense(
        id: expenseId,
        title: _titleController.text.trim(),
        amount: totalAmount,
        date: _date,
        category: _category,
      );
      expense
        ..title = _titleController.text.trim()
        ..amount = totalAmount
        ..date = _date
        ..category = _category
        ..note = _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim()
        ..paymentMethod = 'debt'
        ..personId = _personId
        ..currency = baseCurrencyCode
        ..exchangeRate = 1.0
        ..allocations = [];
      if (widget.existing == null) {
        provider.addExpense(expense);
      } else {
        provider.updateExpense(expense);
      }
      Navigator.pop(context);
      return;
    }

    double allocatedSum = 0;
    final allocations = <ExpenseAllocation>[];
    final paymentIds = <String>{};

    for (final row in _allocRows) {
      if (row.incomeId == null) {
        setState(() => _allocationError = 'اختر إيراداً لكل استقطاع');
        return;
      }
      if (row.paymentId == null) {
        setState(() => _allocationError = 'اختر دفعة استلام لكل استقطاع');
        return;
      }
      if (!paymentIds.add(row.paymentId!)) {
        setState(() =>
            _allocationError = 'لا يمكن استقطاع من نفس دفعة الاستلام مرتين في المصروف الواحد');
        return;
      }
      final enteredVal = MoneyValue.tryParse(row.amountController.text.trim());
      if (enteredVal == null || enteredVal <= 0) {
        setState(() => _allocationError = 'أدخل مبلغاً صحيحاً لكل استقطاع');
        return;
      }

      final prov = context.read<FinanceProvider>();
      final isDebt = row.incomeId == FinanceProvider.debtTemporaryIncomeId;
      final payment = isDebt ? null : prov.incomePayments.firstWhereOrNull((p) => p.id == row.paymentId);
      final source = isDebt ? prov.debtFundingSources.firstWhereOrNull((s) => s.id == row.paymentId) : null;
      final payCurrency = (isDebt ? source?.currency : payment?.currency) ?? baseCurrencyCode;
      final payRate = (isDebt ? source?.exchangeRate : payment?.exchangeRate) ?? 1.0;

      final double valInYemeni = row.inputCurrency == baseCurrencyCode
          ? enteredVal
          : toYemeniEquivalent(enteredVal, row.inputCurrency, payRate);

      allocatedSum += valInYemeni;
      if (isDebt) {
        allocations.add(ExpenseAllocation(
          incomeId: '',
          paymentId: null,
          debtSettlementId: row.paymentId,
          debtId: source?.debtId,
          amount: valInYemeni,
          currency: payCurrency,
        ));
      } else {
        allocations.add(ExpenseAllocation(
          incomeId: row.incomeId!,
          paymentId: row.paymentId,
          amount: valInYemeni,
          currency: payCurrency,
        ));
      }
    }

    if (allocations.isEmpty) {
      setState(() => _allocationError = 'أضف استقطاعاً واحداً على الأقل');
      return;
    }

    if ((allocatedSum - totalAmount).abs() > 0.01) {
      setState(() =>
          _allocationError = 'مجموع المبالغ ($allocatedSum) لا يساوي مبلغ المصروف ($totalAmount)');
      return;
    }

    final provider = context.read<FinanceProvider>();

    final usedByPayment = <String, double>{};
    for (final a in allocations) {
      final idKey = a.debtSettlementId ?? a.paymentId!;
      final used = (usedByPayment[idKey] ?? 0) + a.amount;
      usedByPayment[idKey] = used;
      final available = a.debtSettlementId != null
          ? provider.debtFundingAvailable(a.debtSettlementId!,
              excludeExpenseId: widget.existing?.id)
          : provider.paymentAvailable(a.paymentId!,
              excludeExpenseId: widget.existing?.id);
      if (used > available + 0.001) {
        final prov = context.read<FinanceProvider>();
        final payment = prov.incomePayments.firstWhereOrNull((p) => p.id == a.paymentId);
        final source = prov.debtFundingSources.firstWhereOrNull((s) => s.id == a.debtSettlementId);
        final rate = payment?.exchangeRate ?? source?.exchangeRate ?? 1.0;
        final curr = a.currency;
        final currStr = currencyLabel(curr);
        final availInCurr = (curr == baseCurrencyCode || rate <= 0)
            ? available
            : fromYemeniEquivalent(available, curr, rate);
        final errText = curr == baseCurrencyCode
            ? 'المبلغ يتجاوز المتاح في الدفعة (${available.formatted} ر.ي)'
            : 'المبلغ يتجاوز المتاح في الدفعة (${availInCurr.formatted} $currStr / ${available.formatted} ر.ي)';
        setState(() => _allocationError = errText);
        return;
      }
    }

    String expCurrency = baseCurrencyCode;
    double expRate = 1.0;
    final nonBaseCurrs = allocations.where((a) => a.currency != baseCurrencyCode).map((a) => a.currency).toSet();
    if (nonBaseCurrs.length == 1) {
      expCurrency = nonBaseCurrs.first;
      final alloc = allocations.firstWhere((a) => a.currency == expCurrency);
      final payment = provider.incomePayments.firstWhereOrNull((p) => p.id == alloc.paymentId);
      final source = provider.debtFundingSources.firstWhereOrNull((s) => s.id == alloc.debtSettlementId);
      expRate = (payment?.exchangeRate ?? source?.exchangeRate) ?? 1.0;
    }

    if (widget.existing != null) {
      widget.existing!
        ..title = _titleController.text.trim()
        ..amount = totalAmount
        ..date = _date
        ..category = _category
        ..note = _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim()
          ..paymentMethod = 'cash'
          ..personId = null
        ..currency = expCurrency
        ..exchangeRate = expRate
        ..allocations = allocations;
      provider.updateExpense(widget.existing!);
    } else {
      final newExpense = Expense(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        amount: totalAmount,
        date: _date,
        category: _category,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
          paymentMethod: 'cash',
        currency: expCurrency,
        exchangeRate: expRate,
        allocations: allocations,
      );
      provider.addExpense(newExpense);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'إضافة مصروف' : 'تعديل المصروف'),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final categoriesSet = <String>{};
          for (final c in provider.expenseCategories) {
            final trimmed = c.name.trim();
            if (trimmed.isNotEmpty) categoriesSet.add(trimmed);
          }
          if (categoriesSet.isEmpty) {
            categoriesSet.addAll(defaultExpenseCategories);
          }
          final categories = categoriesSet.toList();
          if (!categories.contains(_category)) {
            _category = categories.isNotEmpty ? categories.first : defaultExpenseCategories.first;
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'اسم المصروف *',
                    hintText: 'مثال: فاتورة كهرباء',
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'أدخل اسماً' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      color: AppTheme.expenseRed,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'المبلغ *',
                    hintText: '0.00',
                    prefixIcon:
                        Icon(Icons.attach_money, color: AppTheme.expenseRed),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل المبلغ';
                    if (double.tryParse(v) == null) return 'مبلغ غير صحيح';
                    if (double.parse(v) <= 0) return 'يجب أن يكون أكبر من صفر';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categories.contains(_category) ? _category : (categories.isNotEmpty ? categories.first : null),
                  decoration: InputDecoration(
                    labelText: 'التصنيف',
                    prefixIcon: const Icon(Icons.category),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.settings, size: 18),
                      tooltip: 'إدارة التصنيفات',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ManageExpenseCategoriesScreen()),
                        );
                      },
                    ),
                  ),
                  style: TextStyle(color: AppTheme.textPrimary),
                  items: categories
                      .toSet()
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'التاريخ',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('EEEE، dd MMMM yyyy - hh:mm a', 'ar').format(_date),
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    hintText: 'أي تفاصيل إضافية...',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'cash',
                      label: Text('نقداً'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: 'debt',
                      label: Text('آجل'),
                      icon: Icon(Icons.receipt_long_outlined),
                    ),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (value) => setState(() {
                    _paymentMethod = value.first;
                    _allocationError = null;
                    if (_paymentMethod == 'cash') {
                      _personId = null;
                      if (_allocRows.isEmpty) {
                        _allocRows.add(_AllocRow());
                      }
                    }
                  }),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
                if (_paymentMethod == 'debt') ...[
                  DropdownButtonFormField<String>(
                    value: provider.partners.any((p) => p.id == _personId) ? _personId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الدائن (المورد / التاجر / الشخص) *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    style: TextStyle(color: AppTheme.textPrimary),
                    items: provider.partners
                        .map((person) => DropdownMenuItem(
                              value: person.id,
                              child: Text(person.name),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _personId = value),
                    validator: (value) => _paymentMethod == 'debt' && value == null
                        ? 'اختر الدائن'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                Consumer<FinanceProvider>(
                  builder: (context, provider, _) {
                    if (_paymentMethod == 'debt') return const SizedBox.shrink();
                    if (provider.wallets.isEmpty) {
                      return Text('لا توجد محافظ، أنشئ محفظة أولاً',
                          style: TextStyle(color: AppTheme.expenseRed));
                    }
                    final validWalletId = provider.wallets.any((w) => w.id == _walletId) ? _walletId : null;
                    return DropdownButtonFormField<String>(
                      value: validWalletId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'المحفظة (اختياري)',
                        hintText: 'تصفية الدفعات حسب المحفظة',
                        prefixIcon: Icon(Icons.wallet),
                      ),
                      style: TextStyle(color: AppTheme.textPrimary),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('جميع المحافظ',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 14)),
                        ),
                        ...provider.wallets
                            .map((w) => DropdownMenuItem(
                                value: w.id, child: Text(w.name))),
                      ],
                      onChanged: (v) => setState(() {
                        _walletId = v;
                        if (v != null) {
                          for (final row in _allocRows) {
                            if (row.incomeId == FinanceProvider.debtTemporaryIncomeId) {
                              final source = provider.debtFundingSources
                                  .firstWhereOrNull((s) => s.id == row.paymentId);
                              if (source != null && source.walletId != v) {
                                row.incomeId = null;
                                row.paymentId = null;
                                row.amountController.clear();
                              }
                              continue;
                            }
                            IncomePayment? pay;
                            String? payWalletId;
                            if (row.paymentId != null) {
                              for (final income in provider.incomes) {
                                pay = income.payments.firstWhereOrNull(
                                    (p) => p.id == row.paymentId);
                                if (pay != null) {
                                  // المحفظة تُستمد من إيراد الدفعة الأب
                                  payWalletId = income.walletId;
                                  break;
                                }
                              }
                            }
                            final belongs =
                                pay != null && payWalletId == v;
                            if (!belongs) {
                              row.incomeId = null;
                              row.paymentId = null;
                              row.amountController.clear();
                            }
                          }
                        }
                        _allocationError = null;
                      }),
                    );
                  },
                ),
                if (_paymentMethod == 'cash') ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    Icon(Icons.account_balance_rounded,
                        color: AppTheme.accentBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('استقطاع من الإيرادات',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                    InkWell(
                      onTap: () => setState(() => _hideDepletedIncomes = !_hideDepletedIncomes),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hideDepletedIncomes ? Icons.filter_alt : Icons.filter_alt_off_outlined,
                              size: 14,
                              color: _hideDepletedIncomes ? AppTheme.accentBlue : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _hideDepletedIncomes ? 'إخفاء المستنفدة' : 'عرض الكل',
                              style: TextStyle(
                                color: _hideDepletedIncomes ? AppTheme.accentBlue : AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('إضافة'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('اختر الإيراد وحدد المبلغ المستقطع',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                if (_allocRows.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder, style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: Text('اضغط "إضافة" لاختيار إيراد',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  )
                else
                  ...List.generate(_allocRows.length, (index) {
                    final row = _allocRows[index];
                    Income? getDebtIncome() {
                      final debtSources = provider.debtFundingSources.where((s) {
                        if (_walletId != null && s.walletId != _walletId) return false;
                        return true;
                      }).toList();
                      if (debtSources.isEmpty) return null;

                      final debtPayments = debtSources.map((s) {
                        final debt = provider.personalDebts.firstWhereOrNull((d) => d.id == s.debtId);
                        final person = provider.partners.firstWhereOrNull((p) => p.id == debt?.personId);
                        final personName = person?.name ?? '';
                        final noteText = s.note != null && s.note!.isNotEmpty ? ' (${s.note})' : '';
                        final desc = s.isSettlement
                            ? (personName.isNotEmpty ? 'استلام دين من $personName$noteText' : 'استلام دفعة دين$noteText')
                            : (personName.isNotEmpty ? 'اقتراض واستلام دين من $personName$noteText' : 'استلام مبلغ دين$noteText');
                        return IncomePayment(
                          id: s.id,
                          incomeId: FinanceProvider.debtTemporaryIncomeId,
                          amount: s.amount,
                          date: s.date,
                          notes: desc,
                          walletId: s.walletId,
                          currency: s.currency,
                          exchangeRate: s.exchangeRate,
                        );
                      }).toList();

                      final debtIncome = Income(
                        id: FinanceProvider.debtTemporaryIncomeId,
                        title: 'الديون المستلمة (تمويل مؤقت)',
                        amount: debtPayments.fold(0.0, (sum, p) => sum + p.amount),
                        date: debtPayments.first.date,
                        source: 'تمويل مؤقت',
                        status: 'confirmed',
                        walletId: _walletId,
                        currency: baseCurrencyCode,
                      );
                      debtIncome.setPayments(debtPayments);
                      return debtIncome;
                    }

                    final debtIncome = getDebtIncome();
                    final allIncomes = List<Income>.from(provider.incomes);
                    if (debtIncome != null) {
                      allIncomes.add(debtIncome);
                    }

                    double shownAvailableFor(IncomePayment p) {
                      final othersUsed = _allocRows.asMap().entries
                          .where((e) =>
                              e.key != index && e.value.paymentId == p.id)
                          .fold(
                              0.0,
                              (s, e) =>
                                  s + e.value.toYemeniAmount(p.exchangeRate));
                      final rawAvail = p.incomeId == FinanceProvider.debtTemporaryIncomeId
                          ? provider.debtFundingAvailable(p.id, excludeExpenseId: widget.existing?.id)
                          : provider.paymentAvailable(p.id, excludeExpenseId: widget.existing?.id);
                      return (rawAvail - othersUsed)
                          .clamp(0.0, double.infinity);
                    }

                    Map<String, double> incomeShownAvailableByCurrency(Income i) {
                      if (i.id != FinanceProvider.debtTemporaryIncomeId && _walletId != null && i.walletId != _walletId) {
                        return {};
                      }
                      final map = <String, double>{};
                      for (final p in i.payments) {
                        if (_allocRows.any((other) =>
                            other != row && other.paymentId == p.id)) {
                          continue;
                        }
                        if (_walletId != null && p.walletId != null && p.walletId != _walletId) {
                          continue;
                        }
                        final rawAvail = i.id == FinanceProvider.debtTemporaryIncomeId
                            ? provider.debtFundingAvailable(p.id, excludeExpenseId: widget.existing?.id)
                            : provider.paymentAvailable(p.id, excludeExpenseId: widget.existing?.id);
                        final availYer = rawAvail.clamp(0.0, double.infinity);
                        if (availYer > 0.001) {
                          final availInCurr = (p.currency == baseCurrencyCode || p.exchangeRate <= 0)
                              ? availYer
                              : fromYemeniEquivalent(availYer, p.currency, p.exchangeRate);
                          map[p.currency] = (map[p.currency] ?? 0.0) + availInCurr;
                        }
                      }
                      return map;
                    }

                    String formatIncomeAvailable(Income i) {
                      final map = incomeShownAvailableByCurrency(i);
                      if (map.isEmpty) return 'المتاح: 0';
                      final parts = map.entries
                          .map((e) => '${e.value.formatted} ${currencyLabel(e.key)}')
                          .join(' + ');
                      return 'المتاح: $parts';
                    }

                    final availableIncomes = allIncomes.where((i) {
                      if (i.id == row.incomeId) return true;
                      final existingValid = widget.existing?.allocations
                              .any((a) =>
                                  (a.incomeId == i.id) ||
                                  (i.id == FinanceProvider.debtTemporaryIncomeId &&
                                       a.debtSettlementId != null)) ==
                          true;
                      final hasAvail = incomeShownAvailableByCurrency(i).values.any((v) => v > 0.001);
                      if (_hideDepletedIncomes && !existingValid) {
                        return hasAvail;
                      }
                      return hasAvail || existingValid;
                    }).toList();

                    final selectedIncome = row.incomeId != null
                        ? (row.incomeId == FinanceProvider.debtTemporaryIncomeId
                            ? debtIncome
                            : provider.incomes.firstWhereOrNull(
                                (i) => i.id == row.incomeId))
                        : null;

                    final paymentIds = selectedIncome != null
                        ? selectedIncome.payments.where((p) {
                            // الدفعة المختارة حالياً في هذا الصف تبقى ظاهرة
                            if (p.id == row.paymentId) return true;
                            // منع اختيار دفعة مستخدمة بالفعل في صف استقطاع آخر
                            if (_allocRows.any((other) =>
                                other != row &&
                                other.paymentId == p.id)) {
                              return false;
                            }
                            // فلترة حسب المحفظة عند اختيارها
                            if (_walletId != null) {
                              final wid = p.walletId ?? selectedIncome.walletId;
                              if (wid != null && wid != _walletId) return false;
                            }
                            // عند تعديل مصروف نُبقي دفعاته المرتبطة فقط إن كان لها متاح
                            if (widget.existing?.allocations
                                    .any((a) => a.paymentId == p.id || a.debtSettlementId == p.id) ==
                                true) {
                              return shownAvailableFor(p) > 0.001;
                            }
                            return shownAvailableFor(p) > 0.001;
                          }).toList()
                        : <IncomePayment>[];

                    final selectedPayment = paymentIds.firstWhereOrNull((p) => p.id == row.paymentId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                   child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: availableIncomes.any((i) => i.id == row.incomeId) ? row.incomeId : null,
                                      isExpanded: true,
                                      hint: Text('اختر الإيراد',
                                          style: TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 13)),
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13),
                                      items: availableIncomes
                                          .map((i) {
                                            final isPos = incomeShownAvailableByCurrency(i).values.any((v) => v > 0.001);
                                            final availText = formatIncomeAvailable(i);
                                            return DropdownMenuItem(
                                              value: i.id,
                                              child: Text(
                                                '${isPos ? "🟢 " : "⚪ "}${i.title} ($availText)',
                                                style: TextStyle(
                                                  color: isPos ? AppTheme.textPrimary : AppTheme.textMuted,
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(),
                                      onChanged: (v) => setState(() {
                                        row.incomeId = v;
                                        row.paymentId = null;
                                        _allocationError = null;
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _removeRow(index),
                                icon: Icon(Icons.remove_circle_outline,
                                    color: AppTheme.expenseRed, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: paymentIds.any((p) => p.id == row.paymentId) ? row.paymentId : null,
                                isExpanded: true,
                                hint: Text('اختر الدفعة المستلمة',
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 13)),
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13),
                                items: paymentIds
                                    .map((p) {
                                      final availYer = shownAvailableFor(p);
                                      final isPos = availYer > 0.001;
                                      final availInCurr = (p.currency == baseCurrencyCode || p.exchangeRate <= 0)
                                          ? availYer
                                          : fromYemeniEquivalent(availYer, p.currency, p.exchangeRate);
                                      final dateStr = DateFormat('dd MMM yyyy', 'ar').format(p.date);
                                      final currStr = currencyLabel(p.currency);
                                      final availStr = p.currency == baseCurrencyCode
                                          ? '${availYer.formatted} $currStr'
                                          : '${availInCurr.formatted} $currStr (يعادل ${availYer.formatted} ر.ي)';
                                      final label = p.incomeId == FinanceProvider.debtTemporaryIncomeId
                                          ? '${isPos ? "🟢 " : "⚪ "}${p.notes ?? "استلام دين"} · $dateStr · متاح: $availStr'
                                          : '${isPos ? "🟢 " : "⚪ "}دفعة $dateStr · متاح: $availStr';
                                      return DropdownMenuItem(
                                        value: p.id,
                                        child: Text(
                                            label,
                                            style: TextStyle(
                                              color: isPos ? AppTheme.textPrimary : AppTheme.textMuted,
                                            ),
                                          ),
                                        );
                                    })
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  row.paymentId = v;
                                  final newP = paymentIds.firstWhereOrNull((p) => p.id == v);
                                  if (newP != null) {
                                    if (row.inputCurrency != baseCurrencyCode && row.inputCurrency != newP.currency) {
                                      row.inputCurrency = newP.currency;
                                    }
                                  } else {
                                    row.inputCurrency = baseCurrencyCode;
                                  }
                                  _allocationError = null;
                                }),
                              ),
                            ),
                          ),
                          if (row.paymentId != null && selectedPayment != null) ...[
                            const SizedBox(height: 6),
                            Builder(
                              builder: (_) {
                                final pAvailYer = shownAvailableFor(selectedPayment);
                                final pAvailInCurr = (selectedPayment.currency == baseCurrencyCode || selectedPayment.exchangeRate <= 0)
                                    ? pAvailYer
                                    : fromYemeniEquivalent(pAvailYer, selectedPayment.currency, selectedPayment.exchangeRate);
                                final currStr = currencyLabel(selectedPayment.currency);
                                final availText = selectedPayment.currency == baseCurrencyCode
                                    ? 'المتاح في هذه الدفعة: ${pAvailYer.formatted} $currStr'
                                    : 'المتاح في هذه الدفعة: ${pAvailInCurr.formatted} $currStr (يعادل ${pAvailYer.formatted} ر.ي)';
                                return Row(
                                  children: [
                                    Icon(
                                      pAvailYer > 0 ? Icons.check_circle_outline : Icons.info_outline,
                                      size: 14,
                                      color: pAvailYer > 0 ? AppTheme.incomeGreen : AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        availText,
                                        style: TextStyle(
                                          color: pAvailYer > 0 ? AppTheme.incomeGreen : AppTheme.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (pAvailYer > 0)
                                      Builder(
                                        builder: (_) {
                                          final payCurrency = selectedPayment.currency;
                                          final payRate = selectedPayment.exchangeRate;
                                          final isForeign = payCurrency != baseCurrencyCode;

                                          final totalExp = double.tryParse(_amountController.text.trim()) ?? 0;
                                          final otherRowsSum = _allocRows.asMap().entries
                                              .where((e) => e.key != index)
                                              .fold(0.0, (s, e) {
                                                final oRow = e.value;
                                                final oProv = context.read<FinanceProvider>();
                                                final oIsDebt = oRow.incomeId == FinanceProvider.debtTemporaryIncomeId;
                                                final oPayment = oIsDebt ? null : oProv.incomePayments.firstWhereOrNull((p) => p.id == oRow.paymentId);
                                                final oSource = oIsDebt ? oProv.debtFundingSources.firstWhereOrNull((s) => s.id == oRow.paymentId) : null;
                                                final oRate = (oIsDebt ? oSource?.exchangeRate : oPayment?.exchangeRate) ?? 1.0;
                                                return s + oRow.toYemeniAmount(oRate);
                                              });
                                          final remainingNeeded = totalExp > 0 ? (totalExp - otherRowsSum) : 0.0;
                                          final bool coversFull = remainingNeeded > 0 && pAvailYer >= remainingNeeded;
                                          final String buttonLabel = coversFull
                                              ? 'استقطاع كامل المبلغ'
                                              : (remainingNeeded > 0 && pAvailYer < remainingNeeded)
                                                  ? 'استقطاع المتاح (${pAvailYer.formatted} ر.ي)'
                                                  : 'استقطاع كامل المبلغ';
                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                final tExp = double.tryParse(_amountController.text.trim()) ?? 0;
                                                final oSum = _allocRows.asMap().entries
                                                    .where((e) => e.key != index)
                                                    .fold(0.0, (s, e) {
                                                      final oRow = e.value;
                                                      final oProv = context.read<FinanceProvider>();
                                                      final oIsDebt = oRow.incomeId == FinanceProvider.debtTemporaryIncomeId;
                                                      final oPayment = oIsDebt ? null : oProv.incomePayments.firstWhereOrNull((p) => p.id == oRow.paymentId);
                                                      final oSource = oIsDebt ? oProv.debtFundingSources.firstWhereOrNull((s) => s.id == oRow.paymentId) : null;
                                                      final oRate = (oIsDebt ? oSource?.exchangeRate : oPayment?.exchangeRate) ?? 1.0;
                                                      return s + oRow.toYemeniAmount(oRate);
                                                    });
                                                final rem = tExp > 0 ? (tExp - oSum) : 0.0;
                                                final needed = rem > 0 ? rem.clamp(0.0, pAvailYer) : pAvailYer;
                                                final fillValYer = needed > 0 ? needed : pAvailYer;

                                                if (row.inputCurrency == baseCurrencyCode || !isForeign || payRate <= 0) {
                                                  row.amountController.text = fillValYer.plain;
                                                } else {
                                                  final inOrig = fromYemeniEquivalent(fillValYer, payCurrency, payRate);
                                                  row.amountController.text = inOrig.plain;
                                                }
                                                _allocationError = null;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentBlue.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.bolt, size: 13, color: AppTheme.accentBlue),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    buttonLabel,
                                                    style: TextStyle(
                                                      color: AppTheme.accentBlue,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final payCurrency = selectedPayment?.currency ?? baseCurrencyCode;
                              final payRate = selectedPayment?.exchangeRate ?? 1.0;
                              final isForeign = payCurrency != baseCurrencyCode;
                              final activeCurr = row.inputCurrency;
                              final activeCurrLabel = currencyLabel(activeCurr);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: row.amountController,
                                          keyboardType: const TextInputType.numberWithOptions(
                                              decimal: true),
                                          style: TextStyle(
                                              color: AppTheme.accentBlue,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600),
                                          onChanged: (_) => setState(() {
                                            _allocationError = null;
                                          }),
                                          decoration: InputDecoration(
                                            labelText: isForeign
                                                ? 'المبلغ المستقطع ($activeCurrLabel)'
                                                : 'المبلغ المستقطع (بالريال اليمني)',
                                            hintText: 'المبلغ المستقطع',
                                            prefixIcon: Icon(Icons.attach_money,
                                                color: AppTheme.accentBlue),
                                            suffixText: activeCurrLabel,
                                            suffixStyle:
                                                TextStyle(color: AppTheme.textMuted),
                                          ),
                                        ),
                                      ),
                                      if (isForeign) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          height: 56,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.card,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppTheme.cardBorder),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: (activeCurr == baseCurrencyCode || activeCurr == payCurrency)
                                                  ? activeCurr
                                                  : baseCurrencyCode,
                                              icon: Icon(Icons.arrow_drop_down, color: AppTheme.accentBlue),
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              items: [
                                                DropdownMenuItem(
                                                  value: baseCurrencyCode,
                                                  child: Text(
                                                    'ر.ي (يمني)',
                                                    style: TextStyle(
                                                      color: activeCurr == baseCurrencyCode
                                                          ? AppTheme.accentBlue
                                                          : AppTheme.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: payCurrency,
                                                  child: Text(
                                                    '${currencyLabel(payCurrency)} (أصل الدفعة)',
                                                    style: TextStyle(
                                                      color: activeCurr == payCurrency
                                                          ? AppTheme.accentBlue
                                                          : AppTheme.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (newCurr) {
                                                if (newCurr == null || newCurr == activeCurr) return;
                                                setState(() {
                                                  final currentVal = double.tryParse(row.amountController.text.trim()) ?? 0;
                                                  if (currentVal > 0 && payRate > 0) {
                                                    if (newCurr == baseCurrencyCode) {
                                                      // تحويل من العملة الأجنبية إلى الريال اليمني
                                                      final inYer = toYemeniEquivalent(currentVal, payCurrency, payRate);
                                                      row.amountController.text = inYer.plain;
                                                    } else {
                                                      // تحويل من الريال اليمني إلى العملة الأجنبية
                                                      final inOrig = fromYemeniEquivalent(currentVal, payCurrency, payRate);
                                                      row.amountController.text = inOrig.plain;
                                                    }
                                                  }
                                                  row.inputCurrency = newCurr;
                                                  _allocationError = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (selectedPayment != null)
                                    Builder(
                                      builder: (_) {
                                        final pAvailYer = shownAvailableFor(selectedPayment);
                                        final pAvailInCurr = (!isForeign || payRate <= 0)
                                            ? pAvailYer
                                            : fromYemeniEquivalent(pAvailYer, payCurrency, payRate);
                                        final currStr = currencyLabel(payCurrency);
                                        final enteredVal = double.tryParse(row.amountController.text.trim()) ?? 0;
                                        final enteredInYer = row.inputCurrency == baseCurrencyCode
                                            ? enteredVal
                                            : toYemeniEquivalent(enteredVal, payCurrency, payRate);

                                        if (enteredInYer > pAvailYer + 0.001) {
                                          final warningText = !isForeign
                                              ? 'تنبيه: المبلغ المدخل (${enteredVal.formatted} ر.ي) يتجاوز المتاح في الدفعة (${pAvailYer.formatted} ر.ي)'
                                              : (row.inputCurrency == baseCurrencyCode
                                                  ? 'تنبيه: المبلغ المدخل (${enteredVal.formatted} ر.ي) يتجاوز المتاح في الدفعة (${pAvailInCurr.formatted} $currStr / ${pAvailYer.formatted} ر.ي)'
                                                  : 'تنبيه: المبلغ المدخل (${enteredVal.formatted} $currStr) يتجاوز المتاح في الدفعة (${pAvailInCurr.formatted} $currStr / ${pAvailYer.formatted} ر.ي)');
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.expenseRed),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    warningText,
                                                    style: TextStyle(
                                                      color: AppTheme.expenseRed,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        if (isForeign && enteredVal > 0) {
                                          if (row.inputCurrency == baseCurrencyCode) {
                                            final origEquiv = fromYemeniEquivalent(enteredVal, payCurrency, payRate);
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'يعادل: ${origEquiv.formatted} $currStr بالعملة الأصلية (بسعر صرف ${payRate.formatted})',
                                                style: TextStyle(
                                                  color: AppTheme.accentBlue,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          } else {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'يعادل: ${enteredInYer.formatted} ر.ي (بسعر صرف ${payRate.formatted})',
                                                style: TextStyle(
                                                  color: AppTheme.accentBlue,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                                if (_allocationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_allocationError!,
                        style: TextStyle(
                            color: AppTheme.expenseRed, fontSize: 13)),
                  ),
                if (_allocRows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('إضافة استقطاع آخر'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      side: BorderSide(color: AppTheme.accentBlue),
                    ),
                  ),
                ],
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.expenseRed,
                        foregroundColor: Colors.white),
                    child: Text(widget.existing == null
                        ? 'حفظ المصروف'
                        : 'تحديث'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
