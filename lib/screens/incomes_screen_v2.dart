import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
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
  int _activeViewIndex = 0; // 0 = Timeline Ledger, 1 = Grouped by Land Plot

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              const Icon(Icons.add_card_rounded, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text('تسجيل دفعة إيراد (إيرادات ٢)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(income.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'المتبقي للتحصيل: ${income.remainingAmount.formattedFull} ر.ي',
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
                    labelText: 'ملاحظة البيان',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final amt = double.tryParse(amountController.text.trim()) ?? 0;
                if (amt <= 0 || walletId == null) return;
                provider.addIncomePayment(IncomePayment(
                  id: const Uuid().v4(),
                  incomeId: income.id,
                  amount: amt,
                  date: paymentDate,
                  notes: noteController.text.trim().isEmpty ? 'سداد إيراد' : noteController.text.trim(),
                  walletId: walletId,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('حفظ السداد', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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

                // Search filtering
                var filtered = allIncomes.where((income) {
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    return income.title.toLowerCase().contains(q) ||
                        income.source.toLowerCase().contains(q) ||
                        (income.note ?? '').toLowerCase().contains(q);
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

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ابحث في الدفتر المالي للإيرادات...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.blueAccent),
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
                          ? const Center(child: Text('لا توجد إيرادات مسجلة'))
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

  Widget _buildCompactStatsRibbon({
    required double total,
    required double received,
    required double remaining,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
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
        final isPaid = inc.remainingAmount <= 0.01;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: AppTheme.card,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isPaid ? AppTheme.incomeGreen.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              child: Icon(
                isPaid ? Icons.check : Icons.hourglass_top,
                color: isPaid ? AppTheme.incomeGreen : Colors.orange,
              ),
            ),
            title: Text(inc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${inc.source} • ${DateFormat('yyyy/MM/dd').format(inc.date)}',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${inc.amount.formattedFull} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.incomeGreen)),
                const SizedBox(height: 2),
                Text(
                  isPaid ? 'مستلم بالكامل' : 'متبقي: ${inc.remainingAmount.formattedFull}',
                  style: TextStyle(color: isPaid ? AppTheme.incomeGreen : Colors.orange, fontSize: 11),
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => IncomeDetailScreen(incomeId: inc.id)),
            ),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.landscape_rounded, color: Colors.amber),
            title: Text(plotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('إجمالي عوائد الأرض: ${totalPlotIncome.formattedFull} ر.ي', style: const TextStyle(color: AppTheme.incomeGreen, fontSize: 12, fontWeight: FontWeight.bold)),
            children: plotList.map((inc) {
              return ListTile(
                title: Text(inc.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('${inc.source} • ${DateFormat('yyyy/MM/dd').format(inc.date)}', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                trailing: Text('${inc.amount.formattedFull} ر.ي', style: const TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => IncomeDetailScreen(incomeId: inc.id)),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
