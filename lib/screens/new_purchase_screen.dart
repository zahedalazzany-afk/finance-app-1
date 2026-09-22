import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key, this.existing});

  final Purchase? existing;

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  Partner? _selectedSupplier;
  final List<_PurchaseItemEntry> _items = [];
  final _paidAmountController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _invoiceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _paymentWalletId;
  bool _loadedExisting = false;
  final _fundingKey = GlobalKey<FundingPickerState>();
  List<ExpenseAllocation> _funding = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final existing = widget.existing;
    if (existing != null && !_loadedExisting) {
      _loadedExisting = true;
      final provider = context.read<FinanceProvider>();
      _selectedSupplier = provider.partners
          .firstWhereOrNull((p) => p.id == existing.supplierId);
      _selectedDate = existing.date;
      _discountController.text = existing.discount > 0 ? existing.discount.plain : '0';
      _paidAmountController.text = existing.paidAmount.toString();
      _notesController.text = existing.notes ?? '';
      _invoiceNumberController.text = existing.invoiceNumber ?? '';
      _paymentWalletId =
          provider.moneyMovements.firstWhereOrNull((m) => m.purchaseId == existing.id)
              ?.walletId;
      final items = provider.purchaseItemsFor(existing.id);
      for (final item in items) {
        final entry = _PurchaseItemEntry();
        entry.selectedProduct =
            provider.products.firstWhereOrNull((p) => p.id == item.productId);
        entry.quantityController.text = item.quantity.toString();
        entry.unitPriceController.text = item.unitPrice.toString();
        _items.add(entry);
      }
      setState(() {});
    } else if (existing == null && !_loadedExisting) {
      _loadedExisting = true;
      _addItem();
    }
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _discountController.dispose();
    _invoiceNumberController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + item.total);
  double get _discount => tryParseFlexible(_discountController.text) ?? 0;
  double get _netAmount => (_totalAmount - _discount).clamp(0.0, double.infinity);
  double get _paidAmount =>
      tryParseFlexible(_paidAmountController.text) ?? 0;

  void _addItem() {
    setState(() {
      _items.add(_PurchaseItemEntry());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  String? _priceWarning(_PurchaseItemEntry entry) {
    final p = entry.selectedProduct;
    if (p == null) return null;
    final price = entry.unitPrice;
    if (price <= 0) return null;
    if (price < p.purchasePrice) {
      return 'أقل من اقل سعر شراء (${p.purchasePrice.formatted} ر.ي)';
    }
    if (p.maxPurchasePrice > 0 && price > p.maxPurchasePrice) {
      return 'أعلى من اكبر سعر شراء (${p.maxPurchasePrice.formatted} ر.ي)';
    }
    return null;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: AppTheme.theme.copyWith(
          colorScheme: ColorScheme.dark(
              primary: AppTheme.accentBlue, surface: AppTheme.card),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSupplierPicker(List<Partner> suppliers) {
    String searchQuery = '';
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
              final filtered = searchQuery.isEmpty
                  ? suppliers
                  : suppliers
                      .where((s) => s.name.contains(searchQuery))
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
                          style:
                              TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'بحث عن مورد...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) =>
                              setSheetState(() => searchQuery = v),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('لا يوجد نتائج',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final s = filtered[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.accentBlueDim,
                                  child: Icon(Icons.business,
                                      color: AppTheme.accentBlue,
                                      size: 20),
                                ),
                                title: Text(s.name,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary)),
                                subtitle: s.phone != null &&
                                        s.phone!.isNotEmpty
                                    ? Text(s.phone!,
                                        style: const TextStyle(
                                            fontSize: 12))
                                    : null,
                                onTap: () {
                                  setState(
                                      () => _selectedSupplier = s);
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

  List<Product> _availableProducts(
      int currentIndex, List<Product> allProducts) {
    final selectedIds = _items
        .asMap()
        .entries
        .where((e) =>
            e.key != currentIndex && e.value.selectedProduct != null)
        .map((e) => e.value.selectedProduct!.id)
        .toSet();
    return allProducts.where((p) => !selectedIds.contains(p.id)).toList();
  }

  void _showProductPicker(int itemIndex, List<Product> available) {
    String searchQuery = '';
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
              final filtered = searchQuery.isEmpty
                  ? available
                  : available
                      .where((p) => p.name.contains(searchQuery))
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
                          style:
                              TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'بحث عن منتج...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) =>
                              setSheetState(() => searchQuery = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('لا يوجد نتائج',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final p = filtered[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.accentBlueDim,
                                  child: Icon(Icons.inventory,
                                      color: AppTheme.accentBlue,
                                      size: 20),
                                ),
                                title: Text(p.name,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(p.unit,
                                    style: const TextStyle(fontSize: 12)),
                                trailing: Text(
                                  p.maxPurchasePrice > 0
                                      ? '${p.purchasePrice.formatted} - ${p.maxPurchasePrice.formatted} ر.ي'
                                      : 'اقل: ${p.purchasePrice.formatted} ر.ي',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.accentBlue),
                                ),
                                onTap: () {
                                  setState(() {
                                    _items[itemIndex]
                                        .selectedProduct = p;
                                    _items[itemIndex]
                                        .unitPriceController
                                        .text = p.purchasePrice.toString();
                                  });
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

  Future<void> _save() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('اختر المورد'), backgroundColor: AppTheme.expenseRed),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('أضف صنفاً واحداً على الأقل'),
            backgroundColor: AppTheme.expenseRed),
      );
      return;
    }
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('اختر المنتج في الصنف ${i + 1}'),
              backgroundColor: AppTheme.expenseRed),
        );
        return;
      }
    }

    final total = _totalAmount;
    final discount = _discount;
    final net = _netAmount;
    final paid = _paidAmount;

    if (discount > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('مبلغ الخصم لا يمكن أن يتجاوز إجمالي الفاتورة'),
            backgroundColor: AppTheme.expenseRed),
      );
      return;
    }

    if (paid > 0 && _paymentWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('اختر المحفظة التي دُفع منها المبلغ'),
            backgroundColor: AppTheme.expenseRed),
      );
      return;
    }
    if (paid > 0) {
      final funding = _fundingKey.currentState?.allocations ?? [];
      final sumFunding = funding.fold(0.0, (s, a) => s + a.amount);
      if ((sumFunding - paid).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'مجموع التمويل يجب أن يساوي المبلغ المدفوع (${paid.formatted} ر.ي)'),
              backgroundColor: AppTheme.expenseRed),
        );
        return;
      }
      if (!(_fundingKey.currentState?.validate() ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تحقق من تمويل المبلغ المدفوع من دفعات الاستلام'),
              backgroundColor: AppTheme.expenseRed),
        );
        return;
      }
      _funding = funding;
    } else {
      _funding = [];
    }
    String paymentType;
    if (paid >= net - 0.01) {
      paymentType = 'cash';
    } else if (paid > 0) {
      paymentType = 'partial';
    } else {
      paymentType = 'debt';
    }

    final entries = _items
        .map((entry) => {
              'productId': entry.selectedProduct!.id,
              'quantity': entry.countQuantity,
              'unitPrice': entry.unitPrice,
            })
        .toList();

    final existing = widget.existing;
    if (existing != null) {
      final updated = Purchase(
        id: existing.id,
        supplierId: _selectedSupplier!.id,
        date: _selectedDate,
        totalAmount: total,
        discount: discount,
        paidAmount: paid,
        paymentType: paymentType,
        invoiceNumber: _invoiceNumberController.text.trim().isNotEmpty
            ? _invoiceNumberController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: existing.createdAt,
      );
      context
          .read<FinanceProvider>()
          .updatePurchase(updated, entries,
              paymentWalletId: _paymentWalletId, funding: _funding);
    } else {
      final purchase = Purchase(
        id: const Uuid().v4(),
        supplierId: _selectedSupplier!.id,
        date: _selectedDate,
        totalAmount: total,
        discount: discount,
        paidAmount: paid,
        paymentType: paymentType,
        invoiceNumber: _invoiceNumberController.text.trim().isNotEmpty
            ? _invoiceNumberController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
      context
          .read<FinanceProvider>()
          .addPurchase(purchase, entries,
              paymentWalletId: _paymentWalletId, funding: _funding);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(existing != null ? 'تم تعديل الفاتورة' : 'تم إنشاء فاتورة الشراء'),
            backgroundColor: AppTheme.incomeGreen),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final suppliers = provider.partners
        .where((p) => p.roles.contains('supplier'))
        .toList();
    final allProducts = provider.products;

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
          title: Text(widget.existing != null
              ? 'تعديل فاتورة شراء'
              : 'فاتورة شراء جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: suppliers.isEmpty
                  ? null
                  : () => _showSupplierPicker(suppliers),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'المورد *',
                  prefixIcon: const Icon(Icons.business),
                  suffixIcon: Icon(Icons.arrow_drop_down,
                      color: AppTheme.textSecondary),
                ),
                child: Text(
                  _selectedSupplier != null
                      ? _selectedSupplier!.name
                      : suppliers.isEmpty
                          ? 'لا يوجد موردون، أضف شخصاً بدور مورد أولاً'
                          : 'اختر المورد',
                  style: TextStyle(
                    color: _selectedSupplier != null
                        ? AppTheme.textPrimary
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'التاريخ',
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy', 'ar').format(_selectedDate),
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invoiceNumberController,
              keyboardType: TextInputType.text,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'رقم الفاتورة الورقية',
                hintText: 'الرقم الموجود على فاتورة المورد',
                prefixIcon: Icon(Icons.receipt_long),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأصناف',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _addItem,
                  icon: Icon(Icons.add_circle,
                      color: AppTheme.accentBlue, size: 30),
                  tooltip: 'إضافة صنف',
                ),
              ],
            ),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Center(
                  child: Text('اضغط + لإضافة صنف',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
              ),
            ...List.generate(_items.length, (index) {
              final entry = _items[index];
              final available =
                  _availableProducts(index, allProducts);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                        Text('صنف ${index + 1}',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (_items.length > 1)
                          IconButton(
                            onPressed: () => _removeItem(index),
                            icon: Icon(Icons.delete,
                                color: AppTheme.expenseRed),
                            tooltip: 'حذف',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: available.isEmpty
                          ? null
                          : () => _showProductPicker(index, available),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'المنتج',
                          suffixIcon: Icon(Icons.arrow_drop_down,
                              color: AppTheme.textSecondary),
                        ),
                        child: Text(
                          entry.selectedProduct != null
                              ? '${entry.selectedProduct!.name} (${entry.selectedProduct!.unit})'
                              : available.isEmpty
                                  ? 'لا توجد منتجات متاحة'
                                  : 'اختر المنتج',
                          style: TextStyle(
                            fontSize: 13,
                            color: entry.selectedProduct != null
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (entry.selectedProduct != null &&
                        entry.selectedProduct!.isPackaged) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الوحدة: ${entry.selectedProduct!.packageType} (${entry.selectedProduct!.packageSize.formatted} ${entry.selectedProduct!.usageUnit})',
                          style: TextStyle(
                              color: AppTheme.accentBlue, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'count',
                              label: Text('عدد العلب/الأكياس')),
                          ButtonSegment(value: 'measure', label: Text('بالقياس')),
                        ],
                        selected: {entry.quantityMode},
                        onSelectionChanged: (s) => setState(() {
                          entry.quantityMode = s.first;
                        }),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: entry.quantityController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: TextStyle(
                                color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: entry.quantityMode == 'count'
                                  ? 'الكمية (عدد)'
                                  : 'الكمية (${entry.selectedProduct?.usageUnit ?? ''})',
                              hintText: '0'),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n <= 0) {
                                return 'رقم غير صحيح';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: entry.unitPriceController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: TextStyle(
                                color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                                labelText: 'سعر الوحدة',
                                hintText: '0'),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n < 0) {
                                return 'رقم غير صحيح';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_priceWarning(entry) != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _priceWarning(entry)!,
                            style: TextStyle(
                                color: AppTheme.expenseRed, fontSize: 12),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'الإجمالي: ${entry.total.formatted} ر.ي',
                        style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addItem,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
                side: BorderSide(
                    color: AppTheme.accentBlue.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة صنف',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentBlueDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accentBlue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إجمالي الأصناف',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${_totalAmount.formatted} ر.ي',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  if (_discount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الخصم الممنوح',
                            style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text(
                          '-${_discount.formatted} ر.ي',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.incomeGreen),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الصافي بعد الخصم',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text(
                          '${_netAmount.formatted} ر.ي',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentBlue),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                  labelText: 'مبلغ الخصم (إن وجد)',
                  hintText: '0',
                  prefixIcon: Icon(Icons.discount_outlined, color: AppTheme.incomeGreen)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paidAmountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع نقدًا',
                  hintText: '0',
                  prefixIcon: Icon(Icons.attach_money)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _paidAmount <= 0
                      ? 'فاتورة آجلة بالكامل'
                      : (_paidAmount >= _netAmount - 0.01 ? 'مسددة نقداً' : 'دفعة جزئية'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _paidAmount <= 0
                        ? Colors.amberAccent
                        : (_paidAmount >= _netAmount - 0.01 ? AppTheme.incomeGreen : AppTheme.accentBlue),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'المتبقي الآجل: ${(_netAmount - _paidAmount).formatted} ر.ي',
                  style: TextStyle(
                    fontSize: 15,
                    color: _netAmount > _paidAmount
                        ? AppTheme.expenseRed
                        : AppTheme.incomeGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_paidAmount > 0) ...[
              const SizedBox(height: 12),
              Text('المحفظة (صرف المبلغ منها)',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Consumer<FinanceProvider>(
                builder: (context, provider, _) {
                  if (provider.wallets.isEmpty) {
                    return Text('لا توجد محافظ، أنشئ محفظة أولاً',
                        style: TextStyle(color: AppTheme.expenseRed));
                  }
                  return DropdownButtonFormField<String>(
                    value: _paymentWalletId,
                    decoration: const InputDecoration(),
                    style: TextStyle(color: AppTheme.textPrimary),
                    items: provider.wallets
                        .map((w) => DropdownMenuItem(
                            value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _paymentWalletId = v),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            FundingPicker(
              provider: provider,
              pickerKey: _fundingKey,
              walletFilter: _paymentWalletId,
              requiredTotalGetter: () => _paidAmount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  hintText: 'أي ملاحظات إضافية...',
                  prefixIcon: Icon(Icons.notes)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('حفظ الفاتورة'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _PurchaseItemEntry {
  Product? selectedProduct;
  final TextEditingController quantityController =
      TextEditingController(text: '1');
  final TextEditingController unitPriceController =
      TextEditingController(text: '0');
  String quantityMode = 'count'; // 'count' عدد العلب/الأكياس | 'measure' بالقياس

  double get quantity => double.tryParse(quantityController.text) ?? 0;
  double get unitPrice => double.tryParse(unitPriceController.text) ?? 0;
  double get countQuantity {
    final v = quantity;
    final p = selectedProduct;
    if (p != null && p.isPackaged && v > 0 && quantityMode == 'measure') {
      return v / p.packageSize;
    }
    return v;
  }
  double get total => countQuantity * unitPrice;

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
  }
}
