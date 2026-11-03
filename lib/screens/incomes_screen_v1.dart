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
import 'incomes_screen_v2.dart';

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

  int get _activeFiltersCount {
    int count = 0;
    if (_statusFilter != 'all') count++;
    if (_selectedPlotId != null) count++;
    if (_selectedWalletId != null) count++;
    if (_dateFilter != 'all') count++;
    if (_sortBy != 'newest') count++;
    return count;
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
                  color: AppTheme.incomeGreen.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_card_rounded, color: AppTheme.incomeGreen, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('تحصيل دفعة إيراد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      Text(
                        income.title,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
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
                  style: TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'مبلغ الدفعة المستلمة (ر.ي) *',
                    hintText: '0',
                    prefixIcon: Icon(Icons.attach_money, color: AppTheme.incomeGreen),
                    filled: true,
                    fillColor: AppTheme.surface,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: walletId,
                  decoration: InputDecoration(
                    labelText: 'إيداع إلى المحفظة *',
                    prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                    filled: true,
                    fillColor: AppTheme.surface,
                  ),
                  items: provider.wallets
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text('${w.name} (${provider.walletBalance(w.id).formattedFull} ر.ي)'),
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
                        Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.incomeGreen),
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
                    labelText: 'ملاحظة أو بيان الدفعة (اختياري)',
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
                backgroundColor: AppTheme.incomeGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final input = amountController.text.trim();
                if (input.isEmpty) return;

                double amt = 0;
                try {
                  amt = MoneyValue.parseInput(input).minorUnits.toDouble();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('المبلغ يجب أن يكون رقماً صحيحاً صالحاً'), backgroundColor: AppTheme.expenseRed),
                  );
                  return;
                }

                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('يجب أن يكون المبلغ أكبر من صفر'), backgroundColor: AppTheme.expenseRed),
                  );
                  return;
                }
                if (walletId == null || walletId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('اختر المحفظة لإيداع الدفعة'), backgroundColor: AppTheme.expenseRed),
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
                    notes: noteController.text.trim().isEmpty ? 'تحصيل دفعة' : noteController.text.trim(),
                    walletId: walletId,
                  ));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('تم تسجيل دفعة الإيراد بنجاح'), backgroundColor: AppTheme.incomeGreen),
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
        title: Row(
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

  void _showFilterBottomSheet(FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list_rounded, color: AppTheme.incomeGreen),
                          SizedBox(width: 8),
                          Text('تصفية وفرز متقدم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          _resetFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text('إعادة ضبط الكل', style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Sort Options
                  const Text('الترتيب حسب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      {'id': 'newest', 'label': 'الأحدث تاريخاً'},
                      {'id': 'oldest', 'label': 'الأقدم تاريخاً'},
                      {'id': 'amount_desc', 'label': 'الأعلى مبلغاً'},
                      {'id': 'remaining_desc', 'label': 'الأعلى متبقياً'},
                    ].map((s) {
                      final isSel = _sortBy == s['id'];
                      return ChoiceChip(
                        selected: isSel,
                        label: Text(s['label']!),
                        selectedColor: AppTheme.incomeGreen,
                        labelStyle: TextStyle(color: isSel ? Colors.black : AppTheme.textPrimary, fontSize: 12),
                        onSelected: (_) {
                          setState(() => _sortBy = s['id']!);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Date Filter
                  const Text('النطاق الزمني:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      {'id': 'all', 'label': 'كل الفترات'},
                      {'id': 'this_month', 'label': 'هذا الشهر'},
                      {'id': 'last_month', 'label': 'الشهر الماضي'},
                      {'id': 'this_year', 'label': 'هذا العام'},
                    ].map((d) {
                      final isSel = _dateFilter == d['id'];
                      return ChoiceChip(
                        selected: isSel,
                        label: Text(d['label']!),
                        selectedColor: AppTheme.incomeGreen,
                        labelStyle: TextStyle(color: isSel ? Colors.black : AppTheme.textPrimary, fontSize: 12),
                        onSelected: (_) {
                          setState(() => _dateFilter = d['id']!);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Land Plot Filter
                  const Text('حسب الموضع (الأرض):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _selectedPlotId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surface,
                      prefixIcon: const Icon(Icons.terrain_rounded, color: Colors.amber),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('جميع المواضع')),
                      ...provider.landPlots.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedPlotId = v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Wallet Filter
                  const Text('حسب المحفظة المستلمة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _selectedWalletId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surface,
                      prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.blueAccent),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('جميع المحافظ')),
                      ...provider.wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedWalletId = v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.incomeGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('تطبيق التصفية', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
              color: AppTheme.incomeGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.incomeGreen),
            ),
            child: Row(
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
              PopupMenuItem(
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
                  if (_statusFilter == 'fully_paid' && income.remainingAmount > 0.000001) return false;
                  if (_statusFilter == 'unpaid' && income.receivedAmount > 0.000001) return false;
                  if (_statusFilter == 'partially_paid' && (income.receivedAmount <= 0.000001 || income.remainingAmount <= 0.000001)) return false;
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

                    // Quick Filter Pills & Filter Button
                    Row(
                      children: [
                        Expanded(child: _buildStatusPillTabs(allIncomes)),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showFilterBottomSheet(provider),
                          style: IconButton.styleFrom(
                            backgroundColor: _activeFiltersCount > 0 ? AppTheme.incomeGreen : AppTheme.surface,
                            foregroundColor: _activeFiltersCount > 0 ? Colors.black : AppTheme.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppTheme.cardBorder),
                            ),
                          ),
                          icon: Badge(
                            isLabelVisible: _activeFiltersCount > 0,
                            label: Text('$_activeFiltersCount'),
                            child: const Icon(Icons.tune_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Active Filters Summary tag if any
                    if (_activeFiltersCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Text('$_activeFiltersCount فلاتر مفعّلة', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _resetFilters,
                              child: const Text('إلغاء الفلاتر', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),

                    // Search Bar
                    _buildSearchBar(),
                    const SizedBox(height: 16),

                    // Income List
                    if (filteredIncomes.isEmpty)
                      _buildEmptyState()
                    else
                      ...filteredIncomes.map((inc) => _buildExecutiveIncomeCard(inc, provider)),
                    const SizedBox(height: 60),
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
                child: Text('$count عملية', style: TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${totalIncome.formattedFull} ر.ي',
            style: TextStyle(color: AppTheme.incomeGreen, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
                  Text('${totalReceived.formattedFull} ر.ي', style: TextStyle(color: AppTheme.incomeGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.incomeGreen),
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
                      Text('${totalReceived.formattedFull} ر.ي', style: TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.bold, fontSize: 13)),
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
    final fullyPaidCount = all.where((i) => i.remainingAmount <= 0.000001).length;
    final pendingCount = all.where((i) => i.remainingAmount > 0.000001).length;

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
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.incomeGreen),
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
    final isFullyPaid = inc.remainingAmount <= 0.000001;
    final progress = inc.amount > 0 ? (inc.receivedAmount / inc.amount).clamp(0.0, 1.0) : 0.0;
    final plot = provider.landPlots.firstWhereOrNull((p) => p.id == inc.landPlotId);
    final zahra = provider.zahras.firstWhereOrNull((z) => z.id == inc.zahraId);
    final wallet = provider.wallets.firstWhereOrNull((w) => w.id == inc.walletId);

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
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Text(inc.source, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        ),
                        if (plot != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Text(plot.name, style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        if (zahra != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                            ),
                            child: Text(zahra.name, style: const TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        if (wallet != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                            ),
                            child: Text(wallet.name, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
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
                    style: TextStyle(color: AppTheme.incomeGreen, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('yyyy/MM/dd').format(inc.date),
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Collection progress bar
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
                tooltip: 'تعديل',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddIncomeScreen(existing: inc)),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.expenseRed),
                tooltip: 'حذف',
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
