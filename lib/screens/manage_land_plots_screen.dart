import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/data_export_import_button.dart';
import 'plot_details_screen.dart';

class ManageLandPlotsScreen extends StatefulWidget {
  const ManageLandPlotsScreen({super.key});

  @override
  State<ManageLandPlotsScreen> createState() => _ManageLandPlotsScreenState();
}

class _ManageLandPlotsScreenState extends State<ManageLandPlotsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'owned', 'partnered', 'client', 'no_warehouse'
  String _sortBy = 'area'; // 'area', 'plots', 'profit', 'name'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'owned':
        return AppTheme.accentBlue;
      case 'partnered':
        return Colors.amber.shade800;
      case 'client':
        return Colors.teal.shade700;
      default:
        return AppTheme.accentBlue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'owned':
        return Icons.verified_user_outlined; // تحت اليد (ملك / زكاة)
      case 'partnered':
        return Icons.people_outline; // مشروك
      case 'client':
        return Icons.water_drop_outlined; // عميل مياه
      default:
        return Icons.landscape_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allPlots = provider.landPlots;
    final now = DateTime.now();

    // Summary calculations
    final totalArea = allPlots.fold(0.0, (s, p) => s + p.area);
    final totalFurrows = allPlots.fold(0, (s, p) => s + p.numPlots);
    final ownedCount = allPlots.where((p) => p.category == 'owned').length;
    final partneredCount =
        allPlots.where((p) => p.category == 'partnered').length;
    final clientCount = allPlots.where((p) => p.category == 'client').length;
    final unlinkedWarehouseCount =
        allPlots.where((p) => p.warehouseId == null).length;

    // Filter plots
    var filtered = allPlots.where((plot) {
      if (_selectedFilter == 'owned' && plot.category != 'owned') return false;
      if (_selectedFilter == 'partnered' && plot.category != 'partnered') {
        return false;
      }
      if (_selectedFilter == 'client' && plot.category != 'client') {
        return false;
      }
      if (_selectedFilter == 'no_warehouse' && plot.warehouseId != null) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final nameMatches = plot.name.toLowerCase().contains(q);
        final warehouse = provider.warehouses
            .firstWhereOrNull((w) => w.id == plot.warehouseId);
        final warehouseMatches =
            warehouse?.name.toLowerCase().contains(q) ?? false;
        final partnerMatches = provider.partnerships
            .where((p) => p.landPlotId == plot.id)
            .any((p) {
          final partner =
              provider.partners.firstWhereOrNull((pt) => pt.id == p.partnerId);
          return partner?.name.toLowerCase().contains(q) ?? false;
        });
        return nameMatches || warehouseMatches || partnerMatches;
      }
      return true;
    }).toList();

    // Sort plots
    if (_sortBy == 'area') {
      filtered.sort((a, b) => b.area.compareTo(a.area));
    } else if (_sortBy == 'plots') {
      filtered.sort((a, b) => b.numPlots.compareTo(a.numPlots));
    } else if (_sortBy == 'name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'profit') {
      filtered.sort((a, b) {
        final netA = _calculatePlotNetProfit(provider, a.id);
        final netB = _calculatePlotNetProfit(provider, b.id);
        return netB.compareTo(netA);
      });
    }

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'إدارة المواضع والأراضي',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          DataExportImportButton(
            label: 'المواضع',
            buildRows: () =>
                provider.landPlots.map((e) => e.toJson()).toList(),
            csvHeaders: const ['الاسم', 'المساحة (م²)', 'عدد الأتلام', 'التصنيف'],
            csvKeys: const ['name', 'area', 'numPlots', 'category'],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final plot = LandPlot.fromJson(row);
                  if (provider.landPlots.any((e) => e.id == plot.id)) continue;
                  provider.addLandPlot(plot);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero Overview Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.14),
                  context.dynamicCardBg,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.dynamicCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.terrain_rounded,
                              color: AppTheme.accentBlue, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي المساحة المزروعة',
                              style: TextStyle(
                                color: context.dynamicTextSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${totalArea.formatted} م²',
                              style: TextStyle(
                                color: AppTheme.accentBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('المواضع والأتلام',
                              style: TextStyle(
                                  color: context.dynamicTextMuted,
                                  fontSize: 10)),
                          Text(
                            '${allPlots.length} موضع · $totalFurrows تلم',
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // Ownership Breakdown Strip
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatBox(
                        context,
                        title: 'تحت اليد (ملك)',
                        subtitle: 'ملك خالص',
                        count: '$ownedCount موضع',
                        color: AppTheme.accentBlue,
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniStatBox(
                        context,
                        title: 'مشروك (شراكة)',
                        subtitle: 'مزارعة',
                        count: '$partneredCount موضع',
                        color: Colors.amber.shade800,
                        icon: Icons.handshake_outlined,
                      ),
                    ),
                    if (clientCount > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStatBox(
                          context,
                          title: 'عميل مياه',
                          subtitle: 'سقي بالطلب',
                          count: '$clientCount موضع',
                          color: Colors.teal.shade700,
                          icon: Icons.water_drop_outlined,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.dynamicCardBg,
                hintText: 'بحث باسم الموضع، الشريك، أو المخزن...',
                hintStyle:
                    TextStyle(color: context.dynamicTextMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.dynamicCardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.dynamicCardBorder),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          const SizedBox(height: 8),

          // Filter Segmented Chips & Sort Menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'الكل (${allPlots.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'owned',
                          'تحت اليد ($ownedCount)',
                          color: AppTheme.accentBlue,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'partnered',
                          'مشروك ($partneredCount)',
                          color: Colors.amber.shade800,
                        ),
                        if (clientCount > 0) ...[
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'client',
                            'عميل مياه ($clientCount)',
                            color: Colors.teal.shade700,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Sort Menu
                PopupMenuButton<String>(
                  color: context.dynamicCardBg,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.dynamicCardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: const Icon(Icons.sort_rounded, size: 18),
                  ),
                  tooltip: 'ترتيب حسب',
                  onSelected: (val) => setState(() => _sortBy = val),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'area',
                      child: Text(
                        'الأكبر مساحة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'area'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'area'
                              ? AppTheme.accentBlue
                              : context.dynamicTextPrimary,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'plots',
                      child: Text(
                        'الأكثر أتلاماً',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'plots'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'plots'
                              ? AppTheme.accentBlue
                              : context.dynamicTextPrimary,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'profit',
                      child: Text(
                        'الأعلى ربحية وصافي عائد',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'profit'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'profit'
                              ? AppTheme.accentBlue
                              : context.dynamicTextPrimary,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'name',
                      child: Text(
                        'أبجدياً بالاسم',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'name'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'name'
                              ? AppTheme.accentBlue
                              : context.dynamicTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Plots List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.terrain_outlined,
                              color: context.dynamicTextMuted, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد مواضع مطابقة للبحث'
                                : 'لا توجد مواضع زراعية مسجلة في هذا القسم',
                            style: TextStyle(
                              color: context.dynamicTextSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أضف موضعاً زراعياً جديداً بالضغط على الزر بالأسفل',
                            style: TextStyle(
                              color: context.dynamicTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final plot = filtered[index];
                      return _buildPlotCard(context, provider, plot, now);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, provider),
        backgroundColor: AppTheme.incomeGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('موضع جديد',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildMiniStatBox(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: context.dynamicTextMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String key,
    String label, {
    Color? color,
  }) {
    final isSelected = _selectedFilter == key;
    final activeColor = color ?? AppTheme.accentBlue;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: activeColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: isSelected ? activeColor : context.dynamicTextSecondary,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? activeColor : context.dynamicCardBorder,
      ),
      backgroundColor: context.dynamicCardBg,
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  double _calculatePlotNetProfit(FinanceProvider provider, String plotId) {
    final incomes =
        provider.incomes.where((i) => i.landPlotId == plotId).toList();
    final events =
        provider.landEvents.where((e) => e.landPlotId == plotId).toList();
    final works =
        provider.workRecords.where((w) => w.landPlotId == plotId).toList();

    final eventsCost = events.fold(
        0.0,
        (s, e) =>
            s +
            provider
                .expensesForEvent(e.id)
                .fold(0.0, (ss, ex) => ss + ex.amount));
    final laborCost = works.fold(0.0, (s, w) => s + w.totalAmount);
    final totalCosts = eventsCost + laborCost;
    final totalIncome = incomes.fold(0.0, (s, i) => s + i.amount);
    return totalIncome - totalCosts;
  }

  Widget _buildPlotCard(BuildContext context, FinanceProvider provider,
      LandPlot plot, DateTime now) {
    final categoryColor = _getCategoryColor(plot.category);
    final categoryIcon = _getCategoryIcon(plot.category);

    // Financial breakdown
    final incomes =
        provider.incomes.where((i) => i.landPlotId == plot.id).toList();
    final events =
        provider.landEvents.where((e) => e.landPlotId == plot.id).toList();
    final works =
        provider.workRecords.where((w) => w.landPlotId == plot.id).toList();

    final eventsCost = events.fold(
        0.0,
        (s, e) =>
            s +
            provider
                .expensesForEvent(e.id)
                .fold(0.0, (ss, ex) => ss + ex.amount));
    final laborCost = works.fold(0.0, (s, w) => s + w.totalAmount);
    final totalCosts = eventsCost + laborCost;
    final totalIncome = incomes.fold(0.0, (s, i) => s + i.amount);
    final netProfit = totalIncome - totalCosts;
    final isProfit = netProfit >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlotDetailsScreen(plot: plot)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category Badge, Name, and Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plot.name,
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: context.dynamicCardBg,
                    icon: Icon(Icons.more_vert,
                        color: context.dynamicTextMuted, size: 20),
                    onSelected: (v) {
                      if (v == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PlotDetailsScreen(plot: plot)),
                        );
                      } else if (v == 'edit') {
                        _showForm(context, provider, existing: plot);
                      } else if (v == 'delete') {
                        _confirmDelete(context, provider, plot);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('عرض السجل والأرباح'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('تعديل البيانات'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: AppTheme.expenseRed),
                            SizedBox(width: 8),
                            Text('حذف',
                                style: TextStyle(color: AppTheme.expenseRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Area & Furrows Row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildDetailPill(
                    context,
                    icon: Icons.straighten_rounded,
                    label: '${plot.area.formatted} م²',
                    color: context.dynamicTextPrimary,
                  ),
                  _buildDetailPill(
                    context,
                    icon: Icons.grid_view_rounded,
                    label: '${plot.numPlots} أتلام/لبنة',
                    color: context.dynamicTextPrimary,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Financial Performance Strip
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإيرادات',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${totalIncome.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.incomeGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                      height: 24, width: 1, color: context.dynamicCardBorder),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التكاليف والمصروفات',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${totalCosts.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.expenseRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                      height: 24, width: 1, color: context.dynamicCardBorder),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'صافي العائد',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${netProfit >= 0 ? '+' : ''}${netProfit.formatted} ر.ي',
                          style: TextStyle(
                            color: isProfit
                                ? AppTheme.incomeGreen
                                : AppTheme.expenseRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: bgColor != null
              ? color.withValues(alpha: 0.3)
              : context.dynamicCardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, FinanceProvider provider,
      {LandPlot? existing}) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final areaController =
        TextEditingController(text: existing?.area.toString() ?? '');
    final numPlotsController =
        TextEditingController(text: existing?.numPlots.toString() ?? '1');
    String category = existing?.category ?? 'partnered';
    String? warehouseId = existing?.warehouseId;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sheetContext.dynamicCardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    existing == null
                        ? 'إضافة موضع / أرض زراعية جديدة'
                        : 'تعديل بيانات الموضع',
                    style: TextStyle(
                      color: sheetContext.dynamicTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  // Name
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: sheetContext.dynamicTextPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: sheetContext.dynamicSurfaceBg,
                      labelText: 'اسم الموضع أو الأرض *',
                      hintText: 'مثال: الحقل الشمالي، الموضع الشرقي...',
                      prefixIcon: const Icon(Icons.terrain_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: sheetContext.dynamicCardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: sheetContext.dynamicCardBorder),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'أدخل اسم الموضع' : null,
                  ),
                  const SizedBox(height: 12),

                  // Area and Furrows
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: areaController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: TextStyle(
                              color: sheetContext.dynamicTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: sheetContext.dynamicSurfaceBg,
                            labelText: 'المساحة (م²) *',
                            hintText: 'مثال: 5000',
                            prefixIcon: const Icon(Icons.straighten_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: sheetContext.dynamicCardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: sheetContext.dynamicCardBorder),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'أدخل المساحة';
                            }
                            if (double.tryParse(v) == null) {
                              return 'رقم غير صحيح';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: numPlotsController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: sheetContext.dynamicTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: sheetContext.dynamicSurfaceBg,
                            labelText: 'عدد الأتلام / اللبن *',
                            hintText: 'مثال: 12',
                            prefixIcon: const Icon(Icons.grid_view_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: sheetContext.dynamicCardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: sheetContext.dynamicCardBorder),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'أدخل عدد الأتلام';
                            }
                            if (int.tryParse(v) == null || int.parse(v) <= 0) {
                              return 'رقم غير صحيح';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Selector
                  Text(
                    'تصنيف ملكية الموضع:',
                    style: TextStyle(
                      color: sheetContext.dynamicTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SheetDropdown<String>(
                    label: 'التصنيف الشرعي والإداري',
                    icon: Icons.category_rounded,
                    hint: 'اختر تصنيف الموضع',
                    value: category,
                    items: landPlotCategories.map((c) {
                      final isOwned = c == 'owned';
                      final isPartnered = c == 'partnered';
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(
                              isOwned
                                  ? Icons.verified_user_rounded
                                  : (isPartnered
                                      ? Icons.handshake_rounded
                                      : Icons.water_drop_rounded),
                              color: isOwned
                                  ? AppTheme.accentBlue
                                  : (isPartnered
                                      ? Colors.amber.shade800
                                      : Colors.teal.shade700),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(landPlotCategoryLabel(c)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setSheetState(() => category = v!),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category == 'owned'
                        ? '✨ تحت اليد (ملك خالص): تُحسب منه الزكاة الشرعية (5%) تلقائياً.'
                        : (category == 'partnered'
                            ? '🤝 مشروك (شراكة مزارعة): بدون زكاة (توزع حسب الحصص).'
                            : '💧 عميل مياه: مخصص لمبيعات السقي وخدمات الري.'),
                    style: TextStyle(
                      color: sheetContext.dynamicTextMuted,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Linked Warehouse
                  Text(
                    'المخزن المرتبط بالصرف:',
                    style: TextStyle(
                      color: sheetContext.dynamicTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SheetDropdown<String>(
                    label: 'المخزن المستودع',
                    icon: Icons.warehouse_rounded,
                    hint: 'اختر المخزن لصرف الأسمدة والمبيدات',
                    value: warehouseId,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('بدون مخزن مرتبط')),
                      ...provider.warehouses.map((w) =>
                          DropdownMenuItem(value: w.id, child: Text(w.name))),
                    ],
                    onChanged: (v) => setSheetState(() => warehouseId = v),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ربط الموضع بمخزن يتيح صرف المواد والمبيدات مباشرة من رصيده أثناء تسجيل الأحداث الزراعية.',
                    style: TextStyle(
                      color: sheetContext.dynamicTextMuted,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Submit Button
                  ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      if (existing != null) {
                        existing.name = nameController.text.trim();
                        existing.area =
                            double.parse(areaController.text.trim());
                        existing.numPlots =
                            int.parse(numPlotsController.text.trim());
                        existing.category = category;
                        existing.warehouseId = warehouseId;
                        provider.updateLandPlot(existing);
                      } else {
                        provider.addLandPlot(LandPlot(
                          id: const Uuid().v4(),
                          name: nameController.text.trim(),
                          area: double.parse(areaController.text.trim()),
                          numPlots: int.parse(numPlotsController.text.trim()),
                          category: category,
                          warehouseId: warehouseId,
                        ));
                      }
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.incomeGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      existing == null ? 'إضافة الموضع' : 'حفظ التعديلات',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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

  void _confirmDelete(
      BuildContext context, FinanceProvider provider, LandPlot plot) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الموضع',
            style: TextStyle(
                color: context.dynamicTextPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
            'هل تريد حذف الموضع "${plot.name}"؟ تنبيه: قد يؤثر هذا على الأحداث والشراكات المرتبطة به.',
            style: TextStyle(color: context.dynamicTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (provider.deleteLandPlot(plot.id)) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف الموضع لأنه مستخدم في سجلات موجودة.')));
              }
            },
            child:
                Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
