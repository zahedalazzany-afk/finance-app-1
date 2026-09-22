import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'new_purchase_screen.dart';
import 'purchase_detail_screen.dart';
import 'purchase_distribution_screen.dart';
import 'purchase_distributions_screen.dart';
import '../widgets/data_export_import_button.dart';

enum PurchaseFilterTab { all, unpaid, paid, needsDistribution }

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String? _selectedSupplierId;
  String _searchQuery = '';
  PurchaseFilterTab _activeTab = PurchaseFilterTab.all;

  List<Partner> _supplierPartners(FinanceProvider provider) =>
      provider.partners.where((p) => p.roles.contains('supplier')).toList();

  void _showSupplierPicker(FinanceProvider provider) {
    final suppliers = _supplierPartners(provider);
    String sheetSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final filtered = sheetSearch.isEmpty
                  ? suppliers
                  : suppliers
                      .where((s) => s.name.toLowerCase().contains(sheetSearch.toLowerCase()))
                      .toList();
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          autofocus: true,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'بحث عن مورد',
                            hintText: 'اكتب اسم المورد...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setSheetState(() => sheetSearch = v),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.clear_all, color: AppTheme.textSecondary),
                    title: Text('جميع الموردين',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() => _selectedSupplierId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('لا يوجد نتائج',
                                style: TextStyle(color: AppTheme.textSecondary)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final s = filtered[index];
                              final isSelected = s.id == _selectedSupplierId;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppTheme.accentBlue
                                      : AppTheme.accentBlueDim,
                                  child: Icon(
                                    Icons.business,
                                    color: isSelected ? Colors.white : AppTheme.accentBlue,
                                    size: 20,
                                  ),
                                ),
                                title: Text(s.name,
                                    style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.accentBlue
                                            : AppTheme.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                                subtitle: s.phone != null && s.phone!.isNotEmpty
                                    ? Text(s.phone!,
                                        style: const TextStyle(fontSize: 12))
                                    : null,
                                trailing: isSelected
                                    ? Icon(Icons.check, color: AppTheme.accentBlue)
                                    : null,
                                onTap: () {
                                  setState(() => _selectedSupplierId = s.id);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final suppliers = _supplierPartners(provider);
    final supplierMap = {for (var s in provider.partners) s.id: s};

    // حسابات المؤشرات المالية لجميع المشتريات
    final allPurchases = provider.purchases;
    final totalNetAll = allPurchases.fold(0.0, (s, p) => s + p.netAmount);
    final totalPaidAll = allPurchases.fold(0.0, (s, p) => s + p.paidAmount);
    final totalRemainingAll = allPurchases.fold(0.0, (s, p) => s + p.remainingAmount);

    int pendingDistributionCount = 0;
    for (final p in allPurchases) {
      final items = provider.purchaseItemsFor(p.id);
      if (items.any((i) => i.remainingToDistribute > 0.01)) {
        pendingDistributionCount++;
      }
    }

    // تصفية القائمة
    final filtered = allPurchases.where((p) {
      // 1. فلتر المورد
      if (_selectedSupplierId != null && p.supplierId != _selectedSupplierId) {
        return false;
      }

      // 2. فلتر البحث
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final sName = (supplierMap[p.supplierId]?.name ?? '').toLowerCase();
        final invNum = (p.invoiceNumber ?? '').toLowerCase();
        final notes = (p.notes ?? '').toLowerCase();
        if (!sName.contains(query) && !invNum.contains(query) && !notes.contains(query)) {
          return false;
        }
      }

      // 3. فلتر التبويبات السريعة
      switch (_activeTab) {
        case PurchaseFilterTab.all:
          return true;
        case PurchaseFilterTab.unpaid:
          return p.remainingAmount > 0.01;
        case PurchaseFilterTab.paid:
          return p.remainingAmount <= 0.01;
        case PurchaseFilterTab.needsDistribution:
          final items = provider.purchaseItemsFor(p.id);
          return items.any((i) => i.remainingToDistribute > 0.01);
      }
    }).toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('سجل المشتريات'),
        actions: [
          DataExportImportButton(
            label: 'المشتريات',
            buildRows: () => context
                .read<FinanceProvider>()
                .purchases
                .map((e) => e.toJson())
                .toList(),
            csvHeaders: const [
              'المورد', 'التاريخ', 'إجمالي الأصناف', 'الخصم', 'المدفوع', 'طريقة الدفع',
              'رقم الفاتورة', 'ملاحظات',
            ],
            csvKeys: const [
              'supplierId', 'date', 'totalAmount', 'discount', 'paidAmount', 'paymentType',
              'invoiceNumber', 'notes',
            ],
            onImport: (rows) async {
              final provider = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final purchase = Purchase.fromJson(row);
                  if (provider.purchases.any((e) => e.id == purchase.id)) {
                    continue;
                  }
                  final entries = provider
                      .purchaseItemsFor(purchase.id)
                      .map((e) => e.toJson())
                      .toList();
                  provider.addPurchase(purchase, entries);
                } catch (_) {}
              }
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: pendingDistributionCount > 0,
              label: Text('$pendingDistributionCount'),
              backgroundColor: Colors.amber,
              textColor: Colors.black,
              child: const Icon(Icons.warehouse_outlined),
            ),
            tooltip: 'توزيع للمخازن',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PurchaseDistributionsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. شريط المؤشرات المالية العلوية (KPIs)
          _buildKpiSummaryBar(
            totalNet: totalNetAll,
            totalPaid: totalPaidAll,
            totalRemaining: totalRemainingAll,
            pendingDistCount: pendingDistributionCount,
          ),

          // 2. شريط البحث والفلترة السريعة
          _buildSearchAndFilterSection(provider, suppliers, supplierMap),

          // 3. قائمة فواتير الشراء
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final purchase = filtered[index];
                      final supplier = supplierMap[purchase.supplierId];
                      final items = provider.purchaseItemsFor(purchase.id);
                      final hasRemainingDist =
                          items.any((i) => i.remainingToDistribute > 0.01);

                      return _PurchaseInvoiceCard(
                        purchase: purchase,
                        supplier: supplier,
                        itemsCount: items.length,
                        hasRemainingDist: hasRemainingDist,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PurchaseDetailScreen(purchaseId: purchase.id),
                          ),
                        ),
                        onPay: () => showPurchasePaymentSheet(
                            context, provider, purchase),
                        onDistribute: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PurchaseDistributionScreen(
                                purchase: purchase),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const NewPurchaseScreen())),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('فاتورة شراء',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildKpiSummaryBar({
    required double totalNet,
    required double totalPaid,
    required double totalRemaining,
    required int pendingDistCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildKpiCard(
              title: 'إجمالي المشتريات',
              value: '${totalNet.formattedFull} ر.ي',
              icon: Icons.shopping_bag_outlined,
              accentColor: AppTheme.accentBlue,
              bgDimColor: AppTheme.accentBlueDim,
            ),
            const SizedBox(width: 8),
            _buildKpiCard(
              title: 'المبالغ المسددة',
              value: '${totalPaid.formattedFull} ر.ي',
              icon: Icons.check_circle_outline,
              accentColor: AppTheme.incomeGreen,
              bgDimColor: AppTheme.incomeGreenDim,
            ),
            const SizedBox(width: 8),
            _buildKpiCard(
              title: 'المتبقي الآجل (ديون)',
              value: '${totalRemaining.formattedFull} ر.ي',
              icon: Icons.warning_amber_rounded,
              accentColor: AppTheme.expenseRed,
              bgDimColor: AppTheme.expenseRedDim,
              isAlert: totalRemaining > 0,
            ),
            const SizedBox(width: 8),
            _buildKpiCard(
              title: 'بانتظار التوزيع',
              value: '$pendingDistCount فواتير',
              icon: Icons.hourglass_top_rounded,
              accentColor: Colors.amber,
              bgDimColor: Colors.amber.withValues(alpha: 0.15),
              isAlert: pendingDistCount > 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgDimColor,
    bool isAlert = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? accentColor.withValues(alpha: 0.4) : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgDimColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentColor, size: 14),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isAlert ? accentColor : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection(
    FinanceProvider provider,
    List<Partner> suppliers,
    Map<String, Partner> supplierMap,
  ) {
    final selectedSupplier = supplierMap[_selectedSupplierId];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // شريط البحث
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: TextField(
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم المورد، رقم الفاتورة (#)...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // زر تصفية المورد
              GestureDetector(
                onTap: () => _showSupplierPicker(provider),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _selectedSupplierId != null
                        ? AppTheme.accentBlue.withValues(alpha: 0.15)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedSupplierId != null
                          ? AppTheme.accentBlue
                          : AppTheme.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: _selectedSupplierId != null
                            ? AppTheme.accentBlue
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedSupplierId != null
                            ? (selectedSupplier?.name ?? 'المورد')
                            : 'المورد',
                        style: TextStyle(
                          color: _selectedSupplierId != null
                              ? AppTheme.accentBlue
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: _selectedSupplierId != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (_selectedSupplierId != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _selectedSupplierId = null),
                          child: Icon(Icons.close, size: 14, color: AppTheme.accentBlue),
                        ),
                      ] else ...[
                        Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.textSecondary),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // تبويبات الفلترة السريعة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('الكل', PurchaseFilterTab.all),
                const SizedBox(width: 6),
                _buildFilterChip('آجل / غير مسدد', PurchaseFilterTab.unpaid),
                const SizedBox(width: 6),
                _buildFilterChip('مسدد بالكامل', PurchaseFilterTab.paid),
                const SizedBox(width: 6),
                _buildFilterChip('يحتاج توزيع للمخزن', PurchaseFilterTab.needsDistribution),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, PurchaseFilterTab tab) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, color: AppTheme.textMuted, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد فواتير مشتريات تطابق البحث',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'يمكنك تغيير الفلاتر أو إنشاء فاتورة شراء جديدة بالضغط على +',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PurchaseInvoiceCard extends StatelessWidget {
  final Purchase purchase;
  final Partner? supplier;
  final int itemsCount;
  final bool hasRemainingDist;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onDistribute;

  const _PurchaseInvoiceCard({
    required this.purchase,
    required this.supplier,
    required this.itemsCount,
    required this.hasRemainingDist,
    required this.onTap,
    required this.onPay,
    required this.onDistribute,
  });

  @override
  Widget build(BuildContext context) {
    final isFullyPaid = purchase.remainingAmount <= 0.01;
    final isPartiallyPaid = purchase.paidAmount > 0.01 && !isFullyPaid;
    final statusColor = isFullyPaid
        ? AppTheme.incomeGreen
        : (isPartiallyPaid ? Colors.orange : AppTheme.expenseRed);
    final paymentPercent = purchase.netAmount > 0
        ? (purchase.paidAmount / purchase.netAmount).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس البطاقة: المورد وشارات الحالة
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier?.name ?? 'مورد محذوف',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM yyyy', 'ar').format(purchase.date),
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                              if (purchase.invoiceNumber != null &&
                                  purchase.invoiceNumber!.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.receipt_long, size: 12, color: AppTheme.accentBlue),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '#${purchase.invoiceNumber}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.accentBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(isFullyPaid, isPartiallyPaid),
                  ],
                ),
                const SizedBox(height: 10),

                // سطر تفاصيل المخزن وعدد الأصناف
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '$itemsCount أصناف',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (hasRemainingDist)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.amber),
                            SizedBox(width: 3),
                            Text(
                              'يحتاج توزيع',
                              style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.all_inbox_rounded, size: 11, color: AppTheme.accentBlue),
                            SizedBox(width: 3),
                            Text(
                              'موزع بالكامل',
                              style: TextStyle(color: AppTheme.accentBlue, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: AppTheme.cardBorder),
                const SizedBox(height: 10),

                // سطر المبالغ والتقدم المالي
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('صافي الفاتورة',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          '${purchase.netAmount.formattedFull} ر.ي',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (purchase.discount > 0)
                          Text(
                            'خصم: ${purchase.discount.formattedFull} ر.ي',
                            style: TextStyle(
                              color: AppTheme.incomeGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (purchase.remainingAmount > 0.01) ...[
                          Text(
                            'المتبقي: ${purchase.remainingAmount.formattedFull} ر.ي',
                            style: TextStyle(
                              color: AppTheme.expenseRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'مسدد: ${purchase.paidAmount.formattedFull} ر.ي',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.check_circle, size: 14, color: AppTheme.incomeGreen),
                              SizedBox(width: 4),
                              Text(
                                'خالصة تماماً',
                                style: TextStyle(
                                  color: AppTheme.incomeGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // شريط تقدم السداد الصغير
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: paymentPercent,
                    minHeight: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFullyPaid ? AppTheme.incomeGreen : (paymentPercent > 0 ? Colors.orange : AppTheme.expenseRed),
                    ),
                  ),
                ),

                // أزرار الإجراءات السريعة في البطاقة
                if (purchase.remainingAmount > 0.01 || hasRemainingDist) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasRemainingDist) ...[
                        OutlinedButton.icon(
                          onPressed: onDistribute,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentBlue,
                            side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.warehouse_outlined, size: 14),
                          label: const Text('توزيع', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (purchase.remainingAmount > 0.01)
                        OutlinedButton.icon(
                          onPressed: onPay,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.incomeGreen,
                            side: BorderSide(color: AppTheme.incomeGreen.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 14),
                          label: const Text('سداد دفعة', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isFullyPaid, bool isPartiallyPaid) {
    if (isFullyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.incomeGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'مسدد',
          style: TextStyle(color: AppTheme.incomeGreen, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    } else if (isPartiallyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'جزئي',
          style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.expenseRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'آجل',
          style: TextStyle(color: AppTheme.expenseRed, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}

/// نافذة تسجيل دفعة سداد أو تطبيق خصم تسوية على فاتورة الشراء
void showPurchasePaymentSheet(
    BuildContext context, FinanceProvider provider, Purchase purchase) {
  final remaining = purchase.remainingAmount;
  final amountController = TextEditingController();
  final discountController = TextEditingController(text: '0');
  DateTime date = DateTime.now();
  String? walletId = provider.defaultWallet()?.id;
  final formKey = GlobalKey<FormState>();
  final fundingKey = GlobalKey<FundingPickerState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final enteredAmt = tryParseFlexible(amountController.text) ?? 0;
        final enteredDisc = tryParseFlexible(discountController.text) ?? 0;
        final remainingAfter =
            (remaining - enteredAmt - enteredDisc).clamp(0.0, double.infinity);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          color: AppTheme.incomeGreen, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'تسجيل سداد / خصم للفاتورة',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المتبقي الآجل: ${remaining.formattedFull} ر.ي',
                    style: TextStyle(
                      color: AppTheme.expenseRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: AppTheme.incomeGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المدفوع نقدًا',
                      hintText: '0',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                    validator: (v) {
                      final a = tryParseFlexible(v ?? '') ?? 0;
                      final d = tryParseFlexible(discountController.text) ?? 0;
                      if (a <= 0 && d <= 0) return 'أدخل المبلغ المدفوع أو مبلغ الخصم';
                      if (a < 0) return 'مبلغ غير صحيح';
                      if (a + d > remaining + 0.01) {
                        return 'المجموع (${(a + d).formatted}) يتجاوز المتبقي (${remaining.formattedFull})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: discountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'خصم تسوية إضافي من المورد (إن وجد)',
                      hintText: '0',
                      prefixIcon: Icon(Icons.discount_outlined,
                          color: AppTheme.incomeGreen),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                    validator: (v) {
                      final d = tryParseFlexible(v ?? '') ?? 0;
                      if (d < 0) return 'رقم غير صحيح';
                      final a = tryParseFlexible(amountController.text) ?? 0;
                      if (a + d > remaining + 0.01) {
                        return 'مجموع الدفعة والخصم يتجاوز المتبقي';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المتبقي بعد السداد والخصم:',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        Text(
                          '${remainingAfter.formattedFull} ر.ي',
                          style: TextStyle(
                            color: remainingAfter <= 0.01
                                ? AppTheme.incomeGreen
                                : AppTheme.expenseRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (ctx, child) => Theme(
                          data: AppTheme.theme.copyWith(
                            colorScheme: ColorScheme.dark(
                                primary: AppTheme.incomeGreen,
                                surface: AppTheme.card),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setSheetState(() => date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: AppTheme.textSecondary, size: 18),
                          const SizedBox(width: 12),
                          Text(DateFormat('dd MMM yyyy', 'ar').format(date),
                              style: TextStyle(
                                  color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  if (enteredAmt > 0) ...[
                    const SizedBox(height: 12),
                    if (provider.wallets.isEmpty)
                      Text('لا توجد محافظ، أنشئ محفظة أولاً',
                          style: TextStyle(color: AppTheme.expenseRed))
                    else
                      SheetDropdown<String>(
                        label: 'المحفظة',
                        icon: Icons.wallet,
                        value: walletId,
                        items: provider.wallets
                            .map((w) => DropdownMenuItem(
                                value: w.id, child: Text(w.name)))
                            .toList(),
                        onChanged: (v) => setSheetState(() => walletId = v),
                      ),
                    const SizedBox(height: 16),
                    FundingPicker(
                      provider: provider,
                      pickerKey: fundingKey,
                      walletFilter: walletId,
                      requiredTotalGetter: () => enteredAmt,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final amount =
                            tryParseFlexible(amountController.text) ?? 0;
                        final discount =
                            tryParseFlexible(discountController.text) ?? 0;

                        if (amount > 0 && walletId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('اختر محفظة الدفع'),
                                backgroundColor: AppTheme.expenseRed),
                          );
                          return;
                        }

                        List<ExpenseAllocation>? funding;
                        if (amount > 0) {
                          funding = fundingKey.currentState?.allocations ?? [];
                          if (!(fundingKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final sumFunding =
                              funding.fold(0.0, (s, a) => s + a.amount);
                          if ((sumFunding - amount).abs() > 0.01) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'مجموع التمويل يجب أن يساوي مبلغ الدفعة (${amount.formatted} ر.ي)'),
                                  backgroundColor: AppTheme.expenseRed),
                            );
                            return;
                          }
                        }

                        provider.recordPurchasePayment(
                          purchase.id,
                          amount,
                          date,
                          amount > 0 ? walletId : null,
                          discount: discount,
                          funding: funding,
                        );
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.incomeGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('تأكيد السداد والخصم',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
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
