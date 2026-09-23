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

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // الفلاتر
  String _statusFilter = 'all'; // all, fully_paid, partially_paid, unpaid
  String? _selectedPlotId;
  String? _selectedWalletId;
  String _dateFilter = 'all'; // all, this_month, last_month, this_year
  String _sortBy = 'newest'; // newest, oldest, amount_desc, remaining_desc
  bool _showAdvancedFilters = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('الإيرادات والمقبوضات'),
        actions: [
          DataExportImportButton(
            label: 'الإيرادات',
            buildRows: () => context
                .read<FinanceProvider>()
                .incomes
                .map((e) => e.toJson())
                .toList(),
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
        label: const Text('إيراد جديد',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final allIncomes = provider.incomes;

          if (allIncomes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up_outlined,
                      color: AppTheme.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text('لا توجد إيرادات مسجلة',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('أضف أول إيراد زراعي من الزر أدناه',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            );
          }

          // تصفية السجلات
          final now = DateTime.now();
          var filteredIncomes = allIncomes.where((income) {
            // البحث النصي
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final plotName = provider.landPlots
                  .firstWhereOrNull((p) => p.id == income.landPlotId)
                  ?.name
                  .toLowerCase();
              final zahraName = provider.zahras
                  .firstWhereOrNull((z) => z.id == income.zahraId)
                  ?.name
                  .toLowerCase();
              final walletName = provider.wallets
                  .firstWhereOrNull((w) => w.id == income.walletId)
                  ?.name
                  .toLowerCase();

              final match = income.title.toLowerCase().contains(q) ||
                  income.source.toLowerCase().contains(q) ||
                  (income.note != null &&
                      income.note!.toLowerCase().contains(q)) ||
                  (plotName != null && plotName.contains(q)) ||
                  (zahraName != null && zahraName.contains(q)) ||
                  (walletName != null && walletName.contains(q));
              if (!match) return false;
            }

            // فلتر حالة التحصيل
            if (_statusFilter == 'fully_paid' && !income.isFullyPaid) return false;
            if (_statusFilter == 'partially_paid' &&
                (income.isFullyPaid || income.receivedAmount <= 0)) {
              return false;
            }
            if (_statusFilter == 'unpaid' && income.receivedAmount > 0) return false;

            // فلتر الموضع
            if (_selectedPlotId != null && income.landPlotId != _selectedPlotId) {
              return false;
            }

            // فلتر المحفظة
            if (_selectedWalletId != null && income.walletId != _selectedWalletId) {
              return false;
            }

            // فلتر التاريخ
            if (_dateFilter == 'this_month') {
              if (income.date.year != now.year || income.date.month != now.month) {
                return false;
              }
            } else if (_dateFilter == 'last_month') {
              final lastMonth = DateTime(now.year, now.month - 1);
              if (income.date.year != lastMonth.year ||
                  income.date.month != lastMonth.month) {
                return false;
              }
            } else if (_dateFilter == 'this_year') {
              if (income.date.year != now.year) return false;
            }

            return true;
          }).toList();

          // الترتيب
          if (_sortBy == 'newest') {
            filteredIncomes.sort((a, b) => b.date.compareTo(a.date));
          } else if (_sortBy == 'oldest') {
            filteredIncomes.sort((a, b) => a.date.compareTo(b.date));
          } else if (_sortBy == 'amount_desc') {
            filteredIncomes.sort((a, b) => b.amount.compareTo(a.amount));
          } else if (_sortBy == 'remaining_desc') {
            filteredIncomes.sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount));
          }

          // المؤشرات المالية العامة (من واقع كل الإيرادات أو الإيرادات المفلترة)
          final totalAmount = filteredIncomes.fold(0.0, (s, i) => s + i.amount);
          final totalReceived = filteredIncomes.fold(0.0, (s, i) => s + i.receivedAmount);
          final totalRemaining = totalAmount - totalReceived;
          final totalDeductedExpenses = filteredIncomes.fold(
              0.0, (s, i) => s + i.totalExpenses + provider.disbursedForIncome(i.id));
          final totalAvailableSurplus = filteredIncomes.fold(
              0.0, (s, i) => s + provider.remainingForIncome(i.id));
          final collectionRate = totalAmount > 0
              ? ((totalReceived / totalAmount) * 100).clamp(0.0, 100.0)
              : 0.0;

          return Column(
            children: [
              // 1. شريط المؤشرات المالية الذكي (Financial KPI Bar)
              _buildKpiSection(
                totalAmount: totalAmount,
                totalReceived: totalReceived,
                totalRemaining: totalRemaining,
                totalDeductedExpenses: totalDeductedExpenses,
                totalAvailableSurplus: totalAvailableSurplus,
                collectionRate: collectionRate,
                count: filteredIncomes.length,
                totalCount: allIncomes.length,
              ),

              // 2. شريط البحث والفلترة السريعة
              _buildSearchAndFilters(provider),

              // 3. قائمة الإيرادات المفلترة
              Expanded(
                child: filteredIncomes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  color: AppTheme.textMuted, size: 54),
                              const SizedBox(height: 12),
                              Text('لا توجد إيرادات تطابق معايير البحث',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('جرب تغيير كلمة البحث أو إعادة ضبط الفلاتر',
                                  style: TextStyle(
                                      color: AppTheme.textMuted, fontSize: 12)),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accentBlue,
                                  side: BorderSide(color: AppTheme.cardBorder),
                                ),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('إعادة ضبط الفلاتر'),
                                onPressed: _resetFilters,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                        itemCount: filteredIncomes.length,
                        itemBuilder: (context, index) {
                          final income = filteredIncomes[index];
                          final wallet = provider.wallets
                              .firstWhereOrNull((w) => w.id == income.walletId);
                          final plot = provider.landPlots
                              .firstWhereOrNull((p) => p.id == income.landPlotId);
                          final zahra = provider.zahras
                              .firstWhereOrNull((z) => z.id == income.zahraId);
                          final available = provider.remainingForIncome(income.id);

                          return _buildIncomeCard(
                            context: context,
                            provider: provider,
                            income: income,
                            wallet: wallet,
                            plot: plot,
                            zahra: zahra,
                            availableAmount: available,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- شريط المؤشرات المالية العلوية ---
  Widget _buildKpiSection({
    required double totalAmount,
    required double totalReceived,
    required double totalRemaining,
    required double totalDeductedExpenses,
    required double totalAvailableSurplus,
    required double collectionRate,
    required int count,
    required int totalCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // السطر الأول: إجمالي الإيراد + نسبة التحصيل
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.monetization_on_outlined,
                    color: AppTheme.incomeGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'إجمالي الإيرادات التعاقدية',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Text(
                            '$count${count != totalCount ? ' من $totalCount' : ''} إيراد',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${totalAmount.formattedFull} ر.ي',
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
              // نسبة التحصيل في شارة بيضاوية أنيقة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (collectionRate >= 80
                          ? AppTheme.incomeGreen
                          : collectionRate >= 40
                              ? Colors.orange
                              : AppTheme.expenseRed)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (collectionRate >= 80
                            ? AppTheme.incomeGreen
                            : collectionRate >= 40
                                ? Colors.orange
                                : AppTheme.expenseRed)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${collectionRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: collectionRate >= 80
                            ? AppTheme.incomeGreen
                            : collectionRate >= 40
                                ? Colors.orange
                                : AppTheme.expenseRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text('تم تحصيله',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // شريط نسبة التحصيل الأفقي
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalAmount > 0 ? (totalReceived / totalAmount).clamp(0.0, 1.0) : 0,
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                collectionRate >= 80
                    ? AppTheme.incomeGreen
                    : collectionRate >= 40
                        ? Colors.orange
                        : AppTheme.expenseRed,
              ),
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),

          // السطر السفلي: 4 مؤشرات فرعية
          Row(
            children: [
              _buildMiniMetric(
                label: 'المقبوض (نقد)',
                amount: totalReceived,
                color: AppTheme.incomeGreen,
                icon: Icons.account_balance_wallet_outlined,
              ),
              _metricDivider(),
              _buildMiniMetric(
                label: 'المتبقي (آجل)',
                amount: totalRemaining,
                color: totalRemaining > 0 ? Colors.orange : AppTheme.textMuted,
                icon: Icons.pending_actions_outlined,
              ),
              _metricDivider(),
              _buildMiniMetric(
                label: 'المصروف منه',
                amount: totalDeductedExpenses,
                color: AppTheme.expenseRed,
                icon: Icons.arrow_outward_rounded,
              ),
              _metricDivider(),
              _buildMiniMetric(
                label: 'الفائض المتاح',
                amount: totalAvailableSurplus,
                color: AppTheme.accentBlue,
                icon: Icons.savings_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            amount.formatted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricDivider() => Container(
        width: 1,
        height: 24,
        color: AppTheme.cardBorder,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  // --- شريط البحث والفلترة السريعة ---
  Widget _buildSearchAndFilters(FinanceProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              // حقل البحث
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
                      hintText: 'بحث باسم الإيراد، الموضع، المصدر...',
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // زر الفلاتر المتقدمة مع شارة عدد الفلاتر
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: _showAdvancedFilters
                          ? AppTheme.accentBlue.withValues(alpha: 0.15)
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showAdvancedFilters
                            ? AppTheme.accentBlue
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
                            ? AppTheme.accentBlue
                            : AppTheme.textSecondary,
                      ),
                      tooltip: 'الفلاتر والترتيب',
                      onPressed: () {
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                        });
                      },
                    ),
                  ),
                  if (_activeFiltersCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeGreen,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_activeFiltersCount',
                          style: const TextStyle(
                            color: Colors.black,
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

        // تبويبات الفلترة السريعة (Horizontal Chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('الكل', 'all', _statusFilter == 'all', (val) {
                setState(() => _statusFilter = 'all');
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  'مستلم بالكامل', 'fully_paid', _statusFilter == 'fully_paid',
                  (val) {
                setState(() => _statusFilter = 'fully_paid');
              }, color: AppTheme.incomeGreen),
              const SizedBox(width: 6),
              _buildFilterChip('مستلم جزئياً', 'partially_paid',
                  _statusFilter == 'partially_paid', (val) {
                setState(() => _statusFilter = 'partially_paid');
              }, color: Colors.orange),
              const SizedBox(width: 6),
              _buildFilterChip(
                  'آجل / غير مستلم', 'unpaid', _statusFilter == 'unpaid',
                  (val) {
                setState(() => _statusFilter = 'unpaid');
              }, color: AppTheme.expenseRed),
            ],
          ),
        ),

        // لوحة الفلاتر المتقدمة القابلة للطي
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
                    Text('تصفية متقدمة وفرز:',
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
                    // تصفية حسب الموضع
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
                            value: _selectedPlotId,
                            hint: Text('كل المواضع / الأراضي',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('كل المواضع',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              ...provider.landPlots.map(
                                (p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text(p.name,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedPlotId = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // تصفية الفترة الزمنية
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
                    const SizedBox(width: 8),

                    // فرز النتائج
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
                                  value: 'remaining_desc',
                                  child: Text('الأكبر متبقياً (دين)',
                                      style: TextStyle(fontSize: 11))),
                            ],
                            onChanged: (v) =>
                                setState(() => _sortBy = v ?? 'newest'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(
      String label, String value, bool isSelected, Function(bool) onSelected,
      {Color? color}) {
    final activeColor = color ?? AppTheme.accentBlue;
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.cardBorder,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // --- بطاقة الإيراد المطورة والغنية بالمعلومات ---
  Widget _buildIncomeCard({
    required BuildContext context,
    required FinanceProvider provider,
    required Income income,
    required Wallet? wallet,
    required LandPlot? plot,
    required Zahra? zahra,
    required double availableAmount,
  }) {
    final fully = income.isFullyPaid;
    final partially = !fully && income.receivedAmount > 0;
    final statusColor = fully
        ? AppTheme.incomeGreen
        : partially
            ? Colors.orange
            : AppTheme.expenseRed;

    final progressPct = income.amount > 0
        ? (income.receivedAmount / income.amount).clamp(0.0, 1.0)
        : 0.0;
    final totalSpent = income.totalExpenses + provider.disbursedForIncome(income.id);

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
              right: BorderSide(color: statusColor, width: 4.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IncomeDetailScreen(incomeId: income.id),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // السطر الأول: العنوان والمبلغ الإجمالي
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                income.title,
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
                                      size: 12, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('EEEE، dd MMM yyyy', 'ar')
                                        .format(income.date),
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
                              '${income.amount.formattedFull} ر.ي',
                              style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // شارة حالة السداد
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    fully
                                        ? Icons.check_circle
                                        : partially
                                            ? Icons.pie_chart_outline
                                            : Icons.hourglass_empty,
                                    size: 11,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    fully
                                        ? 'مستلم بالكامل'
                                        : partially
                                            ? 'مستلم جزئياً (${(progressPct * 100).toStringAsFixed(0)}%)'
                                            : 'آجل (غير مستلم)',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // شارات السياق: المصدر، الموضع، الزرعة، المحفظة
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildContextBadge(
                          icon: Icons.storefront_outlined,
                          label: income.source,
                          color: AppTheme.accentBlue,
                        ),
                        if (plot != null)
                          _buildContextBadge(
                            icon: Icons.landscape_outlined,
                            label: plot.name,
                            color: Colors.teal,
                          ),
                        if (zahra != null)
                          _buildContextBadge(
                            icon: Icons.eco_outlined,
                            label: zahra.name,
                            color: AppTheme.incomeGreen,
                          ),
                        if (wallet != null)
                          _buildContextBadge(
                            icon: Icons.account_balance_wallet_outlined,
                            label: wallet.name,
                            color: Colors.deepPurpleAccent,
                          ),
                      ],
                    ),

                    // شريط تقدم السداد والتحصيل
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        minHeight: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // تفاصيل المستلم والمتبقي والمصروف
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('المستلم: ',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                            Text(
                              '${income.receivedAmount.formattedFull} ر.ي',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (!fully)
                          Row(
                            children: [
                              Text('المتبقي للتحصيل: ',
                                  style: TextStyle(
                                      color: AppTheme.textMuted, fontSize: 11)),
                              Text(
                                '${income.remainingAmount.formattedFull} ر.ي',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // المصروفات المربوطة والتصريفات والمتاح للصرف (إن وجدت)
                    if (totalSpent > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.arrow_outward_rounded,
                              size: 11, color: AppTheme.expenseRed),
                          const SizedBox(width: 3),
                          Text(
                            'صُرف منه: ${totalSpent.formattedFull} ر.ي',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 10),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.savings_outlined,
                              size: 11, color: AppTheme.accentBlue),
                          const SizedBox(width: 3),
                          Text(
                            'الفائض المتاح: ${availableAmount.formattedFull} ر.ي',
                            style: TextStyle(
                                color: AppTheme.accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],

                    // الملاحظات إن وجدت
                    if (income.note != null && income.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded,
                                size: 13, color: AppTheme.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                income.note!,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppTheme.cardBorder),
                    const SizedBox(height: 8),

                    // شريط الأزرار والإجراءات السريعة
                    Row(
                      children: [
                        // زر قبض دفعة سريع (إذا كان متبقي شيء)
                        if (!fully)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.incomeGreen,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.payments_outlined, size: 16),
                              label: const Text(
                                'قبض دفعة سريع',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                              onPressed: () => _showQuickReceiptSheet(
                                context,
                                provider,
                                income,
                              ),
                            ),
                          ),
                        if (!fully) const SizedBox(width: 8),

                        // زر التفاصيل الكاملة
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentBlue,
                              side: BorderSide(color: AppTheme.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.receipt_long_outlined,
                                size: 16),
                            label: const Text('التفاصيل الكاملة',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12)),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    IncomeDetailScreen(incomeId: income.id),
                              ),
                            ),
                          ),
                        ),

                        // قائمة المزيد (تعديل / حذف)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: AppTheme.textMuted, size: 18),
                          color: AppTheme.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddIncomeScreen(existing: income),
                                ),
                              );
                            } else if (val == 'delete') {
                              _confirmDeleteIncome(context, provider, income);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 16, color: AppTheme.textSecondary),
                                  SizedBox(width: 8),
                                  Text('تعديل الإيراد',
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 16, color: AppTheme.expenseRed),
                                  SizedBox(width: 8),
                                  Text('حذف الإيراد',
                                      style: TextStyle(
                                          color: AppTheme.expenseRed,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- نافذة القبض السريع للمبالغ والديون (Quick Receipt Modal) ---
  void _showQuickReceiptSheet(
    BuildContext context,
    FinanceProvider provider,
    Income income,
  ) {
    final remaining = income.remainingAmount;
    final amountController =
        TextEditingController(text: remaining.plain);
    final noteController = TextEditingController();
    final exchangeRateController = TextEditingController(text: '1');
    String currency = baseCurrencyCode;
    DateTime paymentDate = DateTime.now();

    // اختيار المحفظة
    String? selectedWalletId = income.walletId ??
        (provider.wallets.isNotEmpty ? provider.wallets.first.id : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final rawAmount = tryParseFlexible(amountController.text.trim()) ?? 0.0;
          final currentRate = double.tryParse(exchangeRateController.text.trim()) ?? 1.0;
          final equivYer = toYemeniEquivalent(rawAmount, currency, currentRate);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.incomeGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.payments_outlined,
                            color: AppTheme.incomeGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'قبض دفعة من الإيراد',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              income.title,
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // بطاقة المتبقي وخيار السداد الكامل بنقرة واحدة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('المبلغ المتبقي المطلوب تحصيله:',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '${remaining.formattedFull} ر.ي',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.incomeGreen,
                            side: BorderSide(color: AppTheme.incomeGreen),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.done_all, size: 16),
                          label: const Text('كامل المتبقي',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                          onPressed: () {
                            setSheetState(() {
                              if (currency == baseCurrencyCode) {
                                amountController.text = remaining.plain;
                              } else {
                                final r = double.tryParse(exchangeRateController.text) ?? 1.0;
                                if (r > 0) {
                                  amountController.text = (remaining / r).toStringAsFixed(1);
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // حقل المبلغ والعملة
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: amountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'مبلغ الدفعة المستلمة *',
                            suffixText: currencyLabel(currency),
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: currency,
                          decoration: const InputDecoration(
                            labelText: 'العملة',
                            prefixIcon: Icon(Icons.currency_exchange, size: 18),
                          ),
                          items: supportedCurrencyCodes
                              .map((code) => DropdownMenuItem(
                                    value: code,
                                    child: Text(currencyLabel(code)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setSheetState(() {
                              currency = val;
                              if (val == baseCurrencyCode) {
                                exchangeRateController.text = '1';
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (currency != baseCurrencyCode) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: exchangeRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'سعر الصرف مقابل الريال اليمني *',
                        helperText: 'يثبت سعر الصرف بتاريخ استلام الدفعة',
                        prefixIcon: Icon(Icons.price_change_outlined),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    if (rawAmount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlueDim,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'المبلغ المعادل باليمني: ${equivYer.formattedFull} ر.ي',
                                style: TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),

                  // تاريخ الاستلام
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today_outlined,
                        color: AppTheme.accentBlue),
                    title: Text('تاريخ الاستلام',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    subtitle: Text(
                      DateFormat('EEEE، dd MMMM yyyy', 'ar').format(paymentDate),
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    trailing: Icon(Icons.edit_calendar,
                        size: 20, color: AppTheme.textMuted),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setSheetState(() => paymentDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 6),

                  // المحفظة المورد إليها
                  if (provider.wallets.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: selectedWalletId,
                      decoration: const InputDecoration(
                        labelText: 'المحفظة المورد إليها النقد *',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: provider.wallets
                          .map((w) => DropdownMenuItem(
                                value: w.id,
                                child: Text(w.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedWalletId = v),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ملاحظات
                  TextFormField(
                    controller: noteController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الدفعة (اختياري)',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // زر التأكيد والحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.incomeGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final entered =
                            tryParseFlexible(amountController.text.trim()) ?? 0.0;
                        if (entered <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('يرجى إدخال مبلغ صحيح')),
                          );
                          return;
                        }

                        final rate = currency == baseCurrencyCode
                            ? 1.0
                            : (double.tryParse(exchangeRateController.text.trim()) ?? 1.0);
                        if (rate <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إدخال سعر صرف صحيح')),
                          );
                          return;
                        }
                        final equivalentInYemeni = toYemeniEquivalent(entered, currency, rate);

                        // تحديث المحفظة في الإيراد إن لم تكن محددة
                        if (income.walletId == null && selectedWalletId != null) {
                          income.walletId = selectedWalletId;
                          provider.updateIncome(income);
                        }

                        final newPayment = IncomePayment(
                          id: const Uuid().v4(),
                          incomeId: income.id,
                          amount: equivalentInYemeni,
                          date: paymentDate,
                          notes: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                          walletId: selectedWalletId ?? income.walletId,
                          currency: currency,
                          exchangeRate: rate,
                        );

                        provider.addIncomePayment(newPayment);
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم استلام دفعة بقيمة ${equivalentInYemeni.formattedFull} ر.ي بنجاح',
                            ),
                            backgroundColor: AppTheme.incomeGreen,
                          ),
                        );
                      },
                      child: const Text(
                        'تأكيد استلام الدفعة وتوريدها',
                        style:
                            TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- تأكيد حذف الإيراد ---
  void _confirmDeleteIncome(
    BuildContext context,
    FinanceProvider provider,
    Income income,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الإيراد',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'هل تريد بالتأكيد حذف "${income.title}"؟\nسيتم أيضاً إزالة سجلات الدفعات والمصروفات المرتبطة به.',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                );
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
