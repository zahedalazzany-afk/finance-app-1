import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class AddIncomeScreen extends StatefulWidget {
  final Income? existing;
  const AddIncomeScreen({super.key, this.existing});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _source = incomeSources.first;
  DateTime _date = DateTime.now();
  String? _landPlotId;
  String? _zahraId;
  bool _isReceived = false;
  String? _walletId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FinanceProvider>();
      if (_walletId == null && provider.wallets.isNotEmpty) {
        setState(() => _walletId = provider.defaultWallet()?.id);
      }
    });
    if (widget.existing != null) {
      final e = widget.existing!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toString();
      _noteController.text = e.note ?? '';
      _source = e.source;
      _date = e.date;
      _landPlotId = e.landPlotId;
      _zahraId = e.zahraId;
      _isReceived = e.status == 'confirmed';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
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
            primary: AppTheme.incomeGreen,
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final amount = MoneyValue.parseInput(_amountController.text.trim())
        .minorUnits
        .toDouble();
    if (widget.existing != null) {
      widget.existing!
        ..title = _titleController.text.trim()
        ..amount = amount
        ..source = _source
        ..date = _date
        ..note = _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim()
        ..landPlotId = _landPlotId
        ..zahraId = _zahraId
        ..walletId = _walletId;
      provider.updateIncome(widget.existing!);
      if (_isReceived && widget.existing!.remainingAmount > 0) {
        provider.addIncomePayment(IncomePayment(
          id: const Uuid().v4(),
          incomeId: widget.existing!.id,
          amount: widget.existing!.remainingAmount,
          date: _date,
          notes: 'مستلم فوراً',
        ));
      }
    } else {
      final newIncome = Income(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        amount: amount,
        date: _date,
        source: _source,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        landPlotId: _landPlotId,
        zahraId: _zahraId,
        walletId: _walletId,
        status: 'pending',
      );
      provider.addIncome(newIncome);
      if (_isReceived) {
        provider.addIncomePayment(IncomePayment(
          id: const Uuid().v4(),
          incomeId: newIncome.id,
          amount: newIncome.amount,
          date: _date,
          notes: 'مستلم فوراً',
        ));
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'إضافة إيراد' : 'تعديل الإيراد'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('عنوان الإيراد'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'عنوان الإيراد *',
                hintText: 'مثال: بيع زهرة رمان',
                prefixIcon: Icon(Icons.description),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'أدخل عنواناً' : null,
            ),
            const SizedBox(height: 20),
            _label('مبلغ الإيراد'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                  color: AppTheme.incomeGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'مبلغ الإيراد (ر.ي) *',
                hintText: '0',
                suffixText: 'ر.ي',
                prefixIcon:
                    Icon(Icons.attach_money, color: AppTheme.incomeGreen),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل المبلغ';
                try {
                  final value = MoneyValue.parseInput(v);
                  if (value.minorUnits <= 0) return 'يجب أن يكون أكبر من صفر';
                  return null;
                } on FormatException {
                  return 'المبلغ يجب أن يكون صحيحاً بدون فواصل عشرية';
                }
              },
            ),
            const SizedBox(height: 20),
            _label('المصدر'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _source,
                  isExpanded: true,
                  hint: Text('اختر المصدر', style: TextStyle(color: AppTheme.textMuted)),
                  style: TextStyle(color: AppTheme.textPrimary),
                  items: incomeSources
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _source = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('التاريخ'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDateTime,
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
                    Text(
                      DateFormat('EEEE، dd MMMM yyyy - hh:mm a', 'ar').format(_date),
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Consumer<FinanceProvider>(
              builder: (context, provider, _) {
                final validLandPlotId = provider.landPlots.any((p) => p.id == _landPlotId)
                    ? _landPlotId : null;
                final validZahraId = provider.zahras.any((z) => z.id == _zahraId)
                    ? _zahraId : null;
                if (_landPlotId != validLandPlotId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _landPlotId = validLandPlotId);
                  });
                }
                if (_zahraId != validZahraId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _zahraId = validZahraId);
                  });
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('الموضع'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: validLandPlotId,
                          isExpanded: true,
                          hint: Text('اختر الموضع',
                              style: TextStyle(color: AppTheme.textMuted)),
                          style:
                              TextStyle(color: AppTheme.textPrimary),
                          items: provider.landPlots
                              .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                      '${p.name} (${p.area.formattedFull} م²)')))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _landPlotId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label('الزهرة'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: validZahraId,
                          isExpanded: true,
                          hint: Text('اختر الزهرة',
                              style: TextStyle(color: AppTheme.textMuted)),
                          style:
                              TextStyle(color: AppTheme.textPrimary),
                          items: provider.zahras.map((z) {
                            final type = provider.zahraTypes
                                .firstWhere((t) => t.id == z.typeId,
                                    orElse: () => ZahraType(
                                        id: '', name: ''))
                                .name;
                            return DropdownMenuItem(
                                value: z.id,
                                child: Text(
                                    '${z.name} ($type)'));
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _zahraId = v),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _label('ملاحظة (اختياري)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                hintText: 'أي تفاصيل إضافية...',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.incomeGreen, size: 20),
                  const SizedBox(width: 10),
                  Text('تم استلام المبلغ كاملاً',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  const Spacer(),
                  Checkbox(
                    value: _isReceived,
                    activeColor: AppTheme.incomeGreen,
                    onChanged: (v) => setState(() => _isReceived = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _label('المحفظة'),
            const SizedBox(height: 8),
            Consumer<FinanceProvider>(
              builder: (context, provider, _) {
                return DropdownButtonFormField<String>(
                  value: _walletId,
                  decoration: const InputDecoration(
                    labelText: 'المحفظة *',
                    prefixIcon: Icon(Icons.wallet),
                  ),
                  style: TextStyle(color: AppTheme.textPrimary),
                  items: provider.wallets.map((w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(w.name))).toList(),
                  onChanged: (v) => setState(() => _walletId = v),
                  validator: (v) => v == null ? 'اختر المحفظة' : null,
                );
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              child: Text(
                  widget.existing == null ? 'حفظ الإيراد' : 'تحديث'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600));
}
