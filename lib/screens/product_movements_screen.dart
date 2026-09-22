import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'product_form_screen.dart';
import 'purchase_distributions_screen.dart';

class ProductMovementsScreen extends StatefulWidget {
  final Product product;
  const ProductMovementsScreen({super.key, required this.product});

  @override
  State<ProductMovementsScreen> createState() => _ProductMovementsScreenState();
}

class _Movement {
  final DateTime date;
  final String type; // 'purchase', 'in', 'out'
  final String title;
  final double quantity;
  final double? unitPrice;
  final double? total;
  final String? location;
  final String? warehouseId;
  final String? plotName;
  final String? eventType;
  final String? details;
  final String? refId;
  final String? invoiceNumber;
  final String? supplierName;
  final double runningWarehouseBalance;
  final double runningTotalStock;
  final double runningUndistributed;
  final double? purchaseDistributedQuantity;
  final double? purchaseRemainingQuantity;

  _Movement({
    required this.date,
    required this.type,
    required this.title,
    required this.quantity,
    this.unitPrice,
    this.total,
    this.location,
    this.warehouseId,
    this.plotName,
    this.eventType,
    this.details,
    this.refId,
    this.invoiceNumber,
    this.supplierName,
    this.runningWarehouseBalance = 0.0,
    this.runningTotalStock = 0.0,
    this.runningUndistributed = 0.0,
    this.purchaseDistributedQuantity,
    this.purchaseRemainingQuantity,
  });
}

class _ProductMovementsScreenState extends State<ProductMovementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _movementFilter = 'all'; // 'all', 'purchase', 'in', 'out'
  String _searchQuery = '';
  bool _sortAscending = false; // false: newest first, true: oldest first

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_Movement> _getMovements(
      FinanceProvider provider, Product currentProduct) {
    final rawMovements = <_Movement>[];

    // 1. المشتريات
    final productPurchaseItems = provider.purchaseItems
        .where((pi) => pi.productId == currentProduct.id)
        .toList();
    final purchaseItemIds = productPurchaseItems.map((pi) => pi.id).toSet();

    for (final pi in productPurchaseItems) {
      final purchase =
          provider.purchases.firstWhereOrNull((p) => p.id == pi.purchaseId);
      if (purchase == null) continue;
      final supplier = provider.partners
          .firstWhereOrNull((p) => p.id == purchase.supplierId);
      final supplierName = supplier?.name ?? 'مورد غير محدد';
      final invNum = purchase.invoiceNumber?.trim() ?? '';

      rawMovements.add(_Movement(
        date: purchase.date,
        type: 'purchase',
        title: 'شراء من $supplierName',
        quantity: pi.quantity,
        unitPrice: pi.unitPrice,
        total: pi.total,
        supplierName: supplierName,
        invoiceNumber: invNum,
        purchaseDistributedQuantity: pi.distributedQuantity,
        purchaseRemainingQuantity: pi.remainingToDistribute,
        details: invNum.isNotEmpty
            ? 'فاتورة رقم: $invNum'
            : 'فاتورة شراء',
        refId: purchase.id,
      ));
    }

    // 2. حركات المخازن (إدخال وتوزيع / صرف واستهلاك)
    final storageItemByTxId = {
      for (final si in provider.storageItems) si.id: si,
    };

    final matchingStorageItems = provider.storageItems
        .where((si) =>
            si.productId == currentProduct.id ||
            si.name.trim() == currentProduct.name.trim())
        .toList();
    final matchingStorageItemIds =
        matchingStorageItems.map((si) => si.id).toSet();

    for (final tx in provider.inventoryTransactions) {
      if (tx.type == 'in') {
        final isMatch = tx.purchaseItemId != null &&
                purchaseItemIds.contains(tx.purchaseItemId) ||
            matchingStorageItemIds.contains(tx.itemId);
        if (!isMatch) continue;

        final item = storageItemByTxId[tx.itemId];
        final warehouse = provider.warehouses
            .firstWhereOrNull((w) => w.id == item?.warehouseId);
        final wName = warehouse?.name ?? 'المخزن';

        final isTransfer = tx.transferId != null;
        rawMovements.add(_Movement(
          date: tx.date,
          type: 'in',
          title: isTransfer ? 'تحويل وارد إلى مخزن $wName' : 'إدخال إلى مخزن $wName',
          quantity: tx.quantity,
          location: wName,
          warehouseId: item?.warehouseId,
          details: tx.notes?.isNotEmpty == true ? tx.notes : (isTransfer ? 'تحويل مخزني' : 'توزيع من فاتورة شراء'),
          refId: tx.id,
        ));
      } else {
        // out
        final item = storageItemByTxId[tx.itemId];
        if (item == null) continue;
        final isProduct = matchingStorageItemIds.contains(tx.itemId) ||
            item.productId == currentProduct.id ||
            item.name.trim() == currentProduct.name.trim();
        if (!isProduct) continue;

        final warehouse = provider.warehouses
            .firstWhereOrNull((w) => w.id == item.warehouseId);
        final wName = warehouse?.name ?? 'المخزن';

        final isTransfer = tx.transferId != null;
        final event = tx.eventId != null
            ? provider.landEvents
                .firstWhereOrNull((e) => e.id == tx.eventId)
            : null;

        String? plotName;
        if (event?.landPlotId != null) {
          final plot = provider.landPlots
              .firstWhereOrNull((p) => p.id == event!.landPlotId);
          plotName = plot?.name;
        }

        String eventDetail = '';
        if (isTransfer) {
          eventDetail = tx.notes ?? 'تحويل إلى مخزن آخر';
        } else if (event != null) {
          if (plotName != null && plotName.isNotEmpty) {
            eventDetail = 'موضع: $plotName · عملية: ${event.eventType}';
          } else {
            eventDetail = 'عملية زراعية: ${event.eventType}';
          }
        } else if (tx.notes?.isNotEmpty == true) {
          eventDetail = tx.notes!;
        } else {
          eventDetail = 'صرف واستهلاك زراعي';
        }

        rawMovements.add(_Movement(
          date: tx.date,
          type: 'out',
          title: isTransfer ? 'تحويل صادر من مخزن $wName' : 'صرف من مخزن $wName',
          quantity: tx.quantity,
          location: wName,
          warehouseId: item.warehouseId,
          plotName: plotName,
          eventType: isTransfer ? 'تحويل مخزني' : event?.eventType,
          details: eventDetail,
          refId: tx.id,
        ));
      }
    }

    // 3. حساب تتبع الرصيد التراكمي زمنياً بدقة من الأقدم إلى الأحدث
    rawMovements.sort((a, b) => a.date.compareTo(b.date));

    // الأرصدة تبدأ من الصفر وتتراكم حصراً بناءً على الحركات المسجلة
    final runningWarehouseMap = <String, double>{};
    double runningUndistributed = 0.0;
    final processedMovements = <_Movement>[];

    for (final m in rawMovements) {
      if (m.type == 'purchase') {
        runningUndistributed += m.quantity;
      } else if (m.type == 'in') {
        final tx = provider.inventoryTransactions.firstWhereOrNull((t) => t.id == m.refId);
        if (tx?.purchaseItemId != null && tx!.purchaseItemId!.isNotEmpty) {
          runningUndistributed =
              (runningUndistributed - m.quantity).clamp(0.0, double.infinity);
        }
        if (m.warehouseId != null) {
          runningWarehouseMap[m.warehouseId!] =
              (runningWarehouseMap[m.warehouseId!] ?? 0.0) + m.quantity;
        }
      } else if (m.type == 'out') {
        if (m.warehouseId != null) {
          runningWarehouseMap[m.warehouseId!] =
              ((runningWarehouseMap[m.warehouseId!] ?? 0.0) - m.quantity)
                  .clamp(0.0, double.infinity);
        }
      }

      final wBal = m.warehouseId != null
          ? (runningWarehouseMap[m.warehouseId!] ?? 0.0)
          : 0.0;
      final totalInWarehouses =
          runningWarehouseMap.values.fold(0.0, (s, v) => s + v);
      final totalStock = totalInWarehouses + runningUndistributed;

      processedMovements.add(_Movement(
        date: m.date,
        type: m.type,
        title: m.title,
        quantity: m.quantity,
        unitPrice: m.unitPrice,
        total: m.total,
        location: m.location,
        warehouseId: m.warehouseId,
        plotName: m.plotName,
        eventType: m.eventType,
        details: m.details,
        refId: m.refId,
        invoiceNumber: m.invoiceNumber,
        supplierName: m.supplierName,
        runningWarehouseBalance: wBal,
        runningTotalStock: totalStock,
        runningUndistributed: runningUndistributed,
        purchaseDistributedQuantity: m.purchaseDistributedQuantity,
        purchaseRemainingQuantity: m.purchaseRemainingQuantity,
      ));
    }

    // الترتيب حسب رغبة المستخدم
    if (_sortAscending) {
      return processedMovements;
    } else {
      return processedMovements.reversed.toList();
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'أسمدة':
        return Colors.green;
      case 'مبيدات':
        return Colors.redAccent;
      case 'بذور':
        return Colors.orange;
      case 'أدوات ومعدات':
        return Colors.blue;
      case 'أدوية بيطرية':
        return Colors.purple;
      default:
        return AppTheme.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    // Always fetch latest product entity if modified
    final currentProduct = provider.products
            .firstWhereOrNull((p) => p.id == widget.product.id) ??
        widget.product;

    final movements = _getMovements(provider, currentProduct);

    final undistributed = provider.purchaseItems
        .where((pi) => pi.productId == currentProduct.id)
        .fold<double>(0.0, (sum, pi) => sum + pi.remainingToDistribute);

    final warehouseItems = provider.storageItems
        .where((si) =>
            si.productId == currentProduct.id ||
            si.name.trim() == currentProduct.name.trim())
        .toList();

    final inWarehouses = warehouseItems.fold<double>(
        0.0, (sum, si) => sum + si.quantity);

    // Linked Active Chemical Ingredients
    final productIngredients = provider.productIngredients
        .where((pi) => pi.productId == currentProduct.id)
        .toList();

    // Low stock warning
    final isLowStock = currentProduct.minStock > 0 &&
        (inWarehouses + undistributed) <= currentProduct.minStock;

    final catColor = _categoryColor(currentProduct.category);

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('تفاصيل وحركات المنتج'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'تعديل بيانات المنتج',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(product: currentProduct),
                ),
              );
            },
          ),
          if (undistributed > 0.001)
            IconButton(
              icon: const Icon(Icons.alt_route_rounded, color: Colors.amber),
              tooltip: 'توزيع الكميات غير الموزعة',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PurchaseDistributionsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- بطاقة المنتج الرئيسية ---
                  _buildProductHeroCard(
                    context: context,
                    product: currentProduct,
                    catColor: catColor,
                    isLowStock: isLowStock,
                    inWarehouses: inWarehouses,
                    undistributed: undistributed,
                  ),
                  const SizedBox(height: 12),

                  // --- شبكة المؤشرات السريعة ---
                  _buildQuickStatsGrid(
                    context: context,
                    product: currentProduct,
                    inWarehouses: inWarehouses,
                    undistributed: undistributed,
                    isLowStock: isLowStock,
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.accentBlue,
                unselectedLabelColor: context.dynamicTextMuted,
                indicatorColor: AppTheme.accentBlue,
                indicatorWeight: 3,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_outlined, size: 20),
                    text: 'المخازن والتفاصيل',
                  ),
                  Tab(
                    icon: Icon(Icons.history_rounded, size: 20),
                    text: 'سجل الحركات والتوريد',
                  ),
                ],
              ),
              backgroundColor: context.dynamicScaffoldBg,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // التبويب 1: المخازن والمواصفات
            _buildProductOverviewTab(
              context: context,
              provider: provider,
              product: currentProduct,
              warehouseItems: warehouseItems,
              productIngredients: productIngredients,
              undistributed: undistributed,
              inWarehouses: inWarehouses,
            ),

            // التبويب 2: سجل الحركات
            _buildMovementsTab(
              context: context,
              provider: provider,
              product: currentProduct,
              movements: movements,
            ),
          ],
        ),
      ),
    );
  }

  // --- بطاقة هيدر المنتج الرئيسية ---
  Widget _buildProductHeroCard({
    required BuildContext context,
    required Product product,
    required Color catColor,
    required bool isLowStock,
    required double inWarehouses,
    required double undistributed,
  }) {
    final totalStock = inWarehouses + undistributed;
    final isOutOfStock = totalStock <= 0.0001;

    // حالة المخزون
    final String stockStatusText;
    final Color stockStatusColor;
    final Color stockStatusBg;
    final IconData stockStatusIcon;

    if (isOutOfStock) {
      stockStatusText = 'نفد المخزون';
      stockStatusColor = AppTheme.expenseRed;
      stockStatusBg = AppTheme.expenseRed.withValues(alpha: 0.12);
      stockStatusIcon = Icons.cancel_outlined;
    } else if (isLowStock) {
      stockStatusText = 'مخزون منخفض (تحت حد الطلب)';
      stockStatusColor = Colors.amber[900]!;
      stockStatusBg = Colors.amber.withValues(alpha: 0.14);
      stockStatusIcon = Icons.warning_amber_rounded;
    } else {
      stockStatusText = 'المخزون متوفر ومستقر';
      stockStatusColor = AppTheme.incomeGreen;
      stockStatusBg = AppTheme.incomeGreen.withValues(alpha: 0.12);
      stockStatusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط علوي ملون بلون فئة الصنف
            Container(
              height: 4,
              color: catColor,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // أيقونة / شعار المنتج
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            product.name.isNotEmpty
                                ? product.name.characters.first
                                : '📦',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // تفاصيل الاسم والفئة
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.dynamicTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _tagBadge(
                                  text: product.category,
                                  color: catColor,
                                  bg: catColor.withValues(alpha: 0.12),
                                  icon: Icons.category_outlined,
                                ),
                                if (product.isPackaged)
                                  _tagBadge(
                                    text:
                                        '${product.packageType} (${product.packageSize.formatted} ${product.usageUnit ?? ""})',
                                    color: Colors.deepPurple,
                                    bg: Colors.deepPurple.withValues(alpha: 0.12),
                                    icon: Icons.inventory_2_outlined,
                                  )
                                else
                                  _tagBadge(
                                    text: 'وحدة: ${product.unit}',
                                    color: Colors.teal,
                                    bg: Colors.teal.withValues(alpha: 0.12),
                                    icon: Icons.straighten_outlined,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // شارة حالة المخزون
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: stockStatusBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: stockStatusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(stockStatusIcon, size: 16, color: stockStatusColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stockStatusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: stockStatusColor,
                            ),
                          ),
                        ),
                        if (product.minStock > 0)
                          Text(
                            'حد الطلب: ${product.minStock.formatted} ${product.unit}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: stockStatusColor.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // شريط سعر الشراء أسفل الهيدر
                  if (product.purchasePrice > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? AppTheme.card.withValues(alpha: 0.6)
                            : AppTheme.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: context.dynamicCardBorder.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _heroMiniPrice(
                            context: context,
                            label: 'سعر الشراء',
                            price: product.purchasePrice,
                            color: AppTheme.accentBlue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMiniPrice({
    required BuildContext context,
    required String label,
    required double price,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: context.dynamicTextMuted,
          ),
        ),
        Text(
          price > 0 ? '${price.formatted} ر.ي' : 'غير مسجل',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: price > 0 ? color : context.dynamicTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _tagBadge({
    required String text,
    required Color color,
    required Color bg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- شبكة المؤشرات السريعة ---
  Widget _buildQuickStatsGrid({
    required BuildContext context,
    required Product product,
    required double inWarehouses,
    required double undistributed,
    required bool isLowStock,
  }) {
    final totalStock = inWarehouses + undistributed;
    final warehousePct =
        totalStock > 0 ? ((inWarehouses / totalStock) * 100).toInt() : 0;

    return Row(
      children: [
        // المخزون بالمخازن
        Expanded(
          child: _statBox(
            context: context,
            label: 'بالمخازن',
            value: '${inWarehouses.formatted} ${product.unit}',
            subtitle: totalStock > 0 ? '$warehousePct% من الإجمالي' : 'لا يوجد',
            color: AppTheme.incomeGreen,
            icon: Icons.warehouse_rounded,
          ),
        ),
        const SizedBox(width: 8),

        // غير موزع
        Expanded(
          child: _statBox(
            context: context,
            label: 'غير موزع',
            value: '${undistributed.formatted} ${product.unit}',
            subtitle: undistributed > 0.001 ? 'بانتظار التوزيع' : 'موزع بالكامل',
            color: undistributed > 0.001
                ? Colors.amber[800]!
                : context.dynamicTextMuted,
            icon: Icons.local_shipping_outlined,
          ),
        ),
        const SizedBox(width: 8),

        // إجمالي الرصيد
        Expanded(
          child: _statBox(
            context: context,
            label: 'إجمالي المتوفر',
            value: '${totalStock.formatted} ${product.unit}',
            subtitle: isLowStock ? 'تحت حد الأمان' : 'رصيد كلي',
            color: isLowStock ? Colors.redAccent : AppTheme.accentBlue,
            icon: Icons.all_inbox_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statBox({
    required BuildContext context,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.dynamicTextMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: context.dynamicTextMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- التبويب 1: تفاصيل المنتج وتوزيعه بالمخازن ---
  Widget _buildProductOverviewTab({
    required BuildContext context,
    required FinanceProvider provider,
    required Product product,
    required List<StorageItem> warehouseItems,
    required List<ProductIngredient> productIngredients,
    required double undistributed,
    required double inWarehouses,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // 1. توزيع المخزون الفعلي على المخازن
        _buildWarehousesDistributionCard(
          context: context,
          provider: provider,
          product: product,
          warehouseItems: warehouseItems,
          inWarehouses: inWarehouses,
        ),
        const SizedBox(height: 14),

        // 2. بطاقة الأسعار والتكلفة
        _buildPricingCard(context: context, product: product),
        const SizedBox(height: 14),

        // 3. بطاقة مواصفات التعبئة والتغليف
        _buildPackagingSpecsCard(context: context, product: product),
        const SizedBox(height: 14),

        // 4. المواد الفعالة والتركيب الكيميائي المرتبط
        if (productIngredients.isNotEmpty) ...[
          _buildActiveIngredientsCard(
            context: context,
            provider: provider,
            product: product,
            productIngredients: productIngredients,
          ),
          const SizedBox(height: 14),
        ],

        // 5. زر إجراء سريع
        if (undistributed > 0.001)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'كميات بحاجة للتوزيع',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.amber,
                        ),
                      ),
                      Text(
                        'يوجد ${undistributed.formatted} ${product.unit} بانتظار التوزيع إلى المخازن الفعلية.',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.dynamicTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PurchaseDistributionsScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.alt_route_rounded, size: 14),
                  label: const Text('توزيع الآن'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // بطاقة توزيع المخزون على المخازن
  Widget _buildWarehousesDistributionCard({
    required BuildContext context,
    required FinanceProvider provider,
    required Product product,
    required List<StorageItem> warehouseItems,
    required double inWarehouses,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warehouse_outlined,
                    color: AppTheme.accentBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توزيع المخزون بالمخازن (${warehouseItems.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.dynamicTextPrimary,
                      ),
                    ),
                    Text(
                      'الرصيد الفعلي المتواجد بالمستودعات',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.incomeGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${inWarehouses.formatted} ${product.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.incomeGreen,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (warehouseItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 32,
                        color: context.dynamicTextMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 6),
                    Text(
                      'المنتج غير موجود حالياً في أي مخزن.',
                      style: TextStyle(
                        color: context.dynamicTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...warehouseItems.map((item) {
              final warehouse = provider.warehouses
                  .firstWhereOrNull((w) => w.id == item.warehouseId);
              final pct = inWarehouses > 0 ? (item.quantity / inWarehouses) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppTheme.card.withValues(alpha: 0.5)
                      : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(12),
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
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.location_on_outlined,
                                  size: 14, color: AppTheme.accentBlue),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              warehouse?.name ?? 'مخزن رئيسي',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.dynamicTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.incomeGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.incomeGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الكمية المتوفرة:',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.dynamicTextMuted,
                          ),
                        ),
                        Text(
                          '${item.quantity.formatted} ${product.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.incomeGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: context.dynamicCardBorder,
                        valueColor:
                            AlwaysStoppedAnimation(AppTheme.incomeGreen),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // بطاقة الأسعار والتكلفة
  Widget _buildPricingCard({
    required BuildContext context,
    required Product product,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_money_rounded,
                    color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أسعار الشراء والتكلفة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.dynamicTextPrimary,
                      ),
                    ),
                    Text(
                      'أقل وأعلى سعر شراء مسجل للصنف',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _priceItem(
                  context: context,
                  label: 'أقل سعر شراء',
                  price: product.purchasePrice,
                  color: AppTheme.accentBlue,
                  icon: Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _priceItem(
                  context: context,
                  label: 'أعلى سعر شراء',
                  price: product.maxPurchasePrice > 0
                      ? product.maxPurchasePrice
                      : product.purchasePrice,
                  color: Colors.deepOrange,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceItem({
    required BuildContext context,
    required String label,
    required double price,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.isDark ? AppTheme.card : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.dynamicTextMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              price > 0 ? '${price.formatted} ر.ي' : 'غير محدد',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: price > 0 ? color : context.dynamicTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بطاقة مواصفات التعبئة
  Widget _buildPackagingSpecsCard({
    required BuildContext context,
    required Product product,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings_suggest_outlined,
                    color: Colors.purple, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات التعبئة وحد الطلب الأدنى',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.dynamicTextPrimary,
                      ),
                    ),
                    Text(
                      'مواصفات التغليف ووحدات القياس والاستخدام',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _specRow(
            context: context,
            icon: Icons.inventory_2_outlined,
            label: 'طبيعة التعبئة:',
            value: product.isPackaged
                ? 'منتج معبأ (${product.packageType})'
                : 'منتج غير معبأ (كميات سائبة)',
          ),
          if (product.isPackaged) ...[
            const SizedBox(height: 10),
            _specRow(
              context: context,
              icon: Icons.format_paint_outlined,
              label: 'سعة العبوة الواحدة:',
              value:
                  '${product.packageSize.formatted} ${product.usageUnit ?? ""}',
            ),
            const SizedBox(height: 10),
            _specRow(
              context: context,
              icon: Icons.speed_rounded,
              label: 'وحدة الاستخدام بالرش/السقي:',
              value: product.usageUnit ?? 'غير محددة',
            ),
          ],
          const SizedBox(height: 10),
          _specRow(
            context: context,
            icon: Icons.notifications_active_outlined,
            label: 'حد الطلب الأدنى (نقطة الأمان):',
            value: product.minStock > 0
                ? '${product.minStock.formatted} ${product.unit}'
                : 'غير محدد',
            valueColor: product.minStock > 0
                ? Colors.redAccent
                : context.dynamicTextMuted,
          ),
        ],
      ),
    );
  }

  Widget _specRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppTheme.card.withValues(alpha: 0.5)
            : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: context.dynamicTextMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.dynamicTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? context.dynamicTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // بطاقة المواد الفعالة المرتبطة
  Widget _buildActiveIngredientsCard({
    required BuildContext context,
    required FinanceProvider provider,
    required Product product,
    required List<ProductIngredient> productIngredients,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  color: Colors.tealAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'المواد الفعالة والتركيب الكيميائي (${productIngredients.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.dynamicTextPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...productIngredients.map((pi) {
            final ing = provider.chemicalIngredients
                .firstWhereOrNull((ci) => ci.id == pi.ingredientId);
            final ingName = ing?.name ?? 'مادة غير معروفة';
            final ingType = ing?.type ?? '';
            final conc = pi.concentration;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.isDark ? AppTheme.card : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.dynamicCardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.biotech, color: Colors.teal, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.dynamicTextPrimary,
                          ),
                        ),
                        if (ingType.isNotEmpty)
                          Text(
                            ingType,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.dynamicTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (conc != null && conc > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${conc.formatted}%',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- التبويب 2: سجل الحركات والتوريد (Timeline) مع تتبع الكميات ---
  Widget _buildMovementsTab({
    required BuildContext context,
    required FinanceProvider provider,
    required Product product,
    required List<_Movement> movements,
  }) {
    // تصفية الحركات
    final filtered = movements.where((m) {
      if (_movementFilter == 'purchase' && m.type != 'purchase') return false;
      if (_movementFilter == 'in' && m.type != 'in') return false;
      if (_movementFilter == 'out' && m.type != 'out') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = m.title.toLowerCase().contains(q);
        final matchDetails = m.details?.toLowerCase().contains(q) ?? false;
        final matchLoc = m.location?.toLowerCase().contains(q) ?? false;
        final matchPlot = m.plotName?.toLowerCase().contains(q) ?? false;
        final matchSupplier = m.supplierName?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchDetails && !matchLoc && !matchPlot && !matchSupplier) {
          return false;
        }
      }
      return true;
    }).toList();

    // إحصائيات تدفق وتتبع الكميات
    final totalPurchased = movements
        .where((m) => m.type == 'purchase')
        .fold<double>(0.0, (s, m) => s + m.quantity);
    final totalIn = movements
        .where((m) => m.type == 'in')
        .fold<double>(0.0, (s, m) => s + m.quantity);
    final totalOut = movements
        .where((m) => m.type == 'out')
        .fold<double>(0.0, (s, m) => s + m.quantity);

    final undistributed = provider.purchaseItems
        .where((pi) => pi.productId == product.id)
        .fold<double>(0.0, (sum, pi) => sum + pi.remainingToDistribute);

    final warehouseItems = provider.storageItems
        .where((si) =>
            si.productId == product.id ||
            si.name.trim() == product.name.trim())
        .toList();

    final inWarehouses =
        warehouseItems.fold<double>(0.0, (sum, si) => sum + si.quantity);
    final totalStockNow = inWarehouses + undistributed;

    return Column(
      children: [
        // شريط التصفية والبحث وإحصائيات التدفق
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: context.dynamicScaffoldBg,
          child: Column(
            children: [
              // بطاقة ملخص تتبع تدفق الكميات
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: context.dynamicSurfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.dynamicCardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined,
                            size: 16, color: AppTheme.accentBlue),
                        const SizedBox(width: 6),
                        Text(
                          'ملخص تتبع تدفق الكميات',
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'الرصيد الفعلي: ${totalStockNow.formatted} ${product.unit}',
                          style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildTrackingFlowItem(
                          context,
                          title: 'المشتريات',
                          value: '${totalPurchased.formatted} ${product.unit}',
                          color: AppTheme.accentBlue,
                          icon: Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(width: 8),
                        _buildTrackingFlowItem(
                          context,
                          title: 'الموزع للمخازن',
                          value: '${totalIn.formatted} ${product.unit}',
                          color: AppTheme.incomeGreen,
                          icon: Icons.arrow_downward_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildTrackingFlowItem(
                          context,
                          title: 'المنصرف والمستهلك',
                          value: '${totalOut.formatted} ${product.unit}',
                          color: AppTheme.expenseRed,
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // مربع البحث + زر الترتيب
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        style: TextStyle(
                            color: context.dynamicTextPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'بحث في سجل الحركات، المورد، المخزن، الموضع...',
                          hintStyle: TextStyle(
                              color: context.dynamicTextMuted, fontSize: 12),
                          prefixIcon: Icon(Icons.search,
                              size: 18, color: context.dynamicTextMuted),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _sortAscending = !_sortAscending;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _sortAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 16,
                            color: AppTheme.accentBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sortAscending ? 'الأقدم' : 'الأحدث',
                            style: TextStyle(
                              color: context.dynamicTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // شرائح التصفية
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _movementFilterChip('all', 'الكل (${movements.length})'),
                    const SizedBox(width: 6),
                    _movementFilterChip(
                      'purchase',
                      'شراء (${movements.where((m) => m.type == "purchase").length})',
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(width: 6),
                    _movementFilterChip(
                      'in',
                      'إدخال لمخزن (${movements.where((m) => m.type == "in").length})',
                      color: AppTheme.incomeGreen,
                    ),
                    const SizedBox(width: 6),
                    _movementFilterChip(
                      'out',
                      'صرف واستهلاك (${movements.where((m) => m.type == "out").length})',
                      color: AppTheme.expenseRed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // قائمة الحركات
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off,
                          color: context.dynamicTextMuted, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد حركات تطابق التصفية الحالية',
                        style: TextStyle(
                          color: context.dynamicTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final m = filtered[index];
                    return _buildMovementTimelineCard(
                      context: context,
                      provider: provider,
                      product: product,
                      movement: m,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrackingFlowItem(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.dynamicTextMuted,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _movementFilterChip(String key, String label, {Color? color}) {
    final isSelected = _movementFilter == key;
    final activeColor = color ?? AppTheme.accentBlue;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _movementFilter = key),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : context.dynamicTextSecondary,
      ),
      selectedColor: activeColor,
      backgroundColor: context.dynamicSurfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? activeColor : context.dynamicCardBorder,
        ),
      ),
    );
  }

  // كرت حركة مفرد بتصميم Timeline مع تتبع الرصيد اللحظي
  Widget _buildMovementTimelineCard({
    required BuildContext context,
    required FinanceProvider provider,
    required Product product,
    required _Movement movement,
  }) {
    final isPurchase = movement.type == 'purchase';
    final isIn = movement.type == 'in';
    final isOut = movement.type == 'out';
    final isTransfer = movement.refId != null &&
        provider.inventoryTransactions.any((t) => t.id == movement.refId && t.transferId != null);

    final color = isTransfer
        ? const Color(0xFF0D9488) // Teal
        : (isPurchase
            ? AppTheme.accentBlue
            : (isIn ? AppTheme.incomeGreen : AppTheme.expenseRed));
    final colorDim = color.withValues(alpha: 0.12);
    final sign = isIn ? '+' : (isOut ? '−' : '');

    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (isPurchase
            ? Icons.shopping_bag_outlined
            : (isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded));

    final typeBadgeText = isTransfer
        ? (isIn ? 'تحويل وارد' : 'تحويل صادر')
        : (isPurchase
            ? 'فاتورة شراء'
            : (isIn ? 'توريد مخزني' : 'صرف زراعي'));

    return InkWell(
      onTap: () => _showMovementDetailSheet(
        context: context,
        provider: provider,
        product: product,
        movement: movement,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.dynamicCardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                right: BorderSide(color: color, width: 4),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorDim,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        movement.title,
                                        style: TextStyle(
                                          color: context.dynamicTextPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        typeBadgeText,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$sign${movement.quantity.formatted} ${product.unit}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 11, color: context.dynamicTextMuted),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('yyyy/MM/dd - hh:mm a', 'ar')
                                    .format(movement.date),
                                style: TextStyle(
                                  color: context.dynamicTextMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (movement.details != null &&
                              movement.details!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              movement.details!,
                              style: TextStyle(
                                color: context.dynamicTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (isPurchase && movement.unitPrice != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? AppTheme.card
                                    : AppTheme.lightCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: context.dynamicCardBorder
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'سعر الوحدة: ${movement.unitPrice!.formatted} ر.ي',
                                    style: TextStyle(
                                      color: context.dynamicTextSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (movement.total != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'الإجمالي: ${movement.total!.formatted} ر.ي',
                                      style: TextStyle(
                                        color: AppTheme.accentBlue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // شريط تتبع الرصيد التراكمي بعد العملية
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppTheme.card.withValues(alpha: 0.6)
                        : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.dynamicCardBorder.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 13, color: context.dynamicTextMuted),
                      const SizedBox(width: 6),
                      if (movement.location != null &&
                          movement.location!.isNotEmpty) ...[
                        Expanded(
                          child: Text(
                            'رصيد (${movement.location}): ${movement.runningWarehouseBalance.formatted} ${product.unit}',
                            style: TextStyle(
                              color: context.dynamicTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else if (isPurchase &&
                          movement.purchaseRemainingQuantity != null) ...[
                        Expanded(
                          child: Text(
                            'متبقي غير موزع من الفاتورة: ${movement.purchaseRemainingQuantity!.formatted} ${product.unit}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Text(
                            'تتبع حركة المخزون',
                            style: TextStyle(
                              color: context.dynamicTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.accentBlue
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          'المتوفر: ${movement.runningTotalStock.formatted} ${product.unit}',
                          style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // نافذة تفاصيل تتبع الحركة الكاملة
  void _showMovementDetailSheet({
    required BuildContext context,
    required FinanceProvider provider,
    required Product product,
    required _Movement movement,
  }) {
    final isPurchase = movement.type == 'purchase';
    final isIn = movement.type == 'in';
    final isOut = movement.type == 'out';
    final isTransfer = movement.refId != null &&
        provider.inventoryTransactions.any((t) => t.id == movement.refId && t.transferId != null);

    final color = isTransfer
        ? const Color(0xFF0D9488)
        : (isPurchase
            ? AppTheme.accentBlue
            : (isIn ? AppTheme.incomeGreen : AppTheme.expenseRed));
    final sign = isIn ? '+' : (isOut ? '−' : '');

    showModalBottomSheet(
      context: context,
      backgroundColor: context.dynamicSurfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isTransfer
                          ? Icons.swap_horiz_rounded
                          : (isPurchase
                              ? Icons.shopping_bag_outlined
                              : (isIn
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded)),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ctx.dynamicTextPrimary,
                          ),
                        ),
                        Text(
                          DateFormat('yyyy/MM/dd - hh:mm a', 'ar')
                              .format(movement.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: ctx.dynamicTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$sign${movement.quantity.formatted} ${product.unit}',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(ctx, 'الصنف:', product.name),
              _buildDetailRow(ctx, 'الفئة:', product.category),
              if (isTransfer)
                _buildDetailRow(ctx, 'طبيعة العملية:', isIn ? 'تحويل كميات واردة' : 'تحويل كميات صادرة'),
              if (movement.location != null)
                _buildDetailRow(ctx, 'المخزن المعني:', movement.location!),
              if (movement.plotName != null)
                _buildDetailRow(ctx, 'الموضع الزراعي:', movement.plotName!),
              if (movement.eventType != null)
                _buildDetailRow(ctx, 'نوع العملية الزراعية:', movement.eventType!),
              if (movement.supplierName != null)
                _buildDetailRow(ctx, 'المورد:', movement.supplierName!),
              if (movement.invoiceNumber != null && movement.invoiceNumber!.isNotEmpty)
                _buildDetailRow(ctx, 'رقم الفاتورة:', movement.invoiceNumber!),
              if (movement.unitPrice != null)
                _buildDetailRow(ctx, 'سعر الوحدة:', '${movement.unitPrice!.formatted} ر.ي'),
              if (movement.total != null)
                _buildDetailRow(ctx, 'الإجمالي:', '${movement.total!.formatted} ر.ي'),
              if (movement.details != null && movement.details!.isNotEmpty)
                _buildDetailRow(ctx, 'الملاحظات:', movement.details!),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ctx.isDark ? AppTheme.card : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ctx.dynamicCardBorder),
                ),
                child: Column(
                  children: [
                    if (movement.location != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('رصيد المخزن بعد العملية:',
                              style: TextStyle(
                                  color: ctx.dynamicTextSecondary, fontSize: 12)),
                          Text(
                            '${movement.runningWarehouseBalance.formatted} ${product.unit}',
                            style: TextStyle(
                              color: ctx.dynamicTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('إجمالي رصيد المخازن + غير الموزع:',
                            style: TextStyle(
                                color: ctx.dynamicTextSecondary, fontSize: 12)),
                        Text(
                          '${movement.runningTotalStock.formatted} ${product.unit}',
                          style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (movement.refId != null &&
                  provider.inventoryTransactions.any((t) => t.id == movement.refId)) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.expenseRed,
                      side: BorderSide(color: AppTheme.expenseRed),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(
                      isTransfer ? 'إلغاء عملية التحويل واسترجاع الكميات' : 'حذف الحركة المخزنية وتصحيح الرصيد',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (diagCtx) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed),
                              const SizedBox(width: 8),
                              Text(isTransfer ? 'إلغاء التحويل' : 'حذف الحركة'),
                            ],
                          ),
                          content: Text(
                            isTransfer
                                ? 'هل أنت متأكد من إلغاء عملية التحويل بالكامل؟ سيتم استرجاع الكمية إلى المخزن المصدر وخصمها من المخزن المستلم.'
                                : 'هل أنت متأكد من حذف هذه الحركة؟ سيتم عكس تأثيرها على رصيد المخزن تلقائياً (${isIn ? 'خصم' : 'إضافة'} ${movement.quantity.formatted} ${product.unit}).',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(diagCtx),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.expenseRed,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(diagCtx);
                                provider.deleteInventoryTransaction(movement.refId!);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تم حذف الحركة وتحديث رصيد المخزن بنجاح'),
                                    backgroundColor: AppTheme.incomeGreen,
                                  ),
                                );
                              },
                              child: const Text('نعم، احذف'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.dynamicTextMuted, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: context.dynamicTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
