import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'batch_wage_payout_screen.dart';
import 'personal_debts_screen.dart';

class DebtSettlementScreen extends StatefulWidget {
  const DebtSettlementScreen({super.key});

  @override
  State<DebtSettlementScreen> createState() => _DebtSettlementScreenState();
}

class _DebtSettlementScreenState extends State<DebtSettlementScreen> {
  String _mode = 'linked'; // 'linked' | 'cumulative'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'إدارة الديون والتسديدات',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline_rounded),
            tooltip: 'الديون الشخصية والذمم',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PersonalDebtsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.payments_outlined, color: AppTheme.incomeGreen),
            tooltip: 'السداد المجمع لأجور العمال',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BatchWagePayoutScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('طريقة التسديد:',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'linked', label: Text('مرتبط بعملية')),
                          ButtonSegment(value: 'cumulative', label: Text('تراكمي')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _mode == 'linked'
                    ? _LinkedDebtsView()
                    : const _CumulativePayView(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DebtItem {
  final String kind; // 'wage' | 'purchase'
  final String ownerName;
  final String sourceLabel;
  final double remaining;
  final String? expenseId;
  final String? purchaseId;
  final DateTime date;

  const _DebtItem({
    required this.kind,
    required this.ownerName,
    required this.sourceLabel,
    required this.remaining,
    this.expenseId,
    this.purchaseId,
    required this.date,
  });
}

class _LinkedDebtsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final items = <_DebtItem>[];
    for (final e in provider.expenses) {
      if (e.workerId == null) continue;
      final rem = e.amount - provider.paidForExpense(e.id);
      if (rem <= 0) continue;
      final worker =
          provider.workers.firstWhereOrNull((w) => w.id == e.workerId);
      final event =
          provider.landEvents.firstWhereOrNull((ev) => ev.id == e.eventId);
      items.add(_DebtItem(
        kind: 'wage',
        ownerName: worker?.name ?? 'عامل محذوف',
        sourceLabel:
            'حدث: ${event?.eventType ?? '—'} · ${DateFormat('dd MMM yyyy', 'ar').format(e.date)}',
        remaining: rem,
        expenseId: e.id,
        date: e.date,
      ));
    }
    for (final p in provider.purchases) {
      final rem = p.remainingAmount;
      if (rem <= 0) continue;
      final supplier =
          provider.partners.firstWhereOrNull((pa) => pa.id == p.supplierId);
      items.add(_DebtItem(
        kind: 'purchase',
        ownerName: supplier?.name ?? 'مورد محذوف',
        sourceLabel: 'فاتورة شراء · ${DateFormat('dd MMM yyyy', 'ar').format(p.date)}',
        remaining: rem,
        purchaseId: p.id,
        date: p.date,
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.incomeGreen, size: 64),
            SizedBox(height: 16),
            Text('لا توجد ديون معلقة',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('كل الأجور والفواتير مسددة',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    final totalWageRemaining = items
        .where((e) => e.kind == 'wage')
        .fold(0.0, (sum, e) => sum + e.remaining);
    final totalPurchaseRemaining = items
        .where((e) => e.kind == 'purchase')
        .fold(0.0, (sum, e) => sum + e.remaining);
    final totalRemaining = totalWageRemaining + totalPurchaseRemaining;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.expenseRed.withValues(alpha: 0.12),
                    context.dynamicCardBg,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.dynamicCardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.pending_actions_rounded,
                        color: AppTheme.expenseRed, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إجمالي الديون المعلقة (أجور ومشتريات)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: context.dynamicTextSecondary,
                          ),
                        ),
                        Text(
                          '${totalRemaining.formattedFull} ر.ي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.expenseRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.dynamicSurfaceBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: Text(
                      '${items.length} ذمة معلقة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.dynamicTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final it = items[index - 1];
        final isWage = it.kind == 'wage';
        final color = isWage ? AppTheme.expenseRed : Colors.orange;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: context.dynamicCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    isWage ? Icons.engineering : Icons.shopping_cart_outlined,
                    color: color,
                    size: 22),
              ),
              title: Text(it.ownerName,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: context.dynamicTextPrimary,
                      fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.sourceLabel,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: context.dynamicTextMuted,
                          fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('متبقي: ${it.remaining.formatted} ر.ي',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppTheme.expenseRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => _openSettlement(context, provider, it),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('تسديد',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSettlement(
      BuildContext context, FinanceProvider provider, _DebtItem item) {
    final amountController =
        TextEditingController(text: item.remaining.plain);
    final discountController = TextEditingController(text: '0');
    String? walletId;
    DateTime date = DateTime.now();
    final formKey = GlobalKey<FormState>();
    final fundingKey = GlobalKey<FundingPickerState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isPurchase = item.kind == 'purchase';
          final enteredAmt = tryParseFlexible(amountController.text) ?? 0;
          final enteredDisc = isPurchase ? (tryParseFlexible(discountController.text) ?? 0) : 0.0;
          final remainingAfter =
              (item.remaining - enteredAmt - enteredDisc).clamp(0.0, double.infinity);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: AppTheme.cardBorder,
                          borderRadius: BorderRadius.circular(2)),
                    )),
                    const SizedBox(height: 20),
                    Text(isPurchase ? 'تسديد دين فاتورة شراء' : 'تسديد دين',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.ownerName,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(item.sourceLabel,
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('المتبقي: ${item.remaining.formatted} ر.ي',
                              style: TextStyle(
                                  color: AppTheme.expenseRed, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المدفوع نقدًا *',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                      validator: (_) {
                        final a = tryParseFlexible(amountController.text) ?? 0;
                        final d = isPurchase ? (tryParseFlexible(discountController.text) ?? 0) : 0.0;
                        if (a <= 0 && d <= 0) return 'أدخل مبلغاً صحيحاً أو مبلغ الخصم';
                        if (a < 0 || d < 0) return 'مبلغ غير صحيح';
                        if (a + d > item.remaining + 0.01) return 'المجموع أكبر من المتبقي';
                        return null;
                      },
                    ),
                    if (isPurchase) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: discountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'خصم تسوية من المورد (إن وجد)',
                          hintText: '0',
                          prefixIcon: Icon(Icons.discount_outlined, color: AppTheme.incomeGreen),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        validator: (_) {
                          final d = tryParseFlexible(discountController.text) ?? 0;
                          if (d < 0) return 'رقم غير صحيح';
                          final a = tryParseFlexible(amountController.text) ?? 0;
                          if (a + d > item.remaining + 0.01) {
                            return 'مجموع الدفعة والخصم يتجاوز المتبقي';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المتبقي بعد السداد والخصم:',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          Text(
                            '${remainingAfter.formatted} ر.ي',
                            style: TextStyle(
                              color: remainingAfter <= 0.01 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (enteredAmt > 0) ...[
                      const SizedBox(height: 12),
                      SheetDropdown<String>(
                        label: 'المحفظة *',
                        icon: Icons.wallet,
                        hint: 'اختر المحفظة',
                        value: walletId,
                        items: provider.wallets
                            .map((x) =>
                                DropdownMenuItem(value: x.id, child: Text(x.name)))
                            .toList(),
                        onChanged: (v) => setSheetState(() => walletId = v),
                      ),
                      const SizedBox(height: 16),
                      FundingPicker(
                        provider: provider,
                        pickerKey: fundingKey,
                        walletFilter: walletId,
                        requiredTotalGetter: () => enteredAmt,
                      ),
                    ],
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (ctx, child) => Theme(
                            data: AppTheme.theme.copyWith(
                              colorScheme: ColorScheme.dark(
                                  primary: AppTheme.accentBlue,
                                  surface: AppTheme.card),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: AppTheme.textMuted, size: 18),
                            const SizedBox(width: 10),
                            Text(DateFormat('dd MMM yyyy', 'ar').format(date),
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final amount =
                              tryParseFlexible(amountController.text) ?? 0;
                          final discount =
                              isPurchase ? (tryParseFlexible(discountController.text) ?? 0) : 0.0;

                          if (amount > 0 && walletId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('اختر المحفظة')));
                            return;
                          }

                          List<ExpenseAllocation>? funding;
                          if (amount > 0) {
                            funding = fundingKey.currentState?.allocations ?? [];
                            if (!(fundingKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            final sumFunding =
                                funding.fold(0.0, (s, a) => s + a.amount);
                            if ((sumFunding - amount).abs() > 0.01) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'مجموع التمويل يجب أن يساوي المبلغ (${amount.formatted} ر.ي)')));
                              return;
                            }
                          }

                          if (item.kind == 'wage') {
                            provider.addExpensePayment(ExpensePayment(
                              id: const Uuid().v4(),
                              expenseId: item.expenseId!,
                              amount: amount,
                              date: date,
                              walletId: walletId!,
                              funding: funding ?? [],
                            ));
                          } else {
                            provider.recordPurchasePayment(
                              item.purchaseId!,
                              amount,
                              date,
                              amount > 0 ? walletId : null,
                              discount: discount,
                              funding: funding,
                            );
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.white),
                        child: const Text('تأكيد التسديد'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CumulativePayView extends StatelessWidget {
  const _CumulativePayView();

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final settlements = provider.moneyMovements
            .where((m) => m.creditorType != null)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final totalSettled =
            settlements.fold<double>(0, (s, m) => s + m.amount);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                    'دفعة مقطوعة لدائن (عامل أجر أو مورد) من ظهر الحساب، دون ربطه أو توزيعه على أي عملية — يُسجَّل كسند صرف واحد على حساب الدائن ويُخصم من إجمالي ديونه.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              if (settlements.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.incomeGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.incomeGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          color: AppTheme.incomeGreen, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          'إجمالي الفعات: ${totalSettled.formattedFull} ر.ي · العدد: ${settlements.length}',
                          style: TextStyle(
                              color: AppTheme.incomeGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (settlements.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          color: AppTheme.textMuted, size: 48),
                      SizedBox(height: 12),
                      Text('لا توجد فعات مسجلة من ظهر الحساب',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              else
                ...settlements.map((m) {
                  final creditorName = m.creditorType == 'w'
                      ? provider.workers
                              .firstWhereOrNull((x) => x.id == m.creditorId)
                              ?.name ??
                          'عامل'
                      : provider.partners
                              .firstWhereOrNull((x) => x.id == m.creditorId)
                              ?.name ??
                          'مورد';
                  final wallet = provider.wallets
                      .firstWhereOrNull((w) => w.id == m.walletId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.incomeGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                              m.creditorType == 'w'
                                  ? Icons.engineering
                                  : Icons.shopping_cart_outlined,
                              color: AppTheme.incomeGreen,
                              size: 20),
                        ),
                        title: Text(creditorName,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        subtitle: Text(
                            [
                              m.creditorType == 'w' ? 'عامل' : 'مورد',
                              DateFormat('dd MMM yyyy', 'ar').format(m.date),
                              if (wallet != null) wallet.name,
                              if (m.note != null &&
                                  m.note!.isNotEmpty &&
                                  m.note != 'تسديد تراكمي من ظهر الحساب')
                                m.note!,
                            ].join(' · '),
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11)),
                        trailing: Text(
                            '-${m.amount.formattedFull} ر.ي',
                            style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ),
                  );
                }),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddForm(context, provider),
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('دفعة جديدة من ظهر الحساب',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }

  void _showAddForm(BuildContext context, FinanceProvider provider) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final fundingKey = GlobalKey<FundingPickerState>();
    String? creditorId;
    String? walletId;
    DateTime date = DateTime.now();

    double outstanding(String cid) {
      if (cid.startsWith('w:')) return provider.workerDebt(cid.substring(2));
      return provider.supplierDebt(cid.substring(2));
    }

    final creditors = <MapEntry<String, String>>[
      for (final w in provider.workers)
        if (provider.workerDebt(w.id) > 0)
          MapEntry('w:${w.id}',
              '${w.name} (عامل · دين ${provider.workerDebt(w.id).formattedFull})'),
      for (final p in provider.partners)
        if (p.roles.contains('supplier'))
          MapEntry('s:${p.id}', () {
            final d = provider.supplierDebt(p.id);
            return d > 0
                ? '${p.name} (مورد · دين ${d.formattedFull})'
                : '';
          }()),
    ]..removeWhere((c) => c.value.isEmpty);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 20),
                  Text('دفعة جديدة من ظهر الحساب',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  SheetDropdown<String>(
                    label: 'الدائن *',
                    icon: Icons.person_outline,
                    hint: 'اختر العامل أو المورد',
                    value: creditorId,
                    items: creditors
                        .map((c) =>
                            DropdownMenuItem(value: c.key, child: Text(c.value)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => creditorId = v),
                  ),
                  if (creditorId != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              color: AppTheme.expenseRed, size: 16),
                          const SizedBox(width: 8),
                          Text(
                              'إجمالي الدين المستحق: ${outstanding(creditorId!).formattedFull} ر.ي',
                              style: TextStyle(
                                  color: AppTheme.expenseRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SheetDropdown<String>(
                    label: 'المحفظة *',
                    icon: Icons.wallet,
                    hint: 'اختر المحفظة',
                    value: walletId,
                    items: provider.wallets
                        .map((x) =>
                            DropdownMenuItem(value: x.id, child: Text(x.name)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => walletId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ *',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (_) {
                      final a = tryParseFlexible(amountController.text);
                      if (a == null || a <= 0) return 'أدخل مبلغاً صحيحاً';
                      if (creditorId != null && a > outstanding(creditorId!) + 0.01) {
                        return 'يتجاوز إجمالي الدين (${outstanding(creditorId!).formattedFull})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (ctx, child) => Theme(
                          data: AppTheme.theme.copyWith(
                            colorScheme: ColorScheme.dark(
                                primary: AppTheme.accentBlue,
                                surface: AppTheme.card),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setSheetState(() => date = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: AppTheme.textMuted, size: 18),
                          const SizedBox(width: 10),
                          Text(DateFormat('dd MMM yyyy', 'ar').format(date),
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FundingPicker(
                    provider: provider,
                    pickerKey: fundingKey,
                    walletFilter: walletId,
                    requiredTotalGetter: () =>
                        tryParseFlexible(amountController.text) ?? 0,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة',
                      hintText: 'مثال: دفعة نقدية للمورد، تسوية جزئية...',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        if (creditorId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('اختر الدائن')));
                          return;
                        }
                        if (walletId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('اختر المحفظة')));
                          return;
                        }
                        final amount = tryParseFlexible(amountController.text) ?? 0;
                        final out = outstanding(creditorId!);
                        if (amount > out + 0.01) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'المبلغ يتجاوز إجمالي الدين (${out.formattedFull} ر.ي)')));
                          return;
                        }
                        final funding = fundingKey.currentState?.allocations ?? [];
                        if (!(fundingKey.currentState?.validate() ?? false)) return;
                        final sumFunding = funding.fold(0.0, (s, a) => s + a.amount);
                        if ((sumFunding - amount).abs() > 0.01) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'مجموع التمويل يجب أن يساوي المبلغ (${amount.formatted} ر.ي)')));
                          return;
                        }

                        final isWorker = creditorId!.startsWith('w:');
                        final rawId = creditorId!.substring(2);
                        final cName = isWorker
                            ? provider.workers
                                    .firstWhereOrNull((w) => w.id == rawId)
                                    ?.name ??
                                'العامل'
                            : provider.partners
                                    .firstWhereOrNull((p) => p.id == rawId)
                                    ?.name ??
                                'المورد';
                        final note = noteController.text.trim().isEmpty
                            ? 'تسديد تراكمي من ظهر الحساب'
                            : noteController.text.trim();

                        provider.addMoneyMovement(MoneyMovement(
                          id: const Uuid().v4(),
                          walletId: walletId!,
                          amount: amount,
                          date: date,
                          note: note,
                          creditorType: isWorker ? 'w' : 's',
                          creditorId: rawId,
                          funding: funding,
                        ));

                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'تم تسجيل دفعة ${amount.formattedFull} ر.ي من ظهر الحساب لـ $cName'),
                            backgroundColor: AppTheme.incomeGreen));
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white),
                      child: const Text('تسجيل الدفعة'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}