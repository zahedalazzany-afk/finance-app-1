import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class PurchaseDistributionScreen extends StatefulWidget {
  final Purchase purchase;
  const PurchaseDistributionScreen({super.key, required this.purchase});

  @override
  State<PurchaseDistributionScreen> createState() =>
      _PurchaseDistributionScreenState();
}

class _DistributionLine {
  String? warehouseId;
  final TextEditingController quantityController;

  _DistributionLine({this.warehouseId})
      : quantityController = TextEditingController(text: '0');

  double get quantity => double.tryParse(quantityController.text) ?? 0;

  void dispose() => quantityController.dispose();
}

class _DistributionEntry {
  final String purchaseItemId;
  final String productId;
  final double purchasedQuantity;
  final double remaining;
  final List<_DistributionLine> lines;
  bool selected = false;

  _DistributionEntry({
    required this.purchaseItemId,
    required this.productId,
    required this.purchasedQuantity,
    required this.remaining,
  }) : lines = [
          _DistributionLine()
            ..quantityController.text = remaining.toString(),
        ];

  double get totalAllocated =>
      lines.fold(0, (sum, line) => sum + line.quantity);

  void addLine() => lines.add(_DistributionLine());

  void removeLine(int index) {
    lines[index].dispose();
    lines.removeAt(index);
  }

  void dispose() {
    for (final line in lines) {
      line.dispose();
    }
  }
}

class _PurchaseDistributionScreenState
    extends State<PurchaseDistributionScreen> {
  late List<_DistributionEntry> _entries;
  DateTime _distributionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _entries = [];
  }

  void _initEntries(FinanceProvider provider) {
    if (_entries.isNotEmpty) return;
    final items = provider.purchaseItemsFor(widget.purchase.id);
    _entries = items.map((item) {
      return _DistributionEntry(
        purchaseItemId: item.id,
        productId: item.productId,
        purchasedQuantity: item.quantity,
        remaining: item.remainingToDistribute,
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDistributionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _distributionDate,
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
      setState(() => _distributionDate = picked);
    }
  }

  void _save(FinanceProvider provider) {
    final hasWarehouses = provider.warehouses.isNotEmpty;
    final entriesToSave = <Map<String, dynamic>>[];
    bool hasError = false;

    for (final e in _entries) {
      if (e.remaining <= 0) continue;
      if (!e.selected) continue;
      if (e.totalAllocated > e.remaining) {
        hasError = true;
        break;
      }
      for (final line in e.lines) {
        final qty = line.quantity;
        if (qty <= 0) continue;
        if (line.warehouseId == null) {
          hasError = true;
          break;
        }
        entriesToSave.add({
          'purchaseItemId': e.purchaseItemId,
          'warehouseId': line.warehouseId!,
          'quantity': qty,
        });
      }
      if (hasError) break;
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تحقق من الأصناف: اختر المخزن لكل كمية ولا تتجاوز المتبقي'),
            backgroundColor: AppTheme.expenseRed),
      );
      return;
    }
    if (entriesToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('لا توجد كميات للتوزيع'),
            backgroundColor: AppTheme.expenseRed),
      );
      return;
    }
    if (!hasWarehouses) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('لا توجد مخازن. أنشئ مخزناً أولاً من شاشة المخازن'),
            backgroundColor: AppTheme.expenseRed),
      );
      return;
    }

    provider.distributePurchase(widget.purchase.id,
        entriesToSave.map((e) => e..['date'] = _distributionDate).toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم توزيع الكميات إلى المخازن'),
            backgroundColor: AppTheme.incomeGreen),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    _initEntries(provider);

    final supplier = provider.partners
        .firstWhereOrNull((p) => p.id == widget.purchase.supplierId);
    final productMap = {
      for (var p in provider.products) p.id: p,
    };
    final warehouses = provider.warehouses;

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(title: const Text('توزيع إلى المخازن')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentBlueDim,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.accentBlue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'فاتورة من ${supplier?.name ?? 'مورد محذوف'}',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${widget.purchase.totalAmount.formatted} ر.ي',
                      style: TextStyle(
                          color: AppTheme.accentBlue,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy', 'ar')
                          .format(widget.purchase.date),
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: _selectDistributionDate,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: AppTheme.textSecondary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'توزيع: ${DateFormat('dd MMM yyyy', 'ar').format(_distributionDate)}',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (warehouses.isEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.expenseRedDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.expenseRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.expenseRed, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا توجد مخازن. أنشئ مخزناً أولاً من شاشة المخازن',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text('لا توجد أصناف في هذه الفاتورة',
                        style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final product = productMap[entry.productId];
                      final isFullyDistributed = entry.remaining <= 0;
                      final exceeds =
                          entry.totalAllocated > entry.remaining;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isFullyDistributed
                              ? AppTheme.surface
                              : AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isFullyDistributed
                                ? AppTheme.incomeGreen.withValues(alpha: 0.4)
                                : exceeds
                                    ? AppTheme.expenseRed
                                        .withValues(alpha: 0.5)
                                    : AppTheme.cardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product?.name ?? 'منتج محذوف',
                                        style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'المشترى: ${entry.purchasedQuantity.formatted} ${product?.unit ?? ''}'
                                        '  ·  المتبقي: ${entry.remaining.formatted} ${product?.unit ?? ''}',
                                        style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
if (isFullyDistributed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.incomeGreenDim,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('مُوزَّع',
                                        style: TextStyle(
                                            color: AppTheme.incomeGreen,
                                            fontSize: 11)),
                                  ),
                              ],
                            ),
                            if (isFullyDistributed)
                              const SizedBox(height: 8),
                            if (isFullyDistributed)
                              Text('تم توزيع كامل الكمية لهذا الصنف',
                                  style: TextStyle(
                                      color: AppTheme.incomeGreen,
                                      fontSize: 12))
                            else ...[
                              InkWell(
                                onTap: () => setState(() {
                                  entry.selected = !entry.selected;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        entry.selected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: entry.selected
                                            ? AppTheme.accentBlue
                                            : AppTheme.textMuted,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          entry.selected
                                              ? 'الصنف مُدرج في التوزيع'
                                              : 'اضغط لتضمين الصنف في التوزيع',
                                          style: TextStyle(
                                            color: entry.selected
                                                ? AppTheme.accentBlue
                                                : AppTheme.textMuted,
                                            fontSize: 13,
                                            fontWeight: entry.selected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (!isFullyDistributed &&
                                entry.selected) ...[
                              const SizedBox(height: 2),
                              Text(
                                'المجموع الموزع في هذه العملية: ${entry.totalAllocated.formatted} ${product?.unit ?? ''}',
                                style: TextStyle(
                                  color: exceeds
                                      ? AppTheme.expenseRed
                                      : AppTheme.accentBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...List.generate(entry.lines.length, (lIdx) {
                                final line = entry.lines[lIdx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppTheme.cardBorder),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _DropdownField<String>(
                                              label: 'المخزن *',
                                              icon: Icons.warehouse,
                                              value: line.warehouseId,
                                              hint: warehouses.isEmpty
                                                  ? 'لا توجد مخازن'
                                                  : 'اختر المخزن',
                                              items: warehouses
                                                  .map((w) => _ItemOption<
                                                      String>(
                                                      value: w.id,
                                                      label: w.name))
                                                  .toList(),
                                              onChanged: (v) => setState(() {
                                                line.warehouseId = v;
                                              }),
                                            ),
                                          ),
                                          if (entry.lines.length > 1)
                                            IconButton(
                                              onPressed: () => setState(() {
                                                entry.removeLine(lIdx);
                                              }),
                                              icon: Icon(
                                                  Icons.remove_circle_outline,
                                                  color:
                                                      AppTheme.expenseRed,
                                                  size: 20),
                                              tooltip: 'حذف التوزيع',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: line.quantityController,
                                        keyboardType:
                                            const TextInputType
                                                .numberWithOptions(
                                                    decimal: true),
                                        style: TextStyle(
                                            color: AppTheme.textPrimary),
                                        decoration: InputDecoration(
                                            labelText: 'الكمية',
                                            hintText:
                                                'الكمية (المتبقي ${entry.remaining.formatted} ${product?.unit ?? ''})',
                                            prefixIcon: Icon(Icons.numbers)),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              TextButton.icon(
                                onPressed: warehouses.isEmpty
                                    ? null
                                    : () => setState(() {
                                          entry.addLine();
                                        }),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.accentBlue),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('إضافة مخزن آخر'),
                              ),
                              if (exceeds)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'الكمية الموزعة تتجاوز المتبقي (${entry.remaining.formatted})',
                                    style: TextStyle(
                                        color: AppTheme.expenseRed,
                                        fontSize: 12),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'سيُضاف للمخزن تلقائياً (إن وجد عنصر بنفس الاسم تُزاد كميته، وإلا يُنشأ)',
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _save(provider),
        backgroundColor: AppTheme.incomeGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.check_rounded),
        label: const Text('توزيع',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ItemOption<T> {
  final T value;
  final String label;
  const _ItemOption({required this.value, required this.label});
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final String hint;
  final List<_ItemOption<T>> items;
  final void Function(T?) onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          hint: Row(
            children: [
              Icon(icon, color: AppTheme.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(hint,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 13)),
              ),
            ],
          ),
          items: items
              .map((o) => DropdownMenuItem(
                  value: o.value,
                  child: Row(
                    children: [
                      Icon(icon, color: AppTheme.accentBlue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(o.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  )))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}