import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'wallets_screen.dart';
import 'all_expenses_screen.dart';
import 'manage_land_plots_screen.dart';
import 'manage_zahra_types_screen.dart';
import 'manage_zahras_screen.dart';
import 'manage_warehouses_screen.dart';
import 'manage_partners_screen.dart';
import 'manage_workers_screen.dart';
import 'manage_partnerships_screen.dart';
import 'distributions_screen.dart';
import 'work_hours_screen.dart';
import 'pests_screen.dart';
import 'chemical_ingredients_screen.dart';
import 'products_screen.dart';
import 'purchases_screen.dart';
import 'reports_screen.dart';
import 'debt_settlement_screen.dart';
import 'incomes_screen.dart';
import 'personal_debts_screen.dart';
import 'manage_partnership_types_screen.dart';
import 'manage_event_types_screen.dart';
import 'backup_restore_screen.dart';
import 'zakat_screen.dart';
import 'agricultural_calendar_screen.dart';
import 'manage_expense_categories_screen.dart';
import 'agricultural_events_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          WalletsScreen(),
          MoreTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.dynamicCardBg,
          border: Border(
            top: BorderSide(
              color: context.dynamicCardBorder,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'الرئيسية',
                  unselectedIcon: Icons.space_dashboard_outlined,
                  selectedIcon: Icons.space_dashboard_rounded,
                ),
                _buildNavItem(
                  index: 1,
                  label: 'المحافظ',
                  unselectedIcon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet_rounded,
                ),
                _buildNavItem(
                  index: 2,
                  label: 'المزيد',
                  unselectedIcon: Icons.grid_view_outlined,
                  selectedIcon: Icons.grid_view_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData unselectedIcon,
    required IconData selectedIcon,
  }) {
    final isSelected = _index == index;
    final activeColor = context.dynamicIncomeGreen;
    final inactiveColor = context.dynamicTextSecondary;

    return InkWell(
      onTap: () => setState(() => _index = index),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: activeColor.withValues(alpha: 0.3), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem('الإيرادات', Icons.trending_up_outlined,
          AppTheme.incomeGreen, const IncomesScreen()),
      _MoreItem('كل المصروفات', Icons.receipt_long_outlined,
          AppTheme.expenseRed, const AllExpensesScreen()),
      _MoreItem('تصنيفات المصروفات', Icons.category_outlined,
          Colors.orange, const ManageExpenseCategoriesScreen()),
      _MoreItem('إدارة الديون', Icons.savings_outlined, Colors.orange,
          const DebtSettlementScreen()),
      _MoreItem('ديون شخصية', Icons.person_outline, Colors.teal,
          const PersonalDebtsScreen()),
      _MoreItem('المواضع', Icons.terrain, AppTheme.accentBlue,
          const ManageLandPlotsScreen()),
      _MoreItem('أنواع الزهرات', Icons.local_florist, AppTheme.incomeGreen,
          const ManageZahraTypesScreen()),
      _MoreItem('الزهرات', Icons.eco, AppTheme.incomeGreen,
          const ManageZahrasScreen()),
      _MoreItem('الأحداث الزراعية', Icons.event_note, Colors.teal,
          const AgriculturalEventsScreen()),
      _MoreItem('التقويم الزراعي', Icons.calendar_month, Colors.lightBlue,
          const AgriculturalCalendarScreen()),
      _MoreItem('أنواع الأحداث', Icons.category_outlined, Colors.teal,
          const ManageEventTypesScreen()),
      _MoreItem('نسخ احتياطي', Icons.backup_outlined, Colors.blue,
          const BackupRestoreScreen()),
      _MoreItem('المخازن', Icons.inventory_2_outlined, Colors.teal,
          const ManageWarehousesScreen()),
      _MoreItem('الأشخاص', Icons.people, AppTheme.accentBlue,
          const ManagePartnersScreen()),
      _MoreItem('عمال الأجر', Icons.engineering_outlined,
          AppTheme.expenseRed, const ManageWorkersScreen()),
      _MoreItem('الشراكات', Icons.link, AppTheme.accentBlue,
          const ManagePartnershipsScreen()),
      _MoreItem('أنواع الشراكات', Icons.category_outlined, Colors.teal,
          const ManagePartnershipTypesScreen()),
      _MoreItem('التوزيعات', Icons.payments_outlined, AppTheme.incomeGreen,
          const DistributionsScreen()),
      _MoreItem('سجلات الزكاة', Icons.volunteer_activism_outlined,
          AppTheme.incomeGreen, const ZakatScreen()),
      _MoreItem('سجل العمل', Icons.work_history, AppTheme.accentBlue,
          const WorkHoursScreen()),
      _MoreItem('الآفات الزراعية', Icons.bug_report_outlined,
          AppTheme.expenseRed, const PestsScreen()),
      _MoreItem('المواد الفعالة', Icons.science_outlined, Colors.purple,
          const ChemicalIngredientsScreen()),
      _MoreItem('المنتجات', Icons.inventory_outlined, Colors.teal,
          const ProductsScreen()),
      _MoreItem('المشتريات', Icons.shopping_cart_outlined, Colors.orange,
          const PurchasesScreen()),
      _MoreItem('التقارير', Icons.insights_outlined, AppTheme.incomeGreen,
          const ReportsScreen()),
    ];
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('المزيد'),
        actions: [
          Consumer<FinanceProvider>(
            builder: (context, provider, _) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  icon: Icon(
                    provider.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: provider.isDarkMode ? Colors.amber : AppTheme.accentBlue,
                  ),
                  tooltip: provider.isDarkMode
                      ? 'التبديل إلى الوضع النهاري (مريح تحت الشمس)'
                      : 'التبديل إلى الوضع الليلي',
                  onPressed: () => provider.toggleTheme(),
                ),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.95,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => item.screen)),
            child: Container(
              decoration: BoxDecoration(
                color: context.dynamicCardBg,
                borderRadius: BorderRadius.circular(16),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _MoreItem(this.label, this.icon, this.color, this.screen);
}