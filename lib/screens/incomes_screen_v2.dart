import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';
import 'add_income_screen.dart';
import 'income_detail_screen.dart';
import 'incomes_screen.dart';
import 'incomes_screen_v1.dart';

class IncomesScreenV2 extends StatefulWidget {
  const IncomesScreenV2({super.key});

  @override
  State<IncomesScreenV2> createState() => _IncomesScreenV2State();
}

class _IncomesScreenV2State extends State<IncomesScreenV2> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, fully_paid, unpaid_or_partial
  int _activeViewIndex = 0; // 0 = Timeline Ledger, 1 = Grouped by Land Plot

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddPaymentDialog(Income income) async {
    final provider = context.read<FinanceProvider>();
    final amountController = TextEditingController(
      text: income.remainingAmount > 0 ? income.remainingAmount.toInt().toString() : '',
    );
    final noteController = TextEditingController();
    String? walletId = income.walletId ??
        provider.defaultWallet()?.id ??
        (provider.wallets.isNotEmpty ? provider.wallets.first.id : null);
    DateTime paymentDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_card_rounded, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('تسجيل دفعة إيراد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(income.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المتبقي للتحصيل:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          Text(
                            '${income.remainingAmount.formattedFull} ر.ي',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'مبلغ الدفعة المستلمة (ر.ي) *',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.attach_money, color: AppTheme.incomeGreen),
                    filled: true,
                    fillColor: AppTheme.surface,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: walletId,
                  decoration: InputDecoration(
                    labelText: 'إيداع إلى المحفظة *',
                    prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.blueAccent),
                    filled: true,
                    fillColor: AppTheme.surface,
                  ),
                  items: provider.wallets
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text('${w.name} (${w.balance.formattedFull} ر.ي)'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => walletId = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => paymentDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.blueAccent),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('yyyy/MM/dd').format(paymentDate),
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظة البيان (اختياري)',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    filled: true,
                    fillColor: AppTheme.surface,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final input = amountController.text.trim();
                if (input.isEmpty) return;

                double amt = 0;
                try {
                  amt = MoneyValue.parseInput(input).minorUnits.toDouble();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('المبلغ يجب أن يكون رقماً صحيحاً صالحاً'), backgroundColor: AppTheme.expenseRed),
                  );
                  return;
                }

                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يجب أن يكون المبلغ أكبر من صفر'), backgroundColor: AppTheme.expenseRed),
                  );
                  return;
                }
                if (walletId == null || walletId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اختر المحفظة لإيداع الدفعة'), backgroundColor: AppTheme.expenseRed),
                  );
                  return;
                }
                if (amt > income.remainingAmount + 0.000001) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('مبلغ الدفعة يتجاوز المتبقي (${income.remainingAmount.formattedFull} ر.ي)'),
                      backgroundColor: AppTheme.expenseRed,
                    ),
                  );
                  return;
                }

                try {
                  provider.addIncomePayment(IncomePayment(
                    id: const Uuid().v4(),
                    incomeId: income.id,
                    amount: amt,
                    date: paymentDate,
                    notes: noteController.text.trim().isEmpty ? 'سداد دفعة' : noteController.text.trim(),
                    walletId: walletId,
                  ));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل دفعة الإيراد بنجاح'), backgroundColor: AppTheme.incomeGreen),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: AppTheme.expenseRed,
                    ),
                  );
                }
              },
              child: const Text('حفظ السداد', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteIncome(Income income) {
    final provider = context.read<FinanceProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed),
            SizedBox(width: 8),
            Text('تأكيد حذف الإيراد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل تريد بالتأكيد حذف الإيراد "${income.title}"؟\nسيتم أيضاً إزالة سجلات الدفعات والمصروفات والتوزيعات المرتبطة به.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              try {
                final deleted = provider.deleteIncome(income.id);
                if (!deleted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الإيراد بنجاح')),
                );
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: AppTheme.expenseRed,
                  ),
                );
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignSwitcherHeader() {
    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent),
            ),
            child: const Row(
              children: [
                Icon(Icons.palette_rounded, size: 14, color: Colors.blueAccent),
                SizedBox(width: 4),
                Text('تصميم إيرادات ٢', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تبديل التصميم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Icon(Icons.swap_horiz_rounded, size: 16),
                ],
              ),
            ),
            onSelected: (val) {
              if (val == 'main') {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IncomesScreen()));
              } else if (val == 'v1') {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IncomesScreenV1()));
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'v2',
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Text('إيرادات ٢ (الدفتر الزمني وتجميع الأراضي)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'v1',
                child: Row(
                  children: [
                    SizedBox(width: 26),
                    Text('إيرادات ١ (اللوحة التنفيذية)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'main',
                child: Row(
                  children: [
                    SizedBox(width: 26),
                    Text('التصميم الأساسي'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('إيرادات 2 - الدفتر الزمني والأراضي'),
        actions: [
          DataExportImportButton(
            label: 'الإيرادات',
            buildRows: () => context.read<FinanceProvider>().incomes.map((e) => e.toJson()).toList(),
            csvHeaders: const [
              'المعرّف',
              'العنوان',
              'المبلغ',
              'التاريخ',
              'المصدر',
              'ملاحظات',
              'معرّف الموضع',
              'معرّف الزرعة',
              'معرّف المحفظة',
              'الحالة',
            ],
            csvKeys: const [
              'id',
              'title',
              'amount',
              'date',
              'source',
              'note',
              'landPlotId',
              'zahraId',
              'walletId',
              'status',
            ],
            onImport: (rows) async {
              final provider = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final income = Income.fromJson(row);
                  if (provider.incomes.any((e) => e.id == income.id)) continue;
                  provider.addIncome(income);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('إيراد جديد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: Column(
        children: [
          _buildDesignSwitcherHeader(),
          Expanded(
            child: Consumer<FinanceProvider>(
              builder: (context, provider, _) {
                final allIncomes = provider.incomes;

                final totalIncomeAmt = allIncomes.fold(0.0, (sum, i) => sum + i.amount);
                final totalReceivedAmt = allIncomes.fold(0.0, (sum, i) => sum + i.receivedAmount);
                final totalRemainingAmt = allIncomes.fold(0.0, (sum, i) => sum + i.remainingAmount);

                // Search & Status filtering
                var filtered = allIncomes.where((income) {
                  if (_statusFilter == 'fully_paid' && income.remainingAmount > 0.000001) return false;
                  if (_statusFilter == 'unpaid_or_partial' && income.remainingAmount <= 0.000001) return false;

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final plot = provider.landPlots.firstWhereOrNull((p) => p.id == income.landPlotId);
                    final plotName = plot?.name.toLowerCase() ?? '';
                    final titleMatch = income.title.toLowerCase().contains(q);
                    final sourceMatch = income.source.toLowerCase().contains(q);
                    final noteMatch = (income.note ?? '').toLowerCase().contains(q);
                    final plotMatch = plotName.contains(q);
                    return titleMatch || sourceMatch || noteMatch || plotMatch;
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    // Compact Stats Ribbon
                    _buildCompactStatsRibbon(
                      total: totalIncomeAmt,
                      received: totalReceivedAmt,
                      remaining: totalRemainingAmt,
                    ),

                    // View Mode Switcher Segment (Timeline vs Land Plot Grouping)
                    _buildViewSegmentControl(),
                    const SizedBox(height: 8),

                    // Status Chips
                    _buildStatusChips(allIncomes),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ابحث في الدفتر المالي (عنوان، أرض، مصدر)...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.blueAccent),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppTheme.cardBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    // Main Content
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox_outlined, color: AppTheme.textMuted, size: 48),
                                    const SizedBox(height: 12),
                                    Text('لا توجد إيرادات مطابقة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('جرّب تغيير خيارات البحث أو التصفية', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : (_activeViewIndex == 0
                              ? _buildTimelineView(filtered, provider)
                              : _buildGroupedByPlotView(filtered, provider)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips(List<Income> all) {
    final paidCount = all.where((i) => i.remainingAmount <= 0.000001).length;
    final partialCount = all.where((i) => i.remainingAmount > 0.000001).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            selected: _statusFilter == 'all',
            label: Text('الكل (${all.length})'),
            selectedColor: Colors.blueAccent,
            backgroundColor: AppTheme.surface,
            labelStyle: TextStyle(
              color: _statusFilter == 'all' ? Colors.white : AppTheme.textPrimary,
              fontWeight: _statusFilter == 'all' ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
            onSelected: (_) => setState(() => _statusFilter = 'all'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            selected: _statusFilter == 'fully_paid',
            label: Text('مستلم بالكامل ($paidCount)'),
            selectedColor: AppTheme.incomeGreen,
            backgroundColor: AppTheme.surface,
            labelStyle: TextStyle(
              color: _statusFilter == 'fully_paid' ? Colors.black : AppTheme.textPrimary,
              fontWeight: _statusFilter == 'fully_paid' ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
            onSelected: (_) => setState(() => _statusFilter = 'fully_paid'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            selected: _statusFilter == 'unpaid_or_partial',
            label: Text('آجل / متبقي ($partialCount)'),
            selectedColor: Colors.orange,
            backgroundColor: AppTheme.surface,
            labelStyle: TextStyle(
              color: _statusFilter == 'unpaid_or_partial' ? Colors.black : AppTheme.textPrimary,
              fontWeight: _statusFilter == 'unpaid_or_partial' ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
            onSelected: (_) => setState(() => _statusFilter = 'unpaid_or_partial'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatsRibbon({
    required double total,
    required double received,
    required double remaining,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ribbonItem('الإجمالي', total, AppTheme.incomeGreen),
          Container(width: 1, height: 30, color: AppTheme.cardBorder),
          _ribbonItem('المستلم', received, Colors.blueAccent),
          Container(width: 1, height: 30, color: AppTheme.cardBorder),
          _ribbonItem('الآجل', remaining, Colors.orange),
        ],
      ),
    );
  }

  Widget _ribbonItem(String title, double val, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          '${val.formattedFull} ر.ي',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildViewSegmentControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeViewIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeViewIndex == 0 ? Colors.blueAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timeline_rounded, size: 16, color: _activeViewIndex == 0 ? Colors.white : AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text('الدفتر الزمني', style: TextStyle(color: _activeViewIndex == 0 ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeViewIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeViewIndex == 1 ? Colors.blueAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.landscape_rounded, size: 16, color: _activeViewIndex == 1 ? Colors.white : AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text('حسب الأرض والموضِع', style: TextStyle(color: _activeViewIndex == 1 ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(List<Income> items, FinanceProvider provider) {
    items.sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final inc = items[index];
        final isPaid = inc.remainingAmount <= 0.000001;
        final plot = provider.landPlots.firstWhereOrNull((p) => p.id == inc.landPlotId);
        final wallet = provider.wallets.firstWhereOrNull((w) => w.id == inc.walletId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPaid ? Colors.blueAccent.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isPaid ? AppTheme.incomeGreen.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    child: Icon(
                      isPaid ? Icons.check : Icons.hourglass_top,
                      color: isPaid ? AppTheme.incomeGreen : Colors.orange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(DateFormat('yyyy/MM/dd').format(inc.date), style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                            Text(inc.source, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            if (plot != null) ...[
                              Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                              Text(plot.name, style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                            if (wallet != null) ...[
                              Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                              Text(wallet.name, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${inc.amount.formattedFull} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.incomeGreen, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        isPaid ? 'مستلم بالكامل' : 'متبقي: ${inc.remainingAmount.formattedFull}',
                        style: TextStyle(color: isPaid ? AppTheme.incomeGreen : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isPaid) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showAddPaymentDialog(inc),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('تسجيل سداد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => IncomeDetailScreen(incomeId: inc.id)),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('التفاصيل', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                    tooltip: 'تعديل',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddIncomeScreen(existing: inc)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.expenseRed),
                    tooltip: 'حذف',
                    onPressed: () => _confirmDeleteIncome(inc),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedByPlotView(List<Income> items, FinanceProvider provider) {
    final Map<String, List<Income>> grouped = {};
    for (var inc in items) {
      final key = inc.landPlotId ?? 'unspecified';
      grouped.putIfAbsent(key, () => []).add(inc);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final plotId = entry.key;
        final plotList = entry.value;
        final plot = provider.landPlots.firstWhereOrNull((p) => p.id == plotId);
        final plotName = plot != null ? plot.name : 'إيرادات بدون موضع محدد';
        final totalPlotIncome = plotList.fold(0.0, (sum, i) => sum + i.amount);
        final totalPlotReceived = plotList.fold(0.0, (sum, i) => sum + i.receivedAmount);
        final totalPlotRemaining = plotList.fold(0.0, (sum, i) => sum + i.remainingAmount);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.landscape_rounded, color: Colors.amber, size: 20),
            ),
            title: Text(plotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'الإجمالي: ${totalPlotIncome.formattedFull} ر.ي • المستلم: ${totalPlotReceived.formattedFull} ر.ي',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                if (totalPlotRemaining > 0)
                  Text(
                    'المتبقي آجل: ${totalPlotRemaining.formattedFull} ر.ي',
                    style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            children: plotList.map((inc) {
              final isPaid = inc.remainingAmount <= 0.000001;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inc.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${inc.source} • ${DateFormat('yyyy/MM/dd').format(inc.date)}', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${inc.amount.formattedFull} ر.ي', style: const TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          isPaid ? 'مستلم' : 'متبقي: ${inc.remainingAmount.formattedFull}',
                          style: TextStyle(color: isPaid ? AppTheme.incomeGreen : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (val) {
                        if (val == 'pay') {
                          _showAddPaymentDialog(inc);
                        } else if (val == 'details') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => IncomeDetailScreen(incomeId: inc.id)),
                          );
                        } else if (val == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddIncomeScreen(existing: inc)),
                          );
                        } else if (val == 'delete') {
                          _confirmDeleteIncome(inc);
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (!isPaid)
                          const PopupMenuItem(
                            value: 'pay',
                            child: Row(
                              children: [
                                Icon(Icons.add_card, size: 16, color: Colors.blueAccent),
                                SizedBox(width: 8),
                                Text('تسجيل سداد'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 16),
                              SizedBox(width: 8),
                              Text('عرض التفاصيل'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: AppTheme.expenseRed),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
