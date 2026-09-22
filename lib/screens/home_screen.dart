import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'income_detail_screen.dart';
import 'add_income_screen.dart';
import 'add_expense_screen.dart';
import 'batch_wage_payout_screen.dart';
import 'agricultural_calendar_screen.dart';
import 'manage_partnerships_screen.dart';
import 'agricultural_events_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hideBalances = false;
  String _selectedFilter = 'all'; // 'all', 'payment', 'expense', 'disburse'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      body: SafeArea(
        child: Consumer<FinanceProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return Center(
                child: CircularProgressIndicator(color: AppTheme.incomeGreen),
              );
            }
            final allOps = _buildOps(provider);
            final filteredOps = _selectedFilter == 'all'
                ? allOps
                : allOps.where((o) => o.type == _selectedFilter).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, provider)),
                SliverToBoxAdapter(child: _buildHeroBalanceCard(context, provider)),
                SliverToBoxAdapter(child: _buildQuickActionHub(context)),
                SliverToBoxAdapter(child: _buildFinancialTrendVisualizer(context, provider)),
                SliverToBoxAdapter(child: _buildFilterSection(allOps.length)),
                if (filteredOps.isEmpty)
                  _buildEmptyState()
                else
                  _buildOpsList(context, provider, filteredOps),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
        ),
        backgroundColor: context.dynamicIncomeGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'إيراد جديد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FinanceProvider provider) {
    final isDark = context.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.dynamicIncomeGreen,
                  context.dynamicAccentBlue,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: context.dynamicIncomeGreen.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'المتابع المالي والزراعي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.incomeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  'لوحة الإدارة والتشغيل المالي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: context.dynamicTextMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // زر إخفاء / إظهار الأرقام للخصوصية
          IconButton(
            onPressed: () => setState(() => _hideBalances = !_hideBalances),
            icon: Icon(
              _hideBalances ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: context.dynamicTextSecondary,
              size: 22,
            ),
            tooltip: _hideBalances ? 'إظهار الأرصدة' : 'إخفاء الأرصدة للخصوصية',
          ),
          // زر التبديل بين الوضع النهاري والليلي
          IconButton(
            onPressed: () => provider.toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : AppTheme.accentBlue,
              size: 22,
            ),
            tooltip: isDark ? 'الوضع النهاري (تحت الشمس)' : 'الوضع الليلي',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBalanceCard(BuildContext context, FinanceProvider provider) {
    final isDark = context.isDark;
    final totalWorkerDebts = provider.workers.fold(0.0, (s, w) => s + provider.workerDebt(w.id));
    final expenseRatio = provider.overallExpenseRatio.clamp(0.0, 100.0);

    // حالة الموقف المالي
    final String statusText;
    final Color statusColor;
    if (expenseRatio <= 50) {
      statusText = 'وضع مالي ممتاز';
      statusColor = AppTheme.incomeGreen;
    } else if (expenseRatio <= 80) {
      statusText = 'وضع مالي متوازن';
      statusColor = Colors.orange;
    } else {
      statusText = 'مصروفات مرتفعة';
      statusColor = AppTheme.expenseRed;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF152636), const Color(0xFF102D22)]
                : [const Color(0xFFEAF5F0), const Color(0xFFF1F6FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: context.dynamicIncomeGreen.withValues(alpha: isDark ? 0.3 : 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'صافي الرصيد التشغيلي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: context.dynamicTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hideBalances
                  ? '•••••••• ر.ي'
                  : '${provider.netBalance.formatted} ر.ي',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: provider.netBalance >= 0
                    ? context.dynamicIncomeGreen
                    : context.dynamicExpenseRed,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            if (!_hideBalances) ...[
              Text(
                'المبلغ الدقيق: ${provider.netBalance.formattedFull} ر.ي',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: context.dynamicTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _buildProgressBar(expenseRatio, context),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${expenseRatio.toStringAsFixed(1)}% نسبة المصروفات من الإيراد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: context.dynamicTextMuted,
                    fontSize: 11,
                  ),
                ),
                if (provider.totalIncome > 0)
                  Text(
                    'المتبقي: ${(100 - expenseRatio).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: context.dynamicIncomeGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: context.dynamicCardBorder, thickness: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statPill(
                    label: 'الإيرادات',
                    value: _hideBalances ? '••••' : '${provider.totalIncome.formatted} ر.ي',
                    color: context.dynamicIncomeGreen,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statPill(
                    label: 'المصروفات',
                    value: _hideBalances ? '••••' : '${provider.totalExpenses.formatted} ر.ي',
                    color: context.dynamicExpenseRed,
                    icon: Icons.trending_down_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statPill(
                    label: 'نقد المحافظ',
                    value: _hideBalances ? '••••' : '${provider.totalWalletsBalance.formatted} ر.ي',
                    color: context.dynamicAccentBlue,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            if (totalWorkerDebts > 0) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BatchWagePayoutScreen()),
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'أجور عمال مستحقة وغير مسددة: ${totalWorkerDebts.formatted} ر.ي',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Text(
                        'سداد ⚡',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double percent, BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final fillWidth = (constraints.maxWidth * (percent / 100)).clamp(0.0, constraints.maxWidth);
      final barColor = percent > 80
          ? context.dynamicExpenseRed
          : percent > 50
              ? Colors.orange
              : context.dynamicIncomeGreen;

      return Container(
        height: 6,
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.dynamicCardBorder,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: fillWidth,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: barColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildQuickActionHub(BuildContext context) {
    final actions = [
      _QuickAction(
        title: 'إيراد جديد',
        subtitle: 'تسجيل بيع أو دفعة',
        icon: Icons.add_circle_outline_rounded,
        color: context.dynamicIncomeGreen,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
        ),
      ),
      _QuickAction(
        title: 'تسجيل مصروف',
        subtitle: 'وقود، سماد، مواد',
        icon: Icons.receipt_long_rounded,
        color: context.dynamicExpenseRed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        ),
      ),
      _QuickAction(
        title: 'أجور العمال',
        subtitle: 'سداد مجمع فوري',
        icon: Icons.payments_outlined,
        color: Colors.amber.shade700,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BatchWagePayoutScreen()),
        ),
      ),
      _QuickAction(
        title: 'التقويم والري',
        subtitle: 'جدول السقي والرش',
        icon: Icons.water_drop_outlined,
        color: Colors.lightBlue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgriculturalCalendarScreen()),
        ),
      ),
      _QuickAction(
        title: 'كشف الشركاء',
        subtitle: 'توزيعات ومستحقات',
        icon: Icons.handshake_outlined,
        color: context.dynamicAccentBlue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManagePartnershipsScreen()),
        ),
      ),
      _QuickAction(
        title: 'الأحداث الزراعية',
        subtitle: 'قلب، تقليم، معالجة',
        icon: Icons.event_available_outlined,
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgriculturalEventsScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الوصول السريع',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: context.dynamicTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'أهم العمليات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: context.dynamicTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final a = actions[i];
                return InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 130,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.dynamicCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.dynamicCardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(a.icon, color: a.color, size: 18),
                        ),
                        const Spacer(),
                        Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          a.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: context.dynamicTextMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTrendVisualizer(BuildContext context, FinanceProvider provider) {
    final income = provider.totalIncome;
    final expense = provider.totalExpenses;
    final total = income + expense;
    final incomePercent = total > 0 ? (income / total) * 100 : 50.0;
    final expensePercent = total > 0 ? (expense / total) * 100 : 50.0;
    final coverageRatio = expense > 0 ? (income / expense) : (income > 0 ? 99.0 : 0.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.dynamicCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.dynamicCardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                    Icon(Icons.insights_rounded, color: context.dynamicAccentBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'تحليل التدفق والمؤشرات المالية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.dynamicAccentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'معدل التغطية: ${coverageRatio >= 99 ? 'مفتوح' : '${coverageRatio.toStringAsFixed(1)}x'}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: context.dynamicAccentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // شريط مقارنة متناسب بين الإيراد والمصروف
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: incomePercent.round().clamp(1, 99),
                      child: Container(
                        color: context.dynamicIncomeGreen,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: expensePercent.round().clamp(1, 99),
                      child: Container(
                        color: context.dynamicExpenseRed,
                      ),
                    ),
                  ],
                ),
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
                        color: context.dynamicIncomeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'الإيرادات: ${incomePercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                        color: context.dynamicExpenseRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'المصروفات: ${expensePercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  provider.netBalance >= 0 ? 'فائض تشغيلي 🟢' : 'عجز نقدي 🔴',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: provider.netBalance >= 0
                        ? context.dynamicIncomeGreen
                        : context.dynamicExpenseRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل العمليات المالية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: context.dynamicTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$totalCount حركة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: context.dynamicTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _filterChip('الكل', 'all'),
                const SizedBox(width: 8),
                _filterChip('الإيرادات فقط 🟢', 'payment'),
                const SizedBox(width: 8),
                _filterChip('المصروفات فقط 🔴', 'expense'),
                const SizedBox(width: 8),
                _filterChip('التصريف 🔵', 'disburse'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final activeColor = context.dynamicIncomeGreen;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.16)
              : context.dynamicCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : context.dynamicCardBorder,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: isSelected ? activeColor : context.dynamicTextSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                color: context.dynamicTextMuted, size: 54),
            const SizedBox(height: 14),
            Text(
              'لا توجد عمليات مسجلة في هذا القسم',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: context.dynamicTextSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'أضف إيراداً أو مصروفاً للبدء بتتبع التدفقات',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: context.dynamicTextMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Op> _buildOps(FinanceProvider provider) {
    final ops = <_Op>[];
    for (final income in provider.incomes) {
      for (final p in income.payments) {
        ops.add(_Op(
          type: 'payment',
          date: p.date,
          amount: p.amount,
          title: income.title,
          subtitle: 'دفعة مستلمة',
          income: income,
        ));
      }
    }
    for (final e in provider.expenses) {
      final income = e.allocations.isNotEmpty
          ? provider.incomes
              .firstWhereOrNull((i) => i.id == e.allocations.first.incomeId)
          : null;
      ops.add(_Op(
        type: 'expense',
        date: e.date,
        amount: e.amount,
        title: e.title,
        subtitle: income?.title,
        income: income,
        expense: e,
      ));
    }
    for (final m in provider.moneyMovements) {
      final income = m.incomeId != null
          ? provider.incomes.firstWhereOrNull((i) => i.id == m.incomeId)
          : null;
      final isDeposit = m.amount < 0;
      final debt = m.debtId != null
          ? provider.personalDebts.firstWhereOrNull((d) => d.id == m.debtId)
          : null;
      final person = debt != null
          ? provider.partners.firstWhereOrNull((p) => p.id == debt.personId)
          : null;
      final personName = person?.name ?? '';

      final String title;
      if (m.debtId != null) {
        if (isDeposit) {
          title = personName.isNotEmpty
              ? 'استلام ديون وأقساط من $personName'
              : 'استلام ديون وأقساط';
        } else {
          title = personName.isNotEmpty
              ? 'دفع ديون وأقساط إلى $personName'
              : 'دفع ديون وأقساط';
        }
      } else if (isDeposit) {
        title = 'توريد / إيداع نقدي';
      } else {
        title = 'تصريف نقدي';
      }

      ops.add(_Op(
        type: isDeposit ? 'payment' : 'disburse',
        date: m.date,
        amount: m.amount.abs(),
        title: title,
        subtitle: m.note ?? income?.title,
        income: income,
      ));
    }
    ops.sort((a, b) => b.date.compareTo(a.date));
    return ops;
  }

  Widget _buildOpsList(
      BuildContext context, FinanceProvider provider, List<_Op> ops) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final op = ops[index];
          final isPayment = op.type == 'payment';
          final isDisburse = op.type == 'disburse';
          final color = isPayment
              ? context.dynamicIncomeGreen
              : (isDisburse ? context.dynamicAccentBlue : context.dynamicExpenseRed);
          final icon = isPayment
              ? Icons.arrow_downward_rounded
              : (isDisburse ? Icons.swap_horiz_rounded : Icons.arrow_upward_rounded);

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: InkWell(
              onTap: () {
                if (op.type == 'expense' && op.expense != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(existing: op.expense),
                    ),
                  );
                } else if (op.income != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IncomeDetailScreen(incomeId: op.income!.id),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.dynamicCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.dynamicCardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy', 'ar').format(op.date),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: context.dynamicTextMuted,
                                  fontSize: 11,
                                ),
                              ),
                              if (op.subtitle != null && op.subtitle!.isNotEmpty) ...[
                                Text(' • ',
                                    style: TextStyle(color: context.dynamicTextMuted)),
                                Expanded(
                                  child: Text(
                                    op.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: context.dynamicTextSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hideBalances
                          ? '••••••'
                          : '${isPayment ? '+' : (isDisburse ? '' : '-')}${op.amount.formatted} ر.ي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: ops.length,
      ),
    );
  }
}

class _Op {
  final String type;
  final DateTime date;
  final double amount;
  final String title;
  final String? subtitle;
  final Income? income;
  final Expense? expense;

  const _Op({
    required this.type,
    required this.date,
    required this.amount,
    required this.title,
    this.subtitle,
    this.income,
    this.expense,
  });
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}