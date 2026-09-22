import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedYear = DateTime.now().year;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final rows = provider.monthlyReport();
        final totalIncome = rows.fold(0.0, (s, r) => s + r.income);
        final totalOut = rows.fold(0.0, (s, r) => s + r.out);
        final netCash = totalIncome - totalOut;
        final inventoryVal = provider.inventoryValue;
        final totalAssets = netCash + inventoryVal;

        // Years available in monthly report
        final availableYears = rows.map((r) => r.year).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        if (availableYears.isEmpty) {
          availableYears.add(DateTime.now().year);
        }
        if (!availableYears.contains(_selectedYear)) {
          _selectedYear = availableYears.first;
        }

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            backgroundColor: context.dynamicScaffoldBg,
            elevation: 0,
            title: const Text(
              'التقارير والتحليلات المالية',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.accentBlue,
              indicatorWeight: 3,
              labelColor: AppTheme.accentBlue,
              unselectedLabelColor: context.dynamicTextMuted,
              labelStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.analytics_outlined, size: 18),
                  text: 'نظرة شاملة',
                ),
                Tab(
                  icon: Icon(Icons.calendar_view_month_outlined, size: 18),
                  text: 'التقرير الشهري',
                ),
                Tab(
                  icon: Icon(Icons.landscape_outlined, size: 18),
                  text: 'ربحية المواضع',
                ),
                Tab(
                  icon: Icon(Icons.inventory_2_outlined, size: 18),
                  text: 'المخزون والسيولة',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, provider, totalIncome, totalOut,
                  netCash, inventoryVal, totalAssets),
              _buildMonthlyTab(context, provider, rows, availableYears),
              _buildPlotsProfitabilityTab(context, provider),
              _buildInventoryValuationTab(context, provider, inventoryVal),
            ],
          ),
        );
      },
    );
  }

  // ==================== TAB 1: OVERVIEW ====================

  Widget _buildOverviewTab(
    BuildContext context,
    FinanceProvider provider,
    double totalIncome,
    double totalOut,
    double netCash,
    double inventoryVal,
    double totalAssets,
  ) {
    final isProfit = netCash >= 0;
    final profitMargin = totalIncome > 0 ? (netCash / totalIncome) * 100 : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Hero Net Cash Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isProfit
                  ? [
                      AppTheme.incomeGreen.withValues(alpha: 0.18),
                      context.dynamicCardBg,
                    ]
                  : [
                      AppTheme.expenseRed.withValues(alpha: 0.18),
                      context.dynamicCardBg,
                    ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isProfit
                  ? AppTheme.incomeGreen.withValues(alpha: 0.35)
                  : AppTheme.expenseRed.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isProfit
                                  ? AppTheme.incomeGreen
                                  : AppTheme.expenseRed)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isProfit
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: isProfit
                              ? AppTheme.incomeGreen
                              : AppTheme.expenseRed,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'صافي الأرباح النقدية',
                        style: TextStyle(
                          color: context.dynamicTextSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isProfit
                              ? AppTheme.incomeGreen
                              : AppTheme.expenseRed)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isProfit
                          ? 'هامش ربح ${profitMargin.toStringAsFixed(1)}%'
                          : 'عجز نقدي',
                      style: TextStyle(
                        color: isProfit
                            ? AppTheme.incomeGreen
                            : AppTheme.expenseRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${netCash.formatted} ر.ي',
                style: TextStyle(
                  color: isProfit ? AppTheme.incomeGreen : AppTheme.expenseRed,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isProfit
                    ? 'الفائض النقدي التراكمي لجميع العمليات المسجلة'
                    : 'إجمالي المصروفات تجاوز الإيرادات المحققة',
                style: TextStyle(
                  color: context.dynamicTextMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Inflow & Outflow Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'إجمالي الإيرادات',
                value: '${totalIncome.formatted} ر.ي',
                subtitle: '${provider.incomes.length} حركة قبض',
                icon: Icons.arrow_downward_rounded,
                color: AppTheme.incomeGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'إجمالي المصروفات',
                value: '${totalOut.formatted} ر.ي',
                subtitle: '${provider.expenses.length} حركة صرف',
                icon: Icons.arrow_upward_rounded,
                color: AppTheme.expenseRed,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Total Assets Banner (Cash Net + Inventory Value)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.dynamicCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.dynamicCardBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance_wallet_outlined,
                            color: AppTheme.accentBlue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المركز المالي الشامل',
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'السيولة النقدية + قيمة بضاعة المخازن',
                            style: TextStyle(
                              color: context.dynamicTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${totalAssets.formatted} ر.ي',
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: totalAssets > 0
                      ? (netCash > 0 ? (netCash / totalAssets).clamp(0.0, 1.0) : 0.0)
                      : 0.5,
                  minHeight: 8,
                  backgroundColor: Colors.amber.withValues(alpha: 0.3),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.incomeGreen),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'سيولة نقدية: ${netCash.formatted} ر.ي',
                    style: TextStyle(
                      color: AppTheme.incomeGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'مخزون عيني: ${inventoryVal.formatted} ر.ي',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section Title: Quick Financial Indicators
        Text(
          'مؤشرات الأداء والتوزيعات',
          style: TextStyle(
            color: context.dynamicTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildSecondaryCard(
                context,
                title: 'توزيعات الشركاء',
                mainValue: '${provider.paidPartnerTotal.formatted} ر.ي',
                subText:
                    'متبقي ${provider.pendingPartnerTotal.formatted} ر.ي مستحق',
                icon: Icons.people_outline,
                iconColor: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryCard(
                context,
                title: 'زكاة الزروع',
                mainValue:
                    '${provider.zakatEntries.fold(0.0, (s, e) => s + e.amount).formatted} ر.ي',
                subText: '${provider.zakatEntries.length} سجل زكاة مسجل',
                icon: Icons.volunteer_activism_outlined,
                iconColor: Colors.purple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildSecondaryCard(
                context,
                title: 'أجور العمال المصروفة',
                mainValue:
                    '${provider.expenses.where((e) => e.category == 'أجور عمال' || e.workerId != null).fold(0.0, (s, e) => s + e.amount).formatted} ر.ي',
                subText: '${provider.workers.length} عامل مسجل',
                icon: Icons.engineering_outlined,
                iconColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryCard(
                context,
                title: 'فواتير المشتريات',
                mainValue:
                    '${provider.purchases.fold(0.0, (s, p) => s + p.totalAmount).formatted} ر.ي',
                subText: '${provider.purchases.length} فاتورة شراء',
                icon: Icons.shopping_cart_outlined,
                iconColor: AppTheme.accentBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.dynamicTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: context.dynamicTextMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryCard(
    BuildContext context, {
    required String title,
    required String mainValue,
    required String subText,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.dynamicTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style: TextStyle(
              color: context.dynamicTextMuted,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: MONTHLY ====================

  Widget _buildMonthlyTab(
    BuildContext context,
    FinanceProvider provider,
    List<MonthlyReportRow> allRows,
    List<int> availableYears,
  ) {
    final yearRows = allRows.where((r) => r.year == _selectedYear).toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    final yearIncome = yearRows.fold(0.0, (s, r) => s + r.income);
    final yearOut = yearRows.fold(0.0, (s, r) => s + r.out);
    final yearNet = yearIncome - yearOut;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Year Selector Filter Chips
        Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: AppTheme.accentBlue),
            const SizedBox(width: 8),
            Text(
              'السنة المالية:',
              style: TextStyle(
                color: context.dynamicTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: availableYears.map((y) {
                    final isSel = y == _selectedYear;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text('$y'),
                        selected: isSel,
                        selectedColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.accentBlue,
                        labelStyle: TextStyle(
                          fontFamily: 'Cairo',
                          color: isSel
                              ? AppTheme.accentBlue
                              : context.dynamicTextSecondary,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: isSel
                              ? AppTheme.accentBlue
                              : context.dynamicCardBorder,
                        ),
                        backgroundColor: context.dynamicCardBg,
                        onSelected: (_) => setState(() => _selectedYear = y),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Year Summary Strip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.dynamicCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.dynamicCardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('إيراد $_selectedYear',
                      style: TextStyle(
                          color: context.dynamicTextMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('${yearIncome.formatted} ر.ي',
                      style: TextStyle(
                          color: AppTheme.incomeGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
              Container(
                  height: 24, width: 1, color: context.dynamicCardBorder),
              Column(
                children: [
                  Text('مصروف $_selectedYear',
                      style: TextStyle(
                          color: context.dynamicTextMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('${yearOut.formatted} ر.ي',
                      style: TextStyle(
                          color: AppTheme.expenseRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
              Container(
                  height: 24, width: 1, color: context.dynamicCardBorder),
              Column(
                children: [
                  Text('صافي $_selectedYear',
                      style: TextStyle(
                          color: context.dynamicTextMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('${yearNet.formatted} ر.ي',
                      style: TextStyle(
                          color: yearNet >= 0
                              ? AppTheme.incomeGreen
                              : AppTheme.expenseRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (yearRows.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.dynamicCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.calendar_month_outlined,
                    color: context.dynamicTextMuted, size: 48),
                const SizedBox(height: 12),
                Text(
                  'لا توجد حركات مالية مسجلة لسنة $_selectedYear',
                  style: TextStyle(
                      color: context.dynamicTextSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          ...yearRows.map((row) => _buildMonthCard(context, row)),
      ],
    );
  }

  Widget _buildMonthCard(BuildContext context, MonthlyReportRow row) {
    final isProfit = row.net >= 0;
    final total = row.income + row.out;
    final incomeRatio = total > 0 ? (row.income / total) : 0.5;
    final monthName =
        DateFormat('MMMM yyyy', 'ar').format(DateTime(row.year, row.month));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isProfit
                              ? AppTheme.incomeGreen
                              : AppTheme.expenseRed)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${row.month}',
                        style: TextStyle(
                          color: isProfit
                              ? AppTheme.incomeGreen
                              : AppTheme.expenseRed,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    monthName,
                    style: TextStyle(
                      color: context.dynamicTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isProfit
                          ? AppTheme.incomeGreen
                          : AppTheme.expenseRed)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${row.net >= 0 ? '+' : ''}${row.net.formatted} ر.ي',
                  style: TextStyle(
                    color:
                        isProfit ? AppTheme.incomeGreen : AppTheme.expenseRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Ratio Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: (incomeRatio * 100).round().clamp(1, 99),
                  child: Container(
                    height: 6,
                    color: AppTheme.incomeGreen,
                  ),
                ),
                Expanded(
                  flex: ((1.0 - incomeRatio) * 100).round().clamp(1, 99),
                  child: Container(
                    height: 6,
                    color: AppTheme.expenseRed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.incomeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'إيرادات: ${row.income.formatted} ر.ي',
                    style: TextStyle(
                      color: AppTheme.incomeGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
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
                  Text(
                    'صادر: ${row.out.formatted} ر.ي',
                    style: TextStyle(
                      color: AppTheme.expenseRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: PLOTS PROFITABILITY ====================

  Widget _buildPlotsProfitabilityTab(
    BuildContext context,
    FinanceProvider provider,
  ) {
    final plots = provider.landPlots;

    if (plots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.landscape_outlined,
                  color: context.dynamicTextMuted, size: 56),
              const SizedBox(height: 14),
              Text(
                'لم يتم تسجيل أي مواضع أو أراضٍ حتى الآن',
                style: TextStyle(
                    color: context.dynamicTextSecondary,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    // Compute metrics per plot
    final plotStats = plots.map((plot) {
      final plotIncomes =
          provider.incomes.where((i) => i.landPlotId == plot.id).toList();
      final plotExpenses = provider.expenses.where((e) {
        if (e.eventId != null) {
          final ev = provider.landEvents
              .firstWhereOrNull((l) => l.id == e.eventId);
          if (ev?.landPlotId == plot.id) return true;
        }
        for (final a in e.allocations) {
          final inc =
              provider.incomes.firstWhereOrNull((i) => i.id == a.incomeId);
          if (inc?.landPlotId == plot.id) return true;
        }
        return false;
      }).toList();

      final incTotal = plotIncomes.fold(0.0, (s, i) => s + i.amount);
      final expTotal = plotExpenses.fold(0.0, (s, e) => s + e.amount);
      final net = incTotal - expTotal;

      return {
        'plot': plot,
        'income': incTotal,
        'expense': expTotal,
        'net': net,
        'incomesCount': plotIncomes.length,
        'expensesCount': plotExpenses.length,
      };
    }).toList()
      ..sort((a, b) => (b['net'] as double).compareTo(a['net'] as double));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.accentBlue.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'مقارنة الإيرادات والمصروفات وصافي العائد لكل قطعة أرض وموضع زراعي',
                  style: TextStyle(
                    color: context.dynamicTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...plotStats.map((stat) {
          final plot = stat['plot'] as LandPlot;
          final inc = stat['income'] as double;
          final exp = stat['expense'] as double;
          final net = stat['net'] as double;
          final isProfit = net >= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.dynamicCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.eco_rounded,
                              color: AppTheme.accentBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plot.name,
                              style: TextStyle(
                                color: context.dynamicTextPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${plot.category == 'owned' ? 'ملك (تحت اليد)' : 'مشروك'} · ${plot.numPlots} قصبة/لبنة (${plot.area.formatted} م²)',
                              style: TextStyle(
                                color: context.dynamicTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isProfit
                                ? AppTheme.incomeGreen
                                : AppTheme.expenseRed)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${net >= 0 ? '+' : ''}${net.formatted} ر.ي',
                        style: TextStyle(
                          color: isProfit
                              ? AppTheme.incomeGreen
                              : AppTheme.expenseRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الإيراد',
                                style: TextStyle(
                                    color: AppTheme.incomeGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${inc.formatted} ر.ي',
                                style: TextStyle(
                                    color: AppTheme.incomeGreen,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('المصروفات',
                                style: TextStyle(
                                    color: AppTheme.expenseRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${exp.formatted} ر.ي',
                                style: TextStyle(
                                    color: AppTheme.expenseRed,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==================== TAB 4: INVENTORY VALUATION ====================

  Widget _buildInventoryValuationTab(
    BuildContext context,
    FinanceProvider provider,
    double inventoryVal,
  ) {
    final productById = {for (final p in provider.products) p.id: p};
    final byWarehouse = <String, double>{};
    for (final w in provider.warehouses) {
      byWarehouse[w.id] = 0;
    }
    for (final item in provider.storageItems) {
      if (!byWarehouse.containsKey(item.warehouseId)) continue;
      byWarehouse[item.warehouseId] = byWarehouse[item.warehouseId]! +
          item.quantity * (productById[item.productId]?.purchasePrice ?? 0);
    }
    var undistributed = 0.0;
    for (final p in provider.products) {
      undistributed += p.currentStock * p.purchasePrice;
    }

    // Top high-value products
    final highValueProducts = [...provider.products]..sort((a, b) =>
        (b.currentStock * b.purchasePrice)
            .compareTo(a.currentStock * a.purchasePrice));
    final top5 = highValueProducts.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Hero Total Valuation Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentBlue.withValues(alpha: 0.15),
                context.dynamicCardBg,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppTheme.accentBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        color: AppTheme.accentBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي قيمة المخزون الحالي',
                        style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      Text(
                        '${provider.products.length} صنف مسجل في المستودعات',
                        style: TextStyle(
                            color: context.dynamicTextMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${inventoryVal.formatted} ر.ي',
                style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'توزيع القيمة حسب المستودعات',
          style: TextStyle(
            color: context.dynamicTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),

        if (provider.warehouses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.dynamicCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: Center(
              child: Text(
                'لا توجد مستودعات مسجلة',
                style: TextStyle(color: context.dynamicTextMuted),
              ),
            ),
          )
        else
          ...provider.warehouses.map((w) {
            final val = byWarehouse[w.id] ?? 0;
            final ratio = inventoryVal > 0 ? (val / inventoryVal) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.dynamicCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.dynamicCardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warehouse_outlined,
                              color: AppTheme.accentBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            w.name,
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${val.formatted} ر.ي',
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: context.dynamicSurfaceBg,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accentBlue),
                    ),
                  ),
                ],
              ),
            );
          }),

        if (undistributed > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.dynamicCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.all_inbox_outlined,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'مخزون عام غير موزع',
                      style: TextStyle(
                        color: context.dynamicTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${undistributed.formatted} ر.ي',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        Text(
          'أعلى 5 أصناف من حيث القيمة الإجمالية',
          style: TextStyle(
            color: context.dynamicTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),

        ...top5.map((p) {
          final val = p.currentStock * p.purchasePrice;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.dynamicCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${p.currentStock.formatted} ${p.unit} · سعر الوحدة: ${p.purchasePrice.formatted} ر.ي',
                        style: TextStyle(
                          color: context.dynamicTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${val.formatted} ر.ي',
                  style: TextStyle(
                    color: AppTheme.accentBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
