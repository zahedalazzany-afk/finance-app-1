import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/data_export_import_button.dart';

class ManageWarehousesScreen extends StatefulWidget {
  const ManageWarehousesScreen({super.key});

  @override
  State<ManageWarehousesScreen> createState() => _ManageWarehousesScreenState();
}

class _ManageWarehousesScreenState extends State<ManageWarehousesScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'low_stock', 'active'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allWarehouses = provider.warehouses;

    // Calculate aggregate metrics
    int totalItemsCount = 0;
    int totalLowStockCount = 0;
    for (final w in allWarehouses) {
      final items = provider.getItemsForWarehouse(w.id);
      totalItemsCount += items.length;
      for (final i in items) {
        if (i.minQuantity != null && i.quantity <= i.minQuantity!) {
          totalLowStockCount++;
        }
      }
    }

    // Filter warehouses based on search and selected filter
    final filteredWarehouses = allWarehouses.where((w) {
      final items = provider.getItemsForWarehouse(w.id);
      final hasLowStock = items.any((i) => i.minQuantity != null && i.quantity <= i.minQuantity!);
      final hasItems = items.any((i) => i.quantity > 0);

      if (_filterType == 'low_stock' && !hasLowStock) return false;
      if (_filterType == 'active' && !hasItems) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = w.name.toLowerCase().contains(query);
        final matchNotes = (w.notes ?? '').toLowerCase().contains(query);
        final matchItem = items.any((i) => i.name.toLowerCase().contains(query));
        if (!matchName && !matchNotes && !matchItem) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('المخازن والمستودعات'),
        actions: [
          if (provider.warehouses.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D9488)),
              tooltip: 'تحويل كميات بين المخازن',
              onPressed: () => _showTransferSheet(context, provider),
            ),
            IconButton(
              icon: Icon(Icons.history_rounded, color: context.dynamicTextSecondary),
              tooltip: 'سجل التحويلات بين المخازن',
              onPressed: () => _showTransferHistorySheet(context, provider),
            ),
          ],
          DataExportImportButton(
            label: 'المخازن',
            buildRows: () => provider.warehouses.map((e) => e.toJson()).toList(),
            csvHeaders: const ['الاسم', 'ملاحظات'],
            csvKeys: const ['name', 'notes'],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final item = Warehouse.fromJson(row);
                  if (provider.warehouses.any((e) => e.id == item.id)) continue;
                  provider.addWarehouse(item);
                } catch (_) {}
              }
            },
          ),
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: provider.isDarkMode ? Colors.amber : AppTheme.accentBlue,
            ),
            tooltip: 'تبديل المظهر',
            onPressed: () => provider.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top KPI Summary Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'المخازن',
                    value: '${allWarehouses.length}',
                    icon: Icons.warehouse_rounded,
                    color: AppTheme.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'المواد المخزنة',
                    value: '$totalItemsCount صنف',
                    icon: Icons.inventory_2_rounded,
                    color: AppTheme.incomeGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'نواقص التخزين',
                    value: '$totalLowStockCount صنف',
                    icon: Icons.warning_amber_rounded,
                    color: totalLowStockCount > 0 ? AppTheme.expenseRed : context.dynamicTextMuted,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: context.dynamicCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.dynamicCardBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'بحث باسم المخزن أو المادة المخزنة...',
                  hintStyle: TextStyle(color: context.dynamicTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: context.dynamicTextMuted, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('الكل (${allWarehouses.length})', 'all', Icons.grid_view_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('بها نواقص ($totalLowStockCount)', 'low_stock', Icons.warning_amber_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('مخازن بها مخزون', 'active', Icons.check_circle_outline_rounded),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Warehouses List or Empty State
          Expanded(
            child: allWarehouses.isEmpty
                ? _buildInitialEmptyState(context, provider)
                : filteredWarehouses.isEmpty
                    ? _buildNoResultsEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                        itemCount: filteredWarehouses.length,
                        itemBuilder: (context, index) {
                          final w = filteredWarehouses[index];
                          return _buildWarehouseCard(context, provider, w);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: allWarehouses.length < 2
          ? FloatingActionButton.extended(
              heroTag: 'add_warehouse_fab',
              onPressed: () => _showForm(context, provider),
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('مخزن جديد', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'transfer_fab',
                  onPressed: () => _showTransferSheet(context, provider),
                  backgroundColor: const Color(0xFF0D9488), // Teal
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('تحويل كميات', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  heroTag: 'add_warehouse_fab',
                  onPressed: () => _showForm(context, provider),
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('مخزن جديد', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricCard(BuildContext context,
      {required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: TextStyle(color: context.dynamicTextMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String type, IconData icon) {
    final isSelected = _filterType == type;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _filterType = type),
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : context.dynamicTextSecondary),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : context.dynamicTextSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selectedColor: AppTheme.accentBlue,
      backgroundColor: context.dynamicCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppTheme.accentBlue : context.dynamicCardBorder,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildWarehouseCard(BuildContext context, FinanceProvider provider, Warehouse w) {
    final items = provider.getItemsForWarehouse(w.id).where((i) => i.quantity != 0).toList();
    final totalQty = items.fold<double>(0, (s, i) => s + i.quantity);
    final lowStockCount = items.where((i) => i.minQuantity != null && i.quantity <= i.minQuantity!).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lowStockCount > 0
              ? AppTheme.expenseRed.withValues(alpha: 0.35)
              : context.dynamicCardBorder,
          width: lowStockCount > 0 ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warehouse_rounded, color: AppTheme.accentBlue, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  w.name,
                  style: TextStyle(
                    color: context.dynamicTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (lowStockCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.expenseRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '$lowStockCount نواقص',
                        style: TextStyle(color: AppTheme.expenseRed, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(
                  '${items.length} أصناف · ${totalQty.formatted} وحدة إجمالاً',
                  style: TextStyle(color: context.dynamicTextMuted, fontSize: 11),
                ),
                if (w.notes != null && w.notes!.trim().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('· ${w.notes!}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11)),
                ],
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            color: context.dynamicCardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: Icon(Icons.more_vert_rounded, color: context.dynamicTextMuted, size: 20),
            onSelected: (v) {
              if (v == 'consume') _showWarehouseConsume(context, provider, w);
              if (v == 'transfer') _showTransferSheet(context, provider, defaultSourceWarehouseId: w.id);
              if (v == 'edit') _showForm(context, provider, existing: w);
              if (v == 'delete') _confirmDelete(context, provider, w);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'consume',
                child: Row(
                  children: [
                    Icon(Icons.agriculture_rounded, color: AppTheme.accentBlue, size: 18),
                    SizedBox(width: 8),
                    Text('صرف مواد لحدث زراعي', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13)),
                  ],
                ),
              ),
              if (provider.warehouses.length > 1)
                const PopupMenuItem(
                  value: 'transfer',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D9488), size: 18),
                      SizedBox(width: 8),
                      Text('تحويل كميات لمخزن آخر', style: TextStyle(color: Color(0xFF0D9488), fontSize: 13)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: context.dynamicTextPrimary, size: 18),
                    SizedBox(width: 8),
                    Text('تعديل اسم المخزن', style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.expenseRed, size: 18),
                    SizedBox(width: 8),
                    Text('حذف المخزن', style: TextStyle(color: AppTheme.expenseRed, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'لا توجد مواد مخزنة في هذا المستودع حالياً',
                    style: TextStyle(color: context.dynamicTextMuted, fontSize: 12),
                  ),
                ),
              )
            else
              ...items.map((item) => _buildStorageItemRow(context, provider, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageItemRow(BuildContext context, FinanceProvider provider, StorageItem item) {
    final isLow = item.quantity < 0 || (item.minQuantity != null && item.quantity <= item.minQuantity!);
    final categoryColor = item.category == 'pesticide'
        ? Colors.purple
        : item.category == 'fertilizer'
            ? AppTheme.incomeGreen
            : AppTheme.accentBlue;

    final categoryIcon = item.category == 'pesticide'
        ? Icons.science_outlined
        : item.category == 'fertilizer'
            ? Icons.eco_outlined
            : Icons.inventory_2_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow ? AppTheme.expenseRed.withValues(alpha: 0.3) : context.dynamicCardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon, color: categoryColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: context.dynamicTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${productCategoryLabel(item.category)}${item.category == 'pesticide' && item.pesticideType != null ? ' · ${pesticideTypeLabel(item.pesticideType!)}' : ''}',
                  style: TextStyle(color: context.dynamicTextMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.isPackaged && item.packageSize != null)
                Text(
                  '${(item.quantity * item.packageSize!).formatted} ${item.usageUnit ?? ''}',
                  style: TextStyle(
                    color: isLow ? AppTheme.expenseRed : AppTheme.incomeGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              Text(
                '${item.quantity.formatted} ${item.unit}',
                style: TextStyle(
                  color: isLow ? AppTheme.expenseRed : AppTheme.incomeGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: item.isPackaged ? 11 : 13,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Quick actions
          InkWell(
            onTap: () => _showItemActions(context, provider, item),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.more_vert, color: context.dynamicTextMuted, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialEmptyState(BuildContext context, FinanceProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warehouse_outlined, color: AppTheme.accentBlue, size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مخازن مضافة بعد',
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'قم بإضافة مخزن جديد لترتيب وتتبع المواد الزراعية والمبيدات',
            style: TextStyle(color: context.dynamicTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showForm(context, provider),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة مخزن الآن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: context.dynamicTextMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'لا توجد نتائج تطابق بحثك',
            style: TextStyle(color: context.dynamicTextSecondary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _filterType = 'all';
              });
            },
            child: const Text('إعادة ضبط الفلاتر'),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, FinanceProvider provider, {Warehouse? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.dynamicCardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                existing == null ? 'إضافة مخزن جديد' : 'تعديل بيانات المخزن',
                style: TextStyle(
                  color: context.dynamicTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                style: TextStyle(color: context.dynamicTextPrimary),
                decoration: InputDecoration(
                  labelText: 'اسم المخزن *',
                  hintText: 'مثال: مخزن الأسمدة والمبيدات',
                  prefixIcon: const Icon(Icons.warehouse),
                  filled: true,
                  fillColor: context.dynamicSurfaceBg,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                style: TextStyle(color: context.dynamicTextPrimary),
                decoration: InputDecoration(
                  labelText: 'ملاحظات',
                  hintText: 'وصف أو موقع المخزن (اختياري)',
                  prefixIcon: const Icon(Icons.notes),
                  filled: true,
                  fillColor: context.dynamicSurfaceBg,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (existing != null) {
                      existing.name = nameController.text.trim();
                      existing.notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
                      provider.updateWarehouse(existing);
                    } else {
                      provider.addWarehouse(Warehouse(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      ));
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(existing == null ? 'حفظ المخزن' : 'تحديث المخزن'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemActions(BuildContext context, FinanceProvider provider, StorageItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.dynamicCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.inventory_rounded, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      color: context.dynamicTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.quantity.formatted} ${item.unit}',
              style: TextStyle(
                color: item.minQuantity != null && item.quantity <= item.minQuantity!
                    ? AppTheme.expenseRed
                    : AppTheme.incomeGreen,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            _actionTile(context, Icons.history_rounded, 'سجل حركات الصنف', AppTheme.accentBlue, () {
              Navigator.pop(context);
              _showItemHistorySheet(context, provider, item);
            }),
            _actionTile(context, Icons.agriculture_rounded, 'صرف لحدث زراعي (استهلاك)', const Color(0xFFF59E0B), () {
              Navigator.pop(context);
              _showTransactionForm(context, provider, item, 'out');
            }),
            if (provider.warehouses.length > 1 && item.quantity > 0)
              _actionTile(context, Icons.swap_horiz_rounded, 'تحويل لمخزن آخر', const Color(0xFF0D9488), () {
                Navigator.pop(context);
                _showTransferSheet(context, provider,
                    defaultSourceWarehouseId: item.warehouseId,
                    defaultItemId: item.id);
              }),
            _actionTile(context, Icons.delete, 'حذف الصنف من المخزن', AppTheme.expenseRed, () {
              Navigator.pop(context);
              _confirmDeleteItem(context, provider, item);
            }),
          ],
        ),
      ),
    );
  }

  void _showItemHistorySheet(BuildContext context, FinanceProvider provider, StorageItem initialItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicSurfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<FinanceProvider>(
          builder: (context, prov, _) {
            final currentItem = prov.storageItems.firstWhereOrNull((s) => s.id == initialItem.id) ?? initialItem;
            final warehouse = prov.warehouses.firstWhereOrNull((w) => w.id == currentItem.warehouseId);
            final txs = prov.getTransactionsForItem(currentItem.id)
              ..sort((a, b) => b.date.compareTo(a.date));

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.dynamicCardBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.history_rounded, color: AppTheme.accentBlue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سجل حركات: ${currentItem.name}',
                                  style: TextStyle(
                                    color: context.dynamicTextPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'المخزن: ${warehouse?.name ?? 'غير محدد'} · الرصيد الحالي: ${currentItem.quantity.formatted} ${currentItem.unit}',
                                  style: TextStyle(
                                    color: context.dynamicTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      if (txs.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 54, color: context.dynamicTextMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد حركات مسجلة لهذا الصنف بعد',
                                  style: TextStyle(color: context.dynamicTextMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: txs.length,
                            itemBuilder: (context, idx) {
                              final tx = txs[idx];
                              final isIn = tx.type == 'in';
                              final isTransfer = tx.transferId != null;
                              final color = isTransfer
                                  ? const Color(0xFF0D9488)
                                  : (isIn ? AppTheme.incomeGreen : AppTheme.expenseRed);
                              final sign = isIn ? '+' : '−';

                              final typeLabel = isTransfer
                                  ? (isIn ? 'تحويل وارد' : 'تحويل صادر')
                                  : (isIn ? 'توريد مخزني' : 'صرف لحدث زراعي');

                              // Associated event details
                              String? eventInfo;
                              if (tx.eventId != null) {
                                final ev = prov.landEvents.firstWhereOrNull((e) => e.id == tx.eventId);
                                if (ev != null) {
                                  final plot = prov.landPlots.firstWhereOrNull((p) => p.id == ev.landPlotId);
                                  eventInfo = '${ev.eventType} - ${plot?.name ?? 'موضع غير محدد'}';
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isTransfer
                                                    ? Icons.swap_horiz_rounded
                                                    : (isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                                                size: 14,
                                                color: color,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                typeLabel,
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '$sign${tx.quantity.formatted} ${currentItem.unit}',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 13, color: context.dynamicTextMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(tx.date),
                                          style: TextStyle(color: context.dynamicTextMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    if (eventInfo != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.agriculture_rounded, size: 14, color: AppTheme.accentBlue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              eventInfo,
                                              style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        tx.notes!,
                                        style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11),
                                      ),
                                    ],
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (!isTransfer) ...[
                                          TextButton.icon(
                                            onPressed: () {
                                              _showEditTransactionSheet(context, prov, currentItem, tx);
                                            },
                                            icon: const Icon(Icons.edit_outlined, size: 15),
                                            label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppTheme.accentBlue,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        TextButton.icon(
                                          onPressed: () {
                                            _confirmDeleteTransaction(context, prov, currentItem, tx);
                                          },
                                          icon: const Icon(Icons.delete_outline, size: 15),
                                          label: Text(
                                            isTransfer ? 'إلغاء التحويل' : 'حذف الحركة',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.expenseRed,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTransaction(
      BuildContext context, FinanceProvider provider, StorageItem item, InventoryTransaction tx) {
    final isTransfer = tx.transferId != null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed),
            const SizedBox(width: 8),
            Text(isTransfer ? 'إلغاء عملية التحويل' : 'حذف الحركة المخزنية'),
          ],
        ),
        content: Text(
          isTransfer
              ? 'هل أنت متأكد من إلغاء عملية التحويل بالكامل؟ سيتم استرجاع الكمية إلى المخزن المصدر وخصمها من المخزن المستلم.'
              : 'هل أنت متأكد من حذف هذه الحركة؟ سيتم عكس تأثيرها على رصيد المخزن تلقائياً (${tx.type == 'in' ? 'خصم' : 'إضافة'} ${tx.quantity.formatted} ${item.unit}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expenseRed, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteInventoryTransaction(tx.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف الحركة وتحديث رصيد المخزن تلقائياً'),
                  backgroundColor: AppTheme.incomeGreen,
                ),
              );
            },
            child: const Text('نعم، احذف'),
          ),
        ],
      ),
    );
  }

  void _showEditTransactionSheet(
      BuildContext context, FinanceProvider provider, StorageItem item, InventoryTransaction tx) {
    final qtyController = TextEditingController(text: (item.isPackaged && item.packageSize != null && item.packageSize! > 0)
        ? (tx.quantity * item.packageSize!).formatted
        : tx.quantity.formatted);
    final notesController = TextEditingController(text: tx.notes ?? '');
    final formKey = GlobalKey<FormState>();
    DateTime date = tx.date;
    String? eventId = tx.eventId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.dynamicCardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      tx.type == 'in' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: tx.type == 'in' ? AppTheme.incomeGreen : AppTheme.expenseRed,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تعديل حركة: ${tx.type == 'in' ? 'توريد مخزني' : 'صرف لحدث زراعي'}',
                      style: TextStyle(
                        color: context.dynamicTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: context.dynamicTextPrimary),
                  decoration: InputDecoration(
                    labelText: item.isPackaged ? 'الكمية (${item.usageUnit ?? ''})' : 'الكمية *',
                    hintText: item.isPackaged ? 'الكمية (${item.usageUnit ?? ''})' : 'الكمية (${item.unit})',
                    prefixIcon: const Icon(Icons.numbers),
                    filled: true,
                    fillColor: context.dynamicSurfaceBg,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    final qty = double.tryParse(v);
                    if (qty == null || qty <= 0) return 'قيمة غير صالحة';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setSheetState(() => date = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.dynamicSurfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: context.dynamicTextSecondary, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                          style: TextStyle(color: context.dynamicTextPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (tx.type == 'out') ...[
                  const SizedBox(height: 12),
                  (() {
                    final currentItem = provider.storageItems.firstWhereOrNull((i) => i.id == tx.itemId);
                    final warehouseId = currentItem?.warehouseId;
                    final linkedPlots = warehouseId != null
                        ? provider.landPlots.where((p) => p.warehouseId == warehouseId).toList()
                        : <LandPlot>[];
                    final linkedPlotIds = linkedPlots.map((p) => p.id).toSet();

                    final availableEvents = provider.landEvents
                        .where((e) =>
                            linkedPlotIds.isEmpty ||
                            linkedPlotIds.contains(e.landPlotId) ||
                            e.id == tx.eventId)
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    return DropdownButtonFormField<String>(
                      value: eventId,
                      decoration: InputDecoration(
                        labelText: 'الحدث الزراعي *',
                        prefixIcon: const Icon(Icons.agriculture),
                        filled: true,
                        fillColor: context.dynamicSurfaceBg,
                      ),
                      items: availableEvents.map((e) {
                        final plot = provider.landPlots.firstWhereOrNull((p) => p.id == e.landPlotId);
                        final plotName = plot?.name ?? 'موضع غير محدد';
                        final dStr = DateFormat('yyyy/MM/dd', 'ar').format(e.date);
                        return DropdownMenuItem(
                          value: e.id,
                          child: Text(
                            '${e.eventType} - $plotName ($dStr)',
                            style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setSheetState(() {
                        eventId = v;
                        if (v != null) {
                          final selEv = provider.landEvents.firstWhereOrNull((e) => e.id == v);
                          if (selEv != null) date = selEv.date;
                        }
                      }),
                    );
                  })(),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: context.dynamicTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات',
                    hintText: 'ملاحظات (اختياري)',
                    prefixIcon: const Icon(Icons.notes),
                    filled: true,
                    fillColor: context.dynamicSurfaceBg,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      if (tx.type == 'out' && (eventId == null || eventId!.isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى تحديد الحدث الزراعي')),
                        );
                        return;
                      }
                      final qtyIn = double.parse(qtyController.text.trim());
                      final qty = (item.isPackaged && item.packageSize != null && item.packageSize! > 0)
                          ? qtyIn / item.packageSize!
                          : qtyIn;

                      final updatedTx = InventoryTransaction(
                        id: tx.id,
                        itemId: tx.itemId,
                        type: tx.type,
                        quantity: qty,
                        date: date,
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        eventId: eventId,
                        toWarehouseId: tx.toWarehouseId,
                        fromWarehouseId: tx.fromWarehouseId,
                        transferId: tx.transferId,
                      );

                      provider.updateInventoryTransaction(updatedTx);
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم تعديل الحركة وتحديث رصيد المخزن بنجاح'),
                          backgroundColor: AppTheme.incomeGreen,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('حفظ التعديلات'),
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

  Widget _actionTile(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionForm(BuildContext context, FinanceProvider provider, StorageItem item, String type) {
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime date = DateTime.now();
    String? eventId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.dynamicCardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      type == 'in' ? Icons.add_circle : Icons.remove_circle,
                      color: type == 'in' ? AppTheme.incomeGreen : AppTheme.expenseRed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type == 'in' ? 'إضافة للمخزون' : 'صرف من المخزون',
                      style: TextStyle(
                        color: context.dynamicTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.name, style: TextStyle(color: context.dynamicTextMuted, fontSize: 14)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: context.dynamicTextPrimary),
                  decoration: InputDecoration(
                    labelText: item.isPackaged ? 'الكمية (${item.usageUnit ?? ''})' : 'الكمية *',
                    hintText: item.isPackaged ? 'الكمية (${item.usageUnit ?? ''})' : 'الكمية (${item.unit})',
                    prefixIcon: const Icon(Icons.numbers),
                    filled: true,
                    fillColor: context.dynamicSurfaceBg,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    final qty = double.tryParse(v);
                    if (qty == null || qty <= 0) return 'قيمة غير صالحة';
                    if (type == 'out') {
                      if (item.isPackaged) {
                        final available = item.quantity * (item.packageSize ?? 0);
                        if (available <= 0) return 'لا توجد كمية متاحة';
                        if (qty > available) return 'المتاح: ${available.formatted} ${item.usageUnit} (${item.quantity.formatted} ${item.unit})';
                      } else if (qty > item.quantity) {
                        return 'الكمية المتاحة: ${item.quantity.formatted} ${item.unit}';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        date = picked;
                        eventId = null;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.dynamicSurfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: context.dynamicTextSecondary, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                          style: TextStyle(color: context.dynamicTextPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (type == 'out') ...[
                  const SizedBox(height: 12),
                  ...(() {
                    final linkedPlots = provider.landPlots
                        .where((p) => p.warehouseId == item.warehouseId)
                        .toList();
                    final linkedPlotIds = linkedPlots.map((p) => p.id).toSet();

                    if (linkedPlotIds.isEmpty) {
                      final w = provider.warehouses.firstWhereOrNull((wh) => wh.id == item.warehouseId);
                      final wName = w?.name ?? 'المخزن';
                      return [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.expenseRedDim,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه: لا يوجد أي موضع زراعي مرتبط بمخزن "$wName". يرجى ربط موضع زراعي بالمخزن أولاً من إعدادات المواضع الزراعية لتتمكن من صرف المواد له.',
                                  style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }

                    final availableEvents = provider.landEvents
                        .where((e) => linkedPlotIds.contains(e.landPlotId))
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    if (availableEvents.isEmpty) {
                      final plotNames = linkedPlots.map((p) => p.name).join('، ');
                      return [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.expenseRedDim,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه: لا توجد أحداث زراعية مسجلة للمواضع المرتبطة بهذا المخزن ($plotNames). يرجى تسجيل حدث زراعي أولاً في شاشة الأحداث الزراعية.',
                                  style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }
                    return [
                      SheetDropdown<String>(
                        label: 'الحدث الزراعي المستفيد * (إلزامي)',
                        icon: Icons.agriculture_rounded,
                        hint: 'اختر الحدث الزراعي لصرف المادة له',
                        value: eventId,
                        items: availableEvents.map((e) {
                          final plot = provider.landPlots.firstWhereOrNull((p) => p.id == e.landPlotId);
                          final plotName = plot != null ? '🌱 ${plot.name}' : 'بدون موضع';
                          final dStr = DateFormat('dd MMM yyyy', 'ar').format(e.date);
                          return DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              '${e.eventType} - $plotName ($dStr)',
                              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setSheetState(() {
                          eventId = v;
                          if (v != null) {
                            final selEv = provider.landEvents.firstWhereOrNull((e) => e.id == v);
                            if (selEv != null) date = selEv.date;
                          }
                        }),
                      ),
                    ];
                  })(),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: context.dynamicTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات',
                    hintText: 'ملاحظات (اختياري)',
                    prefixIcon: const Icon(Icons.notes),
                    filled: true,
                    fillColor: context.dynamicSurfaceBg,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      if (type == 'out' && (eventId == null || eventId!.isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ممنوع صرف مواد غير مرتبطة بحدث زراعي، يرجى اختيار الحدث أولاً')),
                        );
                        return;
                      }
                      final qtyIn = double.parse(qtyController.text.trim());
                      final qty = (item.isPackaged && item.packageSize != null && item.packageSize! > 0)
                          ? qtyIn / item.packageSize!
                          : qtyIn;
                      provider.addInventoryTransaction(InventoryTransaction(
                        id: const Uuid().v4(),
                        itemId: item.id,
                        type: type,
                        quantity: qty,
                        date: date,
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        eventId: eventId,
                      ));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'in' ? AppTheme.incomeGreen : AppTheme.expenseRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(type == 'in' ? 'تأكيد الإضافة' : 'تأكيد الصرف'),
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

  void _showWarehouseConsume(BuildContext context, FinanceProvider provider, Warehouse w) {
    final availItems = provider.getItemsForWarehouse(w.id).where((s) => s.quantity > 0).toList();
    if (availItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مواد متاحة في هذا المخزن للصرف.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    DateTime date = DateTime.now();
    String? eventId;
    final notesController = TextEditingController();
    final lines = <_WarehouseConsumeLine>[_WarehouseConsumeLine()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.dynamicCardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.remove_circle, color: AppTheme.expenseRed, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'صرف مواد من المخزن',
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('المخزن: ${w.name}',
                      style: TextStyle(color: context.dynamicTextMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          date = picked;
                          eventId = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: context.dynamicTextSecondary, size: 18),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                            style: TextStyle(color: context.dynamicTextPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(() {
                    final linkedPlots = provider.landPlots
                        .where((p) => p.warehouseId == w.id)
                        .toList();
                    final linkedPlotIds = linkedPlots.map((p) => p.id).toSet();

                    if (linkedPlotIds.isEmpty) {
                      return [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.expenseRedDim,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه: لا يوجد أي موضع زراعي مرتبط بمخزن "${w.name}". يرجى ربط موضع زراعي بالمخزن أولاً من إعدادات المواضع الزراعية لتتمكن من صرف المواد له.',
                                  style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }

                    final availableEvents = provider.landEvents
                        .where((e) => linkedPlotIds.contains(e.landPlotId))
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    if (availableEvents.isEmpty) {
                      final plotNames = linkedPlots.map((p) => p.name).join('، ');
                      return [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.expenseRedDim,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه: لا توجد أحداث زراعية مسجلة للمواضع المرتبطة بهذا المخزن ($plotNames). يرجى تسجيل حدث زراعي أولاً في شاشة الأحداث الزراعية.',
                                  style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }
                    return [
                      SheetDropdown<String>(
                        label: 'الحدث الزراعي المستفيد * (إلزامي)',
                        icon: Icons.agriculture_rounded,
                        hint: 'اختر الحدث الزراعي لصرف المواد له',
                        value: eventId,
                        items: availableEvents.map((e) {
                          final plot = provider.landPlots.firstWhereOrNull((p) => p.id == e.landPlotId);
                          final plotName = plot != null ? '🌱 ${plot.name}' : 'بدون موضع';
                          final dStr = DateFormat('dd MMM yyyy', 'ar').format(e.date);
                          return DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              '${e.eventType} - $plotName ($dStr)',
                              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setSheetState(() {
                          eventId = v;
                          if (v != null) {
                            final selEv = provider.landEvents.firstWhereOrNull((e) => e.id == v);
                            if (selEv != null) date = selEv.date;
                          }
                        }),
                      ),
                    ];
                  })(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'المواد المراد صرفها',
                      style: TextStyle(
                        color: AppTheme.accentBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...lines.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final line = entry.value;
                    final selectedItem = availItems.firstWhereOrNull((s) => s.id == line.itemId);
                    final availableDisplay = selectedItem == null
                        ? ''
                        : selectedItem.isPackaged
                            ? '${(selectedItem.quantity * (selectedItem.packageSize ?? 1)).formatted} ${selectedItem.usageUnit ?? ''}'
                            : '${selectedItem.quantity.formatted} ${selectedItem.unit}';

                    final selectedOtherItemIds = lines
                        .asMap()
                        .entries
                        .where((e) => e.key != idx && e.value.itemId != null)
                        .map((e) => e.value.itemId!)
                        .toSet();

                    final selectableItems = availItems
                        .where((s) => s.id == line.itemId || !selectedOtherItemIds.contains(s.id))
                        .toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'مادة #${idx + 1}',
                                style: TextStyle(color: context.dynamicTextSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const Spacer(),
                              if (lines.length > 1)
                                IconButton(
                                  icon: Icon(Icons.remove_circle, color: AppTheme.expenseRed, size: 20),
                                  onPressed: () => setSheetState(() {
                                    line.dispose();
                                    lines.removeAt(idx);
                                  }),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SheetDropdown<String>(
                            label: 'المادة *',
                            hint: 'اختر المادة',
                            value: line.itemId,
                            items: selectableItems
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text('${s.name} (المتاح: ${s.quantity.formatted} ${s.unit})'),
                                    ))
                                .toList(),
                            onChanged: (v) => setSheetState(() {
                              line.itemId = v;
                              line.qtyController.clear();
                            }),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: line.qtyController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: context.dynamicTextPrimary),
                            decoration: InputDecoration(
                              labelText: selectedItem != null && selectedItem.isPackaged
                                  ? 'الكمية (${selectedItem.usageUnit ?? ''})'
                                  : 'الكمية *',
                              hintText: selectedItem != null ? 'المتاح: $availableDisplay' : 'الكمية',
                              prefixIcon: const Icon(Icons.numbers),
                              filled: true,
                              fillColor: context.dynamicCardBg,
                            ),
                            validator: (v) {
                              if (line.itemId == null) return null;
                              if (v == null || v.trim().isEmpty) return 'مطلوب';
                              final qty = double.tryParse(v);
                              if (qty == null || qty <= 0) return 'قيمة غير صالحة';
                              if (selectedItem != null) {
                                final avail = selectedItem.isPackaged
                                    ? selectedItem.quantity * (selectedItem.packageSize ?? 1)
                                    : selectedItem.quantity;
                                if (qty > avail) return 'أكبر من المتاح ($availableDisplay)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setSheetState(() => lines.add(_WarehouseConsumeLine())),
                      icon: Icon(Icons.add, color: AppTheme.accentBlue, size: 18),
                      label: Text('إضافة مادة أخرى', style: TextStyle(color: AppTheme.accentBlue)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: context.dynamicTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'ملاحظات إضافية عن الصرف (اختياري)',
                      prefixIcon: const Icon(Icons.notes),
                      filled: true,
                      fillColor: context.dynamicSurfaceBg,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        if (eventId == null || eventId!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ممنوع صرف مواد غير مرتبطة بحدث زراعي، يرجى اختيار الحدث أولاً')),
                          );
                          return;
                        }
                        final validLines = lines.where((l) => l.itemId != null).toList();
                        if (validLines.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى اختيار مادة واحدة على الأقل')),
                          );
                          return;
                        }
                        for (final l in validLines) {
                          final itm = availItems.firstWhere((s) => s.id == l.itemId);
                          final qtyIn = double.parse(l.qtyController.text.trim());
                          final qty = (itm.isPackaged && itm.packageSize != null && itm.packageSize! > 0)
                              ? qtyIn / itm.packageSize!
                              : qtyIn;
                          provider.addInventoryTransaction(InventoryTransaction(
                            id: const Uuid().v4(),
                            itemId: itm.id,
                            type: 'out',
                            quantity: qty,
                            date: date,
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            eventId: eventId,
                          ));
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.expenseRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('تأكيد صرف المواد'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, FinanceProvider provider, StorageItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الصنف', style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'هل تريد بالتأكيد حذف "${item.name}" من هذا المخزن؟',
          style: TextStyle(color: context.dynamicTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.deleteStorageItem(item.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider, Warehouse w) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف المخزن', style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'هل تريد حذف المخزن "${w.name}"؟ سيتم حذف جميع المواد المرتبطة به.',
          style: TextStyle(color: context.dynamicTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (provider.deleteWarehouse(w.id)) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف المخزن لأن لديه حركات مخزنية مرتبطة.')));
              }
            },
            child: Text('حذف المخزن', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }

  void _showTransferSheet(
    BuildContext context,
    FinanceProvider provider, {
    String? defaultSourceWarehouseId,
    String? defaultItemId,
  }) {
    if (provider.warehouses.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يتوفر مخزنان على الأقل لإجراء عملية تحويل بينهما')),
      );
      return;
    }

    String sourceId = defaultSourceWarehouseId ?? provider.warehouses.first.id;
    String destId = provider.warehouses.firstWhere((w) => w.id != sourceId).id;
    DateTime date = DateTime.now();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final List<_WarehouseTransferLine> lines = [
      _WarehouseTransferLine(itemId: defaultItemId),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final availItems = provider
              .getItemsForWarehouse(sourceId)
              .where((s) => s.quantity > 0)
              .toList();

          final otherWarehouses = provider.warehouses.where((w) => w.id != sourceId).toList();
          if (!otherWarehouses.any((w) => w.id == destId)) {
            destId = otherWarehouses.first.id;
          }

          final fromW = provider.warehouses.firstWhereOrNull((w) => w.id == sourceId);
          final toW = provider.warehouses.firstWhereOrNull((w) => w.id == destId);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
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
                          color: context.dynamicCardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D9488), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'تحويل كميات بين المخازن',
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Source & Destination Card with swap button
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Column(
                        children: [
                          SheetDropdown<String>(
                            label: 'المخزن المحول منه (المصدر) *',
                            icon: Icons.warehouse_rounded,
                            hint: 'اختر المخزن المصدر',
                            value: sourceId,
                            items: provider.warehouses.map((w) {
                              final count = provider.getItemsForWarehouse(w.id).where((i) => i.quantity > 0).length;
                              return DropdownMenuItem(
                                value: w.id,
                                child: Text('${w.name} ($count أصناف متوفرة)'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v == null || v == sourceId) return;
                              setSheetState(() {
                                sourceId = v;
                                if (destId == sourceId) {
                                  final alt = provider.warehouses.firstWhereOrNull((w) => w.id != sourceId);
                                  if (alt != null) destId = alt.id;
                                }
                                for (final l in lines) {
                                  l.itemId = null;
                                  l.qtyController.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton.filledTonal(
                                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                  foregroundColor: const Color(0xFF0D9488),
                                ),
                                tooltip: 'تبديل المخزن المصدر والوجهة',
                                onPressed: () {
                                  setSheetState(() {
                                    final temp = sourceId;
                                    sourceId = destId;
                                    destId = temp;
                                    for (final l in lines) {
                                      l.itemId = null;
                                      l.qtyController.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SheetDropdown<String>(
                            label: 'المخزن المحول إليه (الوجهة) *',
                            icon: Icons.input_rounded,
                            hint: 'اختر المخزن المستلم',
                            value: destId,
                            items: otherWarehouses.map((w) {
                              return DropdownMenuItem(
                                value: w.id,
                                child: Text(w.name),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setSheetState(() => destId = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date Picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.dynamicSurfaceBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.dynamicCardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: context.dynamicTextSecondary, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'الأصناف والكميات المحولة',
                      style: TextStyle(
                        color: context.dynamicTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (availItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRedDim,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppTheme.expenseRed, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'لا توجد أي مواد ذات رصيد متاح في مخزن "${fromW?.name ?? ''}" للتحويل منها.',
                                style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ...lines.mapIndexed((idx, line) {
                        final selectedItem = line.itemId != null
                            ? availItems.firstWhereOrNull((s) => s.id == line.itemId)
                            : null;

                        String availText = '';
                        if (selectedItem != null) {
                          if (selectedItem.isPackaged && selectedItem.packageSize != null && selectedItem.packageSize! > 0) {
                            availText = '${selectedItem.quantity.formatted} ${selectedItem.unit} (${(selectedItem.quantity * selectedItem.packageSize!).formatted} ${selectedItem.usageUnit ?? ''})';
                          } else {
                            availText = '${selectedItem.quantity.formatted} ${selectedItem.unit}';
                          }
                        }

                        final selectedOtherItemIds = lines
                            .whereIndexed((i, l) => i != idx && l.itemId != null)
                            .map((l) => l.itemId!)
                            .toSet();

                        final selectableItems = availItems
                            .where((s) => s.id == line.itemId || !selectedOtherItemIds.contains(s.id))
                            .toList();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.dynamicSurfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.dynamicCardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'الصنف رقم ${idx + 1}',
                                    style: TextStyle(
                                      color: context.dynamicTextSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (lines.length > 1)
                                    IconButton(
                                      icon: Icon(Icons.close, color: AppTheme.expenseRed, size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => setSheetState(() {
                                        line.dispose();
                                        lines.removeAt(idx);
                                      }),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SheetDropdown<String>(
                                label: 'الصنف المراد تحويله *',
                                icon: Icons.inventory_2_outlined,
                                hint: 'اختر الصنف',
                                value: line.itemId,
                                items: selectableItems.map((s) {
                                  return DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${s.name} (المتاح: ${s.quantity.formatted} ${s.unit})'),
                                  );
                                }).toList(),
                                onChanged: (v) => setSheetState(() {
                                  line.itemId = v;
                                  line.qtyController.clear();
                                }),
                              ),
                              if (selectedItem != null) ...[
                                const SizedBox(height: 8),
                                if (selectedItem.isPackaged && selectedItem.packageSize != null && selectedItem.packageSize! > 0) ...[
                                  Row(
                                    children: [
                                      Text(
                                        'الوحدة المدخلة:',
                                        style: TextStyle(color: context.dynamicTextSecondary, fontSize: 11),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: Text(selectedItem.unit, style: const TextStyle(fontSize: 11)),
                                        selected: !line.useUsageUnit,
                                        onSelected: (val) {
                                          if (val) setSheetState(() => line.useUsageUnit = false);
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      ChoiceChip(
                                        label: Text(selectedItem.usageUnit ?? 'استخدام', style: const TextStyle(fontSize: 11)),
                                        selected: line.useUsageUnit,
                                        onSelected: (val) {
                                          if (val) setSheetState(() => line.useUsageUnit = true);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                TextFormField(
                                  controller: line.qtyController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(color: context.dynamicTextPrimary),
                                  decoration: InputDecoration(
                                    labelText: line.useUsageUnit && selectedItem.isPackaged
                                        ? 'الكمية المحولة بـ (${selectedItem.usageUnit}) *'
                                        : 'الكمية المحولة بـ (${selectedItem.unit}) *',
                                    hintText: 'المتاح: $availText',
                                    prefixIcon: const Icon(Icons.numbers_rounded),
                                    filled: true,
                                    fillColor: context.dynamicCardBg,
                                  ),
                                  validator: (v) {
                                    if (line.itemId == null) return null;
                                    if (v == null || v.trim().isEmpty) return 'يرجى إدخال الكمية';
                                    final numVal = double.tryParse(v.trim());
                                    if (numVal == null || numVal <= 0) return 'قيمة غير صالحة';
                                    final maxAvail = line.useUsageUnit && selectedItem.isPackaged
                                        ? selectedItem.quantity * (selectedItem.packageSize ?? 1)
                                        : selectedItem.quantity;
                                    if (numVal > maxAvail) {
                                      return 'الكمية تتجاوز المتاح ($availText)';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (availItems.length > lines.length)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setSheetState(() => lines.add(_WarehouseTransferLine())),
                            icon: const Icon(Icons.add_rounded, color: Color(0xFF0D9488), size: 18),
                            label: const Text('إضافة صنف آخر للتحويل', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(color: context.dynamicTextPrimary),
                      decoration: InputDecoration(
                        labelText: 'ملاحظات التحويل',
                        hintText: 'سبب التحويل، رقم الإذن، أو أي تفاصيل (اختياري)',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        filled: true,
                        fillColor: context.dynamicSurfaceBg,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: availItems.isEmpty
                            ? null
                            : () {
                                if (!formKey.currentState!.validate()) return;
                                final validLines = lines.where((l) => l.itemId != null).toList();
                                if (validLines.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('يرجى اختيار صنف واحد على الأقل للتحويل')),
                                  );
                                  return;
                                }

                                final entries = <Map<String, dynamic>>[];
                                for (final l in validLines) {
                                  final itm = availItems.firstWhere((s) => s.id == l.itemId);
                                  final rawQty = double.parse(l.qtyController.text.trim());
                                  final actualStorageQty = (l.useUsageUnit && itm.isPackaged && itm.packageSize != null && itm.packageSize! > 0)
                                      ? rawQty / itm.packageSize!
                                      : rawQty;
                                  entries.add({
                                    'itemId': itm.id,
                                    'quantity': actualStorageQty,
                                  });
                                }

                                provider.transferWarehouseItems(
                                  fromWarehouseId: sourceId,
                                  toWarehouseId: destId,
                                  entries: entries,
                                  date: date,
                                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                );

                                for (final l in lines) {
                                  l.dispose();
                                }
                                notesController.dispose();
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF0D9488),
                                    content: Text('تم تحويل الكميات بنجاح من ${fromW?.name ?? ''} إلى ${toW?.name ?? ''}'),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('تأكيد تحويل الكميات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTransferHistorySheet(BuildContext context, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final transferTxs = provider.inventoryTransactions
            .where((t) => t.transferId != null && t.type == 'out')
            .toList();

        // Group by transferId
        final groupedTransfers = <String, List<InventoryTransaction>>{};
        for (final tx in transferTxs) {
          groupedTransfers.putIfAbsent(tx.transferId!, () => []).add(tx);
        }

        final sortedTransferIds = groupedTransfers.keys.toList()
          ..sort((a, b) {
            final dateA = groupedTransfers[a]!.first.date;
            final dateB = groupedTransfers[b]!.first.date;
            return dateB.compareTo(dateA);
          });

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.dynamicCardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, color: Color(0xFF0D9488), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سجل التحويلات بين المخازن',
                            style: TextStyle(
                              color: ctx.dynamicTextPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${sortedTransferIds.length} عملية تحويل مسجلة',
                            style: TextStyle(color: ctx.dynamicTextMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: sortedTransferIds.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 48, color: ctx.dynamicTextMuted),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد عمليات تحويل مسجلة حتى الآن',
                                style: TextStyle(color: ctx.dynamicTextSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: sortedTransferIds.length,
                          itemBuilder: (context, index) {
                            final transferId = sortedTransferIds[index];
                            final txs = groupedTransfers[transferId]!;
                            final firstTx = txs.first;

                            final fromW = provider.warehouses.firstWhereOrNull((w) => w.id == firstTx.fromWarehouseId);
                            final toW = provider.warehouses.firstWhereOrNull((w) => w.id == firstTx.toWarehouseId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ctx.dynamicSurfaceBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ctx.dynamicCardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              fromW?.name ?? 'مخزن مصدر',
                                              style: TextStyle(
                                                color: ctx.dynamicTextPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 6),
                                              child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF0D9488), size: 16),
                                            ),
                                            Text(
                                              toW?.name ?? 'مخزن مستلم',
                                              style: const TextStyle(
                                                color: Color(0xFF0D9488),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.undo_rounded, color: AppTheme.expenseRed, size: 20),
                                        tooltip: 'إلغاء التحويل واسترجاع الكميات',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              backgroundColor: ctx.dynamicCardBg,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              title: Text('إلغاء عملية التحويل', style: TextStyle(color: ctx.dynamicTextPrimary, fontWeight: FontWeight.w700)),
                                              content: const Text('هل تريد بالتأكيد إلغاء عملية التحويل هذه؟ سيتم استرجاع الكميات إلى المخزن المصدر وخصمها من المخزن المستلم.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
                                                TextButton(
                                                  onPressed: () {
                                                    provider.deleteWarehouseTransfer(transferId);
                                                    Navigator.pop(context);
                                                    Navigator.pop(ctx);
                                                  },
                                                  child: Text('تأكيد الإلغاء', style: TextStyle(color: AppTheme.expenseRed)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(firstTx.date),
                                    style: TextStyle(color: ctx.dynamicTextMuted, fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  ...txs.map((tx) {
                                    final item = provider.storageItems.firstWhereOrNull((s) => s.id == tx.itemId);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, size: 6, color: Color(0xFF0D9488)),
                                          const SizedBox(width: 8),
                                          Text(
                                            item?.name ?? 'صنف',
                                            style: TextStyle(color: ctx.dynamicTextPrimary, fontSize: 12),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${tx.quantity.formatted} ${item?.unit ?? ''}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (firstTx.notes != null && firstTx.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'ملاحظات: ${firstTx.notes}',
                                      style: TextStyle(color: ctx.dynamicTextSecondary, fontSize: 11),
                                    ),
                                  ],
                                ],
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
    );
  }
}

class _WarehouseConsumeLine {
  String? itemId;
  final TextEditingController qtyController;
  _WarehouseConsumeLine() : qtyController = TextEditingController();
  void dispose() => qtyController.dispose();
}

class _WarehouseTransferLine {
  String? itemId;
  bool useUsageUnit;
  final TextEditingController qtyController;
  _WarehouseTransferLine({this.itemId, this.useUsageUnit = false})
      : qtyController = TextEditingController();
  void dispose() => qtyController.dispose();
}
