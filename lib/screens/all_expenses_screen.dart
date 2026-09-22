import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'add_expense_screen.dart';
import 'edit_movement_sheet.dart';
import 'manage_expense_categories_screen.dart';
import '../widgets/data_export_import_button.dart';

enum OutgoingType { expense, disbursement }

class OutgoingItem {
  final OutgoingType type;
  final Expense? expense;
  final MoneyMovement? movement;
  final DateTime date;
  final double amount;
  final String title;

  OutgoingItem.fromExpense(Expense e)
      : type = OutgoingType.expense,
        expense = e,
        movement = null,
        date = e.date,
        amount = e.amount,
        title = e.title;

  OutgoingItem.fromMovement(MoneyMovement m)
      : type = OutgoingType.disbursement,
        expense = null,
        movement = m,
        date = m.date,
        amount = m.amount,
        title = m.note?.trim().isNotEmpty == true ? m.note! : 'تصريف من المحفظة';
}

class AllExpensesScreen extends StatefulWidget {
  const AllExpensesScreen({super.key});

  @override
  State<AllExpensesScreen> createState() => _AllExpensesScreenState();
}

class _AllExpensesScreenState extends State<AllExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // الفلاتر والفرز
  String? _selectedCategory;
  String? _selectedWalletId;
  String _dateFilter = 'all'; // all, this_month, last_month, this_year
  String _sortBy = 'newest'; // newest, oldest, amount_desc, amount_asc
  bool _showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedWalletId != null) count++;
    if (_dateFilter != 'all') count++;
    if (_sortBy != 'newest') count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = null;
      _selectedWalletId = null;
      _dateFilter = 'all';
      _sortBy = 'newest';
    });
  }

  (IconData, Color) _getCategoryStyle(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('أجور') || cat.contains('عمال')) {
      return (Icons.groups_outlined, Colors.indigoAccent);
    } else if (cat.contains('مبيد') || cat.contains('سماد')) {
      return (Icons.science_outlined, Colors.teal);
    } else if (cat.contains('بذور') || cat.contains('شتل')) {
      return (Icons.eco_outlined, Colors.lightGreen);
    } else if (cat.contains('ديزل') || cat.contains('وقود') || cat.contains('بنزين')) {
      return (Icons.local_gas_station_outlined, Colors.amber);
    } else if (cat.contains('ري') || cat.contains('ماء') || cat.contains('مياه')) {
      return (Icons.water_drop_outlined, Colors.lightBlue);
    } else if (cat.contains('صيان') || cat.contains('معد')) {
      return (Icons.build_outlined, Colors.blueGrey);
    } else if (cat.contains('نقل') || cat.contains('شحن')) {
      return (Icons.local_shipping_outlined, Colors.cyan);
    }
    return (Icons.receipt_long_outlined, AppTheme.expenseRed);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final allExpenses = provider.expenses;
        // استبعاد أي تدفقات واردة أو إيداعات نقدية (مثل استلام الديون الشخصية أو تحصيل الذمم)
        // شاشة المصروفات والتصريفات مخصصة فقط للنفقات والمسحوبات الخارجة (amount > 0)
        final allMovements =
            provider.moneyMovements.where((m) => m.amount > 0).toList();

        // فلترة المصروفات
        final now = DateTime.now();
        var filteredExpenses = allExpenses.where((e) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final event = provider.landEvents.firstWhereOrNull((ev) => ev.id == e.eventId);
            final plot = event != null
                ? provider.landPlots.firstWhereOrNull((p) => p.id == event.landPlotId)
                : null;
            final worker = provider.workers.firstWhereOrNull((w) => w.id == e.workerId);
            final person = e.personId != null
                ? provider.partners.firstWhereOrNull((p) => p.id == e.personId)
                : null;
            final match = e.title.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q) ||
                (e.note != null && e.note!.toLowerCase().contains(q)) ||
                (worker != null && worker.name.toLowerCase().contains(q)) ||
                (person != null && person.name.toLowerCase().contains(q)) ||
                (e.paymentMethod == 'debt' && (q == 'دين' || q == 'آجل')) ||
                (event != null && event.eventType.toLowerCase().contains(q)) ||
                (plot != null && plot.name.toLowerCase().contains(q));
            if (!match) return false;
          }

          if (_selectedCategory != null && e.category != _selectedCategory) {
            return false;
          }

          if (_selectedWalletId != null) {
            final hasWallet = e.allocations.any((a) {
              final inc = provider.incomes.firstWhereOrNull((i) => i.id == a.incomeId);
              return inc?.walletId == _selectedWalletId;
            });
            if (!hasWallet) return false;
          }

          if (_dateFilter == 'this_month') {
            if (e.date.year != now.year || e.date.month != now.month) return false;
          } else if (_dateFilter == 'last_month') {
            final lastMonth = DateTime(now.year, now.month - 1);
            if (e.date.year != lastMonth.year || e.date.month != lastMonth.month) {
              return false;
            }
          } else if (_dateFilter == 'this_year') {
            if (e.date.year != now.year) return false;
          }

          return true;
        }).toList();

        // فلترة تصريفات المحافظ
        var filteredMovements = allMovements.where((m) {
          if (_selectedCategory != null) {
            return false; // movements do not have general category
          }

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final wallet = provider.wallets.firstWhereOrNull((w) => w.id == m.walletId);
            final worker = m.creditorType == 'w'
                ? provider.workers.firstWhereOrNull((w) => w.id == m.creditorId)
                : null;
            final partner = m.creditorType == 's'
                ? provider.partners.firstWhereOrNull((p) => p.id == m.creditorId)
                : null;
            final match = (m.note != null && m.note!.toLowerCase().contains(q)) ||
                (wallet != null && wallet.name.toLowerCase().contains(q)) ||
                (worker != null && worker.name.toLowerCase().contains(q)) ||
                (partner != null && partner.name.toLowerCase().contains(q));
            if (!match) return false;
          }

          if (_selectedWalletId != null && m.walletId != _selectedWalletId) {
            return false;
          }

          if (_dateFilter == 'this_month') {
            if (m.date.year != now.year || m.date.month != now.month) return false;
          } else if (_dateFilter == 'last_month') {
            final lastMonth = DateTime(now.year, now.month - 1);
            if (m.date.year != lastMonth.year || m.date.month != lastMonth.month) {
              return false;
            }
          } else if (_dateFilter == 'this_year') {
            if (m.date.year != now.year) return false;
          }

          return true;
        }).toList();

        // قائمة الكل المدمجة
        final List<OutgoingItem> combinedItems = [
          ...filteredExpenses.map((e) => OutgoingItem.fromExpense(e)),
          ...filteredMovements.map((m) => OutgoingItem.fromMovement(m)),
        ];

        // ترتيب النتائج
        if (_sortBy == 'newest') {
          filteredExpenses.sort((a, b) => b.date.compareTo(a.date));
          filteredMovements.sort((a, b) => b.date.compareTo(a.date));
          combinedItems.sort((a, b) => b.date.compareTo(a.date));
        } else if (_sortBy == 'oldest') {
          filteredExpenses.sort((a, b) => a.date.compareTo(b.date));
          filteredMovements.sort((a, b) => a.date.compareTo(b.date));
          combinedItems.sort((a, b) => a.date.compareTo(b.date));
        } else if (_sortBy == 'amount_desc') {
          filteredExpenses.sort((a, b) => b.amount.compareTo(a.amount));
          filteredMovements.sort((a, b) => b.amount.compareTo(a.amount));
          combinedItems.sort((a, b) => b.amount.compareTo(a.amount));
        } else if (_sortBy == 'amount_asc') {
          filteredExpenses.sort((a, b) => a.amount.compareTo(b.amount));
          filteredMovements.sort((a, b) => a.amount.compareTo(b.amount));
          combinedItems.sort((a, b) => a.amount.compareTo(b.amount));
        }

        // المؤشرات المالية
        final totalExp = filteredExpenses.fold<double>(0.0, (s, e) => s + e.amount);
        final totalDisb = filteredMovements.fold<double>(0.0, (s, m) => s + m.amount);
        final totalOutgoing = totalExp + totalDisb;

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: const Text('المصروفات والتصريفات'),
            actions: [
              IconButton(
                icon: const Icon(Icons.category_outlined),
                tooltip: 'إدارة تصنيفات المصروفات',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageExpenseCategoriesScreen()),
                ),
              ),
              DataExportImportButton(
                label: 'المصروفات',
                buildRows: () => provider.expenses.map((e) => e.toJson()).toList(),
                csvHeaders: const [
                  'العنوان',
                  'المبلغ',
                  'التاريخ',
                  'التصنيف',
                  'ملاحظات',
                ],
                csvKeys: const [
                  'title',
                  'amount',
                  'date',
                  'category',
                  'note',
                ],
                onImport: (rows) async {
                  for (final row in rows) {
                    try {
                      final expense = Expense.fromJson(row);
                      if (provider.expenses.any((e) => e.id == expense.id)) {
                        continue;
                      }
                      provider.addExpense(expense);
                    } catch (_) {}
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.expenseRed,
              indicatorWeight: 3,
              labelColor: AppTheme.expenseRed,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(
                  icon: const Icon(Icons.all_inbox_rounded, size: 18),
                  text: 'الكل (${combinedItems.length})',
                ),
                Tab(
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  text: 'المصروفات (${filteredExpenses.length})',
                ),
                Tab(
                  icon: const Icon(Icons.outbox_rounded, size: 18),
                  text: 'التصريفات (${filteredMovements.length})',
                ),
                const Tab(
                  icon: Icon(Icons.pie_chart_outline_rounded, size: 18),
                  text: 'التحليل',
                ),
              ],
            ),
          ),
          floatingActionButton: _buildFab(context, provider),
          body: Column(
            children: [
              // 1. شريط المؤشرات المالية العلوية
              _buildKpiStrip(
                totalOutgoing: totalOutgoing,
                totalExpenses: totalExp,
                totalDisbursements: totalDisb,
                expensesCount: filteredExpenses.length,
                disbursementsCount: filteredMovements.length,
                allExpensesCount: allExpenses.length,
                allMovementsCount: allMovements.length,
              ),

              // 2. شريط البحث والفلاتر
              if (_tabController.index != 3)
                _buildSearchAndFilters(provider),

              // 3. المحتوى حسب التبويب
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // تبويب الكل المدمج
                    _buildCombinedView(context, provider, combinedItems),

                    // تبويب المصروفات فقط
                    _buildExpensesView(context, provider, filteredExpenses),

                    // تبويب التصريفات فقط
                    _buildDisbursementsView(context, provider, filteredMovements),

                    // تبويب التحليل والتوزيع
                    _buildAnalyticsView(provider, filteredExpenses, totalExp),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- زر الإجراء العائم ---
  Widget _buildFab(BuildContext context, FinanceProvider provider) {
    return FloatingActionButton.extended(
      heroTag: 'fab_add_expense',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
      ),
      backgroundColor: AppTheme.expenseRed,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text(
        'مصروف جديد',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }

  // --- شريط المؤشرات المالية الذكي ---
  Widget _buildKpiStrip({
    required double totalOutgoing,
    required double totalExpenses,
    required double totalDisbursements,
    required int expensesCount,
    required int disbursementsCount,
    required int allExpensesCount,
    required int allMovementsCount,
  }) {
    final expRatio = totalOutgoing > 0 ? (totalExpenses / totalOutgoing) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.expenseRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.payments_outlined,
                    color: AppTheme.expenseRed, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي المنصرف الكلي (تشغيلي + تصريف)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${totalOutgoing.formattedFull} ر.ي',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      '${expensesCount + disbursementsCount}',
                      style: TextStyle(
                        color: AppTheme.expenseRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text('عملية مسجلة',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // شريط النسبة بين المصروفات التشغيلية والتصريفات
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (expRatio * 100).round().clamp(1, 99),
                    child: Container(color: AppTheme.expenseRed),
                  ),
                  Expanded(
                    flex: ((1 - expRatio) * 100).round().clamp(1, 99),
                    child: Container(color: Colors.orangeAccent),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),

          // السطر السفلي: تفصيل المصروفات مقابل التصريفات
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.expenseRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مصروفات تشغيلية ($expensesCount)',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                          Text(
                            '${totalExpenses.formatted} ر.ي',
                            style: TextStyle(
                              color: AppTheme.expenseRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: AppTheme.cardBorder),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تصريف من المحافظ ($disbursementsCount)',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                          Text(
                            '${totalDisbursements.formatted} ر.ي',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- شريط البحث والفلترة ---
  Widget _buildSearchAndFilters(FinanceProvider provider) {
    final categories = [
      'الكل',
      ...provider.expenseCategories.map((c) => c.name.trim()).where((name) => name.isNotEmpty).toSet(),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم المصروف، التصنيف، الملاحظات...',
                      hintStyle: TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.search,
                          size: 18, color: AppTheme.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: _showAdvancedFilters
                          ? AppTheme.expenseRed.withValues(alpha: 0.15)
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showAdvancedFilters
                            ? AppTheme.expenseRed
                            : AppTheme.cardBorder,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _showAdvancedFilters
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                        size: 20,
                        color: _showAdvancedFilters
                            ? AppTheme.expenseRed
                            : AppTheme.textSecondary,
                      ),
                      tooltip: 'خيارات الفلترة والفرز',
                      onPressed: () => setState(
                          () => _showAdvancedFilters = !_showAdvancedFilters),
                    ),
                  ),
                  if (_activeFiltersCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_activeFiltersCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // شرائح التصنيفات السريعة
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: categories.map((cat) {
              final isAll = cat == 'الكل';
              final isSelected = isAll
                  ? _selectedCategory == null
                  : _selectedCategory == cat;

              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = isAll ? null : cat;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.expenseRed.withValues(alpha: 0.18)
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.expenseRed
                            : AppTheme.cardBorder,
                        width: isSelected ? 1.4 : 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.expenseRed
                            : AppTheme.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // لوحة الفلاتر المتقدمة
        if (_showAdvancedFilters)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تصفية إضافية وفرز:',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    if (_activeFiltersCount > 0)
                      GestureDetector(
                        onTap: _resetFilters,
                        child: Text('إعادة ضبط الكل',
                            style: TextStyle(
                                color: AppTheme.accentBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // تصفية حسب المحفظة
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedWalletId,
                            hint: Text('كل المحافظ',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('كل المحافظ',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              ...provider.wallets.map(
                                (w) => DropdownMenuItem<String?>(
                                  value: w.id,
                                  child: Text(w.name,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedWalletId = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // الفترة الزمنية
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _dateFilter,
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all',
                                  child: Text('كل الفترات',
                                      style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(
                                  value: 'this_month',
                                  child: Text('هذا الشهر',
                                      style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(
                                  value: 'last_month',
                                  child: Text('الشهر السابق',
                                      style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(
                                  value: 'this_year',
                                  child: Text('هذا العام',
                                      style: TextStyle(fontSize: 11))),
                            ],
                            onChanged: (v) =>
                                setState(() => _dateFilter = v ?? 'all'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // الفرز
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _sortBy,
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                      items: const [
                        DropdownMenuItem(
                            value: 'newest',
                            child: Text('الأحدث تاريخاً',
                                style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(
                            value: 'oldest',
                            child: Text('الأقدم تاريخاً',
                                style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(
                            value: 'amount_desc',
                            child: Text('الأعلى مبلغاً',
                                style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(
                            value: 'amount_asc',
                            child: Text('الأقل مبلغاً',
                                style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v ?? 'newest'),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- تبويب 1: العرض المدمج للكل ---
  Widget _buildCombinedView(
      BuildContext context, FinanceProvider provider, List<OutgoingItem> items) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.type == OutgoingType.expense) {
          return _buildExpenseCard(context, provider, item.expense!);
        } else {
          return _buildDisbursementCard(context, provider, item.movement!);
        }
      },
    );
  }

  // --- تبويب 2: المصروفات فقط ---
  Widget _buildExpensesView(
      BuildContext context, FinanceProvider provider, List<Expense> expenses) {
    if (expenses.isEmpty) {
      return _buildEmptyState(message: 'لا توجد مصروفات تشغيلية تطابق البحث');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: expenses.length,
      itemBuilder: (context, index) =>
          _buildExpenseCard(context, provider, expenses[index]),
    );
  }

  // --- تبويب 3: التصريفات فقط ---
  Widget _buildDisbursementsView(BuildContext context, FinanceProvider provider,
      List<MoneyMovement> movements) {
    if (movements.isEmpty) {
      return _buildEmptyState(
          message: 'لا توجد تصريفات من المحافظ تطابق البحث');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: movements.length,
      itemBuilder: (context, index) =>
          _buildDisbursementCard(context, provider, movements[index]),
    );
  }

  // --- تبويب 4: التحليل المالي والتوزيع حسب التصنيف ---
  Widget _buildAnalyticsView(
      FinanceProvider provider, List<Expense> expenses, double totalExpense) {
    if (expenses.isEmpty) {
      return _buildEmptyState(message: 'لا توجد بيانات مصروفات لتحليلها');
    }

    // تجميع المبالغ حسب التصنيف
    final Map<String, double> categorySums = {};
    final Map<String, int> categoryCounts = {};

    for (final e in expenses) {
      categorySums[e.category] = (categorySums[e.category] ?? 0.0) + e.amount;
      categoryCounts[e.category] = (categoryCounts[e.category] ?? 0) + 1;
    }

    final sortedCategories = categorySums.keys.toList()
      ..sort((a, b) => (categorySums[b] ?? 0).compareTo(categorySums[a] ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_rounded,
                      color: AppTheme.expenseRed, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'توزيع المصروفات التشغيلية حسب التصنيف',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'إجمالي المبلغ المحلل: ${totalExpense.formattedFull} ر.ي عبر ${expenses.length} مصروف',
                style:
                    TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ...sortedCategories.map((cat) {
          final sum = categorySums[cat] ?? 0;
          final count = categoryCounts[cat] ?? 0;
          final pct = totalExpense > 0 ? (sum / totalExpense) : 0.0;
          final (icon, color) = _getCategoryStyle(cat);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$count مصروفات',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${sum.formattedFull} ر.ي',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Map<String, dynamic> _getExpenseDisplay(Expense expense, FinanceProvider provider) {
    if (expense.currency != baseCurrencyCode && expense.exchangeRate > 0) {
      final origAmount = fromYemeniEquivalent(expense.amount, expense.currency, expense.exchangeRate);
      return {
        'amount': origAmount,
        'currency': expense.currency,
        'rate': expense.exchangeRate,
        'hasForeign': true,
        'yemeniAmount': expense.amount,
      };
    }
    if (expense.allocations.isNotEmpty) {
      final nonBaseAllocations = expense.allocations.where((a) => a.currency != baseCurrencyCode).toList();
      final nonBaseCurrs = nonBaseAllocations.map((a) => a.currency).toSet();
      if (nonBaseCurrs.length == 1 && nonBaseAllocations.length == expense.allocations.length) {
        final foreignCurr = nonBaseCurrs.first;
        double totalOrig = 0.0;
        double lastRate = 1.0;
        for (final a in expense.allocations) {
          final p = provider.incomePayments.firstWhereOrNull((pay) => pay.id == a.paymentId);
          final s = provider.debtFundingSources.firstWhereOrNull((src) => src.id == a.debtSettlementId);
          final rate = p?.exchangeRate ?? s?.exchangeRate ?? 1.0;
          lastRate = rate;
          totalOrig += fromYemeniEquivalent(a.amount, foreignCurr, rate);
        }
        return {
          'amount': totalOrig,
          'currency': foreignCurr,
          'rate': lastRate,
          'hasForeign': true,
          'yemeniAmount': expense.amount,
        };
      }
    }
    return {
      'amount': expense.amount,
      'currency': baseCurrencyCode,
      'rate': 1.0,
      'hasForeign': false,
      'yemeniAmount': expense.amount,
    };
  }

  Map<String, dynamic> _getMovementDisplay(MoneyMovement movement) {
    if (movement.currency != baseCurrencyCode && movement.exchangeRate > 0) {
      final origAmount = fromYemeniEquivalent(movement.amount, movement.currency, movement.exchangeRate);
      return {
        'amount': origAmount,
        'currency': movement.currency,
        'rate': movement.exchangeRate,
        'hasForeign': true,
        'yemeniAmount': movement.amount,
      };
    }
    return {
      'amount': movement.amount,
      'currency': baseCurrencyCode,
      'rate': 1.0,
      'hasForeign': false,
      'yemeniAmount': movement.amount,
    };
  }

  // --- بطاقة المصروف المطورّة ---
  Widget _buildExpenseCard(
      BuildContext context, FinanceProvider provider, Expense expense) {
    final (catIcon, catColor) = _getCategoryStyle(expense.category);

    final disp = _getExpenseDisplay(expense, provider);
    final double dispAmount = disp['amount'];
    final String dispCurr = disp['currency'];
    final bool hasForeign = disp['hasForeign'];
    final double yemeniAmount = disp['yemeniAmount'];

    // البحث عن الحدث الزراعي والموضع إن وُجد
    final event = provider.landEvents.firstWhereOrNull((ev) => ev.id == expense.eventId);
    final plot = event != null
        ? provider.landPlots.firstWhereOrNull((p) => p.id == event.landPlotId)
        : null;

    // العامل وأيام العمل
    final worker = expense.workerId != null
        ? provider.workers.firstWhereOrNull((w) => w.id == expense.workerId)
        : null;

    // الدائن / الشخص إن كان المصروف آجلاً
    final isDebt = expense.paymentMethod == 'debt';
    final person = expense.personId != null
        ? provider.partners.firstWhereOrNull((p) => p.id == expense.personId)
        : null;

    // تفاصيل الاستقطاع من الإيرادات
    final allocationsInfo = expense.allocations.map((a) {
      final inc = provider.incomes.firstWhereOrNull((i) => i.id == a.incomeId);
      final p = provider.incomePayments.firstWhereOrNull((pay) => pay.id == a.paymentId);
      final s = provider.debtFundingSources.firstWhereOrNull((src) => src.id == a.debtSettlementId);
      final rate = p?.exchangeRate ?? s?.exchangeRate ?? 1.0;
      final wallet = inc != null
          ? provider.wallets.firstWhereOrNull((w) => w.id == inc.walletId)
          : null;
      final isFor = a.currency != baseCurrencyCode && rate > 0;
      final origAmount = isFor ? fromYemeniEquivalent(a.amount, a.currency, rate) : a.amount;
      return {
        'incomeTitle': inc?.title ?? (a.debtSettlementId != null ? 'استلام دين' : 'إيراد'),
        'walletName': wallet?.name,
        'amount': a.amount,
        'origAmount': origAmount,
        'currency': a.currency,
        'isForeign': isFor,
      };
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: catColor, width: 4.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(existing: expense)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // السطر الأول: الأيقونة، العنوان، التاريخ، والمبلغ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(catIcon, color: catColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 11, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('EEEE، dd MMM yyyy', 'ar')
                                        .format(expense.date),
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${dispAmount.formattedFull} ${currencyLabel(dispCurr)}',
                              style: TextStyle(
                                color: AppTheme.expenseRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            if (hasForeign) ...[
                              const SizedBox(height: 2),
                              Text(
                                'يعادل ${yemeniAmount.formattedFull} ر.ي',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: catColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                expense.category,
                                style: TextStyle(
                                  color: catColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          color: AppTheme.surface,
                          icon: Icon(Icons.more_vert,
                              color: AppTheme.textMuted, size: 18),
                          onSelected: (v) {
                            if (v == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        AddExpenseScreen(existing: expense)),
                              );
                            } else if (v == 'delete') {
                              _confirmDeleteExpense(context, provider, expense);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل',
                                    style: TextStyle(color: AppTheme.textPrimary))),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف',
                                    style:
                                        TextStyle(color: AppTheme.expenseRed))),
                          ],
                        ),
                      ],
                    ),

                    // الشارات المرتبطة: حدث زراعي، عامل، أيام عمل، دين
                    if (isDebt || event != null || worker != null || expense.wageDays != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (isDebt)
                            _buildBadge(
                              icon: Icons.receipt_long,
                              label: 'آجل' +
                                  (person != null ? ' (له: ${person.name})' : ''),
                              color: Colors.orange,
                            ),
                          if (event != null)
                            _buildBadge(
                              icon: Icons.event_note,
                              label: 'حدث: ${event.eventType}${plot != null ? ' (${plot.name})' : ''}',
                              color: Colors.teal,
                            ),
                          if (worker != null)
                            _buildBadge(
                              icon: Icons.person_outline,
                              label: 'العامل: ${worker.name}',
                              color: Colors.indigoAccent,
                            ),
                          if (expense.wageDays != null && expense.wageDays! > 0)
                            _buildBadge(
                              icon: Icons.work_history_outlined,
                              label: '${expense.wageDays} يوم' +
                                  (expense.wageRate != null
                                      ? ' @ ${expense.wageRate} ر.ي'
                                      : ''),
                              color: Colors.orange,
                            ),
                        ],
                      ),
                    ],

                    // الملاحظات
                    if (expense.note != null && expense.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Text(
                          expense.note!,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],

                    // حالة المصروف الآجل والالتزام
                    if (isDebt) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                color: Colors.orange, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                person != null
                                    ? 'مصروف آجل · مسجل كدين التزام في حساب: ${person.name}'
                                    : 'مصروف آجل · مسجل كدين التزام',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // الاستقطاعات والتمويل من الإيرادات
                    if (allocationsInfo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.accentBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                color: AppTheme.accentBlue, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                allocationsInfo.map((a) {
                                  final amount =
                                      (a['amount'] as double).formatted;
                                  final title = a['incomeTitle'];
                                  final wallet = a['walletName'] != null
                                      ? ' [${a['walletName']}]'
                                      : '';
                                  final isFor = a['isForeign'] == true;
                                  final origAmt = (a['origAmount'] as double).formatted;
                                  final curr = a['currency'] as String? ?? baseCurrencyCode;
                                  final amountText = isFor
                                      ? '$origAmt ${currencyLabel(curr)} ($amount ر.ي)'
                                      : '$amount ر.ي';
                                  return '$title$wallet: $amountText';
                                }).join(' · '),
                                style: TextStyle(
                                  color: AppTheme.accentBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- بطاقة تصريف المحفظة المطورة ---
  Widget _buildDisbursementCard(
      BuildContext context, FinanceProvider provider, MoneyMovement movement) {
    final disp = _getMovementDisplay(movement);
    final double dispAmount = disp['amount'];
    final String dispCurr = disp['currency'];
    final bool hasForeign = disp['hasForeign'];
    final double yemeniAmount = disp['yemeniAmount'];

    final wallet = provider.wallets.firstWhereOrNull((w) => w.id == movement.walletId);
    final income = movement.incomeId != null
        ? provider.incomes.firstWhereOrNull((i) => i.id == movement.incomeId)
        : null;

    String? creditorLabel;
    Color creditorColor = Colors.orangeAccent;
    if (movement.creditorType != null && movement.creditorId != null) {
      if (movement.creditorType == 'w') {
        final worker = provider.workers.firstWhereOrNull((x) => x.id == movement.creditorId);
        creditorLabel = 'سداد عامل: ${worker?.name ?? '—'}';
        creditorColor = Colors.indigoAccent;
      } else {
        final partner = provider.partners.firstWhereOrNull((x) => x.id == movement.creditorId);
        creditorLabel = 'سداد مورد / شريك: ${partner?.name ?? '—'}';
        creditorColor = Colors.teal;
      }
    } else if (movement.debtId != null) {
      final debt = provider.personalDebts.firstWhereOrNull((d) => d.id == movement.debtId);
      final person = debt != null
          ? provider.partners.firstWhereOrNull((p) => p.id == debt.personId)
          : null;
      final personName = person?.name ?? '';
      creditorLabel = personName.isNotEmpty
          ? 'دفع ديون وأقساط إلى $personName'
          : 'دفع ديون وأقساط';
      creditorColor = Colors.amber;
    } else if (movement.zakatPaymentId != null) {
      creditorLabel = 'صرف زكاة';
      creditorColor = AppTheme.incomeGreen;
    } else if (movement.distributionId != null) {
      creditorLabel = 'توزيع أرباح';
      creditorColor = Colors.purpleAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.orangeAccent, width: 4.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.outbox_rounded,
                          color: Colors.orangeAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movement.note?.trim().isNotEmpty == true
                                ? movement.note!
                                : 'تصريف من المحفظة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 11, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('EEEE، dd MMM yyyy', 'ar')
                                    .format(movement.date),
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${dispAmount.formattedFull} ${currencyLabel(dispCurr)}',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (hasForeign) ...[
                          const SizedBox(height: 2),
                          Text(
                            'يعادل ${yemeniAmount.formattedFull} ر.ي',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orangeAccent.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'تصريف',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      color: AppTheme.surface,
                      icon: Icon(Icons.more_vert,
                          color: AppTheme.textMuted, size: 18),
                      onSelected: (v) {
                        if (v == 'edit') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            builder: (_) =>
                                EditMovementSheet(movement: movement),
                          );
                        } else if (v == 'delete') {
                          _confirmDeleteMovement(context, provider, movement);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'edit',
                            child: Text('تعديل',
                                style: TextStyle(color: AppTheme.textPrimary))),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف',
                                style: TextStyle(color: AppTheme.expenseRed))),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (wallet != null)
                      _buildBadge(
                        icon: Icons.account_balance_wallet_outlined,
                        label: wallet.name,
                        color: Colors.deepPurpleAccent,
                      ),
                    if (creditorLabel != null)
                      _buildBadge(
                        icon: Icons.payments_outlined,
                        label: creditorLabel,
                        color: creditorColor,
                      ),
                    if (income != null)
                      _buildBadge(
                        icon: Icons.trending_up,
                        label: 'إيراد: ${income.title}',
                        color: AppTheme.incomeGreen,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                color: AppTheme.textMuted, size: 56),
            const SizedBox(height: 14),
            Text(
              message ?? 'لا توجد نتائج تطابق معايير الفلترة أو البحث',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب تغيير كلمة البحث أو إعادة ضبط الفلاتر',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            if (_activeFiltersCount > 0 || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.expenseRed,
                  side: BorderSide(color: AppTheme.cardBorder),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('إعادة ضبط الفلاتر'),
                onPressed: _resetFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- نافذة تسجيل تصريف جديد من محفظة ---
  void _showAddDisbursementSheet(
      BuildContext context, FinanceProvider provider) {
    if (provider.wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء إضافة محفظة أولاً من شاشة المحافظ'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now();
    String selectedWalletId = provider.wallets.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final wallet = provider.wallets
              .firstWhereOrNull((w) => w.id == selectedWalletId);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.outbox_rounded,
                              color: Colors.orangeAccent, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'تسجيل تصريف نقد من محفظة',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // اختيار المحفظة
                  Text('المحفظة المسحوب منها:',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: AppTheme.surface,
                        value: selectedWalletId,
                        items: provider.wallets.map((w) {
                          return DropdownMenuItem<String>(
                            value: w.id,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(w.name,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13)),
                                Text(
                                  'الرصيد: ${provider.walletBalance(w.id).formatted} ر.ي',
                                  style: TextStyle(
                                      color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() => selectedWalletId = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // حقل المبلغ
                  Text('المبلغ المصروف:',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                          color: AppTheme.textMuted, fontSize: 16),
                      suffixText: 'ر.ي',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                    validator: (v) {
                      final val = double.tryParse(v?.trim() ?? '');
                      if (val == null || val <= 0) {
                        return 'أدخل مبلغاً صحيحاً أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // التاريخ والبيان
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('التاريخ:',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: pickedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) {
                                  setSheetState(() => pickedDate = d);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(pickedDate),
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13),
                                    ),
                                    Icon(Icons.calendar_month,
                                        size: 16, color: AppTheme.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // البيان والملاحظات
                  Text('البيان / ملاحظة الصرف:',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: noteCtrl,
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'مثال: سحب نقدي نثري، شراء ديزل نقداً...',
                      hintStyle: TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text(
                        'تسجيل التصريف',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final amt = double.parse(amountCtrl.text.trim());

                        final movement = MoneyMovement(
                          id: const Uuid().v4(),
                          walletId: selectedWalletId,
                          amount: amt,
                          date: pickedDate,
                          note: noteCtrl.text.trim().isNotEmpty
                              ? noteCtrl.text.trim()
                              : 'تصريف نقدي',
                        );

                        provider.addMoneyMovement(movement);
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'تم تسجيل تصريف بقيمة ${amt.formatted} ر.ي من محفظة ${wallet?.name ?? ''} بنجاح'),
                            backgroundColor: Colors.orangeAccent,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- تأكيد حذف المصروف ---
  void _confirmDeleteExpense(
      BuildContext context, FinanceProvider provider, Expense expense) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف المصروف',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'هل تريد بالتأكيد حذف "${expense.title}" بمبلغ ${expense.amount.formatted} ر.ي؟ ستتم استعادة المبالغ المستقطعة إلى الإيرادات المخصصة لها.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              provider.deleteExpense(expense.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف المصروف بنجاح'),
                  backgroundColor: AppTheme.expenseRed,
                ),
              );
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  // --- تأكيد حذف التصريف ---
  void _confirmDeleteMovement(
      BuildContext context, FinanceProvider provider, MoneyMovement movement) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف التصريف',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'هل تريد بالتأكيد حذف حركة التصريف هذه بقيمة ${movement.amount.formatted} ر.ي؟',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final deleted = provider.deleteMoneyMovement(movement.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(deleted
                      ? 'تم حذف حركة التصريف بنجاح'
                      : 'لا يمكن حذف هذه الحركة منفردة لأنها مرتبطة بعملية أخرى.'),
                  backgroundColor: deleted ? AppTheme.expenseRed : Colors.orange,
                ),
              );
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }
}
