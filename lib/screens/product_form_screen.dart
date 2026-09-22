import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class _IngredientEntry {
  String? ingredientId;
  final TextEditingController concentrationController =
      TextEditingController();

  double get concentration =>
      double.tryParse(concentrationController.text) ?? 0;

  void dispose() => concentrationController.dispose();
}

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _maxPurchasePriceController;
  late final TextEditingController _minStockController;
  late String _selectedCategory;
  late String _selectedUnit;
  late String _packageType;
  late final TextEditingController _packageSizeController;
  late String? _usageUnit;
  final List<_IngredientEntry> _ingredientEntries = [];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.product?.name ?? '');
    _purchasePriceController = TextEditingController(
        text: widget.product?.purchasePrice.toString() ?? '');
    _maxPurchasePriceController = TextEditingController(
        text: widget.product?.maxPurchasePrice.toString() ?? '');
    _minStockController = TextEditingController(
        text: widget.product?.minStock.toString() ?? '0');
    _selectedCategory =
        widget.product?.category ?? chemicalProductCategories.first;
    _selectedUnit = widget.product?.unit ?? chemicalProductUnits.first;
    _packageType = widget.product?.packageType ?? 'بدون';
    _packageSizeController = TextEditingController(
        text: widget.product?.packageSize.toString() ?? '');
    _usageUnit = widget.product?.usageUnit;
    if (widget.product != null) {
      final provider = context.read<FinanceProvider>();
      for (final link in provider.productIngredientsFor(widget.product!.id)) {
        final entry = _IngredientEntry()
          ..ingredientId = link.ingredientId;
        if (link.concentration != null) {
          entry.concentrationController.text = link.concentration.toString();
        }
        _ingredientEntries.add(entry);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _maxPurchasePriceController.dispose();
    _minStockController.dispose();
    _packageSizeController.dispose();
    for (final entry in _ingredientEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _selectedCategory,
      unit: _selectedUnit,
      purchasePrice: double.tryParse(_purchasePriceController.text.trim()) ?? 0,
      maxPurchasePrice: double.tryParse(_maxPurchasePriceController.text.trim()) ?? 0,
      currentStock: widget.product?.currentStock ?? 0,
      minStock: double.tryParse(_minStockController.text.trim()) ?? 0,
      packageType: _packageType == 'بدون' ? null : _packageType,
      packageSize: _packageType == 'بدون'
          ? 0
          : (double.tryParse(_packageSizeController.text.trim()) ?? 0),
      usageUnit: _packageType == 'بدون' ? null : _usageUnit,
    );

    if (widget.product == null) {
      provider.addProduct(product);
    } else {
      provider.updateProduct(product);
    }

    final entries = _ingredientEntries
        .where((e) => e.ingredientId != null)
        .map((e) => {
              'ingredientId': e.ingredientId!,
              'concentration': e.concentration,
            })
        .toList();
    provider.saveProductIngredients(product.id, entries);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final provider = context.watch<FinanceProvider>();
    final ingredients = provider.chemicalIngredients;

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(title: Text(isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج *',
                  hintText: 'اسم المنتج *',
                  prefixIcon: Icon(Icons.inventory),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'أدخل اسم المنتج' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  prefixIcon: Icon(Icons.category),
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                items: chemicalProductCategories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'اقل قيمة شراء',
                        hintText: 'اقل قيمة شراء',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'رقم غير صحيح';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxPurchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'اكبر سعر شراء',
                        hintText: 'اكبر سعر شراء (اختياري)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'رقم غير صحيح';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'الوحدة',
                  prefixIcon: Icon(Icons.straighten),
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                items: chemicalProductUnits
                    .map((u) =>
                        DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUnit = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minStockController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للمخزون *',
                  hintText: 'الحد الأدنى للمخزون (تنبيه عند النقص)',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (v == null || n == null || n < 0) return 'رقم غير صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.inventory, color: AppTheme.accentBlue),
                  const SizedBox(width: 8),
                  Text('التعبئة',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  'للسوائل تُدار كعلب وتقاس بالمل، وللَّبودرة تُدار كأكياس وتقاس بالغرام. إن لم تكن معبأة اختر (بدون).',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: ['بدون', 'علبة', 'كيس'].map((t) {
                  final selected = _packageType == t;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: selected,
                      selectedColor: AppTheme.accentBlueDim,
                      checkmarkColor: AppTheme.accentBlue,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.accentBlue
                            : AppTheme.textSecondary,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                          color: selected
                              ? AppTheme.accentBlue
                              : AppTheme.cardBorder),
                      onSelected: (_) => setState(() {
                        _packageType = t;
                        _usageUnit = t == 'علبة'
                            ? 'مل'
                            : (t == 'كيس' ? 'غرام' : null);
                      }),
                    ),
                  );
                }).toList(),
              ),
              if (_packageType != 'بدون') ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _packageSizeController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'حجم ال${_packageType == 'علبة' ? 'علبة' : 'كيس'} الواحد',
                          hintText: 'مثال: 500',
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (v == null || n == null || n <= 0) {
                            return 'أدخل الحجم';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        value: _usageUnit,
                        decoration: const InputDecoration(
                          labelText: 'وحدة القياس',
                          prefixIcon: Icon(Icons.speed),
                        ),
                        style: TextStyle(color: AppTheme.textPrimary),
                        items: ['مل', 'غرام']
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _usageUnit = v!),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.science, color: AppTheme.accentBlue),
                  const SizedBox(width: 8),
                  Text('المواد الفعالة',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              if (ingredients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppTheme.textMuted, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا توجد مواد فعالة بعد. أضفها أولاً من شاشة المواد الفعالة',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      setState(
                          () => _ingredientEntries.add(_IngredientEntry()));
                    },
                    icon: Icon(Icons.add_circle,
                        color: AppTheme.accentBlue, size: 30),
                    tooltip: 'إضافة مادة',
                  ),
                ),
                if (_ingredientEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Center(
                      child: Text('اضغط + لإضافة مادة فعالة',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                ...List.generate(_ingredientEntries.length, (index) {
                  final entry = _ingredientEntries[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: entry.ingredientId,
                                isExpanded: true,
                                hint: Text('اختر المادة الفعالة',
                                    style: TextStyle(
                                        color: AppTheme.textMuted)),
                                decoration: const InputDecoration(
                                  labelText: 'المادة الفعالة',
                                  prefixIcon: Icon(Icons.science),
                                ),
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13),
                                items: ingredients.map((i) {
                                  final isInsecticide = i.type == 'حشري';
                                  return DropdownMenuItem(
                                    value: i.id,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isInsecticide
                                              ? Icons.bug_report
                                              : Icons.eco,
                                          size: 16,
                                          color: isInsecticide
                                              ? AppTheme.expenseRed
                                              : AppTheme.incomeGreen,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(i.name,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => entry.ingredientId = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  entry.dispose();
                                  _ingredientEntries.removeAt(index);
                                });
                              },
                              icon: Icon(Icons.delete,
                                  color: AppTheme.expenseRed, size: 24),
                              tooltip: 'حذف',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: entry.concentrationController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'التركيز %',
                            hintText: 'التركيز % (اختياري)',
                            prefixIcon: Icon(Icons.percent),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: Text(isEditing ? 'تعديل المنتج' : 'إضافة المنتج'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
