import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'providers/finance_provider.dart';
import 'models/models.dart';
import 'theme.dart';

Widget fieldLabel(String text) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                color: context.dynamicTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );

/// Dropdown field for use inside modal bottom sheets.
///
/// Replaces the native [DropdownButton]/[DropdownButtonFormField] which is
/// broken inside bottom sheets (Flutter issue #46676): the menu is positioned
/// while the keyboard is open, and when the keyboard closes the sheet drops
/// while the menu stays detached from the field. This widget dismisses the
/// keyboard first, waits for the sheet to settle, then opens a menu anchored
/// to the field so it always stays adjacent to it.
class SheetDropdown<T> extends StatefulWidget {
  const SheetDropdown({
    super.key,
    this.hint,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.icon,
    this.iconColor,
    this.labelAlways = false,
    this.labelAbove = false,
    this.error = false,
  });

  final T? value;
  final String? hint;
  final String? label;
  final IconData? icon;
  final Color? iconColor;

  /// Always shown floating above the field (unlike [label] which only floats
  /// once a value is selected and sits inside the field otherwise).
  final bool labelAlways;

  /// Renders [label] as a small text above the field instead of inside it.
  final bool labelAbove;

  /// Colors the border red when true.
  final bool error;

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  State<SheetDropdown<T>> createState() => _SheetDropdownState<T>();
}

class _SheetDropdownState<T> extends State<SheetDropdown<T>> {
  bool _opening = false;

  Future<void> _openMenu() async {
    if (_opening) return;
    _opening = true;
    try {
      if (MediaQuery.viewInsetsOf(context).bottom > 0) {
        FocusManager.instance.primaryFocus?.unfocus();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!mounted) return;
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      final box = context.findRenderObject() as RenderBox?;
      if (overlay == null || box == null) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final position = RelativeRect.fromRect(rect, Offset.zero & overlay.size);
      if (widget.items.any((i) => i.value == null)) {
        final sentinel = Object();
        final picked = await showMenu<Object>(
          context: context,
          position: position,
          initialValue: widget.value,
          color: context.dynamicCardBg,
          elevation: 8,
          items: [
            for (final i in widget.items)
              PopupMenuItem<Object>(
                value: i.value ?? sentinel,
                enabled: i.enabled,
                child: DefaultTextStyle(
                  style: TextStyle(
                      color: context.dynamicTextPrimary, fontSize: 14),
                  child: i.child,
                ),
              ),
          ],
        );
        if (!mounted || picked == null) return;
        widget.onChanged(picked == sentinel ? null : picked as T);
      } else {
        final picked = await showMenu<T>(
          context: context,
          position: position,
          initialValue: widget.value,
          color: context.dynamicCardBg,
          elevation: 8,
          items: [
            for (final i in widget.items)
              PopupMenuItem<T>(
                value: i.value,
                enabled: i.enabled,
                child: DefaultTextStyle(
                  style: TextStyle(
                      color: context.dynamicTextPrimary, fontSize: 14),
                  child: i.child,
                ),
              ),
          ],
        );
        if (!mounted || picked == null) return;
        widget.onChanged(picked);
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    DropdownMenuItem<T>? selectedItem;
    if (hasValue) {
      for (final item in widget.items) {
        if (item.value == widget.value) {
          selectedItem = item;
          break;
        }
      }
    }
    final showLabel =
        widget.label != null && (widget.labelAlways || hasValue);
    final placeholder = widget.label != null && !widget.labelAlways
        ? widget.label!
        : (widget.hint ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelAbove) fieldLabel(widget.label!),
        GestureDetector(
          onTap: _openMenu,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.dynamicSurfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.error ? context.dynamicExpenseRed : context.dynamicCardBorder,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.iconColor ?? context.dynamicTextMuted, size: 18),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: selectedItem != null
                          ? DefaultTextStyle(
                              style: TextStyle(
                                  color: context.dynamicTextPrimary, fontSize: 14),
                              child: selectedItem.child,
                            )
                          : Text(
                              placeholder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.dynamicTextMuted, fontSize: 14),
                            ),
                    ),
                    Icon(Icons.arrow_drop_down,
                        color: context.dynamicTextPrimary),
                  ],
                ),
                if (showLabel)
                  Positioned(
                    right: 12,
                    top: -8,
                    child: Container(
                      color: context.dynamicSurfaceBg,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.label!,
                        style: TextStyle(
                            color: context.dynamicTextMuted, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// اختيار مصدر تمويل عملية صرف من دفعات الاستلام (الدفع المستلم من الإيرادات).
/// يُظهر صفوفاً: إيراد → دفعة استلام → مبلغ. مجموع المبالغ يجب أن يغطي الصرف.
class FundingPicker extends StatefulWidget {
  const FundingPicker({
    required this.provider,
    GlobalKey<FundingPickerState>? pickerKey,
    this.walletFilter,
    this.requiredTotal = 0,
    this.requiredTotalGetter,
    this.autoAmount,
  }) : super(key: pickerKey);

  final FinanceProvider provider;

  /// في حال تحديد المحفظة، نعرض فقط الدفعات المستلمة داخلها.
  final String? walletFilter;

  /// المبلغ الذي يجب أن يغطيه التمويل (لإظهار الخطأ عند عدم تطابق المجموع).
  final double requiredTotal;

  /// دالة ديناميكية لجلب المبلغ المطلوب تغطيته في أي لحظة.
  final double Function()? requiredTotalGetter;

  /// عند اختيار صف تمويل، نملأ حقل المبلغ تلقائياً بهذه القيمة
  /// (إن لم يدخل المستخدم مبلغاً بعد).
  final double? autoAmount;

  @override
  State<FundingPicker> createState() => FundingPickerState();
}

class FundingPickerState extends State<FundingPicker> {
  static const _debtGroupId = FinanceProvider.debtTemporaryIncomeId;
  final List<_FundingRow> _rows = [_FundingRow()];
  String? _error;
  bool _hideDepleted = true;

  double get _effectiveRequiredTotal {
    if (widget.requiredTotalGetter != null) {
      try {
        final v = widget.requiredTotalGetter!();
        if (v > 0) return v;
      } catch (_) {}
    }
    return widget.requiredTotal;
  }

  @override
  void didUpdateWidget(covariant FundingPicker old) {
    super.didUpdateWidget(old);
    if (old.walletFilter != widget.walletFilter) {
      for (final r in _rows) {
        r.incomeId = null;
        r.paymentId = null;
      }
    }
  }

  /// دفعات الإيرادات الحقيقية المتاحة.
  List<IncomePayment> get _eligiblePayments {
    final incomeWallet = {
      for (final i in widget.provider.incomes) i.id: i.walletId,
    };
    bool match(IncomePayment p) {
      if (widget.walletFilter == null) return true;
      final wid = widget.provider.incomePaymentWalletId(p.id) ?? incomeWallet[p.incomeId];
      return wid == widget.walletFilter;
    }

    return widget.provider.incomePayments
        .where(match)
        .where((p) => widget.provider.paymentAvailable(p.id) > 0.001)
        .toList();
  }

  List<IncomePayment> get _eligibleDebtPayments => widget.provider
      .debtFundingSources
      .where((s) => widget.walletFilter == null || s.walletId == widget.walletFilter)
      .where((s) => widget.provider.debtFundingAvailable(s.id) > 0.001)
      .map((s) {
        final debt = widget.provider.personalDebts.firstWhereOrNull((d) => d.id == s.debtId);
        final person = widget.provider.partners.firstWhereOrNull((p) => p.id == debt?.personId);
        final personName = person?.name ?? '';
        final noteText = s.note != null && s.note!.isNotEmpty ? ' (${s.note})' : '';
        final desc = s.isSettlement
            ? (personName.isNotEmpty ? 'استلام دين من $personName$noteText' : 'استلام دفعة دين$noteText')
            : (personName.isNotEmpty ? 'اقتراض واستلام دين من $personName$noteText' : 'استلام مبلغ دين$noteText');
        return IncomePayment(
          id: s.id,
          incomeId: _debtGroupId,
          amount: s.amount,
          date: s.date,
          notes: desc,
          walletId: s.walletId,
          currency: s.currency,
          exchangeRate: s.exchangeRate,
        );
      })
      .toList();

  double _available(IncomePayment payment) => payment.incomeId == _debtGroupId
      ? widget.provider.debtFundingAvailable(payment.id)
      : widget.provider.paymentAvailable(payment.id);

  List<IncomePayment> _paymentsFor(String? incomeId) {
    if (incomeId == _debtGroupId) return _eligibleDebtPayments;
    return _eligiblePayments.where((p) => p.incomeId == incomeId).toList();
  }

  List<Income> get _incomesWithPayments {
    final paymentIds = _eligiblePayments.map((p) => p.incomeId).toSet();
    final list = widget.provider.incomes
        .where((i) => paymentIds.contains(i.id))
        .toList();
    final debtPayments = _eligibleDebtPayments;
    if (debtPayments.isNotEmpty) {
      final debtIncome = Income(
        id: _debtGroupId,
        title: 'الديون المستلمة (تمويل مؤقت)',
        amount: debtPayments.fold(0.0, (sum, p) => sum + p.amount),
        date: debtPayments.first.date,
        source: 'تمويل مؤقت',
        status: 'confirmed',
      );
      debtIncome.setPayments(debtPayments);
      list.add(debtIncome);
    }
    if (_hideDepleted) {
      return list.where((i) => _incomeAvailable(i) > 0.001).toList();
    }
    return list;
  }

  Map<String, double> _incomeShownAvailableByCurrency(Income inc, _FundingRow currentRow) {
    if (widget.walletFilter != null && inc.id != _debtGroupId && inc.walletId != widget.walletFilter) {
      return {};
    }
    final usedElsewhere = {
      for (final r in _rows) if (r != currentRow) r.paymentId,
    };
    final map = <String, double>{};
    for (final p in _paymentsFor(inc.id)) {
      if (usedElsewhere.contains(p.id)) continue;
      final rawAvail = _available(p);
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

  String _formatIncomeAvailable(Income inc, _FundingRow currentRow) {
    final map = _incomeShownAvailableByCurrency(inc, currentRow);
    if (map.isEmpty) return 'المتاح: 0';
    final parts = map.entries
        .map((e) => '${e.value.formatted} ${currencyLabel(e.key)}')
        .join(' + ');
    return 'المتاح: $parts';
  }

  List<Income> _availableIncomesFor(_FundingRow currentRow) {
    return _incomesWithPayments.where((inc) {
      if (inc.id == currentRow.incomeId) return true;
      final hasAvail = _incomeShownAvailableByCurrency(inc, currentRow).values.any((v) => v > 0.001);
      if (_hideDepleted) {
        return hasAvail;
      }
      return true;
    }).toList();
  }

  double _incomeAvailable(Income inc) {
    return _paymentsFor(inc.id).fold(
      0.0, (sum, p) => sum + _available(p).clamp(0.0, double.infinity));
  }

  List<ExpenseAllocation> get allocations {
    final list = <ExpenseAllocation>[];
    for (final r in _rows) {
      if (r.paymentId == null) continue;
      final isDebt = r.incomeId == _debtGroupId;
      final payment = isDebt ? null : _paymentsFor(r.incomeId).firstWhereOrNull((p) => p.id == r.paymentId);
      final debtSource = isDebt ? widget.provider.debtFundingSources.firstWhereOrNull((s) => s.id == r.paymentId) : null;
      final rate = (isDebt ? debtSource?.exchangeRate : payment?.exchangeRate) ?? 1.0;
      final curr = (isDebt ? debtSource?.currency : payment?.currency) ?? baseCurrencyCode;
      final yemeniAmount = r.toYemeniAmount(rate);
      list.add(
        isDebt
            ? ExpenseAllocation(
                incomeId: '',
                debtSettlementId: r.paymentId,
                debtId: debtSource?.debtId,
                amount: yemeniAmount,
                currency: curr,
              )
            : ExpenseAllocation(
                incomeId: r.incomeId!,
                paymentId: r.paymentId,
                amount: yemeniAmount,
                currency: curr,
              ),
      );
    }
    return list;
  }

  double get sum =>
      allocations.fold(0.0, (s, a) => s + a.amount);

  bool validate() {
    final required = _effectiveRequiredTotal;
    if (required > 0 && (sum - required).abs() > 0.01) {
      setState(() =>
          _error = 'مجموع التمويل يجب أن يساوي المبلغ (${required.formatted} ر.ي)');
      return false;
    }
    if (_rows.any((r) => r.paymentId == null)) {
      setState(() => _error = 'اختر دفعة استلام لكل صف تمويل');
      return false;
    }
    if (_rows.any((r) => (tryParseFlexible(r.amountController.text) ?? 0) <= 0)) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً لكل صف تمويل');
      return false;
    }
    final selectedIds = _rows.map((r) => r.paymentId).whereType<String>().toList();
    if (selectedIds.length != selectedIds.toSet().length) {
      setState(() =>
          _error = 'لا يمكن الاستقطاع من نفس دفعة الاستلام أكثر من مرة');
      return false;
    }
    for (final r in _rows) {
      if (r.paymentId != null) {
        final isDebt = r.incomeId == _debtGroupId;
        final payment = isDebt ? null : _paymentsFor(r.incomeId).firstWhereOrNull((p) => p.id == r.paymentId);
        final debtSource = isDebt ? widget.provider.debtFundingSources.firstWhereOrNull((s) => s.id == r.paymentId) : null;
        final availYer = payment != null
            ? _available(payment)
            : (debtSource != null ? widget.provider.debtFundingAvailable(debtSource.id) : 0.0);
        final rate = (isDebt ? debtSource?.exchangeRate : payment?.exchangeRate) ?? 1.0;
        final curr = (isDebt ? debtSource?.currency : payment?.currency) ?? baseCurrencyCode;
        final enteredYer = r.toYemeniAmount(rate);
        if (enteredYer > availYer + 0.001) {
          final isForeign = curr != baseCurrencyCode;
          final currStr = currencyLabel(curr);
          final availInCurr = isForeign && rate > 0
              ? fromYemeniEquivalent(availYer, curr, rate)
              : availYer;
          final enteredVal = tryParseFlexible(r.amountController.text) ?? 0;
          final inputCurrStr = currencyLabel(r.inputCurrency);
          setState(() => _error = r.inputCurrency == baseCurrencyCode
              ? 'المبلغ المدخل (${enteredVal.formatted} ر.ي) يتجاوز المتاح في الدفعة (${availYer.formatted} ر.ي)'
              : 'المبلغ المدخل (${enteredVal.formatted} $inputCurrStr) يتجاوز المتاح في الدفعة (${availInCurr.formatted} $currStr / ${availYer.formatted} ر.ي)');
          return false;
        }
      }
    }
    try {
      widget.provider.validateFunding(allocations);
    } catch (e) {
      setState(() => _error = e.toString());
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('مصدر التمويل (الدفع المستلم من الإيرادات)',
                style: TextStyle(
                    color: context.dynamicTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            InkWell(
              onTap: () => setState(() => _hideDepleted = !_hideDepleted),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hideDepleted
                          ? Icons.filter_alt
                          : Icons.filter_alt_off_outlined,
                      size: 14,
                      color: _hideDepleted
                          ? context.dynamicAccentBlue
                          : context.dynamicTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _hideDepleted ? 'إخفاء المستنفدة' : 'عرض الكل',
                      style: TextStyle(
                        color: _hideDepleted
                            ? context.dynamicAccentBlue
                            : context.dynamicTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.dynamicSurfaceBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: Text('لا يوجد تمويل - أضف دفعة استلام',
                style: TextStyle(color: context.dynamicTextMuted, fontSize: 12)),
          ),
        ...List.generate(_rows.length, (i) {
          final row = _rows[i];
          final usedElsewhere = {
            for (final r in _rows)
              if (r != row) r.paymentId,
          };
            final payments = _paymentsFor(row.incomeId)
              .where((p) => !usedElsewhere.contains(p.id))
              .toList();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.dynamicSurfaceBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.dynamicCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.dynamicCardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _availableIncomesFor(row).any((i) => i.id == row.incomeId)
                                ? row.incomeId
                                : null,
                            isExpanded: true,
                            dropdownColor: context.dynamicCardBg,
                            icon: Icon(Icons.arrow_drop_down, color: context.dynamicTextPrimary),
                            hint: Text(
                              'اختر الإيراد',
                              style: TextStyle(
                                color: context.dynamicTextMuted,
                                fontSize: 13,
                              ),
                            ),
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontSize: 13,
                            ),
                            items: _availableIncomesFor(row).map((inc) {
                              final isPos = _incomeShownAvailableByCurrency(inc, row).values.any((v) => v > 0.001);
                              final availText = _formatIncomeAvailable(inc, row);
                              return DropdownMenuItem(
                                value: inc.id,
                                child: Text(
                                  '${isPos ? "🟢 " : "⚪ "}${inc.title} ($availText)',
                                  style: TextStyle(
                                    color: isPos ? context.dynamicTextPrimary : context.dynamicTextMuted,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() {
                              row.incomeId = v;
                              row.paymentId = null;
                              _error = null;
                            }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _rows.length > 1
                          ? () {
                              setState(() {
                                row.dispose();
                                _rows.removeAt(i);
                                _error = null;
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: _rows.length > 1
                            ? context.dynamicExpenseRed
                            : context.dynamicTextMuted.withValues(alpha: 0.4),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (row.incomeId != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.dynamicCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: payments.any((p) => p.id == row.paymentId) ? row.paymentId : null,
                        isExpanded: true,
                        dropdownColor: context.dynamicCardBg,
                        icon: Icon(Icons.arrow_drop_down, color: context.dynamicTextPrimary),
                        hint: Text(
                          'اختر الدفعة المستلمة',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 13,
                          ),
                        ),
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontSize: 13,
                        ),
                        items: payments.map((p) {
                          final availYer = _available(p);
                          final isPositive = availYer > 0.001;
                          final dateStr = DateFormat('dd MMM yyyy', 'ar').format(p.date);
                          final isForeign = p.currency != baseCurrencyCode;
                          final currStr = currencyLabel(p.currency);
                          final pAvailInCurr = isForeign && p.exchangeRate > 0
                              ? fromYemeniEquivalent(availYer, p.currency, p.exchangeRate)
                              : availYer;
                          final availStr = !isForeign
                              ? '${availYer.formatted} $currStr'
                              : '${pAvailInCurr.formatted} $currStr (يعادل ${availYer.formatted} ر.ي)';
                          final label = p.incomeId == _debtGroupId
                              ? '${isPositive ? "🟢 " : "⚪ "}${p.notes ?? "استلام دين"} · $dateStr · متاح: $availStr'
                              : '${isPositive ? "🟢 " : "⚪ "}دفعة $dateStr · متاح: $availStr';
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isPositive ? context.dynamicTextPrimary : context.dynamicTextMuted,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() {
                          row.paymentId = v;
                          final p = payments.firstWhereOrNull((pp) => pp.id == v);
                          if (p != null) {
                            if (row.inputCurrency != baseCurrencyCode && row.inputCurrency != p.currency) {
                              row.inputCurrency = p.currency;
                            }
                          } else {
                            row.inputCurrency = baseCurrencyCode;
                          }
                          _error = null;
                      if (row.amountController.text.trim().isEmpty) {
                        final effectiveRequired = _effectiveRequiredTotal;
                        final otherSum = _rows.where((r) => r != row).fold(0.0, (s, r) {
                          final pp = payments.firstWhereOrNull((x) => x.id == r.paymentId);
                          return s + r.toYemeniAmount(pp?.exchangeRate ?? 1.0);
                        });
                        final remainingNeeded = effectiveRequired > 0 ? (effectiveRequired - otherSum) : 0.0;
                        final targetYer = widget.autoAmount ?? (remainingNeeded > 0 ? remainingNeeded : null);
                        if (targetYer != null && targetYer > 0 && p != null) {
                          final availYer = _available(p).clamp(0.0, double.infinity);
                          final fillYer = targetYer <= availYer ? targetYer : availYer;
                          if (fillYer > 0) {
                            if (row.inputCurrency == baseCurrencyCode || p.currency == baseCurrencyCode || p.exchangeRate <= 0) {
                              row.amountController.text = fillYer.plain;
                            } else {
                              row.amountController.text = fromYemeniEquivalent(fillYer, p.currency, p.exchangeRate).plain;
                            }
                          }
                        }
                      }
                    }),
                  ),
                ),
              ),
              if (row.paymentId != null) ...[
                    const SizedBox(height: 6),
                    Builder(
                      builder: (_) {
                        final selPayment = payments.firstWhereOrNull((p) => p.id == row.paymentId);
                        final pAvailYer = selPayment != null
                            ? _available(selPayment).clamp(0.0, double.infinity)
                            : 0.0;
                        final payCurrency = selPayment?.currency ?? baseCurrencyCode;
                        final payRate = selPayment?.exchangeRate ?? 1.0;
                        final isForeign = payCurrency != baseCurrencyCode;
                        final currStr = currencyLabel(payCurrency);
                        final pAvailInCurr = isForeign && payRate > 0
                            ? fromYemeniEquivalent(pAvailYer, payCurrency, payRate)
                            : pAvailYer;

                        final effectiveRequired = _effectiveRequiredTotal;
                        final otherRowsSum = _rows.where((r) => r != row).fold(0.0, (s, r) {
                          final p = payments.firstWhereOrNull((x) => x.id == r.paymentId);
                          return s + r.toYemeniAmount(p?.exchangeRate ?? 1.0);
                        });
                        final remainingNeededYer = effectiveRequired > 0
                            ? (effectiveRequired - otherRowsSum)
                            : 0.0;
                        final bool coversFull = remainingNeededYer > 0 && pAvailYer >= remainingNeededYer;
                        final String buttonLabel = coversFull
                            ? 'استقطاع كامل المبلغ'
                            : (remainingNeededYer > 0 && pAvailYer < remainingNeededYer)
                                ? (row.inputCurrency == baseCurrencyCode
                                    ? 'استقطاع المتاح (${pAvailYer.formatted})'
                                    : 'استقطاع المتاح (${pAvailInCurr.formatted})')
                                : 'استقطاع كامل المبلغ';

                        final String availInfoText = !isForeign
                            ? 'المتاح في هذه الدفعة: ${pAvailYer.formatted} ر.ي'
                            : 'المتاح: ${pAvailInCurr.formatted} $currStr (يعادل ${pAvailYer.formatted} ر.ي)';

                        return Row(
                          children: [
                            Icon(
                              pAvailYer > 0 ? Icons.check_circle_outline : Icons.info_outline,
                              size: 14,
                              color: pAvailYer > 0 ? context.dynamicIncomeGreen : context.dynamicTextMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                availInfoText,
                                style: TextStyle(
                                  color: pAvailYer > 0 ? context.dynamicIncomeGreen : context.dynamicTextMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (pAvailYer > 0)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    final rem = effectiveRequired > 0 ? (effectiveRequired - otherRowsSum) : 0.0;
                                    final needed = rem > 0 ? rem.clamp(0.0, pAvailYer) : pAvailYer;
                                    final fillValYer = needed > 0 ? needed : pAvailYer;
                                    if (row.inputCurrency == baseCurrencyCode || !isForeign || payRate <= 0) {
                                      row.amountController.text = fillValYer.plain;
                                    } else {
                                      row.amountController.text = fromYemeniEquivalent(fillValYer, payCurrency, payRate).plain;
                                    }
                                    _error = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.dynamicAccentBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: context.dynamicAccentBlue.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt, size: 13, color: context.dynamicAccentBlue),
                                      const SizedBox(width: 2),
                                      Text(
                                        buttonLabel,
                                        style: TextStyle(
                                          color: context.dynamicAccentBlue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final selPayment = payments.firstWhereOrNull((p) => p.id == row.paymentId);
                      final payCurrency = selPayment?.currency ?? baseCurrencyCode;
                      final payRate = selPayment?.exchangeRate ?? 1.0;
                      final isForeign = payCurrency != baseCurrencyCode;
                      final currStr = currencyLabel(payCurrency);

                      if (isForeign) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: row.amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w600),
                                onChanged: (_) => setState(() {
                                  _error = null;
                                }),
                                decoration: InputDecoration(
                                  labelText: 'مبلغ الاستقطاع (${currencyLabel(row.inputCurrency)}) *',
                                  prefixIcon: const Icon(Icons.attach_money),
                                  suffixText: currencyLabel(row.inputCurrency),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                value: row.inputCurrency == payCurrency ? payCurrency : baseCurrencyCode,
                                decoration: const InputDecoration(
                                  labelText: 'العملة',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                dropdownColor: context.dynamicCardBg,
                                style: TextStyle(color: context.dynamicTextPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                items: [
                                  const DropdownMenuItem(
                                    value: baseCurrencyCode,
                                    child: Text('ر.ي (يمني)', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: payCurrency,
                                    child: Text('$currStr (أصل الدفعة)', style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                                onChanged: (newC) {
                                  if (newC == null || newC == row.inputCurrency) return;
                                  setState(() {
                                    final curVal = tryParseFlexible(row.amountController.text);
                                    if (curVal != null && curVal > 0 && payRate > 0) {
                                      if (newC == baseCurrencyCode) {
                                        row.amountController.text = toYemeniEquivalent(curVal, payCurrency, payRate).plain;
                                      } else {
                                        row.amountController.text = fromYemeniEquivalent(curVal, payCurrency, payRate).plain;
                                      }
                                    }
                                    row.inputCurrency = newC;
                                    _error = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }

                      return TextFormField(
                        controller: row.amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w600),
                        onChanged: (_) => setState(() {
                          _error = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'مبلغ التمويل *',
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'ر.ي',
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (_) {
                      final selPayment = payments.firstWhereOrNull((p) => p.id == row.paymentId);
                      if (selPayment == null) return const SizedBox.shrink();
                      final payCurrency = selPayment.currency;
                      final payRate = selPayment.exchangeRate;
                      final isForeign = payCurrency != baseCurrencyCode;
                      final currStr = currencyLabel(payCurrency);
                      final pAvailYer = _available(selPayment).clamp(0.0, double.infinity);
                      final pAvailInCurr = isForeign && payRate > 0
                          ? fromYemeniEquivalent(pAvailYer, payCurrency, payRate)
                          : pAvailYer;
                      final enteredVal = tryParseFlexible(row.amountController.text) ?? 0;
                      final enteredYer = row.toYemeniAmount(payRate);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isForeign && enteredVal > 0 && payRate > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.dynamicAccentBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                row.inputCurrency == baseCurrencyCode
                                    ? 'يعادل: ${fromYemeniEquivalent(enteredVal, payCurrency, payRate).formatted} $currStr بالعملة الأصلية (سعر الصرف: ${payRate.plain})'
                                    : 'يعادل: ${toYemeniEquivalent(enteredVal, payCurrency, payRate).formatted} ر.ي (سعر الصرف: ${payRate.plain})',
                                style: TextStyle(color: context.dynamicAccentBlue, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          if (enteredYer > pAvailYer + 0.001)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 14, color: context.dynamicExpenseRed),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      row.inputCurrency == baseCurrencyCode
                                          ? 'تنبيه: المبلغ المدخل (${enteredVal.formatted} ر.ي) يتجاوز المتاح في الدفعة (${pAvailYer.formatted} ر.ي)'
                                          : 'تنبيه: المبلغ المدخل (${enteredVal.formatted} ${currencyLabel(row.inputCurrency)}) يتجاوز المتاح في الدفعة (${pAvailInCurr.formatted} $currStr / ${pAvailYer.formatted} ر.ي)',
                                      style: TextStyle(
                                        color: context.dynamicExpenseRed,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _rows.add(_FundingRow())),
            icon: Icon(Icons.add,
                color: _isEligibleEmpty ? context.dynamicTextMuted : context.dynamicAccentBlue,
                size: 18),
            label: Text('إضافة دفعة',
                style: TextStyle(
                    color: _isEligibleEmpty
                        ? context.dynamicTextMuted
                        : context.dynamicAccentBlue)),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!,
                style: TextStyle(
                    color: context.dynamicExpenseRed, fontSize: 12)),
          ),
      ],
    );
  }

  bool get _isEligibleEmpty => _incomesWithPayments.isEmpty;
}

class _FundingRow {
  String? incomeId;
  String? paymentId;
  String inputCurrency;
  final TextEditingController amountController;

  _FundingRow()
      : inputCurrency = baseCurrencyCode,
        amountController = TextEditingController();

  void dispose() => amountController.dispose();

  double toYemeniAmount(double exchangeRate) {
    final entered = tryParseFlexible(amountController.text) ?? 0.0;
    if (entered <= 0) return 0.0;
    if (inputCurrency == baseCurrencyCode || exchangeRate <= 0) {
      return entered;
    }
    return toYemeniEquivalent(entered, inputCurrency, exchangeRate);
  }
}

/// يعرض نافذة دفع حصة شريك عبر الاستقطاع من الإيرادات.
void showDistributionPaymentSheet(
    BuildContext context, FinanceProvider provider, Distribution d) {
  DateTime date = DateTime.now();
  final fundingKey = GlobalKey<FundingPickerState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.dynamicCardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.dynamicCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.handshake_outlined,
                    color: ctx.dynamicIncomeGreen, size: 20),
                const SizedBox(width: 8),
                Text('دفع حصة شريك',
                    style: TextStyle(
                        color: ctx.dynamicTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('المبلغ: ${d.amount.formatted} ر.ي',
                style: TextStyle(
                    color: ctx.dynamicTextMuted, fontSize: 13)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setSheetState(() => date = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ctx.dynamicSurfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ctx.dynamicCardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: ctx.dynamicTextSecondary, size: 18),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy', 'ar').format(date),
                        style: TextStyle(color: ctx.dynamicTextPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('الاستقطاع من الإيرادات',
                style: TextStyle(
                    color: ctx.dynamicTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            FundingPicker(
              pickerKey: fundingKey,
              provider: provider,
              requiredTotal: d.amount,
              requiredTotalGetter: () => d.amount,
              autoAmount: d.amount,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final picker = fundingKey.currentState;
                  if (picker == null || !picker.validate()) {
                    return;
                  }
                  provider.markDistributionPaid(
                      d.id, date, picker.allocations);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ctx.dynamicIncomeGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('تأكيد الدفع',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
