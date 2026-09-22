import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'agricultural_calendar_screen.dart';
import 'agricultural_events_screen.dart';

class ManageEventsScreen extends StatefulWidget {
  final int initialProposal;
  const ManageEventsScreen({super.key, this.initialProposal = 0});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();

  static IconData eventIcon(String type) => _eventIcon(type);

  static IconData _eventIcon(String type) {
    switch (type) {
      case 'قلب التربة': return Icons.grass;
      case 'سقي المزروعات': return Icons.water_drop;
      case 'قصة الأشجار': return Icons.content_cut;
      case 'رش المبيدات': return Icons.science;
      default: return Icons.edit_note;
    }
  }

  static void showEventForm(BuildContext context, FinanceProvider provider,
      {LandEvent? existing, DateTime? initialDate, String? initialType, String? initialPlotId}) {
    String? landPlotId = existing?.landPlotId ?? initialPlotId;
    String eventType = existing?.eventType ?? initialType ?? (provider.eventTypesList.isNotEmpty ? provider.eventTypesList.first.name : 'أخرى');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    DateTime date = existing?.date ?? initialDate ?? DateTime.now();
    final formKey = GlobalKey<FormState>();

    final lines = <_ConsumptionLine>[];
    if (existing != null) {
      final linked = provider.inventoryTransactions
          .where((t) => t.eventId == existing.id && t.type == 'out')
          .toList();
      for (final t in linked) {
        final item = provider.storageItems.firstWhereOrNull((s) => s.id == t.itemId);
        final line = _ConsumptionLine()
          ..warehouseId = item?.warehouseId
          ..itemId = t.itemId
          ..existingId = t.id;
        if (item != null && item.isPackaged && item.packageSize != null && item.packageSize! > 0) {
          line.qtyController.text = (t.quantity * item.packageSize!).formatted;
        } else {
          line.qtyController.text = t.quantity.formatted;
        }
        lines.add(line);
      }
    }

    final laborLines = <_LaborLine>[];
    if (existing != null) {
      for (final e in provider.expensesForEvent(existing.id)) {
        if (e.workerId == null) continue;
        final ll = _LaborLine()
          ..workerId = e.workerId
          ..existingId = e.id;
        ll.daysController.text = (e.wageDays ?? 0).plain;
        ll.rateController.text = (e.wageRate ?? 0).plain;
        laborLines.add(ll);
      }
    }
    String paymentType = 'debt';
    String? walletId;
    final wageFundingKey = GlobalKey<FundingPickerState>();
    if (laborLines.isNotEmpty) {
      final first = provider.expenses
          .firstWhereOrNull((e) => e.id == laborLines.first.existingId);
      if (first != null && provider.paidForExpense(first.id) >= first.amount) {
        paymentType = 'cash';
        final p = provider.expensePaymentsFor(first.id)
            .firstWhereOrNull((x) => true);
        walletId = p?.walletId;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),
                Text(existing == null ? 'إضافة حدث' : 'تعديل الحدث',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                SheetDropdown<String>(
                  label: 'الموضع *',
                  icon: Icons.landscape,
                  hint: 'اختر الموضع',
                  value: landPlotId,
                  items: provider.landPlots
                      .map((p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setSheetState(() {
                      landPlotId = v;
                      final wid = v == null
                          ? null
                          : provider.landPlots.firstWhereOrNull((p) => p.id == v)?.warehouseId;
                      for (final l in lines) {
                        l.warehouseId = wid;
                        l.itemId = null;
                      }
                    }),
                ),
                const SizedBox(height: 12),
                SheetDropdown<String>(
                  label: 'نوع الحدث',
                  icon: Icons.event_note,
                  hint: 'اختر نوع الحدث',
                  value: eventType,
                  items: provider.eventTypesList
                      .map((t) => DropdownMenuItem(
                          value: t.name,
                          child: Row(
                            children: [
                              Icon(_eventIcon(t.name),
                                  color: AppTheme.accentBlue, size: 18),
                              const SizedBox(width: 8),
                              Text(t.name),
                            ],
                          )))
                      .toList(),
                  onChanged: (v) => setSheetState(() => eventType = v!),
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
                            primary: AppTheme.accentBlue, surface: AppTheme.card,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'التاريخ',
                      prefixIcon: Icon(Icons.calendar_today,
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                    child: Text(DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'أي تفاصيل إضافية...',
                      prefixIcon: Icon(Icons.notes)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.science, color: AppTheme.accentBlue, size: 20),
                    SizedBox(width: 8),
                    Text('المواد المستهلكة',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('صرف المواد العينية المرتبط بهذا الحدث (يتم خصمها من مخازن الموضع)',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                if (landPlotId != null &&
                    provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId)?.warehouseId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlueDim,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warehouse, color: AppTheme.accentBlue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'المخزن: ${provider.warehouses.firstWhereOrNull((w) => w.id == provider.landPlots.firstWhere((p) => p.id == landPlotId).warehouseId)?.name ?? '—'}',
                          style: TextStyle(color: AppTheme.accentBlue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (landPlotId != null &&
                    provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId)?.warehouseId == null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseRedDim,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                    ),
                    child: Text('هذا الموضع غير مرتبط بمخزن. اربط الموضع بمخزن من شاشة المواضع لتتمكن من صرف المواد.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                if (lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text('لا توجد مواد مستهلكة لهذا الحدث',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
                ...lines.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final line = entry.value;
                  final wid =
                      landPlotId == null ? null : provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId)?.warehouseId;
                  if (wid != null) line.warehouseId = wid;
                  final selectedElsewhere = lines
                      .asMap()
                      .entries
                      .where((e) => e.key != idx && e.value.itemId != null)
                      .map((e) => e.value.itemId)
                      .toSet();
                  final warehouseItems = line.warehouseId == null
                      ? <StorageItem>[]
                      : provider.getItemsForWarehouse(line.warehouseId!)
                          .where((s) => s.quantity > 0 || (line.itemId != null && line.itemId == s.id))
                          .where((s) => !selectedElsewhere.contains(s.id))
                          .toList();
                  final item = warehouseItems.firstWhereOrNull((s) => s.id == line.itemId) ??
                      provider.storageItems.firstWhereOrNull((s) => s.id == line.itemId);
                  final existingCount = line.existingId == null
                      ? 0.0
                      : (provider.inventoryTransactions
                              .firstWhereOrNull((t) => t.id == line.existingId)
                              ?.quantity ??
                          0.0);
                  final availableCount = (item?.quantity ?? 0.0) + existingCount;
                  final maxAllowed = (item != null && item.isPackaged && (item.packageSize ?? 0) > 0)
                      ? (availableCount * item.packageSize!)
                      : availableCount;
                  final unitLabel = item != null
                      ? (item.isPackaged ? (item.usageUnit ?? item.unit) : item.unit)
                      : '';
                  final enteredQty = double.tryParse(line.qtyController.text.trim());
                  final isExceeded = item != null && enteredQty != null && enteredQty > maxAllowed;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isExceeded ? AppTheme.expenseRed.withOpacity(0.5) : AppTheme.cardBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SheetDropdown<String>(
                                hint: 'المادة',
                                labelAbove: true,
                                label: 'المادة',
                                value: line.itemId,
                                items: warehouseItems
                                    .map((s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text('${s.name} (${s.quantity.formatted} ${s.unit})')))
                                    .toList(),
                                onChanged: (v) => setSheetState(() => line.itemId = v),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setSheetState(() => lines.removeAt(idx)),
                              icon: Icon(Icons.close, color: AppTheme.expenseRed, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: isExceeded ? 3 : 1,
                              child: TextFormField(
                                controller: line.qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setSheetState(() {}),
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: () {
                                    if (item != null && item.isPackaged) {
                                      return 'الكمية (${item.usageUnit ?? ''})';
                                    }
                                    return 'الكمية ${line.existingId != null ? '(تحديث)' : ''}';
                                  }(),
                                  prefixIcon: const Icon(Icons.numbers),
                                ),
                                validator: (_) {
                                  if (line.warehouseId == null) return 'هذا الموضع غير مرتبط بمخزن';
                                  if (line.itemId == null) return 'اختر المادة';
                                  final qty = double.tryParse(line.qtyController.text.trim());
                                  if (qty == null || qty <= 0) return 'كمية غير صالحة';
                                  if (item != null) {
                                    if (maxAllowed <= 0) return 'لا توجد كمية متاحة';
                                    if (qty > maxAllowed) {
                                      return 'المتاح: ${maxAllowed.formatted} $unitLabel';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (isExceeded) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.expenseRed.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.expenseRed.withOpacity(0.6), width: 1.2),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 20),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'أكبر من المتاح في المخزن!\n(المتاح: ${maxAllowed.formatted} $unitLabel)',
                                          style: TextStyle(
                                            color: AppTheme.expenseRed,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (item != null) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: Text(
                                    'المتاح: ${maxAllowed.formatted} $unitLabel',
                                    style: TextStyle(
                                      color: AppTheme.incomeGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setSheetState(() {
                    final wid = landPlotId == null
                        ? null
                        : provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId)?.warehouseId;
                    lines.add(_ConsumptionLine()..warehouseId = wid);
                  }),
                    icon: Icon(Icons.add, color: AppTheme.accentBlue, size: 18),
                    label: Text('إضافة مادة', style: TextStyle(color: AppTheme.accentBlue)),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('أجور العمالة',
                      style: TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                const SizedBox(height: 8),
                if (laborLines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text('لا توجد أجور عمالة لهذا الحدث',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
                ...laborLines.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ll = entry.value;
                  final days = tryParseFlexible(ll.daysController.text) ?? 0;
                  final rate = tryParseFlexible(ll.rateController.text) ?? 0;
                  final total = days * rate;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SheetDropdown<String>(
                                hint: 'العامل',
                                labelAbove: true,
                                label: 'العامل',
                                value: ll.workerId,
                                items: provider.workers
                                    .map((x) => DropdownMenuItem(
                                        value: x.id, child: Text(x.name)))
                                    .toList(),
                                onChanged: (v) => setSheetState(() => ll.workerId = v),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setSheetState(() => laborLines.removeAt(idx)),
                              icon: Icon(Icons.close, color: AppTheme.expenseRed, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: ll.daysController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'عدد الأيام',
                                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                                validator: (_) {
                                  final d = tryParseFlexible(ll.daysController.text);
                                  if (ll.workerId == null) return 'اختر العامل';
                                  if (d == null || d <= 0) return 'عدد غير صالح';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: ll.rateController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'الأجر اليومي',
                                  prefixIcon: Icon(Icons.attach_money, size: 18),
                                ),
                                validator: (_) {
                                  final r = tryParseFlexible(ll.rateController.text);
                                  if (r == null || r <= 0) return 'أجر غير صالح';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('الإجمالي: ${total.formatted}',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setSheetState(() => laborLines.add(_LaborLine())),
                    icon: Icon(Icons.add, color: AppTheme.accentBlue, size: 18),
                    label: Text('إضافة عامل', style: TextStyle(color: AppTheme.accentBlue)),
                  ),
                ),
                const SizedBox(height: 8),
                if (laborLines.isNotEmpty) ...[
                  Row(
                    children: [
                      Text('طريقة الدفع:', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'cash', label: Text('نقدي')),
                          ButtonSegment(value: 'debt', label: Text('آجل (دين)')),
                        ],
                        selected: {paymentType},
                        onSelectionChanged: (s) => setSheetState(() => paymentType = s.first),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  if (paymentType == 'cash') ...[
                    const SizedBox(height: 10),
                    SheetDropdown<String>(
                      label: 'المحفظة *',
                      icon: Icons.wallet,
                      hint: 'اختر المحفظة',
                      value: walletId,
                      items: provider.wallets
                          .map((x) => DropdownMenuItem(
                              value: x.id, child: Text(x.name)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => walletId = v),
                    ),
                    const SizedBox(height: 12),
                    FundingPicker(
                      provider: provider,
                      pickerKey: wageFundingKey,
                      walletFilter: walletId,
                      requiredTotalGetter: () => laborLines.fold(
                          0.0,
                          (s, l) =>
                              s +
                              ((tryParseFlexible(l.daysController.text) ?? 0) *
                                  (tryParseFlexible(l.rateController.text) ?? 0))),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      if (landPlotId == null) return;

                      // تحقق صارم من عدم تجاوز الكمية المتاحة في المخزن
                      for (final l in lines) {
                        if (l.itemId == null) continue;
                        final qty = double.tryParse(l.qtyController.text.trim()) ?? 0;
                        if (qty <= 0) continue;
                        final item = provider.storageItems.firstWhereOrNull((s) => s.id == l.itemId);
                        if (item != null) {
                          final existingCount = l.existingId == null
                              ? 0.0
                              : (provider.inventoryTransactions
                                      .firstWhereOrNull((t) => t.id == l.existingId)
                                      ?.quantity ??
                                  0.0);
                          final availableCount = item.quantity + existingCount;
                          final maxAllowed = item.isPackaged && (item.packageSize ?? 0) > 0
                              ? (availableCount * item.packageSize!)
                              : availableCount;
                          if (qty > maxAllowed) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('الكمية المطلوبة من (${item.name}) تتجاوز المتاح في المخزن (${maxAllowed.formatted})'),
                              backgroundColor: AppTheme.expenseRed,
                            ));
                            return;
                          }
                        }
                      }

                      if (existing != null) {
                        existing.landPlotId = landPlotId!;
                        existing.eventType = eventType;
                        existing.date = date;
                        existing.notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
                        provider.updateLandEvent(existing);
                      } else {
                        provider.addLandEvent(LandEvent(
                          id: const Uuid().v4(),
                          landPlotId: landPlotId!,
                          eventType: eventType,
                          date: date,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        ));
                      }

                      final validLines = lines.where((l) =>
                            l.warehouseId != null && l.itemId != null &&
                            _lineCount(provider, l) > 0).toList();
                      final eventId = existing?.id ??
                          provider.landEvents.first.id;
                      final old = provider.inventoryTransactions
                          .where((t) => t.eventId == eventId && t.type == 'out')
                          .toList();
                      for (final t in old) {
                        if (!validLines.any((l) => l.existingId == t.id)) {
                          provider.deleteInventoryTransaction(t.id);
                        }
                      }
                      for (final line in validLines) {
                        final qty = _lineCount(provider, line);
                        if (line.existingId != null) {
                          final tx = provider.inventoryTransactions
                              .firstWhereOrNull((t) => t.id == line.existingId);
                          if (tx != null && (tx.itemId != line.itemId || tx.quantity != qty)) {
                            provider.deleteInventoryTransaction(tx.id);
                            provider.addInventoryTransaction(InventoryTransaction(
                              id: const Uuid().v4(),
                              itemId: line.itemId!,
                              type: 'out',
                              quantity: qty,
                              date: date,
                              eventId: eventId,
                            ));
                          }
                        } else {
                          provider.addInventoryTransaction(InventoryTransaction(
                            id: const Uuid().v4(),
                            itemId: line.itemId!,
                            type: 'out',
                            quantity: qty,
                            date: date,
                            eventId: eventId,
                          ));
                        }
                      }
                      final validLabor = laborLines.where((l) =>
                          l.workerId != null &&
                          (tryParseFlexible(l.daysController.text) ?? 0) > 0 &&
                          (tryParseFlexible(l.rateController.text) ?? 0) > 0).toList();
                      if (paymentType == 'cash' && validLabor.isNotEmpty && walletId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('اختر المحفظة لصرف الأجر النقدي')));
                        return;
                      }
                      final isCashNow = paymentType == 'cash' && walletId != null;
                      final totalCash =
                          validLabor.fold(0.0, (s, l) => s +
                              (tryParseFlexible(l.daysController.text) ?? 0) *
                              (tryParseFlexible(l.rateController.text) ?? 0));
                      var fundingPool = <ExpenseAllocation>[];
                      var poolIdx = 0;
                      var poolRemaining = 0.0;
                      if (isCashNow && validLabor.isNotEmpty) {
                        final funding =
                            wageFundingKey.currentState?.allocations ?? [];
                        final sumFunding =
                            funding.fold(0.0, (s, a) => s + a.amount);
                        if ((sumFunding - totalCash).abs() > 0.01) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'مجموع التمويل يجب أن يساوي إجمالي الأجور النقدية (${totalCash.formatted} ر.ي)')));
                          return;
                        }
                        if (!(wageFundingKey.currentState?.validate() ??
                            false)) {
                          return;
                        }
                        fundingPool = List.of(funding);
                        poolRemaining = fundingPool.isEmpty
                            ? 0
                            : fundingPool[0].amount;
                      }
                      final oldWages = provider.expensesForEvent(eventId)
                          .where((e) => e.workerId != null).toList();
                      for (final e in oldWages) {
                        if (!validLabor.any((l) => l.existingId == e.id)) {
                          provider.deleteExpense(e.id);
                        }
                      }
                      for (final l in validLabor) {
                        final days = tryParseFlexible(l.daysController.text) ?? 0;
                        final rate = tryParseFlexible(l.rateController.text) ?? 0;
                        final amount = days * rate;
                        if (l.existingId != null) {
                          final e = provider.expenses
                              .firstWhereOrNull((x) => x.id == l.existingId);
                          if (e != null) {
                            final wasCash = provider.paidForExpense(e.id) >= e.amount;
                            final same = e.workerId == l.workerId &&
                                e.amount == amount &&
                                (e.wageDays ?? 0) == days &&
                                (e.wageRate ?? 0) == rate;
                            if (same && isCashNow == wasCash) {
                              continue;
                            }
                            provider.deleteExpense(e.id);
                          }
                        }
                        final workerName = provider.workers
                                .firstWhereOrNull((x) => x.id == l.workerId)?.name ??
                            'عامل';
                        final wage = Expense(
                          id: const Uuid().v4(),
                          title: 'أجر $workerName',
                          amount: amount,
                          date: date,
                          category: 'عمالة',
                          eventId: eventId,
                          workerId: l.workerId,
                          wageDays: days,
                          wageRate: rate,
                        );
                        provider.addExpense(wage);
                        if (isCashNow) {
                          final slice = <ExpenseAllocation>[];
                          var need = amount;
                          while (need > 0.001 && poolIdx < fundingPool.length) {
                            final take = need < poolRemaining ? need : poolRemaining;
                            slice.add(ExpenseAllocation(
                              incomeId: fundingPool[poolIdx].incomeId,
                              paymentId: fundingPool[poolIdx].paymentId,
                              debtSettlementId: fundingPool[poolIdx].debtSettlementId,
                              debtId: fundingPool[poolIdx].debtId,
                              amount: take,
                              currency: fundingPool[poolIdx].currency,
                            ));
                            poolRemaining -= take;
                            need -= take;
                            if (poolRemaining <= 0.001) {
                              poolIdx++;
                              poolRemaining = poolIdx < fundingPool.length
                                  ? fundingPool[poolIdx].amount
                                  : 0;
                            }
                          }
                          provider.addExpensePayment(ExpensePayment(
                            id: const Uuid().v4(),
                            expenseId: wage.id,
                            amount: amount,
                            date: date,
                            walletId: walletId!,
                            funding: slice,
                          ));
                        }
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white),
                    child: Text(existing == null ? 'حفظ' : 'تحديث'),
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


  void _showDetails(BuildContext context, FinanceProvider provider, LandEvent event) =>
      showEventDetails(context, provider, event);

  static void showEventDetails(BuildContext context, FinanceProvider provider, LandEvent event) {
    final plot = provider.landPlots.firstWhereOrNull((p) => p.id == event.landPlotId);
    final txs = provider.inventoryTransactions
        .where((t) => t.eventId == event.id && t.type == 'out')
        .toList();
    final wages = provider.expensesForEvent(event.id)
        .where((e) => e.workerId != null)
        .toList();
    final totalMaterials = txs.fold(0.0, (s, t) {
      final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
      final product = item == null
          ? null
          : provider.products.firstWhereOrNull((p) => p.id == item.productId);
      return s + t.quantity * (product?.purchasePrice ?? 0);
    });
    final totalWages = wages.fold(0.0, (s, e) => s + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlueDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_eventIcon(event.eventType), color: AppTheme.accentBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.eventType,
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(DateFormat('EEEE, dd MMM yyyy', 'ar').format(event.date),
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(Icons.terrain, 'الموضع', plot?.name ?? 'محذوف'),
                    _detailRow(Icons.event_note, 'الملاحظات',
                        event.notes == null || event.notes!.isEmpty ? '—' : event.notes!),
                    if (totalMaterials > 0 || totalWages > 0)
                      _detailRow(Icons.payments_outlined, 'إجمالي تكلفة الحدث',
                          (totalMaterials + totalWages).formatted),
                  ],
                ),
              ),
              if (txs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('المواد المستهلكة',
                    style: TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                ...txs.map((t) {
                  final item = provider.storageItems.firstWhereOrNull((i) => i.id == t.itemId);
                  final label = item == null
                      ? 'مادة محذوفة'
                      : item.isPackaged && item.packageSize != null
                          ? '${(t.quantity * item.packageSize!).formatted} ${item.usageUnit} (${t.quantity.formatted} ${item.unit})'
                          : '${t.quantity.formatted} ${item.unit}';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, color: AppTheme.textMuted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item?.name ?? 'مادة محذوفة',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                        ),
                        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  );
                }),
              ],
              if (wages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('أجور العمالة',
                    style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                ...wages.map((e) {
                  final w = provider.workers.firstWhereOrNull((x) => x.id == e.workerId);
                  final paid = provider.paidForExpense(e.id);
                  final rem = e.amount - paid;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.engineering, color: AppTheme.expenseRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w?.name ?? 'عامل محذوف',
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${(e.wageDays ?? 1).plain} يوم × ${(e.wageRate ?? 0).formattedFull} ر.ي',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${e.amount.formatted} ر.ي',
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                            if (rem > 0)
                              Text('متبقي ${rem.formatted}', style: TextStyle(color: AppTheme.expenseRed, fontSize: 11))
                            else
                              Text('مسدد', style: TextStyle(color: AppTheme.incomeGreen, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
        ),
      ],
    ),
  );

  static double _lineCount(FinanceProvider provider, _ConsumptionLine line) {
    final qty = double.tryParse(line.qtyController.text.trim()) ?? 0;
    if (line.itemId == null) return qty;
    final item = provider.storageItems.firstWhereOrNull((s) => s.id == line.itemId);
    if (item != null && item.isPackaged && item.packageSize != null && item.packageSize! > 0) {
      return qty / item.packageSize!;
    }
    return qty;
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider, LandEvent event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الحدث', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف "${event.eventType}"؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () { provider.deleteLandEvent(event.id); Navigator.pop(context); },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  @override
  Widget build(BuildContext context) {
    return const AgriculturalEventsScreen();
  }
}

class _ConsumptionLine {
  String? warehouseId;
  String? itemId;
  String? existingId;
  final TextEditingController qtyController;
  _ConsumptionLine() : qtyController = TextEditingController();
  void dispose() => qtyController.dispose();
}

class _LaborLine {
  String? workerId;
  String? existingId;
  final TextEditingController daysController;
  final TextEditingController rateController;
  _LaborLine()
      : daysController = TextEditingController(),
        rateController = TextEditingController();
  void dispose() {
    daysController.dispose();
    rateController.dispose();
  }
}
