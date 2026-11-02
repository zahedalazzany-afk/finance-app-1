import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class AddIncomeScreenV2 extends StatefulWidget {
  final Income? existing;
  const AddIncomeScreenV2({super.key, this.existing});

  @override
  State<AddIncomeScreenV2> createState() => _AddIncomeScreenV2State();
}

class _AddIncomeScreenV2State extends State<AddIncomeScreenV2> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _source = incomeSources.first;
  DateTime _date = DateTime.now();
  String? _landPlotId;
  String? _zahraId;
  bool _isReceived = true; // Default to true in V2 for convenience
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

  void _addAmountPreset(double val) {
    final currentVal = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;
    final newVal = currentVal + val;
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
          notes: 'مستلم فوراً (إيرادات ٢)',
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
          notes: 'مستلم فوراً (إيرادات ٢)',
          walletId: _walletId,
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
              ),
              child: const Text('إيرادات ٢',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(widget.existing == null ? 'إضافة إيراد (تصميم 2)' : 'تعديل الإيراد (تصميم 2)'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Amount Hero Card (Large Modern Financial Input)
                  _buildHeroAmountCard(),
                  const SizedBox(height: 20),

                  // Title & Presets
                  _buildTitleSection(),
                  const SizedBox(height: 20),

                  // Source Choice Chips
                  _buildSourceChoiceSection(),
                  const SizedBox(height: 20),

                  // Status Segmented Switch (آجل vs مستلم)
                  _buildStatusSegmentedControl(),
                  const SizedBox(height: 20),

                  // Location & Zahra Grid Selection
                  _buildLocationAndCropGrid(),
                  const SizedBox(height: 20),

                  // Date & Wallet Section
                  _buildDateAndWalletCard(),
                  const SizedBox(height: 20),

                  // Note Input
                  _buildNotesInput(),
                  const SizedBox(height: 80), // Extra space for FAB
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickySaveButton(),
    );
  }

  Widget _buildHeroAmountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: AppTheme.incomeGreen, size: 20),
                  SizedBox(width: 6),
                  Text('المبلغ الإجمالي للإيراد',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('ريال يمني YER',
                    style: TextStyle(color: AppTheme.incomeGreen, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: AppTheme.incomeGreen,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
            decoration: const InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: Colors.white30, fontSize: 34),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              filled: false,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'أدخل المبلغ الإجمالي';
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
          // Quick Increments
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [5000, 25000, 50000, 100000, 500000].map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => _addAmountPreset(preset.toDouble()),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '+${preset.formattedFull}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('العنوان المرجعي'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'مثال: حصيلة بيع المحصول الأسبوعي',
            prefixIcon: const Icon(Icons.bookmark_border_rounded, color: Colors.blueAccent),
            filled: true,
            fillColor: AppTheme.surface,
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'أدخل عنوان الإيراد' : null,
        ),
      ],
    );
  }

  Widget _buildSourceChoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('تصنيف المصدر'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: incomeSources.map((src) {
            final isSelected = _source == src;
            return ChoiceChip(
              selected: isSelected,
              label: Text(src),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selectedColor: AppTheme.incomeGreen,
              backgroundColor: AppTheme.surface,
              side: BorderSide(
                color: isSelected ? AppTheme.incomeGreen : AppTheme.cardBorder,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _source = src);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusSegmentedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('حالة التحصيل والسداد'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isReceived = true;
                    _receivedTouched = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isReceived ? AppTheme.incomeGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: _isReceived ? Colors.black : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'مستلم نقدًا / للمحفظة',
                          style: TextStyle(
                            color: _isReceived ? Colors.black : AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isReceived = false;
                    _receivedTouched = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isReceived ? Colors.orange : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: !_isReceived ? Colors.black : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'آجل (قيد التحصيل)',
                          style: TextStyle(
                            color: !_isReceived ? Colors.black : AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationAndCropGrid() {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final validLandPlotId = provider.landPlots.any((p) => p.id == _landPlotId)
            ? _landPlotId : null;
        final validZahraId = provider.zahras.any((z) => z.id == _zahraId)
            ? _zahraId : null;

        return Row(
          children: [
            // Land plot selection
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('الموضع (الأرض)'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: validLandPlotId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'اختر الموضع',
                      prefixIcon: const Icon(Icons.terrain_rounded, color: Colors.amber),
                      filled: true,
                      fillColor: AppTheme.surface,
                    ),
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('غير محدد', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      ...provider.landPlots.map((p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _landPlotId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Zahra selection
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('الزهرة / المحصول'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: validZahraId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'اختر الزهرة',
                      prefixIcon: const Icon(Icons.eco_rounded, color: Colors.pinkAccent),
                      filled: true,
                      fillColor: AppTheme.surface,
                    ),
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('غير محدد', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      ...provider.zahras.map((z) => DropdownMenuItem<String?>(
                            value: z.id,
                            child: Text(z.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _zahraId = v),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateAndWalletCard() {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: [
              // Date Row
              InkWell(
                onTap: _pickDateTime,
                child: Row(
                  children: [
                    const Icon(Icons.event_note_rounded, color: AppTheme.incomeGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تاريخ وتسجيل الإيراد',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          Text(
                            DateFormat('EEEE، dd MMMM yyyy - hh:mm a', 'ar').format(_date),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded, color: Colors.grey, size: 20),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Wallet Row
              DropdownButtonFormField<String>(
                value: _walletId,
                decoration: const InputDecoration(
                  labelText: 'المحفظة المالية الإيداعية *',
                  prefixIcon: Icon(Icons.account_balance_rounded, color: Colors.blueAccent),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                items: provider.wallets
                    .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text('${w.name} - [رصيد: ${w.balance.formattedFull} ر.ي]'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _walletId = v),
                validator: (v) => v == null ? 'اختر المحفظة الإيداعية' : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('ملاحظات وسجل العقد'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _noteController,
          maxLines: 2,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'إضافة تفاصيل البيعة أو رقم الإيصال إن وجد...',
            prefixIcon: const Icon(Icons.note_alt_outlined),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildStickySaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.incomeGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  widget.existing == null ? 'حفظ وتسجيل الإيراد (تصميم 2)' : 'حفظ التعديلات (تصميم 2)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
}
