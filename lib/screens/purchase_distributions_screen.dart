import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'purchase_distribution_screen.dart';

class PurchaseDistributionsScreen extends StatefulWidget {
  const PurchaseDistributionsScreen({super.key});

  @override
  State<PurchaseDistributionsScreen> createState() =>
      _PurchaseDistributionsScreenState();
}

class _PurchaseDistributionsScreenState
    extends State<PurchaseDistributionsScreen> {
  double _remainingFor(FinanceProvider provider, Purchase p) {
    var remaining = 0.0;
    for (final item in provider.purchaseItemsFor(p.id)) {
      remaining += item.remainingToDistribute;
    }
    return remaining;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final suppliers = {
      for (final s in provider.partners) s.id: s,
    };
    final distributable = provider.purchases
        .map((p) => (purchase: p, remaining: _remainingFor(provider, p)))
        .where((e) => e.remaining > 0)
        .toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(title: const Text('توزيع المشتريات للمخازن')),
      body: distributable.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warehouse_outlined,
                      color: AppTheme.textMuted, size: 64),
                  const SizedBox(height: 16),
                  Text('لا توجد مشتريات بكميات غير موزعة',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('أنشئ فاتورة شراء أولاً',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: distributable.length,
              itemBuilder: (context, index) {
                final e = distributable[index];
                final purchase = e.purchase;
                final supplier = suppliers[purchase.supplierId];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PurchaseDistributionScreen(purchase: purchase),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
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
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy', 'ar')
                                    .format(purchase.date),
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${e.remaining.formatted}',
                              style: TextStyle(
                                  color: AppTheme.accentBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            Text('متبقي للتوزيع',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_left,
                            color: AppTheme.textMuted, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
