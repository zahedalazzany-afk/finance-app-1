import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class AddIncomeScreenV1 extends StatefulWidget {
  final Income? existing;
  const AddIncomeScreenV1({super.key, this.existing});

  @override
  State<AddIncomeScreenV1> createState() => _AddIncomeScreenV1State();
}

class _AddIncomeScreenV1State extends State<AddIncomeScreenV1> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  int _currentStep = 0;
  String _source = incomeSources.first;
  DateTime _date = DateTime.now();
  String? _landPlotId;
  String? _zahraId;
  bool _isReceived = false;
  bool _receivedTouched = false;
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
      _walletId = e.walletId;
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

  void _addAmountIncrement(double increment) {
    final currentVal = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;
    final newVal = currentVal + increment;
    setState(() {
      _amountController.text = newVal.toInt().toString();
    });
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

    if (widget.existing != null &&
        amount < widget.existing!.receivedAmount - 0.000001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن تخفيض مبلغ الإيراد أقل من مجموع الدفعات المستلمة '
            '(${widget.existing!.receivedAmount.formattedFull} ر.ي)',
          ),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
      return;
    }

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

      if (_isReceived &&
          _receivedTouched &&
          widget.existing!.remainingAmount > 0) {
        provider.addIncomePayment(IncomePayment(
          id: const Uuid().v4(),
          incomeId: widget.existing!.id,
          amount: widget.existing!.remainingAmount,
          date: _date,
          notes: 'مستلم فوراً (إيرادات ١)',
          walletId: _walletId,
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
          notes: 'مستلم فوراً (إيرادات ١)',
          walletId: _walletId,
        ));
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.incomeGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.incomeGreen.withOpacity(0.5)),
              ),
              child: Text('إيرادات ١',
                  style: TextStyle(color: AppTheme.incomeGreen, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(widget.existing == null ? 'إضافة إيراد (تصميم 1)' : 'تعديل الإيراد (تصميم 1)'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top Header Card / Step Summary
            _buildHeaderSummaryCard(isDark),

            // Step Indicator Tabs
            _buildStepTabs(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Bottom Action Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSummaryCard(bool isDark) {
    final amountText = _amountController.text.trim();
    final amountVal = double.tryParse(amountText) ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.incomeGreen.withOpacity(0.15),
            AppTheme.card,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.incomeGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.incomeGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.incomeGreen.withOpacity(0.4),
                  blurRadius: 8,
                )
              ],
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.black, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleController.text.isEmpty ? 'إيراد زراعي جديد' : _titleController.text,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      amountVal.formattedFull,
                      style: TextStyle(
                        color: AppTheme.incomeGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('ر.ي', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isReceived
                  ? AppTheme.incomeGreen.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isReceived ? Icons.check_circle_rounded : Icons.pending_rounded,
                  size: 14,
                  color: _isReceived ? AppTheme.incomeGreen : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _isReceived ? 'مستلم' : 'قيد التحصيل',
                  style: TextStyle(
                    color: _isReceived ? AppTheme.incomeGreen : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTabs() {
    final steps = ['1. البيانات الرئيسية', '2. الموقع والزرعة', '3. التسليم والملاحظات'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentStep = index),
              child: Container(
                margin: EdgeInsets.only(left: index == steps.length - 1 ? 0 : 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.incomeGreen
                      : (isDone ? AppTheme.incomeGreen.withOpacity(0.2) : AppTheme.surface),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.incomeGreen
                        : (isDone ? AppTheme.incomeGreen.withOpacity(0.4) : AppTheme.cardBorder),
                  ),
                ),
                child: Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive
                        ? Colors.black
                        : (isDone ? AppTheme.incomeGreen : AppTheme.textMuted),
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1MainData();
      case 1:
        return _buildStep2LocationAndCrop();
      case 2:
        return _buildStep3PaymentAndNotes();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1MainData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('عنوان الإيراد *'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'مثال: بيع محصول الرمان، إيراد قات، الخ...',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان للإيراد' : null,
        ),
        const SizedBox(height: 20),

        _label('مبلغ الإيراد *'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: AppTheme.incomeGreen,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: 'المبلغ الإجمالي (ر.ي)',
            prefixIcon: Icon(Icons.attach_money_rounded, color: AppTheme.incomeGreen),
            suffixIcon: IconButton(
              icon: const Icon(Icons.backspace_outlined, size: 20),
              onPressed: () => setState(() => _amountController.clear()),
            ),
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
        const SizedBox(height: 12),

        // Quick amount increments
        _label('إضافة سريعة للمبلغ:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [10000.0, 50000.0, 100000.0, 500000.0, 1000000.0].map((inc) {
            return ActionChip(
              backgroundColor: AppTheme.surface,
              side: BorderSide(color: AppTheme.cardBorder),
              avatar: Icon(Icons.add, size: 14, color: AppTheme.incomeGreen),
              label: Text('+${inc.formattedFull}'),
              labelStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              onPressed: () => _addAmountIncrement(inc.toDouble()),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        _label('مصدر الإيراد'),
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
              style: TextStyle(color: AppTheme.textPrimary),
              items: incomeSources
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(Icons.nature_outlined, size: 18, color: AppTheme.incomeGreen),
                            const SizedBox(width: 10),
                            Text(s),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _source = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2LocationAndCrop() {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final validLandPlotId = provider.landPlots.any((p) => p.id == _landPlotId)
            ? _landPlotId : null;
        final validZahraId = provider.zahras.any((z) => z.id == _zahraId)
            ? _zahraId : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('اختيار الموضع (الأرض)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: validLandPlotId,
                  isExpanded: true,
                  hint: Text('بدون تحديد موضع محدّد', style: TextStyle(color: AppTheme.textMuted)),
                  style: TextStyle(color: AppTheme.textPrimary),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('بدون تحديد أرض', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    ...provider.landPlots.map((p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Row(
                            children: [
                              const Icon(Icons.landscape_rounded, size: 18, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text('${p.name} (${p.area.formattedFull} م²)'),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _landPlotId = v),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _label('اختيار الزهرة المرتبطة'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: validZahraId,
                  isExpanded: true,
                  hint: Text('اختر الزهرة', style: TextStyle(color: AppTheme.textMuted)),
                  style: TextStyle(color: AppTheme.textPrimary),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('بدون زهرة مرتبطة', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    ...provider.zahras.map((z) {
                      final type = provider.zahraTypes
                          .firstWhere((t) => t.id == z.typeId,
                              orElse: () => ZahraType(id: '', name: ''))
                          .name;
                      return DropdownMenuItem<String?>(
                        value: z.id,
                        child: Row(
                          children: [
                            const Icon(Icons.local_florist_rounded, size: 18, color: Colors.pinkAccent),
                            const SizedBox(width: 8),
                            Text('${z.name} ($type)'),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _zahraId = v),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _label('تاريخ الإيراد ووقت التسجيل'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: AppTheme.incomeGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE، dd MMMM yyyy - hh:mm a', 'ar').format(_date),
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStep3PaymentAndNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('المحفظة المستهدفة *'),
        const SizedBox(height: 8),
        Consumer<FinanceProvider>(
          builder: (context, provider, _) {
            return DropdownButtonFormField<String>(
              value: _walletId,
              decoration: const InputDecoration(
                labelText: 'المحفظة المستلمة',
                prefixIcon: Icon(Icons.account_balance_wallet_rounded),
              ),
              style: TextStyle(color: AppTheme.textPrimary),
              items: provider.wallets
                  .map((w) => DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.name} (${provider.walletBalance(w.id).formattedFull} ر.ي)'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _walletId = v),
              validator: (v) => v == null ? 'اختر المحفظة' : null,
            );
          },
        ),
        const SizedBox(height: 20),

        // Received switch card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isReceived
                ? AppTheme.incomeGreen.withOpacity(0.12)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isReceived
                  ? AppTheme.incomeGreen.withOpacity(0.5)
                  : AppTheme.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isReceived
                      ? AppTheme.incomeGreen
                      : Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isReceived ? Icons.check_rounded : Icons.hourglass_empty_rounded,
                  color: _isReceived ? Colors.black : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تم استلام المبلغ كاملاً',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isReceived
                          ? 'سيتم إضافة المبلغ كاملاً للمحفظة المحددة فتقوم بإيقاف رصيد الآجل.'
                          : 'سيُسجّل الإيراد كآجل لحين تحصيله وسداد المبالغ.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isReceived,
                activeColor: AppTheme.incomeGreen,
                onChanged: (v) => setState(() {
                  _isReceived = v;
                  _receivedTouched = true;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _label('ملاحظات وتفاصيل إضافية'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _noteController,
          maxLines: 3,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'أدخل أي تفاصيل أو بيعة أو توثيق آخر...',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton.icon(
                onPressed: () => setState(() => _currentStep--),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('السابق'),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                  } else {
                    _submit();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.incomeGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _currentStep < 2
                      ? 'التالي (${_currentStep + 2}/3)'
                      : (widget.existing == null ? 'حفظ الإيراد' : 'تحديث البيانات'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
}
