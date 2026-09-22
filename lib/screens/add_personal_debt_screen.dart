import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets.dart';

class AddPersonalDebtScreen extends StatefulWidget {
  final String initialDirection;
  final String? initialPersonId;
  final PersonalDebt? existingDebt;

  const AddPersonalDebtScreen({
    super.key,
    this.initialDirection = 'receivable',
    this.initialPersonId,
    this.existingDebt,
  });

  @override
  State<AddPersonalDebtScreen> createState() => _AddPersonalDebtScreenState();
}

class _AddPersonalDebtScreenState extends State<AddPersonalDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fundingKey = GlobalKey<FundingPickerState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _exchangeRateCtrl = TextEditingController(text: '1');
  String? _selectedPersonId;
  String? _selectedWalletId;
  String _currency = baseCurrencyCode;
  late String _direction;
  DateTime _selectedDate = DateTime.now();

  bool get _isEditing => widget.existingDebt != null;

  @override
  void initState() {
    super.initState();
    _direction = widget.existingDebt?.direction ?? widget.initialDirection;
    _selectedPersonId = widget.initialPersonId;
    if (_isEditing) {
      _selectedPersonId = widget.existingDebt!.personId;
      _selectedWalletId = widget.existingDebt!.walletId;
      _currency = widget.existingDebt!.currency;
      _exchangeRateCtrl.text = widget.existingDebt!.exchangeRate.toString();
      _amountCtrl.text = widget.existingDebt!.currency == baseCurrencyCode
          ? widget.existingDebt!.amount.plain
          : (widget.existingDebt!.amount / (widget.existingDebt!.exchangeRate > 0 ? widget.existingDebt!.exchangeRate : 1)).toString();
      _noteCtrl.text = widget.existingDebt!.note ?? '';
      _selectedDate = widget.existingDebt!.date;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _exchangeRateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final enteredAmount = tryParseFlexible(_amountCtrl.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل الدين' : 'دين شخصي جديد'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'receivable',
                  label: Text('لنا عليه (إقراض / تسليف)'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: 'payable',
                  label: Text('له علينا (اقتراض منه)'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPersonId,
              decoration: const InputDecoration(
                labelText: 'الشخص',
                border: OutlineInputBorder(),
              ),
              items: provider.partners
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPersonId = v),
              validator: (v) => v == null ? 'اختر الشخص' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'المبلغ الفعلي المستلم/المسدّد',
                suffixText: currencyLabel(_currency),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل المبلغ';
                final n = double.tryParse(v.replaceAll(RegExp(r'[^\d.]'), ''));
                if (n == null || n <= 0) return 'مبلغ غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(
                labelText: 'عملة الدين',
                border: OutlineInputBorder(),
              ),
              items: supportedCurrencyCodes
                  .map((code) => DropdownMenuItem(
                        value: code,
                        child: Text(currencyLabel(code)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _currency = value;
                  if (value == baseCurrencyCode) {
                    _exchangeRateCtrl.text = '1';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _exchangeRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'سعر الصرف مقابل الريال اليمني',
                helperText: 'مثال: 57.5',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final rate = double.tryParse(v ?? '');
                if (rate == null || rate <= 0) return 'أدخل سعر صرف صحيح';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedWalletId,
              decoration: InputDecoration(
                labelText: _direction == 'receivable'
                    ? 'المحفظة المسحوب منها (دفع)'
                    : 'المحفظة المودع فيها (استلام)',
                border: const OutlineInputBorder(),
              ),
              items: provider.wallets
                  .map((w) => DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.name} (رصيدها: ${provider.walletBalance(w.id).formatted} ر.ي)'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedWalletId = v),
              validator: (v) => v == null ? 'اختر المحفظة' : null,
            ),
            if (_direction == 'receivable' && _selectedWalletId != null) ...[
              const SizedBox(height: 16),
              FundingPicker(
                provider: provider,
                pickerKey: _fundingKey,
                walletFilter: _selectedWalletId,
                requiredTotal: enteredAmount,
                requiredTotalGetter: () => enteredAmount,
                autoAmount: enteredAmount,
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'التاريخ',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    const Icon(Icons.calendar_today, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedWalletId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار المحفظة')),
                    );
                    return;
                  }
                  final amountInSelectedCurrency = double.tryParse(
                          _amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), '')) ??
                      0;
                  final exchangeRate = double.tryParse(_exchangeRateCtrl.text) ?? 1.0;
                  final amount = toBaseCurrency(
                    amountInSelectedCurrency,
                    _currency,
                    exchangeRate,
                  );

                  List<ExpenseAllocation> funding = [];
                  if (_direction == 'receivable') {
                    if (!(_fundingKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    funding = _fundingKey.currentState?.allocations ?? [];
                    final sumFunding =
                        funding.fold(0.0, (s, a) => s + a.amount);
                    if ((sumFunding - amount).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'مجموع مصدر التمويل (${sumFunding.formatted} ر.ي) يجب أن يساوي مبلغ الدين (${amount.formatted} ر.ي)'),
                      ));
                      return;
                    }
                  }

                  if (_isEditing) {
                    provider.updatePersonalDebt(PersonalDebt(
                      id: widget.existingDebt!.id,
                      personId: _selectedPersonId!,
                      direction: _direction,
                      amount: amount,
                      date: _selectedDate,
                      walletId: _selectedWalletId,
                      funding: funding,
                      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
                      currency: _currency,
                      exchangeRate: exchangeRate,
                    ));
                  } else {
                    provider.addPersonalDebt(PersonalDebt(
                      id: const Uuid().v4(),
                      personId: _selectedPersonId!,
                      direction: _direction,
                      amount: amount,
                      date: _selectedDate,
                      walletId: _selectedWalletId,
                      funding: funding,
                      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
                      currency: _currency,
                      exchangeRate: exchangeRate,
                    ));
                  }
                  Navigator.pop(context);
                },
                child: Text(_isEditing ? 'حفظ التعديلات' : 'تسجيل الدين'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
