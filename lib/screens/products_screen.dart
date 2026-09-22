import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';
import 'product_form_screen.dart';
import 'product_movements_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _filterCategory = 'الكل';
  bool _onlyLowStock = false;
  String _searchQuery = '';
  String _sortBy = 'value'; // 'value', 'stock', 'name'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'مبيدات':
        return Colors.purple;
      case 'سماد':
        return AppTheme.incomeGreen;
      case 'بذور':
        return Colors.amber.shade700;
      case 'أدوات':
        return Colors.blueGrey;
      default:
        return AppTheme.accentBlue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'مبيدات':
        return Icons.science_outlined;
      case 'سماد':
        return Icons.eco_outlined;
      case 'بذور':
        return Icons.grass_outlined;
      case 'أدوات':
        return Icons.handyman_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  void _confirmDelete(
      BuildContext context, FinanceProvider provider, Product product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف المنتج',
            style: TextStyle(
                color: context.dynamicTextPrimary,
                fontWeight: FontWeight.w700)),
        content: Text('هل أنت متأكد من حذف "${product.name}"؟',
            style: TextStyle(color: context.dynamicTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (provider.deleteProduct(product.id)) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف المنتج لأنه مستخدم في المخزون أو المشتريات أو الحركات.')));
              }
            },
            child:
                Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allProducts = provider.products;

    final lowStockProducts = allProducts
        .where((p) =>
            p.minStock > 0 && provider.totalStockForProduct(p.id) <= p.minStock)
        .toList();

    // Filter products
    var filtered = allProducts.where((p) {
      final stock = provider.totalStockForProduct(p.id);
      if (_onlyLowStock && (p.minStock <= 0 || stock > p.minStock)) {
        return false;
      }
      if (_filterCategory != 'الكل' && p.category != _filterCategory) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final nameMatches = p.name.toLowerCase().contains(q);
        final catMatches = p.category.toLowerCase().contains(q);
        final unitMatches = p.unit.toLowerCase().contains(q);
        return nameMatches || catMatches || unitMatches;
      }
      return true;
    }).toList();

    // Sort products
    if (_sortBy == 'value') {
      filtered.sort((a, b) => (provider.totalStockForProduct(b.id) * b.purchasePrice)
          .compareTo(provider.totalStockForProduct(a.id) * a.purchasePrice));
    } else if (_sortBy == 'stock') {
      filtered.sort((a, b) => provider.totalStockForProduct(a.id).compareTo(provider.totalStockForProduct(b.id)));
    } else if (_sortBy == 'name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    final totalValue = filtered.fold<double>(
        0, (sum, p) => sum + (provider.totalStockForProduct(p.id) * p.purchasePrice));
    final allTotalValue = allProducts.fold<double>(
        0, (sum, p) => sum + (provider.totalStockForProduct(p.id) * p.purchasePrice));

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'دليل ومخزون المنتجات',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          DataExportImportButton(
            label: 'المنتجات',
            buildRows: () =>
                provider.products.map((e) => e.toJson()).toList(),
            csvHeaders: const [
              'الاسم',
              'التصنيف',
              'الوحدة',
              'سعر الشراء',
              'أقصى سعر شراء',
              'سعر البيع',
              'المخزون الحالي',
              'حد أدنى',
              'نوع العبوة',
              'حجم العبوة',
              'وحدة الاستخدام',
            ],
            csvKeys: const [
              'name',
              'category',
              'unit',
              'purchasePrice',
              'maxPurchasePrice',
              'salePrice',
              'currentStock',
              'minStock',
              'packageType',
              'packageSize',
              'usageUnit',
            ],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final product = Product.fromJson(row);
                  if (provider.products.any((e) => e.id == product.id)) continue;
                  provider.addProduct(product);
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.inventory_2_rounded,
                              color: AppTheme.accentBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي قيمة المنتجات بالمخزن',
                              style: TextStyle(
                                color: context.dynamicTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${allTotalValue.formatted} ر.ي',
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
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('الأصناف',
                              style: TextStyle(
                                  color: context.dynamicTextMuted,
                                  fontSize: 10)),
                          Text(
                            '${allProducts.length}',
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (lowStockProducts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _onlyLowStock = !_onlyLowStock;
                        if (_onlyLowStock) _filterCategory = 'الكل';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _onlyLowStock
                            ? AppTheme.expenseRed
                            : AppTheme.expenseRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: _onlyLowStock
                                    ? Colors.white
                                    : AppTheme.expenseRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${lowStockProducts.length} منتجات وصلت لحد الخطر والنفاد!',
                                style: TextStyle(
                                  color: _onlyLowStock
                                      ? Colors.white
                                      : AppTheme.expenseRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _onlyLowStock ? 'عرض الكل' : 'تصفية 👈',
                            style: TextStyle(
                              color: _onlyLowStock
                                  ? Colors.white
                                  : AppTheme.expenseRed,
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

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.dynamicCardBg,
                hintText: 'بحث باسم المنتج، التصنيف، أو وحدة القياس...',
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

          // Category Filters & Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['الكل', ...chemicalProductCategories].map((cat) {
                        final isSelected =
                            _filterCategory == cat && !_onlyLowStock;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor:
                                AppTheme.accentBlue.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontFamily: 'Cairo',
                              color: isSelected
                                  ? AppTheme.accentBlue
                                  : context.dynamicTextSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.accentBlue
                                  : context.dynamicCardBorder,
                            ),
                            backgroundColor: context.dynamicCardBg,
                            onSelected: (_) {
                              setState(() {
                                _filterCategory = cat;
                                _onlyLowStock = false;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Sort menu button
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
                      value: 'value',
                      child: Text(
                        'الأعلى قيمة مالية',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'value'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'value'
                              ? AppTheme.accentBlue
                              : context.dynamicTextPrimary,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'stock',
                      child: Text(
                        'الأقل كمية مخزون',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'stock'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'stock'
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

          // Count & active value strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} صنف معروض',
                  style: TextStyle(
                    color: context.dynamicTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'قيمة المعروض: ${totalValue.formatted} ر.ي',
                  style: TextStyle(
                    color: context.dynamicTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Product List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              color: context.dynamicTextMuted, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'لا توجد منتجات مسجلة في هذا القسم',
                            style: TextStyle(
                              color: context.dynamicTextSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أضف منتجاً جديداً بالضغط على الزر بالأسفل',
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
                      final product = filtered[index];
                      return _buildProductCard(context, provider, product);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        ),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('منتج جديد',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context, FinanceProvider provider, Product product) {
    final totalStock = provider.totalStockForProduct(product.id);
    final inWarehouses = provider.warehouseStockForProduct(product.id);
    final undistributed = provider.undistributedStockForProduct(product.id);
    final isLow =
        product.minStock > 0 && totalStock <= product.minStock;
    final isOutOfStock = totalStock <= 0;
    final stockValue = totalStock * product.purchasePrice;
    final catColor = _getCategoryColor(product.category);
    final catIcon = _getCategoryIcon(product.category);

    // Linked chemical ingredients
    final ingredients = provider.productIngredientsFor(product.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (!isOutOfStock && isLow)
              ? Colors.amber.shade700
              : context.dynamicCardBorder,
          width: (!isOutOfStock && isLow) ? 1.5 : 1.0,
        ),
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
          MaterialPageRoute(
            builder: (_) => ProductMovementsScreen(product: product),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category Badge, Product Name, and Actions Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(catIcon, color: catColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                product.category,
                                style: TextStyle(
                                  color: catColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isOutOfStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.expenseRed.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚠ نافد من المخزن',
                                  style: TextStyle(
                                    color: AppTheme.expenseRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            else if (isLow)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚠ قارب على النفاد',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Quantity Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${totalStock.formatted} ${product.unit}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isOutOfStock
                              ? AppTheme.expenseRed
                              : isLow
                                  ? Colors.amber.shade800
                                  : AppTheme.accentBlue,
                        ),
                      ),
                      if (product.isPackaged && product.packageSize > 0)
                        Text(
                          '= ${(totalStock * product.packageSize).formatted} ${product.usageUnit ?? ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.dynamicTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (undistributed > 0 && inWarehouses > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'المخازن: ${inWarehouses.formatted} · غير موزع: ${undistributed.formatted}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (undistributed > 0 && inWarehouses == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'غير موزع من الفواتير',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepOrange.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    color: context.dynamicCardBg,
                    icon: Icon(Icons.more_vert,
                        color: context.dynamicTextMuted, size: 20),
                    onSelected: (v) {
                      if (v == 'movements') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductMovementsScreen(product: product),
                          ),
                        );
                      } else if (v == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductFormScreen(product: product),
                          ),
                        );
                      } else if (v == 'delete') {
                        _confirmDelete(context, provider, product);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'movements',
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz, size: 18),
                            SizedBox(width: 8),
                            Text('سجل الحركات'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('تعديل البيانات'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete,
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

              // Active ingredients chips if any
              if (ingredients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ingredients.map((link) {
                    final ing = provider.chemicalIngredients
                        .firstWhereOrNull((i) => i.id == link.ingredientId);
                    if (ing == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.science,
                              size: 12, color: AppTheme.accentBlue),
                          const SizedBox(width: 4),
                          Text(
                            ing.name +
                                (link.concentration != null &&
                                        link.concentration! > 0
                                    ? ' (${link.concentration!.plain}%)'
                                    : ''),
                            style: TextStyle(
                              color: AppTheme.accentBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Footer: Pricing & Valuation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'شراء: ${product.purchasePrice.formatted} ر.ي',
                        style: TextStyle(
                          color: context.dynamicTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (product.maxPurchasePrice > 0 &&
                          product.maxPurchasePrice != product.purchasePrice)
                        Text(
                          ' · أقصى: ${product.maxPurchasePrice.formatted}',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      if (product.minStock > 0)
                        Text(
                          ' · حد أدنى: ${product.minStock.formatted}',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'إجمالي: ${stockValue.formatted} ر.ي',
                    style: TextStyle(
                      color: context.dynamicTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
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
}
