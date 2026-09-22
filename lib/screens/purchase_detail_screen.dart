import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'new_purchase_screen.dart';
import 'purchase_distribution_screen.dart';
import 'purchases_screen.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final String purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final purchase = provider.purchases.firstWhereOrNull((p) => p.id == purchaseId);
        if (purchase == null) {
          return Scaffold(
            backgroundColor: context.dynamicScaffoldBg,
            appBar: AppBar(title: const Text('تفاصيل الفاتورة')),
            body: Center(
              child: Text('الفاتورة غير موجودة أو تم حذفها',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }

        final items = provider.purchaseItemsFor(purchase.id);
        final supplier = provider.partners.firstWhereOrNull((p) => p.id == purchase.supplierId);
        final productMap = {for (var p in provider.products) p.id: p};
        final hasRemainingDist = items.any((i) => i.remainingToDistribute > 0);
        final isFullyPaid = purchase.remainingAmount <= 0.01;
        final isPartiallyPaid = purchase.paidAmount > 0.01 && !isFullyPaid;
        final payments = provider.moneyMovements
            .where((m) => m.purchaseId == purchase.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final totalDistributed = items.fold(0.0, (s, i) => s + i.distributedQuantity);
        final totalPurchasedQty = items.fold(0.0, (s, i) => s + i.quantity);
        final distributionPercent = totalPurchasedQty > 0
            ? (totalDistributed / totalPurchasedQty).clamp(0.0, 1.0)
            : 1.0;
        final paymentPercent = purchase.netAmount > 0
            ? (purchase.paidAmount / purchase.netAmount).clamp(0.0, 1.0)
            : 1.0;

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: Text(
              purchase.invoiceNumber != null && purchase.invoiceNumber!.trim().isNotEmpty
                  ? 'فاتورة #${purchase.invoiceNumber}'
                  : 'تفاصيل فاتورة الشراء',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل الفاتورة',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewPurchaseScreen(existing: purchase),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                color: AppTheme.surface,
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewPurchaseScreen(existing: purchase),
                      ),
                    );
                  } else if (v == 'delete') {
                    _confirmDelete(context, provider, purchase);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: AppTheme.textPrimary),
                        SizedBox(width: 8),
                        Text('تعديل الفاتورة', style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.expenseRed),
                        SizedBox(width: 8),
                        Text('حذف الفاتورة', style: TextStyle(color: AppTheme.expenseRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. بطاقة ترويسة الفاتورة والمورد
                _buildHeaderCard(context, purchase, supplier, isFullyPaid, isPartiallyPaid, hasRemainingDist),
                const SizedBox(height: 14),

                // 2. بطاقة الوضع المالي وحالة السداد
                _buildFinancialCard(context, purchase, paymentPercent, isFullyPaid),
                const SizedBox(height: 14),

                // 3. بطاقة الأصناف وحالة التوزيع المخزني
                _buildItemsCard(context, items, productMap, distributionPercent, hasRemainingDist),
                const SizedBox(height: 14),

                // 4. سجل حركات الدفع والتسويات
                _buildPaymentsHistoryCard(context, provider, purchase, payments),
                const SizedBox(height: 14),

                // 5. الملاحظات إن وجدت
                if (purchase.notes != null && purchase.notes!.trim().isNotEmpty) ...[
                  _buildNotesCard(purchase.notes!),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomActionBar(context, provider, purchase, hasRemainingDist),
        );
      },
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    Purchase purchase,
    Partner? supplier,
    bool isFullyPaid,
    bool isPartiallyPaid,
    bool hasRemainingDist,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.business_rounded, color: AppTheme.accentBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier?.name ?? 'مورد محذوف',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (supplier?.phone != null && supplier!.phone!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            supplier.phone!,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _buildPaymentBadge(isFullyPaid, isPartiallyPaid),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd MMMM yyyy', 'ar').format(purchase.date),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (purchase.invoiceNumber != null && purchase.invoiceNumber!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 13, color: AppTheme.accentBlue),
                      const SizedBox(width: 4),
                      Text(
                        '#${purchase.invoiceNumber}',
                        style: TextStyle(
                          color: AppTheme.accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'طريقة الدفع: ${purchasePaymentTypeLabels[purchase.paymentType] ?? purchase.paymentType}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
              const Spacer(),
              _buildDistributionBadge(hasRemainingDist),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(bool isFullyPaid, bool isPartiallyPaid) {
    if (isFullyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.incomeGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.incomeGreen.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 14, color: AppTheme.incomeGreen),
            SizedBox(width: 4),
            Text(
              'مسدد بالكامل',
              style: TextStyle(
                color: AppTheme.incomeGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else if (isPartiallyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline, size: 14, color: Colors.orange),
            SizedBox(width: 4),
            Text(
              'سداد جزئي',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.expenseRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.expenseRed),
            SizedBox(width: 4),
            Text(
              'آجل غير مسدد',
              style: TextStyle(
                color: AppTheme.expenseRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDistributionBadge(bool hasRemainingDist) {
    if (!hasRemainingDist) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.accentBlue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.all_inbox_rounded, size: 13, color: AppTheme.accentBlue),
            SizedBox(width: 4),
            Text(
              'تم التوزيع للمخازن',
              style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 13, color: Colors.amber),
            SizedBox(width: 4),
            Text(
              'يحتاج توزيع للمخزن',
              style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFinancialCard(
    BuildContext context,
    Purchase purchase,
    double paymentPercent,
    bool isFullyPaid,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accentBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'الملخص المالي',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${(paymentPercent * 100).toStringAsFixed(0)}% مسدد',
                style: TextStyle(
                  color: isFullyPaid ? AppTheme.incomeGreen : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: paymentPercent,
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFullyPaid ? AppTheme.incomeGreen : (paymentPercent > 0 ? Colors.orange : AppTheme.expenseRed),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('صافي الفاتورة',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '${purchase.netAmount.formattedFull} ر.ي',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.cardBorder),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المسدد نقداً',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '${purchase.paidAmount.formattedFull} ر.ي',
                        style: TextStyle(
                          color: AppTheme.incomeGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.cardBorder),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المتبقي الآجل',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '${purchase.remainingAmount.formattedFull} ر.ي',
                        style: TextStyle(
                          color: purchase.remainingAmount > 0.01 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildRowLine('إجمالي الأصناف قبل الخصم', '${purchase.totalAmount.formattedFull} ر.ي'),
          if (purchase.discount > 0) ...[
            const SizedBox(height: 6),
            _buildRowLine(
              'الخصم الممنوح',
              '-${purchase.discount.formattedFull} ر.ي',
              valueColor: AppTheme.incomeGreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowLine(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsCard(
    BuildContext context,
    List<PurchaseItem> items,
    Map<String, Product> productMap,
    double distributionPercent,
    bool hasRemainingDist,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppTheme.accentBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الأصناف وتتبع المخزن (${items.length})',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                hasRemainingDist ? 'بانتظار التوزيع' : 'موزع 100%',
                style: TextStyle(
                  color: hasRemainingDist ? Colors.amber : AppTheme.accentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد أصناف مسجلة في الفاتورة',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...items.map((item) {
              final product = productMap[item.productId];
              final itemDistPercent = item.quantity > 0
                  ? (item.distributedQuantity / item.quantity).clamp(0.0, 1.0)
                  : 1.0;
              final isItemComplete = item.remainingToDistribute <= 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isItemComplete
                        ? AppTheme.cardBorder
                        : Colors.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.science_outlined, color: AppTheme.accentBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product?.name ?? 'منتج محذوف',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.quantity.formattedFull} ${product?.unit ?? 'وحدة'} × ${item.unitPrice.formattedFull} ر.ي',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.total.formattedFull} ر.ي',
                          style: TextStyle(
                            color: AppTheme.incomeGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // تفاصيل التوزيع للمخزن للصنف
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isItemComplete ? Icons.check_circle : Icons.hourglass_bottom,
                                    size: 13,
                                    color: isItemComplete ? AppTheme.incomeGreen : Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isItemComplete
                                        ? 'موزع بالكامل للمخازن'
                                        : 'موزع: ${item.distributedQuantity.formattedFull} / ${item.quantity.formattedFull}',
                                    style: TextStyle(
                                      color: isItemComplete ? AppTheme.incomeGreen : Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (!isItemComplete)
                                Text(
                                  'المتبقي للتوزيع: ${item.remainingToDistribute.formattedFull}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: itemDistPercent,
                              minHeight: 5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isItemComplete ? AppTheme.accentBlue : Colors.amber,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildPaymentsHistoryCard(
    BuildContext context,
    FinanceProvider provider,
    Purchase purchase,
    List<MoneyMovement> payments,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, color: AppTheme.incomeGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'سجل دفعات السداد',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${payments.length} دفعات مسجلة',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (payments.isEmpty && purchase.paidAmount <= 0)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لم يتم تسجيل أي دفعات سداد لهذه الفاتورة حتى الآن',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            )
          else ...[
            // إذا كانت الفاتورة مدفوعة عند إنشائها ولم تكن مرتبطة بـ movement لاحق
            if (payments.isEmpty && purchase.paidAmount > 0)
              _buildPaymentItemRow(
                index: 1,
                date: purchase.date,
                amount: purchase.paidAmount,
                walletName: 'الدفعة الأولى عند الشراء',
                note: 'سداد نقدي عند استلام الفاتورة',
              ),
            ...payments.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              final wallet = provider.wallets.firstWhereOrNull((w) => w.id == p.walletId);
              return _buildPaymentItemRow(
                index: idx,
                date: p.date,
                amount: p.amount,
                walletName: wallet?.name ?? 'الخزينة النقدية',
                note: p.note,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentItemRow({
    required int index,
    required DateTime date,
    required double amount,
    required String walletName,
    String? note,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.incomeGreen.withValues(alpha: 0.15),
            child: Text(
              '$index',
              style: TextStyle(
                color: AppTheme.incomeGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      walletName,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${DateFormat('dd MMM yyyy', 'ar').format(date)}',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${amount.formattedFull} ر.ي',
            style: TextStyle(
              color: AppTheme.incomeGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, color: AppTheme.textSecondary, size: 18),
              SizedBox(width: 6),
              Text(
                'ملاحظات إضافية',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActionBar(
    BuildContext context,
    FinanceProvider provider,
    Purchase purchase,
    bool hasRemainingDist,
  ) {
    final hasRemainingPay = purchase.remainingAmount > 0.01;
    if (!hasRemainingPay && !hasRemainingDist) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (hasRemainingPay)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showPurchasePaymentSheet(context, provider, purchase),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.incomeGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 20),
                  label: const Text(
                    'تسجيل دفعة سداد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            if (hasRemainingPay && hasRemainingDist) const SizedBox(width: 10),
            if (hasRemainingDist)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchaseDistributionScreen(purchase: purchase),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.warehouse_outlined, size: 20),
                  label: const Text(
                    'توزيع إلى المخازن',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider, Purchase purchase) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed),
            SizedBox(width: 8),
            Text('حذف الفاتورة', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف فاتورة الشراء هذه؟\nسيتم حذف الفاتورة وأصنافها ودفعاتها، وتعديل كميات المخزون المرتبطة بها.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (provider.deletePurchase(purchase.id)) {
                Navigator.pop(dlgCtx);
                Navigator.pop(context);
              } else {
                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف الفاتورة بعد توزيع أصنافها على المخزون.')));
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }
}
