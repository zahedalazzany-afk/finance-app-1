import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'agricultural_calendar_screen.dart';
import 'manage_event_types_screen.dart';

/// شاشة إدارة الأحداث الزراعية والتشغيل اليومي مع لوحة المؤشرات، الفلاتر والبحث، وتصفية المستحقات
class AgriculturalEventsScreen extends StatefulWidget {
  final VoidCallback? onSwitchProposal;
  final bool isEmbedded;
  const AgriculturalEventsScreen({
    super.key,
    this.onSwitchProposal,
    this.isEmbedded = false,
  });

  static void showEventForm(BuildContext context, FinanceProvider provider,
      {LandEvent? existing, DateTime? initialDate, String? initialType, String? initialPlotId}) {
    _AgriculturalEventsScreenState._showEventFormProposal3(
      context,
      provider,
      existing: existing,
      initialDate: initialDate,
      initialType: initialType,
      initialPlotId: initialPlotId,
    );
  }

  static void showEventDetails(BuildContext context, FinanceProvider provider, LandEvent event) {
    _AgriculturalEventsScreenState._showDetailsProposal3(context, provider, event);
  }

  @override
  State<AgriculturalEventsScreen> createState() => _AgriculturalEventsScreenState();
}

class _AgriculturalEventsScreenState extends State<AgriculturalEventsScreen> {
  String _searchQuery = '';
  String? _selectedPlotId;
  String _statusFilter = 'all'; // 'all', 'debt', 'cash', 'materials'
  String? _selectedEventType;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text(
                'الأحداث الزراعية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: Icon(Icons.category_outlined, color: AppTheme.accentBlue),
                  tooltip: 'أنواع العمليات',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageEventTypesScreen()),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_month_rounded, color: AppTheme.accentBlue),
                  tooltip: 'التقويم الزراعي',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgriculturalCalendarScreen()),
                  ),
                ),
                if (widget.onSwitchProposal != null)
                  IconButton(
                    icon: Icon(Icons.swap_horiz, color: AppTheme.accentBlue),
                    tooltip: 'التبديل إلى المقترح الأول',
                    onPressed: widget.onSwitchProposal,
                  ),
              ],
            ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final allEvents = provider.landEvents;

          // Aggregates for Dashboard
          double totalCostAll = 0;
          double totalCashPaidAll = 0;
          double totalDebtRemainingAll = 0;
          int totalMaterialsTransactions = 0;

          for (final event in allEvents) {
            final expenses = provider.expensesForEvent(event.id);
            for (final exp in expenses) {
              final paid = provider.paidForExpense(exp.id);
              totalCashPaidAll += paid;
              totalDebtRemainingAll += (exp.amount - paid).clamp(0.0, double.infinity);
              totalCostAll += exp.amount;
            }
            final invTxs = provider.inventoryTransactions.where((t) => t.eventId == event.id && t.type == 'out');
            totalMaterialsTransactions += invTxs.length;
            for (final t in invTxs) {
              final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
              final product = item == null ? null : provider.products.firstWhereOrNull((p) => p.id == item.productId);
              totalCostAll += t.quantity * (product?.purchasePrice ?? 0);
            }
          }

          // Filter logic
          final filteredEvents = allEvents.where((e) {
            if (_selectedPlotId != null && e.landPlotId != _selectedPlotId) return false;
            if (_selectedEventType != null && e.eventType != _selectedEventType) return false;

            final expenses = provider.expensesForEvent(e.id);
            final hasDebt = expenses.any((exp) => (exp.amount - provider.paidForExpense(exp.id)) > 0.01);
            final hasMaterials = provider.inventoryTransactions.any((t) => t.eventId == e.id && t.type == 'out');

            if (_statusFilter == 'debt' && !hasDebt) return false;
            if (_statusFilter == 'cash' && hasDebt) return false;
            if (_statusFilter == 'materials' && !hasMaterials) return false;

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final plot = provider.landPlots.firstWhereOrNull((p) => p.id == e.landPlotId);
              final matchType = e.eventType.toLowerCase().contains(q);
              final matchPlot = (plot?.name ?? '').toLowerCase().contains(q);
              final matchNotes = (e.notes ?? '').toLowerCase().contains(q);
              final matchWorker = expenses.any((exp) {
                final w = provider.workers.firstWhereOrNull((wk) => wk.id == exp.workerId);
                return (w?.name ?? '').toLowerCase().contains(q);
              });
              if (!matchType && !matchPlot && !matchNotes && !matchWorker) return false;
            }
            return true;
          }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          return CustomScrollView(
            slivers: [
              // 1. Dashboard Overview
              SliverToBoxAdapter(
                child: _buildOperationsDashboard(
                  context,
                  eventsCount: allEvents.length,
                  totalCost: totalCostAll,
                  totalPaid: totalCashPaidAll,
                  totalDebt: totalDebtRemainingAll,
                  materialsCount: totalMaterialsTransactions,
                ),
              ),

              // 2. Search and Filter Bar
              SliverToBoxAdapter(
                child: _buildSearchAndFilterSection(context, provider),
              ),

              // 3. Events List or Empty State
              if (allEvents.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.agriculture_rounded, color: AppTheme.accentBlue, size: 54),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'لا توجد أحداث زراعية مسجلة',
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ابدأ بتسجيل أول حدث زراعي (سقي، تقليم، حراثة، رش...) وتابع مصاريفه ومواده بسهولة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.dynamicTextSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _showEventFormProposal3(context, provider),
                            icon: const Icon(Icons.add_task),
                            label: const Text('تسجيل أول حدث زراعي'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (filteredEvents.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_alt_off_rounded, color: context.dynamicTextSecondary, size: 48),
                          const SizedBox(height: 14),
                          Text(
                            'لا توجد أحداث تطابق الفلاتر المحددة',
                            style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'جرب تغيير كلمة البحث أو إعادة ضبط خيارات التصفية.',
                            style: TextStyle(color: context.dynamicTextSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                              _selectedPlotId = null;
                              _selectedEventType = null;
                              _statusFilter = 'all';
                            }),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('إعادة ضبط التصفية'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = filteredEvents[index];
                        final plot = provider.landPlots.firstWhereOrNull((p) => p.id == event.landPlotId);
                        return _buildEventCardProposal3(context, provider, event, plot);
                      },
                      childCount: filteredEvents.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventFormProposal3(context, context.read<FinanceProvider>()),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('تسجيل حدث زراعي', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // --- لوحة مؤشرات التشغيل والأحداث ---
  Widget _buildOperationsDashboard(
    BuildContext context, {
    required int eventsCount,
    required double totalCost,
    required double totalPaid,
    required double totalDebt,
    required int materialsCount,
  }) {
    final paidPercent = totalCost > 0 ? (totalPaid / totalCost).clamp(0.0, 1.0) : 1.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة العمليات والتشغيل الزراعي',
                      style: TextStyle(
                        color: context.dynamicTextPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'متابعة شاملة لتكاليف الأحداث والمستحقات النقدية والآجلة',
                      style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.dynamicSurfaceBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.dynamicCardBorder),
                ),
                child: Text(
                  '$eventsCount حدث',
                  style: TextStyle(
                    color: context.dynamicTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 KPIs Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'إجمالي التكاليف',
                  value: '${totalCost.formatted} ر.ي',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'المسدد نقداً',
                  value: '${totalPaid.formatted} ر.ي',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.incomeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'المتبقي آجل',
                  value: '${totalDebt.formatted} ر.ي',
                  icon: Icons.pending_actions_rounded,
                  color: totalDebt > 0 ? AppTheme.expenseRed : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'صرف المخزن',
                  value: '$materialsCount حركة',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.deepPurpleAccent,
                ),
              ),
            ],
          ),

          if (totalCost > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 7,
                child: Row(
                  children: [
                    Flexible(
                      flex: (paidPercent * 100).round(),
                      child: Container(color: AppTheme.incomeGreen),
                    ),
                    Flexible(
                      flex: ((1.0 - paidPercent) * 100).round(),
                      child: Container(color: AppTheme.expenseRed),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'نسبة السداد النقدي: ${(paidPercent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: AppTheme.incomeGreen, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                if (totalDebt > 0)
                  Text(
                    'المتبقي آجل: ${((1.0 - paidPercent) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: AppTheme.expenseRed, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: context.dynamicTextSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- قسم البحث والتصفية ---
  Widget _buildSearchAndFilterSection(BuildContext context, FinanceProvider provider) {
    final plots = provider.landPlots;
    final hasActiveFilter = _searchQuery.isNotEmpty ||
        _selectedPlotId != null ||
        _selectedEventType != null ||
        _statusFilter != 'all';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: context.dynamicSurfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.dynamicCardBorder),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'بحث في الأحداث، المواضع، العمال أو الملاحظات...',
                hintStyle: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status Filter Chips
                _buildFilterChip(
                  label: 'الكل',
                  isSelected: _statusFilter == 'all' && _selectedPlotId == null,
                  onSelected: () => setState(() {
                    _statusFilter = 'all';
                    _selectedPlotId = null;
                  }),
                ),
                _buildFilterChip(
                  label: '⚠️ ديون معلقة (آجل)',
                  isSelected: _statusFilter == 'debt',
                  color: AppTheme.expenseRed,
                  onSelected: () => setState(() => _statusFilter = _statusFilter == 'debt' ? 'all' : 'debt'),
                ),
                _buildFilterChip(
                  label: '✓ مسدد بالكامل',
                  isSelected: _statusFilter == 'cash',
                  color: AppTheme.incomeGreen,
                  onSelected: () => setState(() => _statusFilter = _statusFilter == 'cash' ? 'all' : 'cash'),
                ),
                _buildFilterChip(
                  label: '📦 مواد مخزن',
                  isSelected: _statusFilter == 'materials',
                  color: Colors.deepPurpleAccent,
                  onSelected: () => setState(() => _statusFilter = _statusFilter == 'materials' ? 'all' : 'materials'),
                ),

                // Plot filter chips
                if (plots.isNotEmpty) ...[
                  Container(
                    height: 18,
                    width: 1,
                    color: context.dynamicCardBorder,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  ...plots.map((p) => _buildFilterChip(
                        label: '🌱 ${p.name}',
                        isSelected: _selectedPlotId == p.id,
                        color: Colors.teal,
                        onSelected: () => setState(() {
                          _selectedPlotId = _selectedPlotId == p.id ? null : p.id;
                        }),
                      )),
                ],

                if (hasActiveFilter) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: Icon(Icons.close_rounded, size: 14, color: AppTheme.expenseRed),
                    label: Text('إلغاء التصفية', style: TextStyle(fontSize: 11, color: AppTheme.expenseRed)),
                    backgroundColor: AppTheme.expenseRed.withValues(alpha: 0.1),
                    side: BorderSide(color: AppTheme.expenseRed.withValues(alpha: 0.3)),
                    onPressed: () => setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedPlotId = null;
                      _selectedEventType = null;
                      _statusFilter = 'all';
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    final activeColor = color ?? AppTheme.accentBlue;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.dynamicTextPrimary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: activeColor,
        backgroundColor: context.dynamicSurfaceBg,
        showCheckmark: false,
        side: BorderSide(
          color: isSelected ? activeColor : context.dynamicCardBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  static IconData _eventIcon(String type) {
    if (type.contains('سقي') || type.contains('ري') || type.contains('ماء')) return Icons.water_drop_rounded;
    if (type.contains('رش') || type.contains('مبيد') || type.contains('سماد') || type.contains('تسميد')) return Icons.science_rounded;
    if (type.contains('قص') || type.contains('تقليم')) return Icons.content_cut_rounded;
    if (type.contains('قلب') || type.contains('حراثة') || type.contains('تربة') || type.contains('حرث')) return Icons.grass_rounded;
    if (type.contains('جني') || type.contains('حصاد') || type.contains('قطف')) return Icons.eco_rounded;
    return Icons.agriculture_rounded;
  }

  static Color _eventColor(String type) {
    if (type.contains('سقي') || type.contains('ري')) return Colors.lightBlue;
    if (type.contains('رش') || type.contains('مبيد') || type.contains('سماد')) return Colors.deepPurpleAccent;
    if (type.contains('قص') || type.contains('تقليم')) return Colors.orange;
    if (type.contains('قلب') || type.contains('حراثة') || type.contains('تربة')) return Colors.green;
    if (type.contains('جني') || type.contains('حصاد')) return Colors.amber;
    return Colors.teal;
  }

  static Widget _summaryMini(String label, double amount) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text('${amount.formatted} ر.ي',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Widget _buildEventCardProposal3(BuildContext context, FinanceProvider provider,
      LandEvent event, LandPlot? plot) {
    final eventExpenses = provider.expensesForEvent(event.id);
    final directExpenses = eventExpenses.where((e) => e.workerId == null).toList();
    final wageExpenses = eventExpenses.where((e) => e.workerId != null).toList();

    final inventoryTxs = provider.inventoryTransactions
        .where((t) => t.eventId == event.id && t.type == 'out')
        .toList();

    double materialsTotal = 0;
    for (final t in inventoryTxs) {
      final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
      final product = item == null
          ? null
          : provider.products.firstWhereOrNull((p) => p.id == item.productId);
      materialsTotal += t.quantity * (product?.purchasePrice ?? 0);
    }

    final directCash = directExpenses
        .where((e) => e.paymentMethod != 'debt')
        .fold(0.0, (s, e) => s + provider.paidForExpense(e.id));
    final directDebt = directExpenses
        .fold(0.0, (s, e) => s + (e.amount - provider.paidForExpense(e.id)).clamp(0.0, double.infinity));

    final wageCash = wageExpenses.fold(0.0, (s, e) => s + provider.paidForExpense(e.id));
    final wageDebt = wageExpenses.fold(0.0, (s, e) => s + (e.amount - provider.paidForExpense(e.id)).clamp(0.0, double.infinity));

    final totalCash = directCash + wageCash;
    final totalDebt = directDebt + wageDebt;

    final grandTotal = materialsTotal +
        directExpenses.fold(0.0, (s, e) => s + e.amount) +
        wageExpenses.fold(0.0, (s, e) => s + e.amount);

    final eventColor = _eventColor(event.eventType);

    // Days count and workers count
    final allDates = {
      ...eventExpenses.map((e) => DateFormat('yyyy-MM-dd').format(e.date)),
      ...inventoryTxs.map((t) => DateFormat('yyyy-MM-dd').format(t.date)),
    };
    final daysCount = allDates.isEmpty ? 1 : allDates.length;
    final workersCount = wageExpenses.map((e) => e.workerId).toSet().length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailsProposal3(context, provider, event),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: eventColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_eventIcon(event.eventType), color: eventColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              event.eventType,
                              style: TextStyle(
                                color: context.dynamicTextPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.dynamicSurfaceBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: context.dynamicCardBorder),
                              ),
                              child: Text(
                                plot?.name != null ? '🌱 ${plot!.name}' : 'بدون موضع',
                                style: TextStyle(
                                  color: context.dynamicTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('EEEE، dd MMMM yyyy', 'ar').format(event.date),
                          style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Debt Status Pill
                  if (totalDebt > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.expenseRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending_actions_rounded, color: AppTheme.expenseRed, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'آجل: ${totalDebt.formatted}',
                            style: TextStyle(
                              color: AppTheme.expenseRed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.incomeGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.incomeGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.incomeGreen, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'مسدد',
                            style: TextStyle(
                              color: AppTheme.incomeGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  PopupMenuButton<String>(
                    color: context.dynamicCardBg,
                    icon: Icon(Icons.more_vert_rounded, color: context.dynamicTextSecondary, size: 20),
                    onSelected: (val) {
                      if (val == 'details') _showDetailsProposal3(context, provider, event);
                      if (val == 'edit') _showEventFormProposal3(context, provider, existing: event);
                      if (val == 'delete') _confirmDelete(context, provider, event);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 18, color: AppTheme.accentBlue),
                            const SizedBox(width: 8),
                            Text('التفاصيل والتصفية', style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: context.dynamicTextPrimary),
                            const SizedBox(width: 8),
                            Text('تعديل الحدث', style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.expenseRed),
                            SizedBox(width: 8),
                            Text('حذف الحدث', style: TextStyle(color: AppTheme.expenseRed, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Operational Badges
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.dynamicSurfaceBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: Text(
                      '🗓️ ${daysCount <= 1 ? "يوم عمل واحد" : "$daysCount أيام عمل"}',
                      style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11),
                    ),
                  ),
                  if (workersCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Text(
                        '👥 $workersCount ${workersCount == 1 ? "عامل" : "عمال"}',
                        style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11),
                      ),
                    ),
                  if (inventoryTxs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '📦 ${inventoryTxs.length} مواد مصروفة',
                        style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),

              if (event.notes != null && event.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.dynamicSurfaceBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.notes!,
                    style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Divider(height: 1, color: context.dynamicCardBorder),
              const SizedBox(height: 10),

              // Financial footer and quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي تكلفة الحدث',
                          style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '${grandTotal.formatted} ر.ي',
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (totalDebt > 0) ...[
                        OutlinedButton(
                          onPressed: () => _showSettleRemainingSheet(context, provider, event, eventExpenses),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.expenseRed,
                            side: BorderSide(color: AppTheme.expenseRed),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('سداد المتبقي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => _showDetailsProposal3(context, provider, event),
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('التفاصيل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
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
    );
  }

  // --- تفاصيل ولوحة تصفية الحدث للمقترح الثالث ---
  static void _showDetailsProposal3(BuildContext context, FinanceProvider provider, LandEvent event) {
    final plot = provider.landPlots.firstWhereOrNull((p) => p.id == event.landPlotId);
    final allExpenses = provider.expensesForEvent(event.id);

    final inventoryTxs = provider.inventoryTransactions
        .where((t) => t.eventId == event.id && t.type == 'out')
        .toList();

    // تصنيف حسب التاريخ مع شمول مصاريف ومواد كل يوم
    final dates = {
      ...allExpenses.map((e) => DateFormat('yyyy-MM-dd').format(e.date)),
      ...inventoryTxs.map((t) => DateFormat('yyyy-MM-dd').format(t.date)),
    }.toList()..sort((a, b) => a.compareTo(b));
    if (dates.isEmpty) {
      dates.add(DateFormat('yyyy-MM-dd').format(event.date));
    }

    double materialsTotal = 0;
    for (final t in inventoryTxs) {
      final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
      final product = item == null
          ? null
          : provider.products.firstWhereOrNull((p) => p.id == item.productId);
      materialsTotal += t.quantity * (product?.purchasePrice ?? 0);
    }

    double cashPaidTotal = 0;
    double debtRemainingTotal = 0;
    for (final e in allExpenses) {
      final paid = provider.paidForExpense(e.id);
      cashPaidTotal += paid;
      debtRemainingTotal += (e.amount - paid).clamp(0.0, double.infinity);
    }

    final grandTotal = materialsTotal + cashPaidTotal + debtRemainingTotal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.view_timeline, color: Colors.teal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.eventType,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text('${plot?.name ?? '—'} · بدءاً من ${DateFormat('dd MMMM yyyy', 'ar').format(event.date)}',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // بطاقة الموقف المالي والتصفية
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الموقف المالي لتشغيل الحدث:',
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                        Text('${grandTotal.formatted} ر.ي',
                            style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                    Divider(height: 16, color: AppTheme.cardBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryMini('مواد المخزن', materialsTotal),
                        _summaryMini('المسدد نقداً', cashPaidTotal),
                        _summaryMini('المتبقي (ديون)', debtRemainingTotal),
                      ],
                    ),
                    if (debtRemainingTotal > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.price_check, size: 18),
                          label: const Text('تصفية وسداد المستحقات المعلقة الآن'),
                          onPressed: () {
                            Navigator.pop(context);
                            _showSettleRemainingSheet(context, provider, event, allExpenses);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // قسم المواد المستهلكة من المخزن
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  Text('المواد المستهلكة من المخزن',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const Spacer(),
                  Text('${inventoryTxs.length} مواد',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              if (inventoryTxs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text('لم يتم صرف مواد عينية من المخزن لهذا الحدث',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                )
              else
                ...inventoryTxs.map((t) {
                  final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
                  final product = item?.productId != null
                      ? provider.products.firstWhereOrNull((p) => p.id == item!.productId)
                      : null;
                  final displayQty = MaterialUnitHelper.formatConsumptionLabel(item, t.quantity,
                      customNotes: t.notes, product: product);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.science, color: Colors.teal, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item?.name ?? 'مادة محذوفة',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                        ),
                        Text(displayQty,
                            style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 20),
              Text('سجل اليوميات التشغيلية للحدث',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 10),

              // استعراض بنود كل يوم تشغيلي
              ...dates.map((dateStr) {
                final dayDate = DateTime.tryParse(dateStr) ?? event.date;
                final dayExpenses = allExpenses
                    .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateStr)
                    .toList();
                final dayDirect = dayExpenses.where((e) => e.workerId == null).toList();
                final dayWages = dayExpenses.where((e) => e.workerId != null).toList();
                final dayMaterials = inventoryTxs
                    .where((t) => DateFormat('yyyy-MM-dd').format(t.date) == dateStr)
                    .toList();

                double dayMatCost = 0;
                for (final t in dayMaterials) {
                  final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
                  final product = item == null
                      ? null
                      : provider.products.firstWhereOrNull((p) => p.id == item.productId);
                  dayMatCost += t.quantity * (product?.purchasePrice ?? 0);
                }
                final dayTotalCost =
                    dayExpenses.fold(0.0, (s, e) => s + e.amount) + dayMatCost;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.today, size: 16, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE، dd MMMM yyyy', 'ar').format(dayDate),
                            style: const TextStyle(
                                color: Colors.teal, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            'تكلفة اليوم: ${dayTotalCost.formatted} ر.ي',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      Divider(height: 14, color: AppTheme.cardBorder),

                      // العمال لهذا اليوم
                      if (dayWages.isNotEmpty) ...[
                        Text('أجور عمال اليوم:',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ...dayWages.map((e) {
                          final worker = provider.workers.firstWhereOrNull((w) => w.id == e.workerId);
                          final paid = provider.paidForExpense(e.id);
                          final rem = e.amount - paid;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: 14, color: AppTheme.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(worker?.name ?? 'عامل',
                                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                                ),
                                Text(
                                  rem <= 0
                                      ? 'دفع كامل: ${e.amount.formatted} ر.ي'
                                      : (paid > 0
                                          ? 'مدفوع جزئياً: ${paid.formatted} (باقي: ${rem.formatted} ر.ي)'
                                          : 'مؤجل كدين: ${e.amount.formatted} ر.ي'),
                                  style: TextStyle(
                                      color: rem <= 0 ? AppTheme.incomeGreen : Colors.orange,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],

                      // مصاريف ومستهلكات اليوم
                      if (dayDirect.isNotEmpty) ...[
                        Text('مصاريف تشغيلية لليوم:',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ...dayDirect.map((e) {
                          final paid = provider.paidForExpense(e.id);
                          final rem = e.amount - paid;
                          final isDebt = e.paymentMethod == 'debt';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_outlined, size: 14, color: AppTheme.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(e.title,
                                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                                ),
                                Text(
                                  rem <= 0
                                      ? 'نقدي: ${e.amount.formatted} ر.ي'
                                      : (isDebt
                                          ? 'آجل كدين: ${e.amount.formatted} ر.ي'
                                          : 'متبقي: ${rem.formatted} ر.ي'),
                                  style: TextStyle(
                                      color: rem <= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // المواد المستهلكة لهذا اليوم
                      if (dayMaterials.isNotEmpty) ...[
                        if (dayWages.isNotEmpty || dayDirect.isNotEmpty) const SizedBox(height: 8),
                        const Text('المواد المستهلكة لهذا اليوم:',
                            style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ...dayMaterials.map((t) {
                          final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
                          final product = item?.productId != null
                              ? provider.products.firstWhereOrNull((p) => p.id == item!.productId)
                              : null;
                          final displayQty = MaterialUnitHelper.formatConsumptionLabel(item, t.quantity,
                              customNotes: t.notes, product: product);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.science_outlined, size: 14, color: Colors.teal),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(item?.name ?? 'مادة محذوفة',
                                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                                ),
                                Text(
                                  displayQty,
                                  style: const TextStyle(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // تصفية المستحقات المعلقة للحدث
  static void _showSettleRemainingSheet(BuildContext context, FinanceProvider provider,
      LandEvent event, List<Expense> allExpenses) {
    final unpaid = allExpenses.where((e) => (e.amount - provider.paidForExpense(e.id)) > 0.01).toList();
    if (unpaid.isEmpty) return;

    String? walletId = provider.wallets.isNotEmpty ? provider.wallets.first.id : null;
    final fundingKey = GlobalKey<FundingPickerState>();
    final totalRemaining = unpaid.fold(0.0, (s, e) => s + (e.amount - provider.paidForExpense(e.id)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تصفية المستحقات المعلقة للحدث',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('المبلغ الإجمالي المطلوب سداده: ${totalRemaining.formatted} ر.ي لعدد ${unpaid.length} بنود',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              SheetDropdown<String>(
                label: 'المحفظة الصارفة للسداد *',
                icon: Icons.wallet,
                hint: 'اختر المحفظة',
                value: walletId,
                items: provider.wallets
                    .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                    .toList(),
                onChanged: (v) => setSheetState(() => walletId = v),
              ),
              const SizedBox(height: 12),
              FundingPicker(
                provider: provider,
                pickerKey: fundingKey,
                walletFilter: walletId,
                requiredTotal: totalRemaining,
                requiredTotalGetter: () => totalRemaining,
                autoAmount: totalRemaining,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (walletId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى اختيار المحفظة')));
                      return;
                    }
                    final funding = fundingKey.currentState?.allocations ?? [];
                    final sumFunding = funding.fold(0.0, (s, a) => s + a.amount);
                    if ((sumFunding - totalRemaining).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('مجموع التمويل يجب أن يساوي ${totalRemaining.formatted} ر.ي')));
                      return;
                    }

                    // سداد كل بند من بنود الديون
                    var pool = List.of(funding);
                    var poolIdx = 0;
                    var poolRem = pool.isEmpty ? 0.0 : pool[0].amount;

                    for (final exp in unpaid) {
                      final rem = exp.amount - provider.paidForExpense(exp.id);
                      if (rem <= 0) continue;

                      final slice = <ExpenseAllocation>[];
                      var need = rem;
                      while (need > 0.001 && poolIdx < pool.length) {
                        final take = need < poolRem ? need : poolRem;
                        slice.add(ExpenseAllocation(
                          incomeId: pool[poolIdx].incomeId,
                          paymentId: pool[poolIdx].paymentId,
                          debtSettlementId: pool[poolIdx].debtSettlementId,
                          debtId: pool[poolIdx].debtId,
                          amount: take,
                          currency: pool[poolIdx].currency,
                        ));
                        poolRem -= take;
                        need -= take;
                        if (poolRem <= 0.001) {
                          poolIdx++;
                          poolRem = poolIdx < pool.length ? pool[poolIdx].amount : 0;
                        }
                      }

                      provider.addExpensePayment(ExpensePayment(
                        id: const Uuid().v4(),
                        expenseId: exp.id,
                        amount: rem,
                        date: DateTime.now(),
                        walletId: walletId!,
                        funding: slice,
                      ));
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تصفية وسداد جميع المستحقات المعلقة للحدث بنجاح')));
                  },
                  child: const Text('تأكيد التصفية والسداد الآن', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- نموذج إضافة وتعديل حدث زراعي ---
  static void _showEventFormProposal3(BuildContext context, FinanceProvider provider,
      {LandEvent? existing, DateTime? initialDate, String? initialType, String? initialPlotId}) {
    String? landPlotId = existing?.landPlotId ?? initialPlotId ??
        (provider.landPlots.isNotEmpty ? provider.landPlots.first.id : null);
    String eventType = existing?.eventType ?? initialType ??
        (provider.eventTypesList.isNotEmpty ? provider.eventTypesList.first.name : 'أخرى');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    DateTime startDate = existing?.date ?? initialDate ?? DateTime.now();

    // قائمة الأيام التشغيلية للحدث
    final dailyLogs = <_OperationalDayLog>[];

    if (existing != null) {
      final allExpenses = provider.expensesForEvent(existing.id);
      final allTxs = provider.inventoryTransactions
          .where((t) => t.eventId == existing.id && t.type == 'out')
          .toList();
      final dates = {
        ...allExpenses.map((e) => DateFormat('yyyy-MM-dd').format(e.date)),
        ...allTxs.map((t) => DateFormat('yyyy-MM-dd').format(t.date)),
      }.toList()..sort((a, b) => a.compareTo(b));
      if (dates.isEmpty) {
        dates.add(DateFormat('yyyy-MM-dd').format(existing.date));
      }

      for (final dStr in dates) {
        final dDate = DateTime.tryParse(dStr) ?? existing.date;
        final dayLog = _OperationalDayLog(date: dDate);
        final dayExp = allExpenses.where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dStr);
        final dayTxs = allTxs.where((t) => DateFormat('yyyy-MM-dd').format(t.date) == dStr);

        for (final e in dayExp) {
          if (e.workerId != null) {
            final paid = provider.paidForExpense(e.id);
            final rem = e.amount - paid;
            String mode = 'cash';
            if (paid <= 0) {
              mode = 'debt';
            } else if (rem > 0) {
              mode = 'partial';
            }
            final line = _LaborLogLine()
              ..workerId = e.workerId
              ..existingId = e.id
              ..wageController.text = e.amount.plain
              ..paidController.text = paid.plain
              ..paymentMode = mode;
            if (paid > 0) {
              final p = provider.expensePaymentsFor(e.id).firstWhereOrNull((_) => true);
              line.walletId = p?.walletId;
            }
            dayLog.laborLines.add(line);
          } else {
            final paid = provider.paidForExpense(e.id);
            final rem = e.amount - paid;
            String mode = 'cash';
            if (paid <= 0) {
              mode = 'debt';
            } else if (rem > 0) {
              mode = 'partial';
            }
            final line = _DirectExpenseLogLine()
              ..titleController.text = e.title
              ..amountController.text = e.amount.plain
              ..paidController.text = paid.plain
              ..personId = e.personId
              ..paymentMode = mode
              ..existingId = e.id;
            if (paid > 0) {
              final p = provider.expensePaymentsFor(e.id).firstWhereOrNull((_) => true);
              line.walletId = p?.walletId;
            }
            dayLog.expenseLines.add(line);
          }
        }

        // تحميل المواد المستهلكة المسجلة لهذا اليوم
        for (final t in dayTxs) {
          final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
          final product = item?.productId != null
              ? provider.products.firstWhereOrNull((p) => p.id == item!.productId)
              : null;
          final displayQty = item != null
              ? MaterialUnitHelper.toDisplayUnits(item, t.quantity, product)
              : t.quantity;

          final line = _MaterialLogLine()
            ..existingId = t.id
            ..itemId = t.itemId
            ..warehouseId = item?.warehouseId
            ..qtyController.text = displayQty.plain;
          dayLog.materialLines.add(line);
        }

        dailyLogs.add(dayLog);
      }
    } else {
      // افتراضياً يوم واحد في البداية
      dailyLogs.add(_OperationalDayLog(date: startDate));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
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
                Text(
                  existing == null ? 'تسجيل حدث زراعي' : 'تعديل حدث زراعي',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),

                SheetDropdown<String>(
                  label: 'الموضع *',
                  icon: Icons.landscape,
                  hint: 'اختر الموضع',
                  value: landPlotId,
                  items: provider.landPlots
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => landPlotId = v),
                ),
                const SizedBox(height: 12),

                SheetDropdown<String>(
                  label: 'نوع الحدث',
                  icon: Icons.event_note,
                  hint: 'اختر نوع الحدث',
                  value: eventType,
                  items: provider.eventTypesList
                      .map((t) => DropdownMenuItem(value: t.name, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => eventType = v!),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الحدث العامة',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),

                // ==================================
                // الأيام التشغيلية (اليوم 1، اليوم 2...)
                // ==================================
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.calendar_view_day, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('الأيام التشغيلية للحدث',
                          style: TextStyle(
                              color: Colors.teal, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => setSheetState(() {
                        final nextDate = dailyLogs.isEmpty
                            ? DateTime.now()
                            : dailyLogs.last.date.add(const Duration(days: 1));
                        dailyLogs.add(_OperationalDayLog(date: nextDate));
                      }),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('إضافة يوم جديد للحدث', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...dailyLogs.asMap().entries.map((dayEntry) {
                  final dayIdx = dayEntry.key;
                  final day = dayEntry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ترويسة اليوم
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('اليوم ${dayIdx + 1}',
                                  style: const TextStyle(
                                      color: Colors.teal, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () async {
                                final p = await showDatePicker(
                                  context: context,
                                  initialDate: day.date,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (p != null) setSheetState(() => day.date = p);
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.edit_calendar, size: 16, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(day.date),
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (dailyLogs.length > 1)
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: AppTheme.expenseRed, size: 18),
                                onPressed: () => setSheetState(() => dailyLogs.removeAt(dayIdx)),
                              ),
                          ],
                        ),
                        Divider(height: 16, color: AppTheme.cardBorder),

                        // أجور عمال هذا اليوم مع السداد الجزئي
                        Row(
                          children: [
                            Text('عمال هذا اليوم',
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => setSheetState(() => day.laborLines.add(_LaborLogLine())),
                              icon: const Icon(Icons.add, size: 14, color: Colors.teal),
                              label: const Text('عامل', style: TextStyle(color: Colors.teal, fontSize: 11)),
                            ),
                          ],
                        ),

                        if (day.laborLines.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('لا يوجد عمال مسجلين في هذا اليوم',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ),

                        ...day.laborLines.asMap().entries.map((wEntry) {
                          final wIdx = wEntry.key;
                          final wl = wEntry.value;

                          // استبعاد العمال الذين تم اختيارهم بالفعل في نفس اليوم
                          final otherChosenWorkerIds = day.laborLines
                              .where((other) => !identical(other, wl) && other.workerId != null)
                              .map((other) => other.workerId!)
                              .toSet();
                          final availableWorkers = provider.workers
                              .where((w) => !otherChosenWorkerIds.contains(w.id))
                              .toList();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: SheetDropdown<String>(
                                        hint: 'العامل',
                                        label: 'العامل',
                                        value: wl.workerId,
                                        items: availableWorkers
                                            .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                                            .toList(),
                                        onChanged: (v) => setSheetState(() => wl.workerId = v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: wl.wageController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'الأجر المستحق'),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, size: 16, color: AppTheme.expenseRed),
                                      onPressed: () => setSheetState(() => day.laborLines.removeAt(wIdx)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // طريقة السداد: نقدي كامل / سداد جزئي / آجل كامل
                                Row(
                                  children: [
                                    Text('الدفع:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                    const SizedBox(width: 6),
                                    SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'cash', label: Text('نقدي')),
                                        ButtonSegment(value: 'partial', label: Text('جزئي')),
                                        ButtonSegment(value: 'debt', label: Text('آجل')),
                                      ],
                                      selected: {wl.paymentMode},
                                      onSelectionChanged: (s) => setSheetState(() {
                                        wl.paymentMode = s.first;
                                        if (wl.paymentMode == 'cash') {
                                          wl.paidController.text = wl.wageController.text;
                                        } else if (wl.paymentMode == 'debt') {
                                          wl.paidController.text = '0';
                                        }
                                      }),
                                      showSelectedIcon: false,
                                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                                    ),
                                  ],
                                ),

                                // حقل المبلغ المدفوع كاش الآن في السداد الجزئي
                                if (wl.paymentMode == 'partial') ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: wl.paidController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'المدفوع نقداً الآن (الباقي يؤجل كدين)',
                                      suffixText: 'ر.ي',
                                      helperText: 'المتبقي كدين: ${( (tryParseFlexible(wl.wageController.text) ?? 0) - (tryParseFlexible(wl.paidController.text) ?? 0) ).formatted} ر.ي',
                                      helperStyle: const TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                ],

                                // اختيار المحفظة ومصدر التمويل للجزء المدفوع نقداً
                                if (wl.paymentMode == 'cash' || wl.paymentMode == 'partial') ...[
                                  const SizedBox(height: 8),
                                  SheetDropdown<String>(
                                    label: 'المحفظة الصارفة *',
                                    icon: Icons.wallet,
                                    hint: 'اختر المحفظة',
                                    value: wl.walletId,
                                    items: provider.wallets
                                        .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                                        .toList(),
                                    onChanged: (v) => setSheetState(() => wl.walletId = v),
                                  ),
                                  const SizedBox(height: 8),
                                  FundingPicker(
                                    provider: provider,
                                    pickerKey: wl.fundingKey,
                                    walletFilter: wl.walletId,
                                    requiredTotalGetter: () {
                                      if (wl.paymentMode == 'cash') {
                                        final w = tryParseFlexible(wl.wageController.text) ?? 0;
                                        final p = tryParseFlexible(wl.paidController.text) ?? 0;
                                        return p > 0 ? p : w;
                                      } else {
                                        return tryParseFlexible(wl.paidController.text) ?? 0;
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                        if (day.laborLines.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 6),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setSheetState(() => day.laborLines.add(_LaborLogLine())),
                                icon: const Icon(Icons.add, size: 14, color: Colors.teal),
                                label: const Text('إضافة عامل آخر لهذا اليوم', style: TextStyle(color: Colors.teal, fontSize: 11)),
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        // مصاريف ومستهلكات هذا اليوم
                        Row(
                          children: [
                            Text('مصاريف ومستهلكات هذا اليوم',
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => setSheetState(() => day.expenseLines.add(_DirectExpenseLogLine())),
                              icon: const Icon(Icons.add, size: 14, color: Colors.orange),
                              label: const Text('مصروف', style: TextStyle(color: Colors.orange, fontSize: 11)),
                            ),
                          ],
                        ),

                        if (day.expenseLines.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('لا توجد مصاريف مسجلة في هذا اليوم',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ),

                        ...day.expenseLines.asMap().entries.map((eEntry) {
                          final eIdx = eEntry.key;
                          final el = eEntry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: el.titleController,
                                        decoration: const InputDecoration(
                                            labelText: 'بيان المصروف', hintText: 'مثال: وجبة عمال، وقود'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: el.amountController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'المبلغ'),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, size: 16, color: AppTheme.expenseRed),
                                      onPressed: () => setSheetState(() => day.expenseLines.removeAt(eIdx)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('الدفع:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                    const SizedBox(width: 6),
                                    SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'cash', label: Text('نقدي')),
                                        ButtonSegment(value: 'debt', label: Text('آجل')),
                                      ],
                                      selected: {el.paymentMode},
                                      onSelectionChanged: (s) => setSheetState(() => el.paymentMode = s.first),
                                      showSelectedIcon: false,
                                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                                    ),
                                  ],
                                ),
                                if (el.paymentMode == 'cash') ...[
                                  const SizedBox(height: 8),
                                  SheetDropdown<String>(
                                    label: 'المحفظة الصارفة *',
                                    icon: Icons.wallet,
                                    hint: 'اختر المحفظة',
                                    value: el.walletId,
                                    items: provider.wallets
                                        .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                                        .toList(),
                                    onChanged: (v) => setSheetState(() => el.walletId = v),
                                  ),
                                  const SizedBox(height: 8),
                                  FundingPicker(
                                    provider: provider,
                                    pickerKey: el.fundingKey,
                                    walletFilter: el.walletId,
                                    requiredTotalGetter: () =>
                                        tryParseFlexible(el.amountController.text) ?? 0,
                                  ),
                                ],
                                if (el.paymentMode == 'debt') ...[
                                  const SizedBox(height: 8),
                                  SheetDropdown<String>(
                                    label: 'الدائن (صاحب الدين علينا) *',
                                    icon: Icons.person,
                                    hint: 'اختر الشخص أو المورد',
                                    value: el.personId,
                                    items: provider.partners
                                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                                        .toList(),
                                    onChanged: (v) => setSheetState(() => el.personId = v),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                        if (day.expenseLines.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 6),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setSheetState(() => day.expenseLines.add(_DirectExpenseLogLine())),
                                icon: const Icon(Icons.add, size: 14, color: Colors.orange),
                                label: const Text('إضافة مصروف آخر لهذا اليوم', style: TextStyle(color: Colors.orange, fontSize: 11)),
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),
                        Divider(height: 1, color: AppTheme.cardBorder),
                        const SizedBox(height: 10),

                        // المواد الزراعية المستهلكة لهذا اليوم
                        Row(
                          children: [
                            const Icon(Icons.science_outlined, color: Colors.teal, size: 18),
                            const SizedBox(width: 6),
                            const Text('المواد المستهلكة لهذا اليوم',
                                style: TextStyle(
                                    color: Colors.teal, fontWeight: FontWeight.w700, fontSize: 13)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => setSheetState(() {
                                final wid = landPlotId == null
                                    ? null
                                    : provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId)?.warehouseId;
                                day.materialLines.add(_MaterialLogLine()..warehouseId = wid);
                              }),
                              icon: const Icon(Icons.add, size: 14, color: Colors.teal),
                              label: const Text('مادة مستهلكة', style: TextStyle(color: Colors.teal, fontSize: 11)),
                            ),
                          ],
                        ),

                        if (day.materialLines.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('لا توجد مواد مستهلكة مضافة في هذا اليوم (اختياري)',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ),

                        ...day.materialLines.asMap().entries.map((mEntry) {
                          final mIdx = mEntry.key;
                          final mLine = mEntry.value;
                          final wid = landPlotId == null
                              ? null
                              : provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId)?.warehouseId;
                          mLine.warehouseId = wid;
                          final warehouseItems = wid == null
                              ? <StorageItem>[]
                              : provider.getItemsForWarehouse(wid);

                          // استبعاد المواد المحددة بالفعل في نفس اليوم
                          final otherChosen = day.materialLines
                              .where((other) => !identical(other, mLine) && other.itemId != null)
                              .map((other) => other.itemId!)
                              .toSet();
                          final availableItems = warehouseItems
                              .where((s) => !otherChosen.contains(s.id))
                              .toList();

                          final item = warehouseItems.firstWhereOrNull((s) => s.id == mLine.itemId) ??
                              provider.storageItems.firstWhereOrNull((s) => s.id == mLine.itemId);
                          final product = item?.productId != null
                              ? provider.products.firstWhereOrNull((p) => p.id == item!.productId)
                              : null;
                          final itemUnit = MaterialUnitHelper.getItemUnit(item, product);

                          // حساب الرصيد المتاح بوحدة القياس
                          final existingTxQty = mLine.existingId == null
                              ? 0.0
                              : (provider.inventoryTransactions
                                      .firstWhereOrNull((t) => t.id == mLine.existingId)
                                      ?.quantity ??
                                  0.0);
                          final availableInUnits = item != null
                              ? MaterialUnitHelper.getAvailableInUnits(item, existingTxQty, product)
                              : 0.0;
                          final enteredQty = tryParseFlexible(mLine.qtyController.text);
                          final isExceeded = item != null && enteredQty != null && enteredQty > availableInUnits;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isExceeded ? AppTheme.expenseRed.withOpacity(0.6) : AppTheme.cardBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SheetDropdown<String>(
                                        hint: 'اختر المادة من المخزن',
                                        labelAbove: true,
                                        label: 'المادة الزراعية',
                                        value: mLine.itemId,
                                        items: availableItems
                                            .map((s) => DropdownMenuItem(
                                                value: s.id,
                                                child: Text('${s.name} (${s.quantity.formatted} ${s.unit})')))
                                            .toList(),
                                        onChanged: (v) => setSheetState(() {
                                          mLine.itemId = v;
                                        }),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, size: 16, color: AppTheme.expenseRed),
                                      onPressed: () => setSheetState(() => day.materialLines.removeAt(mIdx)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: mLine.qtyController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setSheetState(() {}),
                                  style: TextStyle(color: AppTheme.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: itemUnit.isNotEmpty ? 'الكمية المستهلكة ($itemUnit)' : 'الكمية المستهلكة',
                                    hintText: item != null ? 'المتاح: ${availableInUnits.formatted} $itemUnit' : 'أدخل الكمية',
                                    prefixIcon: const Icon(Icons.scale_outlined, size: 18),
                                    suffixText: itemUnit.isNotEmpty ? itemUnit : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (item != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isExceeded ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                          size: 14,
                                          color: isExceeded ? AppTheme.expenseRed : AppTheme.incomeGreen,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            isExceeded
                                                ? 'تجاوزت المتاح بالمخزن! (المتاح: ${availableInUnits.formatted} $itemUnit)'
                                                : (MaterialUnitHelper.getPackageSize(item, product) > 0
                                                    ? 'المتاح في المخزن: ${availableInUnits.formatted} $itemUnit (يعادل ${item.quantity.formatted} ${item.unit})'
                                                    : 'المتاح في المخزن: ${availableInUnits.formatted} $itemUnit'),
                                            style: TextStyle(
                                              color: isExceeded ? AppTheme.expenseRed : AppTheme.textMuted,
                                              fontSize: 11,
                                              fontWeight: isExceeded ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),

                        if (day.materialLines.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 6),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setSheetState(() {
                                  final wid = landPlotId == null
                                      ? null
                                      : provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId)?.warehouseId;
                                  day.materialLines.add(_MaterialLogLine()..warehouseId = wid);
                                }),
                                icon: const Icon(Icons.add, size: 14, color: Colors.teal),
                                label: const Text('إضافة مادة أخرى لهذا اليوم', style: TextStyle(color: Colors.teal, fontSize: 11)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                if (dailyLogs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: BorderSide(color: Colors.teal.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => setSheetState(() {
                          final nextDate = dailyLogs.isEmpty
                              ? DateTime.now()
                              : dailyLogs.last.date.add(const Duration(days: 1));
                          dailyLogs.add(_OperationalDayLog(date: nextDate));
                        }),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('إضافة يوم جديد للحدث',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ),

                // زر الحفظ النهائي للمقترح 3
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (landPlotId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى اختيار الموضع')));
                        return;
                      }

                      // التحقق الصارم من توفر المواد المستهلكة في المخزن عبر كل الأيام
                      final totalRequestedBasePerItem = <String, double>{};
                      final existingBasePerItem = <String, double>{};

                      for (final day in dailyLogs) {
                        for (final ml in day.materialLines) {
                          if (ml.itemId == null) continue;
                          final entered = tryParseFlexible(ml.qtyController.text) ?? 0;
                          if (entered <= 0) continue;
                          final item = provider.storageItems.firstWhereOrNull((s) => s.id == ml.itemId);
                          if (item == null) continue;
                          final product = item.productId != null
                              ? provider.products.firstWhereOrNull((p) => p.id == item.productId)
                              : null;

                          final baseQty = MaterialUnitHelper.toBaseStorageQty(item, entered, product);
                          totalRequestedBasePerItem[item.id] = (totalRequestedBasePerItem[item.id] ?? 0.0) + baseQty;

                          if (ml.existingId != null) {
                            final oldTx = provider.inventoryTransactions.firstWhereOrNull((t) => t.id == ml.existingId);
                            if (oldTx != null) {
                              existingBasePerItem[item.id] = (existingBasePerItem[item.id] ?? 0.0) + oldTx.quantity;
                            }
                          }
                        }
                      }

                      for (final entry in totalRequestedBasePerItem.entries) {
                        final itemId = entry.key;
                        final requestedBase = entry.value;
                        final item = provider.storageItems.firstWhereOrNull((s) => s.id == itemId);
                        if (item != null) {
                          final currentAvail = item.quantity + (existingBasePerItem[itemId] ?? 0.0);
                          if (requestedBase > currentAvail) {
                            final product = item.productId != null
                                ? provider.products.firstWhereOrNull((p) => p.id == item.productId)
                                : null;
                            final unit = MaterialUnitHelper.getItemUnit(item, product);
                            final maxUnits = MaterialUnitHelper.getAvailableInUnits(item, existingBasePerItem[itemId] ?? 0.0, product);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('الكمية الإجمالية المطلوبة من (${item.name}) تتجاوز رصيد المخزن المتاح (${maxUnits.formatted} $unit)'),
                              backgroundColor: AppTheme.expenseRed,
                            ));
                            return;
                          }
                        }
                      }

                      final eventId = existing?.id ?? const Uuid().v4();
                      final firstDate = dailyLogs.isNotEmpty ? dailyLogs.first.date : startDate;

                      if (existing != null) {
                        existing.landPlotId = landPlotId!;
                        existing.eventType = eventType;
                        existing.date = firstDate;
                        existing.notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
                        provider.updateLandEvent(existing);
                      } else {
                        provider.addLandEvent(LandEvent(
                          id: eventId,
                          landPlotId: landPlotId!,
                          eventType: eventType,
                          date: firstDate,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        ));
                      }

                      // حذف حركات المخزن السابقة المرتبطة بهذا الحدث لإعادة بنائها بدقة حسب الأيام
                      final oldTxs = provider.inventoryTransactions
                          .where((t) => t.eventId == eventId && t.type == 'out')
                          .toList();
                      for (final ot in oldTxs) {
                        provider.deleteInventoryTransaction(ot.id);
                      }

                      // حذف المصاريف القديمة لتحديثها بناء على اليوميات
                      final oldExpenses = provider.expensesForEvent(eventId);
                      for (final oe in oldExpenses) {
                        provider.deleteExpense(oe.id);
                      }

                      // حفظ كل الأيام التشغيلية
                      for (final day in dailyLogs) {
                        // حفظ عمال اليوم
                        for (final wl in day.laborLines) {
                          if (wl.workerId == null) continue;
                          final wage = tryParseFlexible(wl.wageController.text) ?? 0;
                          if (wage <= 0) continue;

                          final paid = wl.paymentMode == 'cash'
                              ? wage
                              : (wl.paymentMode == 'debt' ? 0.0 : (tryParseFlexible(wl.paidController.text) ?? 0));

                          final worker = provider.workers.firstWhereOrNull((w) => w.id == wl.workerId);
                          final expId = const Uuid().v4();

                          final wageExpense = Expense(
                            id: expId,
                            title: 'أجر ${worker?.name ?? 'عامل'} - يومية ${DateFormat('dd/MM').format(day.date)}',
                            amount: wage,
                            date: day.date,
                            category: 'عمالة',
                            eventId: eventId,
                            workerId: wl.workerId,
                            paymentMethod: wl.paymentMode,
                          );
                          provider.addExpense(wageExpense);

                          if (paid > 0 && wl.walletId != null) {
                            final funding = wl.fundingKey.currentState?.allocations ?? [];
                            provider.addExpensePayment(ExpensePayment(
                              id: const Uuid().v4(),
                              expenseId: expId,
                              amount: paid,
                              date: day.date,
                              walletId: wl.walletId!,
                              funding: funding,
                            ));
                          }

                          final remainingDebt = wage - paid;
                          if (remainingDebt > 0.01) {
                            final partner = provider.partners.firstWhereOrNull((p) => p.name == worker?.name);
                            if (partner != null) {
                              provider.addPersonalDebt(PersonalDebt(
                                id: const Uuid().v4(),
                                personId: partner.id,
                                direction: 'payable',
                                amount: remainingDebt,
                                date: day.date,
                                note: 'متبقي أجر عامل - حدث: $eventType',
                                eventId: eventId,
                                expenseId: expId,
                              ));
                            }
                          }
                        }

                        // حفظ مصاريف ومستهلكات اليوم
                        for (final el in day.expenseLines) {
                          final amount = tryParseFlexible(el.amountController.text) ?? 0;
                          if (amount <= 0) continue;
                          final title = el.titleController.text.trim().isEmpty
                              ? 'مصروف تشغيل'
                              : el.titleController.text.trim();

                          final expId = const Uuid().v4();
                          final expense = Expense(
                            id: expId,
                            title: '$title (${DateFormat('dd/MM').format(day.date)})',
                            amount: amount,
                            date: day.date,
                            category: 'أخرى',
                            eventId: eventId,
                            personId: el.personId,
                            paymentMethod: el.paymentMode,
                          );
                          provider.addExpense(expense);

                          if (el.paymentMode == 'cash' && el.walletId != null) {
                            final funding = el.fundingKey.currentState?.allocations ?? [];
                            provider.addExpensePayment(ExpensePayment(
                              id: const Uuid().v4(),
                              expenseId: expId,
                              amount: amount,
                              date: day.date,
                              walletId: el.walletId!,
                              funding: funding,
                            ));
                          } else if (el.paymentMode == 'debt' && el.personId != null) {
                            provider.addPersonalDebt(PersonalDebt(
                              id: const Uuid().v4(),
                              personId: el.personId!,
                              direction: 'payable',
                              amount: amount,
                              date: day.date,
                              note: 'مصروف حدث: $eventType ($title)',
                              eventId: eventId,
                              expenseId: expId,
                            ));
                          }
                        }

                        // حفظ المواد المستهلكة لهذا اليوم
                        for (final ml in day.materialLines) {
                          if (ml.itemId == null) continue;
                          final entered = tryParseFlexible(ml.qtyController.text) ?? 0;
                          if (entered <= 0) continue;
                          final item = provider.storageItems.firstWhereOrNull((s) => s.id == ml.itemId);
                          if (item == null) continue;
                          final product = item.productId != null
                              ? provider.products.firstWhereOrNull((p) => p.id == item.productId)
                              : null;

                          final baseQty = MaterialUnitHelper.toBaseStorageQty(item, entered, product);
                          final unit = MaterialUnitHelper.getItemUnit(item, product);
                          final note = '${entered.formatted} $unit';

                          provider.addInventoryTransaction(InventoryTransaction(
                            id: const Uuid().v4(),
                            itemId: ml.itemId!,
                            type: 'out',
                            quantity: baseQty,
                            date: day.date,
                            eventId: eventId,
                            notes: note,
                          ));
                        }
                      }

                      Navigator.pop(context);
                    },
                    child: Text(existing == null ? 'حفظ الحدث التشغيلي' : 'تحديث الحدث التشغيلي',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _confirmDelete(BuildContext context, FinanceProvider provider, LandEvent event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الحدث', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف "${event.eventType}" وكافة يومياته التشغيلية؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.deleteLandEvent(event.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}

class _OperationalDayLog {
  DateTime date;
  final List<_LaborLogLine> laborLines = [];
  final List<_DirectExpenseLogLine> expenseLines = [];
  final List<_MaterialLogLine> materialLines = [];
  _OperationalDayLog({required this.date});
}

class _LaborLogLine {
  String? workerId;
  String? existingId;
  final TextEditingController wageController = TextEditingController();
  final TextEditingController paidController = TextEditingController();
  String paymentMode = 'cash'; // 'cash' | 'partial' | 'debt'
  String? walletId;
  final GlobalKey<FundingPickerState> fundingKey = GlobalKey<FundingPickerState>();
}

class _DirectExpenseLogLine {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController paidController = TextEditingController();
  String? personId;
  String paymentMode = 'cash'; // 'cash' | 'debt'
  String? walletId;
  String? existingId;
  final GlobalKey<FundingPickerState> fundingKey = GlobalKey<FundingPickerState>();
}

class _MaterialLogLine {
  String? warehouseId;
  String? itemId;
  String? existingId;
  final TextEditingController qtyController = TextEditingController();
}

/// مساعد حساب وحدات قياس المواد المستهلكة المأخوذة مباشرة من بيانات المنتج
class MaterialUnitHelper {
  /// وحدة قياس المادة (تؤخذ من وحدة استخدام المنتج إذا كان معبأ، أو وحدة قياس الصنف الأساسية)
  static String getItemUnit(StorageItem? item, [Product? product]) {
    if (item == null) return '';
    final isPackaged = (item.isPackaged && (item.packageSize ?? 0) > 0) ||
        (product != null && product.isPackaged && product.packageSize > 0);
    if (isPackaged) {
      final u = item.usageUnit?.trim() ?? product?.usageUnit?.trim();
      if (u != null && u.isNotEmpty) return u;
    }
    if (product != null && product.unit.trim().isNotEmpty) {
      return product.unit.trim();
    }
    return item.unit.trim();
  }

  /// حجم العبوة الواحدة إذا كانت المادة معبأة
  static double getPackageSize(StorageItem? item, [Product? product]) {
    if (item == null) return 0.0;
    if (item.isPackaged && (item.packageSize ?? 0) > 0) {
      return item.packageSize!;
    }
    if (product != null && product.isPackaged && product.packageSize > 0) {
      return product.packageSize;
    }
    return 0.0;
  }

  /// حساب الرصيد المتاح بوحدة قياس المنتج
  static double getAvailableInUnits(StorageItem item, double existingDeductionInBaseUnits, [Product? product]) {
    final availableBase = item.quantity + existingDeductionInBaseUnits;
    if (availableBase <= 0) return 0.0;

    final pkgSize = getPackageSize(item, product);
    if (pkgSize > 0) {
      return availableBase * pkgSize;
    }
    return availableBase;
  }

  /// تحويل الكمية المدخلة بوحدة قياس المنتج إلى وحدات التخزين الأساسية (عبوات أو كمية أساسية)
  static double toBaseStorageQty(StorageItem item, double enteredQtyInUnits, [Product? product]) {
    if (enteredQtyInUnits <= 0) return 0.0;

    final pkgSize = getPackageSize(item, product);
    if (pkgSize > 0) {
      return enteredQtyInUnits / pkgSize;
    }
    return enteredQtyInUnits;
  }

  /// تحويل الكمية من وحدات التخزين الأساسية إلى وحدة قياس المنتج للعرض
  static double toDisplayUnits(StorageItem item, double baseQty, [Product? product]) {
    final pkgSize = getPackageSize(item, product);
    if (pkgSize > 0) {
      return baseQty * pkgSize;
    }
    return baseQty;
  }

  /// صياغة نص العرض المنسق لوحدة القياس مع بيان المعادل بالعبوات إن كانت المادة معبأة
  static String formatConsumptionLabel(StorageItem? item, double baseQty, {String? customNotes, Product? product}) {
    if (item == null) return '${baseQty.formatted} وحدة';

    if (customNotes != null && customNotes.trim().isNotEmpty) {
      final pkgSize = getPackageSize(item, product);
      if (pkgSize > 0) {
        return '$customNotes (${baseQty.formatted} ${item.unit})';
      }
      return customNotes;
    }

    final unit = getItemUnit(item, product);
    final pkgSize = getPackageSize(item, product);
    if (pkgSize > 0) {
      final inUnits = baseQty * pkgSize;
      return '${inUnits.formatted} $unit (${baseQty.formatted} ${item.unit})';
    }
    return '${baseQty.formatted} $unit';
  }
}
