import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/data_export_import_button.dart';
import 'partnership_results_screen.dart';
import 'partner_statement_screen.dart';
import 'manage_partnership_types_screen.dart';
import 'manage_partners_screen.dart';

class ManagePartnershipsScreen extends StatefulWidget {
  const ManagePartnershipsScreen({super.key});

  @override
  State<ManagePartnershipsScreen> createState() =>
      _ManagePartnershipsScreenState();
}

class _ManagePartnershipsScreenState extends State<ManagePartnershipsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // الفلاتر
  String _statusFilter = 'all'; // all, active, ended
  String? _selectedPlotId;
  String? _selectedPartnerId;
  String? _selectedRole;
  String _sortBy = 'newest'; // newest, oldest, share_desc, share_asc, unpaid_desc
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
    if (_statusFilter != 'all') count++;
    if (_selectedPlotId != null) count++;
    if (_selectedPartnerId != null) count++;
    if (_selectedRole != null) count++;
    if (_sortBy != 'newest') count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _statusFilter = 'all';
      _selectedPlotId = null;
      _selectedPartnerId = null;
      _selectedRole = null;
      _sortBy = 'newest';
    });
  }

  String _getRoleName(String roleId, FinanceProvider provider) {
    final type = provider.partnershipTypeById(roleId);
    if (type != null) return type.name;
    if (roleId == 'water') return 'شريك ماء';
    if (roleId == 'worker') return 'شريك عمل';
    return roleId;
  }

  IconData _getRoleIcon(String roleId) {
    final r = roleId.toLowerCase();
    if (r.contains('ماء') || r.contains('ري') || r == 'water') {
      return Icons.water_drop_outlined;
    } else if (r.contains('عمل') || r.contains('عامل') || r == 'worker') {
      return Icons.engineering_outlined;
    } else if (r.contains('أرض') || r.contains('موضع')) {
      return Icons.terrain_outlined;
    }
    return Icons.handshake_outlined;
  }

  Color _getRoleColor(String roleId) {
    final r = roleId.toLowerCase();
    if (r.contains('ماء') || r.contains('ري') || r == 'water') {
      return Colors.lightBlue;
    } else if (r.contains('عمل') || r.contains('عامل') || r == 'worker') {
      return Colors.teal;
    }
    return AppTheme.accentBlue;
  }

  // حساب الأرقام المالية لشراكة معينة
  ({double totalEarned, double totalPaid, double unpaid, int distCount})
      _calcPartnershipStats(Partnership p, FinanceProvider provider) {
    final incomes = provider.incomes.where((i) =>
        i.landPlotId == p.landPlotId &&
        !i.date.isBefore(p.startDate) &&
        (p.endDate == null || !i.date.isAfter(p.endDate!)));

    double totalEarned = 0.0;
    double totalPaid = 0.0;
    int distCount = 0;

    for (final inc in incomes) {
      final dist = provider.distributions.firstWhereOrNull((d) =>
          d.incomeId == inc.id &&
          d.partnerId == p.partnerId &&
          d.role == p.role);
      if (dist != null) {
        totalEarned += dist.amount;
        if (provider.isDistributionPaid(dist)) totalPaid += dist.amount;
        distCount++;
      }
    }

    final unpaid = (totalEarned - totalPaid).clamp(0.0, double.infinity);
    return (
      totalEarned: totalEarned,
      totalPaid: totalPaid,
      unpaid: unpaid,
      distCount: distCount
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final allPartnerships = provider.partnerships;
        final now = DateTime.now();

        // فلترة الشراكات
        var filteredPartnerships = allPartnerships.where((p) {
          final isActive = p.endDate == null || !p.endDate!.isBefore(now);

          if (_statusFilter == 'active' && !isActive) return false;
          if (_statusFilter == 'ended' && isActive) return false;

          if (_selectedPlotId != null && p.landPlotId != _selectedPlotId) {
            return false;
          }
          if (_selectedPartnerId != null && p.partnerId != _selectedPartnerId) {
            return false;
          }
          if (_selectedRole != null && p.role != _selectedRole) {
            return false;
          }

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final partner =
                provider.partners.firstWhereOrNull((pt) => pt.id == p.partnerId);
            final plot =
                provider.landPlots.firstWhereOrNull((lp) => lp.id == p.landPlotId);
            final roleName = _getRoleName(p.role, provider).toLowerCase();

            final match = (partner != null && partner.name.toLowerCase().contains(q)) ||
                (plot != null && plot.name.toLowerCase().contains(q)) ||
                roleName.contains(q) ||
                p.sharePercentage.toString().contains(q);
            if (!match) return false;
          }

          return true;
        }).toList();

        // الترتيب
        if (_sortBy == 'newest') {
          filteredPartnerships.sort((a, b) => b.startDate.compareTo(a.startDate));
        } else if (_sortBy == 'oldest') {
          filteredPartnerships.sort((a, b) => a.startDate.compareTo(b.startDate));
        } else if (_sortBy == 'share_desc') {
          filteredPartnerships
              .sort((a, b) => b.sharePercentage.compareTo(a.sharePercentage));
        } else if (_sortBy == 'share_asc') {
          filteredPartnerships
              .sort((a, b) => a.sharePercentage.compareTo(b.sharePercentage));
        } else if (_sortBy == 'unpaid_desc') {
          filteredPartnerships.sort((a, b) {
            final statA = _calcPartnershipStats(a, provider).unpaid;
            final statB = _calcPartnershipStats(b, provider).unpaid;
            return statB.compareTo(statA);
          });
        }

        // إحصائيات المؤشرات المالية العامة
        int activeCount = 0;
        int endedCount = 0;
        double overallTotalEarned = 0.0;
        double overallTotalPaid = 0.0;
        double overallUnpaid = 0.0;

        for (final p in allPartnerships) {
          final isActive = p.endDate == null || !p.endDate!.isBefore(now);
          if (isActive) {
            activeCount++;
          } else {
            endedCount++;
          }
          final stats = _calcPartnershipStats(p, provider);
          overallTotalEarned += stats.totalEarned;
          overallTotalPaid += stats.totalPaid;
          overallUnpaid += stats.unpaid;
        }

        // تجميع حسب المواضع
        final Map<String, List<Partnership>> byPlot = {};
        for (final p in filteredPartnerships) {
          byPlot.putIfAbsent(p.landPlotId, () => []).add(p);
        }

        // تجميع حسب الشركاء
        final Map<String, List<Partnership>> byPartner = {};
        for (final p in filteredPartnerships) {
          byPartner.putIfAbsent(p.partnerId, () => []).add(p);
        }

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: const Text('الشراكات والأنصبة'),
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline_rounded),
                tooltip: 'إدارة الشركاء والأشخاص',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManagePartnersScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.category_outlined),
                tooltip: 'أنواع الشراكات',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManagePartnershipTypesScreen()),
                ),
              ),
              DataExportImportButton(
                label: 'الشراكات',
                buildRows: () =>
                    provider.partnerships.map((e) => e.toJson()).toList(),
                csvHeaders: const [
                  'الموضع',
                  'الشريك',
                  'الدور',
                  'النسبة %',
                  'تاريخ البداية',
                  'تاريخ النهاية'
                ],
                csvKeys: const [
                  'landPlotId',
                  'partnerId',
                  'role',
                  'sharePercentage',
                  'startDate',
                  'endDate'
                ],
                onImport: (rows) async {
                  for (final row in rows) {
                    try {
                      final item = Partnership.fromJson(row);
                      if (provider.partnerships.any((e) => e.id == item.id)) {
                        continue;
                      }
                      provider.addPartnership(item);
                    } catch (_) {}
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentBlue,
              indicatorWeight: 3,
              labelColor: AppTheme.accentBlue,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(
                  icon: const Icon(Icons.terrain_rounded, size: 18),
                  text: 'حسب المواضع (${byPlot.length})',
                ),
                Tab(
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  text: 'حسب الشركاء (${byPartner.length})',
                ),
                Tab(
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  text: 'القائمة (${filteredPartnerships.length})',
                ),
                const Tab(
                  icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  text: 'الملخص المالي',
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showForm(context, provider),
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('شراكة جديدة',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: Column(
            children: [
              // 1. شريط المؤشرات المالية للشراكات
              _buildKpiStrip(
                totalCount: allPartnerships.length,
                activeCount: activeCount,
                endedCount: endedCount,
                totalEarned: overallTotalEarned,
                totalPaid: overallTotalPaid,
                unpaid: overallUnpaid,
              ),

              // 2. شريط البحث والفلاتر
              if (_tabController.index != 3) _buildSearchAndFilters(provider),

              // 3. المحتوى حسب التبويب
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // تبويب حسب المواضع
                    _buildByPlotView(context, provider, byPlot),

                    // تبويب حسب الشركاء
                    _buildByPartnerView(context, provider, byPartner),

                    // تبويب القائمة المسطحة
                    _buildFlatListView(
                        context, provider, filteredPartnerships),

                    // تبويب الملخص المالي
                    _buildFinancialSummaryView(
                        context, provider, allPartnerships),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- شريط المؤشرات المالية للشراكات ---
  Widget _buildKpiStrip({
    required int totalCount,
    required int activeCount,
    required int endedCount,
    required double totalEarned,
    required double totalPaid,
    required double unpaid,
  }) {
    final paidRatio = totalEarned > 0 ? (totalPaid / totalEarned) : 0.0;

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
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.handshake_outlined,
                    color: AppTheme.accentBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي مستحقات الشركاء (أنصبة الأرباح)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${totalEarned.formattedFull} ر.ي',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      '$activeCount',
                      style: TextStyle(
                        color: AppTheme.incomeGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text('شراكة سارية',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // شريط نسبة السداد
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: paidRatio.clamp(0.0, 1.0),
              minHeight: 6,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.incomeGreen),
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),

          // تفصيل المدفوع والمتبقي
          Row(
            children: [
              Expanded(
                child: Row(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المدفوع والمورّد للشركاء',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11)),
                          Text(
                            '${totalPaid.formatted} ر.ي',
                            style: TextStyle(
                              color: AppTheme.incomeGreen,
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
                      decoration: BoxDecoration(
                        color: unpaid > 0
                            ? Colors.orangeAccent
                            : AppTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مستحقات معلقة للشركاء',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11)),
                          Text(
                            '${unpaid.formatted} ر.ي',
                            style: TextStyle(
                              color: unpaid > 0
                                  ? Colors.orangeAccent
                                  : AppTheme.textSecondary,
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
                      hintText: 'بحث باسم الشريك، الموضع، الدور...',
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
                      tooltip: 'خيارات التصفية والفرز',
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
                          color: AppTheme.accentBlue,
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

        // شرائح الحالة السريعة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildStatusChip('الكل', 'all'),
              const SizedBox(width: 8),
              _buildStatusChip('سارية ومستمرة', 'active',
                  color: AppTheme.incomeGreen),
              const SizedBox(width: 8),
              _buildStatusChip('منتهية', 'ended', color: AppTheme.textMuted),
            ],
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
                            hint: Text('كل المواضع',
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
                                (lp) => DropdownMenuItem<String?>(
                                  value: lp.id,
                                  child: Text(lp.name,
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

                    // تصفية حسب الشريك
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
                            value: _selectedPartnerId,
                            hint: Text('كل الشركاء',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('كل الشركاء',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              ...provider.partners.map(
                                (pt) => DropdownMenuItem<String?>(
                                  value: pt.id,
                                  child: Text(pt.name,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedPartnerId = v),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    // تصفية حسب الدور
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
                            value: _selectedRole,
                            hint: Text('كل الأدوار',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('كل الأدوار',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              const DropdownMenuItem<String?>(
                                value: 'water',
                                child: Text('شريك ماء',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              const DropdownMenuItem<String?>(
                                value: 'worker',
                                child: Text('شريك عمل',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              ...provider.partnershipTypes.map(
                                (pt) => DropdownMenuItem<String?>(
                                  value: pt.id,
                                  child: Text(pt.name,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _selectedRole = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // الفرز
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
                                  child: Text('الأحدث بداية',
                                      style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(
                                  value: 'oldest',
                                  child: Text('الأقدم بداية',
                                      style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(
                                  value: 'share_desc',
                                  child: Text('الأعلى نسبة %',
                                      style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(
                                  value: 'share_asc',
                                  child: Text('الأقل نسبة %',
                                      style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(
                                  value: 'unpaid_desc',
                                  child: Text('الأعلى مستحقات معلقة',
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

  Widget _buildStatusChip(String label, String value, {Color? color}) {
    final isSelected = _statusFilter == value;
    final activeColor = color ?? AppTheme.accentBlue;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.18)
                : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : AppTheme.cardBorder,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? activeColor : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // --- تبويب 1: العرض حسب المواضع ---
  Widget _buildByPlotView(BuildContext context, FinanceProvider provider,
      Map<String, List<Partnership>> byPlot) {
    if (byPlot.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: byPlot.entries.map((entry) {
        final plot =
            provider.landPlots.firstWhereOrNull((lp) => lp.id == entry.key);
        final partnerships = entry.value;

        // حساب إجمالي النسب في هذا الموضع
        final activePartnerships = partnerships
            .where((p) => p.endDate == null || !p.endDate!.isBefore(DateTime.now()))
            .toList();
        final totalActiveShare = activePartnerships.fold<double>(
            0.0, (s, p) => s + p.sharePercentage);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس بطاقة الموضع
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(
                      bottom: BorderSide(color: AppTheme.cardBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.terrain_rounded,
                          color: AppTheme.accentBlue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plot?.name ?? 'موضع غير محدد',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المساحة: ${plot?.area ?? '—'} قصبة · ${landPlotCategoryLabel(plot?.category ?? 'owned')}',
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
                          '${partnerships.length} شراكة',
                          style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'مجموع النسب: ${totalActiveShare.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: totalActiveShare > 100
                                ? AppTheme.expenseRed
                                : AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // قائمة شراكات هذا الموضع
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: partnerships
                      .map((p) => _buildPartnershipCard(context, provider, p))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- تبويب 2: العرض حسب الشركاء ---
  Widget _buildByPartnerView(BuildContext context, FinanceProvider provider,
      Map<String, List<Partnership>> byPartner) {
    if (byPartner.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: byPartner.entries.map((entry) {
        final partner =
            provider.partners.firstWhereOrNull((pt) => pt.id == entry.key);
        final partnerships = entry.value;

        // إحصائيات الشريك
        double pTotalEarned = 0.0;
        double pTotalPaid = 0.0;
        double pUnpaid = 0.0;

        for (final p in partnerships) {
          final stats = _calcPartnershipStats(p, provider);
          pTotalEarned += stats.totalEarned;
          pTotalPaid += stats.totalPaid;
          pUnpaid += stats.unpaid;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس بطاقة الشريك
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(
                      bottom: BorderSide(color: AppTheme.cardBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.teal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner?.name ?? 'شريك محذوف',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if (partner?.phone != null &&
                              partner!.phone!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              partner.phone!,
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.description_outlined,
                          color: AppTheme.accentBlue, size: 20),
                      tooltip: 'كشف حساب الشريك',
                      onPressed: () {
                        if (partner != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PartnerStatementScreen(
                                partnerId: partner.id,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${pTotalEarned.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (pUnpaid > 0)
                          Text(
                            'متبقي: ${pUnpaid.formatted} ر.ي',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          )
                        else
                          Text(
                            'مستلم بالكامل',
                            style: TextStyle(
                              color: AppTheme.incomeGreen,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // قائمة شراكات هذا الشريك
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: partnerships
                      .map((p) => _buildPartnershipCard(context, provider, p))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- تبويب 3: القائمة المسطحة الكاملة ---
  Widget _buildFlatListView(BuildContext context, FinanceProvider provider,
      List<Partnership> partnerships) {
    if (partnerships.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: partnerships.length,
      itemBuilder: (context, index) =>
          _buildPartnershipCard(context, provider, partnerships[index]),
    );
  }

  // --- تبويب 4: الملخص المالي والتوزيعات ---
  Widget _buildFinancialSummaryView(BuildContext context,
      FinanceProvider provider, List<Partnership> allPartnerships) {
    if (allPartnerships.isEmpty) {
      return _buildEmptyState(message: 'لا توجد بيانات شراكات لعرض الملخص');
    }

    // تجميع الحصص حسب كل شريك
    final partnerStats = <String, ({double earned, double paid, double unpaid, int count})>{};
    for (final p in allPartnerships) {
      final s = _calcPartnershipStats(p, provider);
      final prev = partnerStats[p.partnerId] ??
          (earned: 0.0, paid: 0.0, unpaid: 0.0, count: 0);
      partnerStats[p.partnerId] = (
        earned: prev.earned + s.totalEarned,
        paid: prev.paid + s.totalPaid,
        unpaid: prev.unpaid + s.unpaid,
        count: prev.count + 1,
      );
    }

    final sortedPartnerIds = partnerStats.keys.toList()
      ..sort((a, b) =>
          (partnerStats[b]?.unpaid ?? 0).compareTo(partnerStats[a]?.unpaid ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: AppTheme.accentBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'موقف حسابات الشركاء وتوزيعات الأرباح',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ...sortedPartnerIds.map((partnerId) {
          final partner =
              provider.partners.firstWhereOrNull((pt) => pt.id == partnerId);
          final stat = partnerStats[partnerId]!;
          final paidPct =
              stat.earned > 0 ? (stat.paid / stat.earned) : 1.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: stat.unpaid > 0
                    ? Colors.orangeAccent.withValues(alpha: 0.3)
                    : AppTheme.cardBorder,
              ),
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
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person,
                          color: AppTheme.accentBlue, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner?.name ?? 'شريك محذوف',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${stat.count} شراكات مسجلة',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: AppTheme.accentBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                      icon: const Icon(Icons.description, size: 14),
                      label: const Text('كشف الحساب',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PartnerStatementScreen(
                              partnerId: partnerId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // الأرقام المالية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إجمالي الاستحقاق',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11)),
                        Text(
                          '${stat.earned.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('المسدد له',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11)),
                        Text(
                          '${stat.paid.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.incomeGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('المتبقي المستحق',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11)),
                        Text(
                          '${stat.unpaid.formatted} ر.ي',
                          style: TextStyle(
                            color: stat.unpaid > 0
                                ? Colors.orangeAccent
                                : AppTheme.incomeGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
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
                    value: paidPct.clamp(0.0, 1.0),
                    minHeight: 5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.incomeGreen),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- بطاقة الشراكة المطورة والمفصلة ---
  Widget _buildPartnershipCard(
      BuildContext context, FinanceProvider provider, Partnership part) {
    final partner =
        provider.partners.firstWhereOrNull((p) => p.id == part.partnerId);
    final plot =
        provider.landPlots.firstWhereOrNull((lp) => lp.id == part.landPlotId);
    final roleName = _getRoleName(part.role, provider);
    final roleIcon = _getRoleIcon(part.role);
    final roleColor = _getRoleColor(part.role);

    final now = DateTime.now();
    final isActive = part.endDate == null || !part.endDate!.isBefore(now);
    final stats = _calcPartnershipStats(part, provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.greenAccent.withValues(alpha: 0.25)
              : AppTheme.cardBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isActive ? AppTheme.incomeGreen : AppTheme.textMuted,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // السطر الأول: الأيقونة، الاسم، الدور، ونسبة الشراكة
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(roleIcon, color: roleColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  partner?.name ?? 'شريك غير محدد',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.incomeGreen
                                          .withValues(alpha: 0.15)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isActive ? 'سارية' : 'منتهية',
                                  style: TextStyle(
                                    color: isActive
                                        ? AppTheme.incomeGreen
                                        : AppTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'الموضع: ${plot?.name ?? '—'} · $roleName',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppTheme.accentBlue.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${part.sharePercentage.toStringAsFixed(part.sharePercentage % 1 == 0 ? 0 : 1)}%',
                            style: TextStyle(
                              color: AppTheme.accentBlue,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('حصة الشريك',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 9)),
                      ],
                    ),
                    PopupMenuButton<String>(
                      color: AppTheme.surface,
                      icon: Icon(Icons.more_vert,
                          color: AppTheme.textMuted, size: 18),
                      onSelected: (v) {
                        if (v == 'edit') {
                          _showForm(context, provider, existing: part);
                        } else if (v == 'delete') {
                          _confirmDelete(context, provider, part);
                        } else if (v == 'statement') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PartnerStatementScreen(
                                partnerId: part.partnerId,
                                initialPlotId: part.landPlotId,
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'statement',
                            child: Text('كشف الحساب',
                                style: TextStyle(color: AppTheme.textPrimary))),
                        PopupMenuItem(
                            value: 'edit',
                            child: Text('تعديل الشراكة',
                                style: TextStyle(color: AppTheme.textPrimary))),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف الشراكة',
                                style: TextStyle(color: AppTheme.expenseRed))),
                      ],
                    ),
                  ],
                ),

                // الفترة الزمنية
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'من ${DateFormat('dd MMM yyyy', 'ar').format(part.startDate)}' +
                          (part.endDate != null
                              ? ' إلى ${DateFormat('dd MMM yyyy', 'ar').format(part.endDate!)}'
                              : ' (مستمرة حتى الآن)'),
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),

                // الأرقام المالية لهذه الشراكة
                if (stats.distCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المستحق: ${stats.totalEarned.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'المدفوع: ${stats.totalPaid.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.incomeGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        if (stats.unpaid > 0)
                          Text(
                            'المتبقي: ${stats.unpaid.formatted} ر.ي',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // أزرار الإجراءات السريعة
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentBlue,
                          side: BorderSide(color: AppTheme.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.analytics_outlined, size: 14),
                        label: const Text('نتائج وتوزيعات',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PartnershipResultsScreen(
                                partnership: part,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.expenseRed,
                          side: BorderSide(color: AppTheme.cardBorder),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined, size: 14),
                        label: const Text('إنهاء',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () =>
                            _endPartnership(context, provider, part),
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

  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off_rounded,
                color: AppTheme.textMuted, size: 56),
            const SizedBox(height: 14),
            Text(
              message ?? 'لا توجد شراكات تطابق معايير البحث أو الفلترة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك إضافة شراكة جديدة أو تعديل خيارات الفلترة',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            if (_activeFiltersCount > 0 || _searchQuery.isNotEmpty) ...[
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
          ],
        ),
      ),
    );
  }

  // --- نافذة إضافة أو تعديل الشراكة ---
  void _showForm(BuildContext context, FinanceProvider provider,
      {Partnership? existing}) {
    final formKey = GlobalKey<FormState>();
    String? landPlotId = existing?.landPlotId;
    String? partnerId = existing?.partnerId;
    String? role = existing?.role;
    double sharePercentage = existing?.sharePercentage ?? 25.0;
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  Text(
                    existing == null
                        ? 'تسجيل شراكة زراعية جديدة'
                        : 'تعديل بيانات الشراكة',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // اختيار الموضع
                  _dropField(
                    context,
                    'الموضع / الأرض',
                    Icons.terrain,
                    'اختر الموضع',
                    landPlotId,
                    provider.landPlots
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.name} (${landPlotCategoryLabel(p.category)})',
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 13),
                              ),
                            ))
                        .toList(),
                    (v) => setSheetState(() {
                      landPlotId = v;
                      role = null;
                      partnerId = null;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // اختيار الدور
                  _dropField(
                    context,
                    'الدور / نوع الشراكة',
                    Icons.work_outline,
                    'اختر الدور',
                    role,
                    () {
                      if (landPlotId == null) {
                        return <DropdownMenuItem<String>>[];
                      }
                      final existingRoles = provider.partnerships
                          .where((p) =>
                              p.landPlotId == landPlotId &&
                              (existing == null || p.id != existing.id) &&
                              (p.endDate == null ||
                                  p.endDate!.isAfter(DateTime.now())))
                          .map((p) => p.role)
                          .toSet();

                      final List<DropdownMenuItem<String>> items = [];

                      // الأدوار الافتراضية
                      if (!existingRoles.contains('water')) {
                        items.add(const DropdownMenuItem(
                          value: 'water',
                          child: Row(children: [
                            Icon(Icons.water_drop,
                                color: Colors.lightBlue, size: 16),
                            SizedBox(width: 8),
                            Text('شريك ماء'),
                          ]),
                        ));
                      }
                      if (!existingRoles.contains('worker')) {
                        items.add(const DropdownMenuItem(
                          value: 'worker',
                          child: Row(children: [
                            Icon(Icons.engineering,
                                color: Colors.teal, size: 16),
                            SizedBox(width: 8),
                            Text('شريك عمل'),
                          ]),
                        ));
                      }

                      // الأدوار المخصصة من قائمة الأنواع
                      for (final t in provider.partnershipTypes) {
                        if (!existingRoles.contains(t.id) &&
                            t.id != 'water' &&
                            t.id != 'worker') {
                          items.add(DropdownMenuItem(
                            value: t.id,
                            child: Row(children: [
                              Icon(Icons.handshake,
                                  color: AppTheme.accentBlue, size: 16),
                              const SizedBox(width: 8),
                              Text(t.name),
                            ]),
                          ));
                        }
                      }
                      return items;
                    }(),
                    (v) => setSheetState(() {
                      role = v;
                      partnerId = null;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // اختيار الشريك
                  _dropField(
                    context,
                    'الشريك',
                    Icons.person,
                    'اختر الشريك',
                    partnerId,
                    role == null
                        ? <DropdownMenuItem<String>>[]
                        : provider.partners
                            .where((p) =>
                                p.roles.contains(role!) || p.roles.isEmpty)
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.name,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13),
                                  ),
                                ))
                            .toList(),
                    (v) => setSheetState(() => partnerId = v),
                  ),
                  const SizedBox(height: 12),

                  // نسبة الشريك
                  TextFormField(
                    initialValue: sharePercentage.plain,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'نسبة الشريك من الأرباح % *',
                      prefixIcon: const Icon(Icons.percent_rounded),
                      suffixText: '%',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل النسبة';
                      final p = tryParseFlexible(v);
                      if (p == null || p <= 0 || p > 100) {
                        return 'النسبة يجب أن تكون بين 1 و 100%';
                      }
                      return null;
                    },
                    onChanged: (v) {
                      final p = tryParseFlexible(v);
                      if (p != null) setSheetState(() => sharePercentage = p);
                    },
                  ),
                  const SizedBox(height: 12),

                  // تاريخ البداية
                  _dateField(context, 'تاريخ بدء الشراكة', startDate,
                      (d) => setSheetState(() => startDate = d)),
                  const SizedBox(height: 12),

                  // تاريخ النهاية (اختياري)
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                            context,
                            'تاريخ انتهاء الشراكة (اختياري)',
                            endDate,
                            (d) => setSheetState(() => endDate = d)),
                      ),
                      if (endDate != null)
                        IconButton(
                          icon: Icon(Icons.close,
                              color: AppTheme.textMuted, size: 18),
                          onPressed: () => setSheetState(() => endDate = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final lid = landPlotId;
                        final pid = partnerId;
                        final r = role;
                        if (lid == null || pid == null || r == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('الرجاء تعبئة جميع الحقول المطلوبة'),
                              backgroundColor: AppTheme.expenseRed,
                            ),
                          );
                          return;
                        }

                        // التحقق من عدم تداخل الشراكات لنفس الدور والموضع
                        if (provider.partnerships.any((ps) {
                          if (ps.landPlotId != lid || ps.role != r) {
                            return false;
                          }
                          if (existing != null && ps.id == existing.id) {
                            return false;
                          }
                          final psEnd = ps.endDate ?? DateTime(2100);
                          final newEnd = endDate ?? DateTime(2100);
                          return startDate.isBefore(psEnd) &&
                              ps.startDate.isBefore(newEnd);
                        })) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('تعذر الحفظ',
                                  style:
                                      TextStyle(color: AppTheme.expenseRed)),
                              content: Text(
                                  'توجد شراكة أخرى بنفس الدور في هذا الموضع متداخلة في نفس الفترة الزمنية',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('حسناً',
                                      style: TextStyle(
                                          color: AppTheme.accentBlue)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        if (existing != null) {
                          existing.landPlotId = lid;
                          existing.partnerId = pid;
                          existing.role = r;
                          existing.sharePercentage = sharePercentage;
                          existing.startDate = startDate;
                          existing.endDate = endDate;
                          provider.updatePartnership(existing);
                        } else {
                          provider.addPartnership(Partnership(
                            id: const Uuid().v4(),
                            landPlotId: lid,
                            partnerId: pid,
                            role: r,
                            sharePercentage: sharePercentage,
                            startDate: startDate,
                            endDate: endDate,
                          ));
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(
                        existing == null ? 'تسجيل الشراكة' : 'تحديث الشراكة',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
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

  Widget _dropField(
      BuildContext context,
      String label,
      IconData icon,
      String hint,
      String? value,
      List<DropdownMenuItem<String>> items,
      ValueChanged<String?> onChanged) {
    return SheetDropdown<String>(
      label: label,
      labelAlways: true,
      icon: icon,
      iconColor: AppTheme.accentBlue,
      hint: hint,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _dateField(BuildContext context, String label, DateTime? date,
      ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: AppTheme.theme.copyWith(
              colorScheme: ColorScheme.dark(
                primary: AppTheme.accentBlue,
                surface: AppTheme.card,
              ),
            ),
            child: child!,
          ),
        );
        if (d != null) onChanged(d);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: AppTheme.accentBlue, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    date != null
                        ? DateFormat('dd MMM yyyy', 'ar').format(date)
                        : 'اختر التاريخ',
                    style: TextStyle(
                      color: date != null
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(label,
                    style:
                        TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _endPartnership(
      BuildContext context, FinanceProvider provider, Partnership part) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: part.startDate,
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: AppTheme.theme.copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.expenseRed,
            surface: AppTheme.card,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      part.endDate = date;
      provider.updatePartnership(part);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم إنهاء الشراكة وتحديد تاريخ النهاية: ${DateFormat('dd/MM/yyyy').format(date)}'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
    }
  }

  void _confirmDelete(
      BuildContext context, FinanceProvider provider, Partnership part) {
    final partner =
        provider.partners.firstWhereOrNull((p) => p.id == part.partnerId);
    final plot =
        provider.landPlots.firstWhereOrNull((lp) => lp.id == part.landPlotId);
    final hasPaid = provider.partnershipHasPaidDistributions(part.id);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الشراكة',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تريد بالتأكيد حذف شراكة ${partner?.name ?? ''} في ${plot?.name ?? ''}؟',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (hasPaid) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.expenseRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تنبيه: توجد حصص مسددة بالفعل نقداً لهذا الشريك، سيتم الاحتفاظ بها في السجلات وحذف الحصص غير المسددة فقط.',
                        style: TextStyle(color: AppTheme.expenseRed, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
              provider.deletePartnership(part.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف الشراكة ومزامنة التوزيعات بنجاح'),
                  backgroundColor: AppTheme.expenseRed,
                ),
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
