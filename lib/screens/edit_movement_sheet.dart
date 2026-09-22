import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

class EditMovementSheet extends StatefulWidget {
  final MoneyMovement movement;
  const EditMovementSheet({super.key, required this.movement});

  @override
  State<EditMovementSheet> createState() => _EditMovementSheetState();
}

class _EditMovementSheetState extends State<EditMovementSheet> {
  late final TextEditingController _amountController;
  final _noteController = TextEditingController();
  late DateTime _date;
  String? _walletId;
  late String _inputCurrency;
  final _formKey = GlobalKey<FormState>();

  bool get _amountLocked =>
      widget.movement.purchaseId != null || widget.movement.distributionId != null;

  @override
  void initState() {
    super.initState();
    final m = widget.movement;
    _inputCurrency = m.currency;
    final displayAmount = m.currency == baseCurrencyCode
        ? m.amount
        : fromYemeniEquivalent(m.amount, m.currency, m.exchangeRate);
    _amountController = TextEditingController(text: displayAmount.toString());
    _noteController.text = m.note ?? '';
    _date = m.date;
    _walletId = m.walletId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final maxAllowedInYemeni = provider.movementMaxEditable(widget.movement);
    final m = widget.movement;
    final cur = m.currency;
    final rate = m.exchangeRate;
    final maxAllowed = cur == baseCurrencyCode
        ? maxAllowedInYemeni
        : fromYemeniEquivalent(maxAllowedInYemeni, cur, rate);

    if (_walletId == null && provider.wallets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _walletId == null) {
          setState(() => _walletId = provider.defaultWallet()?.id);
        }
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.edit_outlined,
                    color: AppTheme.expenseRed, size: 20),
                const SizedBox(width: 8),
                Text('تعديل التصريف',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            if (_amountLocked)
              Text('المبلغ مرتبط بسجل آخر ولا يمكن تغييره',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
            else if (cur != baseCurrencyCode)
              Text(
                'العملة الأصلية: ${currencyLabel(cur)} (سعر الصرف: ${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)})',
                style: TextStyle(color: AppTheme.accentBlue, fontSize: 12),
              ),
            const SizedBox(height: 16),
            if (cur != baseCurrencyCode && !_amountLocked) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                          color: AppTheme.expenseRed,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'المبلغ (${currencyLabel(_inputCurrency)}) *',
                        hintText: 'المبلغ',
                        prefixIcon: const Icon(Icons.attach_money),
                        suffixText: currencyLabel(_inputCurrency),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'أدخل المبلغ';
                        final a = double.tryParse(v);
                        if (a == null || a <= 0) return 'مبلغ غير صحيح';
                        final inYemeni = _inputCurrency == baseCurrencyCode
                            ? a
                            : toYemeniEquivalent(a, cur, rate);
                        if (inYemeni > maxAllowedInYemeni + 0.001) {
                          final allowedStr = _inputCurrency == baseCurrencyCode
                              ? '${maxAllowedInYemeni.formatted} ر.ي'
                              : '${maxAllowed.formatted} ${currencyLabel(cur)}';
                          return 'يتجاوز المتاح ($allowedStr)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      value: _inputCurrency,
                      decoration: const InputDecoration(
                        labelText: 'العملة',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem(
                          value: baseCurrencyCode,
                          child: Text('ر.ي (يمني)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: cur,
                          child: Text('${currencyLabel(cur)} (أصل الحركة)', style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                      onChanged: (newC) {
                        if (newC == null || newC == _inputCurrency) return;
                        setState(() {
                          final curVal = double.tryParse(_amountController.text.trim());
                          if (curVal != null && curVal > 0 && rate > 0) {
                            if (newC == baseCurrencyCode) {
                              _amountController.text = toYemeniEquivalent(curVal, cur, rate).plain;
                            } else {
                              _amountController.text = fromYemeniEquivalent(curVal, cur, rate).plain;
                            }
                          }
                          _inputCurrency = newC;
                        });
                      },
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (_) {
                  final entered = double.tryParse(_amountController.text.trim()) ?? 0;
                  if (entered <= 0 || rate <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _inputCurrency == baseCurrencyCode
                            ? 'يعادل: ${fromYemeniEquivalent(entered, cur, rate).formatted} ${currencyLabel(cur)} بالعملة الأصلية (سعر الصرف: ${rate.plain})'
                            : 'يعادل: ${toYemeniEquivalent(entered, cur, rate).formatted} ر.ي (سعر الصرف: ${rate.plain})',
                        style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              TextFormField(
                controller: _amountController,
                enabled: !_amountLocked,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: AppTheme.expenseRed,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                    labelText: 'المبلغ (${currencyLabel(cur)}) *',
                    hintText: 'المبلغ',
                    prefixIcon: const Icon(Icons.attach_money)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'أدخل المبلغ';
                  final a = double.tryParse(v);
                  if (a == null || a <= 0) return 'مبلغ غير صحيح';
                  if (a > maxAllowed + 0.001) {
                    return 'يتجاوز المتاح (${maxAllowed.formatted} ${currencyLabel(cur)})';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (ctx, child) => Theme(
                    data: AppTheme.theme.copyWith(
                      colorScheme: ColorScheme.dark(
                          primary: AppTheme.expenseRed,
                          surface: AppTheme.card),
                    ),
                    child: child!,
                  ),
                );
                if (picked == null || !mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_date),
                );
                if (pickedTime == null || !mounted) return;
                setState(() {
                  _date = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy', 'ar').format(_date),
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (provider.wallets.isEmpty)
              Text('لا توجد محافظ، أنشئ محفظة أولاً',
                  style: TextStyle(color: AppTheme.expenseRed))
            else
              SheetDropdown<String>(
                label: 'المحفظة',
                icon: Icons.wallet,
                value: _walletId,
                items: provider.wallets
                    .map((w) =>
                        DropdownMenuItem(value: w.id, child: Text(w.name)))
                    .toList(),
                onChanged: (v) => setState(() => _walletId = v),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  hintText: 'ملاحظات',
                  prefixIcon: Icon(Icons.notes)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  if (_walletId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('اختر المحفظة'),
                          backgroundColor: AppTheme.expenseRed),
                    );
                    return;
                  }
                  final m = widget.movement;
                  final entered = double.parse(_amountController.text.trim());
                  final amountInYemeni = _inputCurrency == baseCurrencyCode
                      ? entered
                      : toYemeniEquivalent(entered, m.currency, m.exchangeRate);
                  context.read<FinanceProvider>().updateMoneyMovement(
                        MoneyMovement(
                          id: m.id,
                          walletId: _walletId!,
                          amount: amountInYemeni,
                          date: _date,
                          incomeId: m.incomeId,
                          paymentId: m.paymentId,
                          distributionId: m.distributionId,
                          purchaseId: m.purchaseId,
                          creditorType: m.creditorType,
                          creditorId: m.creditorId,
                          debtId: m.debtId,
                          funding: m.funding,
                          currency: m.currency,
                          exchangeRate: m.exchangeRate,
                          note: _noteController.text.trim().isEmpty
                              ? null
                              : _noteController.text.trim(),
                        ),
                      );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.expenseRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حفظ التعديل',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
