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
import 'incomes_screen_v2.dart';
import 'incomes_screen.dart';

class IncomesScreenV1 extends StatefulWidget {
  const IncomesScreenV1({super.key});

  @override
  State<IncomesScreenV1> createState() => _IncomesScreenV1State();
}

class _IncomesScreenV1State extends State<IncomesScreenV1> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, fully_paid, partially_paid, unpaid
  String? _selectedPlotId;
  String? _selectedWalletId;
  String _dateFilter = 'all'; // all, this_month, last_month, this_year
  String _sortBy = 'newest'; // newest, oldest, amount_desc, remaining_desc

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _statusFilter = 'all';
      _selectedPlotId = null;
      _selectedWalletId = null;
      _dateFilter = 'all';
      _sortBy = 'newest';
    });
  }

  void _showAddPaymentDialog(Income income) {
    final provider = context.read<FinanceProvider>();
    final amountController = TextEditingController(
      text: income.remainingAmount > 0 ? income.remainingAmount.toInt().toString() : '',
    );
    final noteController = TextEditingController();
    String? walletId = provider.defaultWallet()?.id ?? (provider.wallets.isNotEmpty ? provider.wallets.first.id : null);
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.add_card_rounded, color: AppTheme.incomeGreen),
              const SizedBox(width: 8),
              const Text('تحصيل دفعة إيراد (إيرادات ١)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  income.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'المبلغ المتبقي: ${income.remainingAmount.formattedFull} ر.ي من إجمالي ${income.amount.formattedFull} ر.ي',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'مبلغ الدفعة المستلمة (ر.ي) *',
                    prefixIcon: Icon(Icons.attach_money, color: AppTheme.incomeGreen),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: walletId,
                  decoration: const InputDecoration(
                    labelText: 'إيداع إلى المحفظة *',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: provider.wallets
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => walletId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة أو بيان الدفعة',
                    prefixIcon: Icon(Icons.notes_rounded),
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
                backgroundColor: AppTheme.incomeGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final amt = double.tryParse(amountController.text.trim()) ?? 0;
                if (amt <= 0) return;
                if (walletId == null) return;
                if (amt > income.remainingAmount + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('مبلغ الدفعة يتجاوز المتبقي')),
                  );
                  return;
                }

                provider.addIncomePayment(IncomePayment(
                  id: const Uuid().v4(),
                  incomeId: income.id,
                  amount: amt,
                  date: paymentDate,
                  notes: noteController.text.trim().isEmpty ? 'تحصيل دفعة' : noteController.text.trim(),
                  walletId: walletId,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('حفظ الدفعة', style: TextStyle(fontWeight: FontWeight.bold)),
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
        content: Text('هل أنت أؤكد حذف الإيراد "${income.title}" والمدفوعات والحصص المرتبطة به؟'),
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
                provider.deleteIncome(income.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الإيراد بنجاح')),
                );
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.expenseRed),
                );
              }
            },
            child: const Text('حذف النهائي'),
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
              color: AppTheme.incomeGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.incomeGreen),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: AppTheme.incomeGreen),
                SizedBox(width: 4),
                Text('تصميم إيرادات ١', style: TextStyle(color: AppTheme.incomeGreen, fontSize: 12, fontWeight: FontWeight.bold)),
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
              } else if (val == 'v2') {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IncomesScreenV2()));
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'v1',
                child: Row(
                  children: [
                    Icon(Icons.check, color: AppTheme.incomeGreen, size: 18),
                    SizedBox(width: 8),
                    Text('إيرادات ١ (اللوحة التنفيذية)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.incomeGreen)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'v2',
                child: Row(
                  children: [
                    SizedBox(width: 26),
                    Text('إيرادات ٢ (الدفتر الزمني وتجميع الأراضي)'),
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
        title: const Text('إيرادات 1 - اللوحة المتقدمة'),
        actions: [
          DataExportImportButton(
            label: 'الإيرادات',
            buildRows: () => context.read<FinanceProvider>().incomes.map((e) => e.toJson()).toList(),
            csvHeaders: const ['المعرّف', 'العنوان', 'المبلغ', 'التاريخ', 'المصدر', 'الحالة'],
            csvKeys: const ['id', 'title', 'amount', 'date', 'source', 'status'],
            onImport: (rows) async {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
        ),
        backgroundColor: AppTheme.incomeGreen,
        foregroundColor: Colors.black,
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

                // Stats calculation
                final totalIncomeAmt = allIncomes.fold(0.0, (sum, i) => sum + i.amount);
                final totalReceivedAmt = allIncomes.fold(0.0, (sum, i) => sum + i.receivedAmount);
                final totalRemainingAmt = allIncomes.fold(0.0, (sum, i) => sum + i.remainingAmount);
                final collectionRatio = totalIncomeAmt > 0 ? (totalReceivedAmt / totalIncomeAmt) : 0.0;

                // Filter logic
                final now = DateTime.now();
                var filteredIncomes = allIncomes.where((income) {
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final titleMatch = income.title.toLowerCase().contains(q);
                    final sourceMatch = income.source.toLowerCase().contains(q);
                    final notesMatch = (income.note ?? '').toLowerCase().contains(q);
                    if (!titleMatch && !sourceMatch && !notesMatch) return false;
                  }
                  if (_statusFilter == 'fully_paid' && income.remainingAmount > 0.01) return false;
                  if (_statusFilter == 'unpaid' && income.receivedAmount > 0.01) return false;
                  if (_statusFilter == 'partially_paid' && (income.receivedAmount <= 0.01 || income.remainingAmount <= 0.01)) return false;
                  if (_selectedPlotId != null && income.landPlotId != _selectedPlotId) return false;
                  if (_selectedWalletId != null && income.walletId != _selectedWalletId) return false;

                  if (_dateFilter == 'this_month') {
                    if (income.date.year != now.year || income.date.month != now.month) return false;
                  } else if (_dateFilter == 'last_month') {
                    final lastM = DateTime(now.year, now.month - 1);
                    if (income.date.year != lastM.year || income.date.month != lastM.month) return false;
                  } else if (_dateFilter == 'this_year') {
                    if (income.date.year != now.year) return false;
                  }

                  return true;
                }).toList();

                // Sort logic
                filteredIncomes.sort((a, b) {
                  if (_sortBy == 'newest') return b.date.compareTo(a.date);
                  if (_sortBy == 'oldest') return a.date.compareTo(b.date);
                  if (_sortBy == 'amount_desc') return b.amount.compareTo(a.amount);
                  if (_sortBy == 'remaining_desc') return b.remainingAmount.compareTo(a.remainingAmount);
                  return 0;
                });

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Executive Analytics Hero Banner
                    _buildExecutiveStatsBanner(
                      totalIncome: totalIncomeAmt,
                      totalReceived: totalReceivedAmt,
                      totalRemaining: totalRemainingAmt,
                      ratio: collectionRatio,
                      count: allIncomes.length,
                    ),
                    const SizedBox(height: 16),

                    // Quick Filter Pills
                    _buildStatusPillTabs(allIncomes),
                    const SizedBox(height: 16),

                    // Search & Filter Bar
                    _buildSearchBar(),
                    const SizedBox(height: 16),

                    // Income List
                    if (filteredIncomes.isEmpty)
                      _buildEmptyState()
                    else
                      ...filteredIncomes.map((inc) => _buildExecutiveIncomeCard(inc, provider)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveStatsBanner({
    required double totalIncome,
    required double totalReceived,
    required double totalRemaining,
    required double ratio,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي المقبوضات والإيرادات', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 2),
                  Text('التقرير التنفيذي الشامل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.incomeGreen.withOpacity(0.4)),
                ),
                child: Text('$count عملية', style: const TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${totalIncome.formattedFull} ر.ي',
            style: const TextStyle(color: AppTheme.incomeGreen, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),

          // Progress Gauge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('نسبة المحصّل للمحفظة: ${(ratio * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${totalReceived.formattedFull} ر.ي', style: const TextStyle(color: AppTheme.incomeGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.incomeGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-stats breakdown
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المستلم المحصل', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('${totalReceived.formattedFull} ر.ي', style: const TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المتبقي الآجل', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('${totalRemaining.formattedFull} ر.ي', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPillTabs(List<Income> all) {
    final fullyPaidCount = all.where((i) => i.remainingAmount <= 0.01).length;
    final pendingCount = all.where((i) => i.remainingAmount > 0.01).length;

    final tabs = [
      {'id': 'all', 'label': 'الكل (${all.length})'},
      {'id': 'fully_paid', 'label': 'مستلمة بالكامل ($fullyPaidCount)'},
      {'id': 'partially_paid', 'label': 'آجل ومتبقي ($pendingCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSel = _statusFilter == t['id'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              selected: isSel,
              label: Text(t['label']!),
              selectedColor: AppTheme.incomeGreen,
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                color: isSel ? Colors.black : AppTheme.textPrimary,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _statusFilter = t['id']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'بحث باسم الإيراد، المزرعة، أو الملاحظة...',
          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.incomeGreen),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildExecutiveIncomeCard(Income inc, FinanceProvider provider) {
    final isFullyPaid = inc.remainingAmount <= 0.01;
    final progress = inc.amount > 0 ? (inc.receivedAmount / inc.amount).clamp(0.0, 1.0) : 0.0;
    final plot = provider.landPlots.firstWhereOrNull((p) => p.id == inc.landPlotId);
    final zahra = provider.zahras.firstWhereOrNull((z) => z.id == inc.zahraId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFullyPaid ? AppTheme.incomeGreen.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFullyPaid ? AppTheme.incomeGreen.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFullyPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                  color: isFullyPaid ? AppTheme.incomeGreen : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inc.title,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(inc.source, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        if (plot != null) ...[
                          Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                          Text(plot.name, style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                        if (zahra != null) ...[
                          Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                          Text(zahra.name, style: const TextStyle(color: Colors.pinkAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${inc.amount.formattedFull} ر.ي',
                    style: const TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd/MM/yyyy').format(inc.date),
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini collection progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFullyPaid
                        ? 'مستلم بالكامل (${inc.receivedAmount.formattedFull} ر.ي)'
                        : 'المُحصّل: ${inc.receivedAmount.formattedFull} ر.ي | المتبقي: ${inc.remainingAmount.formattedFull} ر.ي',
                    style: TextStyle(
                      color: isFullyPaid ? AppTheme.incomeGreen : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('${(progress * 100).toInt()}%', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppTheme.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(isFullyPaid ? AppTheme.incomeGreen : Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Card Action Buttons
          Row(
            children: [
              if (!isFullyPaid) ...[
                ElevatedButton.icon(
                  onPressed: () => _showAddPaymentDialog(inc),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('تسجيل دفعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.incomeGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => IncomeDetailScreen(incomeId: inc.id)),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('التفاصيل', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddIncomeScreen(existing: inc)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.expenseRed),
                onPressed: () => _confirmDeleteIncome(inc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppTheme.textMuted, size: 54),
            const SizedBox(height: 12),
            Text('لا توجد سجلات إيرادات مطابقة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('جرّب تغيير فلاتر البحث أو أضف إيراداً جديداً', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
