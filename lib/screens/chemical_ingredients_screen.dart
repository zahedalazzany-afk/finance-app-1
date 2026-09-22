import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/data_export_import_button.dart';

class ChemicalIngredientsScreen extends StatefulWidget {
  const ChemicalIngredientsScreen({super.key});

  @override
  State<ChemicalIngredientsScreen> createState() =>
      _ChemicalIngredientsScreenState();
}

class _ChemicalIngredientsScreenState extends State<ChemicalIngredientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'الكل'; // 'الكل', 'حشري', 'فطري'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String type) {
    if (type == 'حشري') {
      return Colors.orange.shade800;
    } else {
      return AppTheme.incomeGreen;
    }
  }

  IconData _getTypeIcon(String type) {
    if (type == 'حشري') {
      return Icons.pest_control_outlined;
    } else {
      return Icons.eco_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allIngredients = provider.chemicalIngredients;

    final insecticidesCount =
        allIngredients.where((i) => i.type == 'حشري').length;
    final fungicidesCount =
        allIngredients.where((i) => i.type == 'فطري').length;

    // Filter ingredients
    final filtered = allIngredients.where((item) {
      if (_filterType != 'الكل' && item.type != _filterType) return false;
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final nameMatches = item.name.toLowerCase().contains(q);
      final notesMatch =
          item.notes != null && item.notes!.toLowerCase().contains(q);
      return nameMatches || notesMatch;
    }).toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'دليل المواد الفعالة',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          DataExportImportButton(
            label: 'المواد الفعالة',
            buildRows: () => provider.chemicalIngredients
                .map((e) => e.toJson())
                .toList(),
            csvHeaders: const ['الاسم', 'النوع', 'ملاحظات'],
            csvKeys: const ['name', 'type', 'notes'],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final item = ChemicalIngredient.fromJson(row);
                  if (provider.chemicalIngredients
                      .any((e) => e.id == item.id)) continue;
                  provider.addChemicalIngredient(item);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero Summary Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.12),
                  context.dynamicCardBg,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.dynamicCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.science_rounded,
                      color: AppTheme.accentBlue, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دليل المواد الفعالة والتركيبات',
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$insecticidesCount مادة حشرية · $fungicidesCount مادة فطرية مسجلة',
                        style: TextStyle(
                          color: context.dynamicTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.dynamicSurfaceBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.dynamicCardBorder),
                  ),
                  child: Column(
                    children: [
                      Text('المواد',
                          style: TextStyle(
                              color: context.dynamicTextMuted, fontSize: 10)),
                      Text(
                        '${allIngredients.length}',
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
                hintText: 'بحث باسم المادة الفعالة أو الملاحظات...',
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

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('الكل', 'الكل (${allIngredients.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'حشري',
                  'مبيد حشري ($insecticidesCount)',
                  color: Colors.orange.shade800,
                  icon: Icons.pest_control_outlined,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'فطري',
                  'مبيد فطري ($fungicidesCount)',
                  color: AppTheme.incomeGreen,
                  icon: Icons.eco_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Ingredients List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined,
                              color: context.dynamicTextMuted, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty || _filterType != 'الكل'
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'لا توجد مواد فعالة مسجلة حتى الآن',
                            style: TextStyle(
                              color: context.dynamicTextSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أضف أول مادة فعالة بالضغط على الزر بالأسفل',
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
                      final item = filtered[index];
                      return _buildIngredientCard(context, provider, item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, provider),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مادة جديدة',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildFilterChip(
    String type,
    String label, {
    Color? color,
    IconData? icon,
  }) {
    final isSelected = _filterType == type;
    final activeColor = color ?? AppTheme.accentBlue;

    return ChoiceChip(
      avatar: icon != null
          ? Icon(icon,
              size: 16,
              color: isSelected ? activeColor : context.dynamicTextSecondary)
          : null,
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
      onSelected: (_) => setState(() => _filterType = type),
    );
  }

  Widget _buildIngredientCard(
    BuildContext context,
    FinanceProvider provider,
    ChemicalIngredient item,
  ) {
    final typeColor = _getTypeColor(item.type);
    final typeIcon = _getTypeIcon(item.type);

    // Products containing this ingredient
    final linkedProductLinks = provider.productIngredients
        .where((pi) => pi.ingredientId == item.id)
        .toList();
    final linkedProducts = linkedProductLinks
        .map((link) =>
            provider.products.firstWhereOrNull((p) => p.id == link.productId))
        .whereType<Product>()
        .toList();

    // Pests treated by this ingredient
    final linkedPestLinks = provider.pestIngredients
        .where((pi) => pi.ingredientId == item.id)
        .toList();
    final linkedPests = linkedPestLinks
        .map((link) =>
            provider.pests.firstWhereOrNull((p) => p.id == link.pestId))
        .whereType<Pest>()
        .toList();

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon, Name, Type Pill, Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.type == 'حشري' ? 'مبيد حشري' : 'مبيد فطري',
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: context.dynamicTextSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'تعديل',
                      onPressed: () =>
                          _showForm(context, provider, existing: item),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.expenseRed),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'حذف',
                      onPressed: () => _confirmDelete(context, provider, item),
                    ),
                  ],
                ),
              ],
            ),

            // Notes Section
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.dynamicSurfaceBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.dynamicCardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded,
                        size: 16, color: context.dynamicTextMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.notes!,
                        style: TextStyle(
                          color: context.dynamicTextSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Linked Products & Linked Pests
            if (linkedProducts.isNotEmpty || linkedPests.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Linked Products
              if (linkedProducts.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 14, color: AppTheme.accentBlue),
                    const SizedBox(width: 6),
                    Text(
                      'منتجات بالمخزن تحتوي هذه المادة (${linkedProducts.length}):',
                      style: TextStyle(
                        color: context.dynamicTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: linkedProducts.map((p) {
                    final stock = provider.totalStockForProduct(p.id);
                    final isOutOfStock = stock <= 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${p.name} (${stock.formatted} ${p.unit}${isOutOfStock ? ' - نافد' : ''})',
                        style: TextStyle(
                          color: isOutOfStock
                              ? AppTheme.expenseRed
                              : AppTheme.accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Linked Pests
              if (linkedPests.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.bug_report_outlined,
                        size: 14, color: Colors.orange.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'تكافح الآفات المسجلة (${linkedPests.length}):',
                      style: TextStyle(
                        color: context.dynamicTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: linkedPests.map((pest) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pest.name,
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, FinanceProvider provider,
      {ChemicalIngredient? existing}) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final notesController =
        TextEditingController(text: existing?.notes ?? '');
    String type = existing?.type ?? chemicalIngredientTypes.first;
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
                  existing == null ? 'إضافة مادة فعالة جديدة' : 'تعديل بيانات المادة',
                  style: TextStyle(
                    color: sheetContext.dynamicTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  style: TextStyle(color: sheetContext.dynamicTextPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: sheetContext.dynamicSurfaceBg,
                    labelText: 'اسم المادة الفعالة *',
                    hintText: 'مثال: أبامكتين، كلوربيريفوس...',
                    prefixIcon: const Icon(Icons.science_outlined),
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
                      v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المادة' : null,
                ),
                const SizedBox(height: 14),
                SheetDropdown<String>(
                  label: 'تصنيف المادة',
                  icon: Icons.category_outlined,
                  value: type,
                  items: chemicalIngredientTypes
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t == 'حشري'
                              ? 'حشري (مبيد حشري)'
                              : 'فطري (مبيد فطري)')))
                      .toList(),
                  onChanged: (v) => setSheetState(() => type = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: sheetContext.dynamicTextPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: sheetContext.dynamicSurfaceBg,
                    labelText: 'ملاحظات وتوصيات الاستخدام',
                    hintText: 'ملاحظات علمية، طريقة التأثير، إلخ (اختياري)',
                    prefixIcon: const Icon(Icons.notes_outlined),
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
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (existing != null) {
                      existing
                        ..name = nameController.text.trim()
                        ..type = type
                        ..notes = notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim();
                      provider.updateChemicalIngredient(existing);
                    } else {
                      provider.addChemicalIngredient(ChemicalIngredient(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        type: type,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ));
                    }
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    existing == null ? 'إضافة المادة' : 'حفظ التعديلات',
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
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider,
      ChemicalIngredient item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف المادة الفعالة',
            style: TextStyle(
                color: context.dynamicTextPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
            'سيتم إزالة المادة من الآفات والمنتجات المرتبطة بها. هل تريد حذف "${item.name}"؟',
            style: TextStyle(color: context.dynamicTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.deleteChemicalIngredient(item.id);
              Navigator.pop(context);
            },
            child:
                Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
