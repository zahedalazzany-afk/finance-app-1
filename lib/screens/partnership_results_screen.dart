import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'partner_statement_screen.dart';

/// يعرض نتائج شراكة محددة: إيرادات الموضع في فترة الشراكة،
/// مع حصة الشريك من كل إيراد، مرتبة حسب التاريخ.
class PartnershipResultsScreen extends StatelessWidget {
  final Partnership partnership;
  const PartnershipResultsScreen({super.key, required this.partnership});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final plot =
            provider.landPlots.firstWhereOrNull((p) => p.id == partnership.landPlotId);
        final partner =
            provider.partners.firstWhereOrNull((p) => p.id == partnership.partnerId);
        final roleLabel =
            provider.partnershipTypeById(partnership.role)?.name ?? partnership.role;

        final incomes = provider.incomes
            .where((i) =>
                i.landPlotId == partnership.landPlotId &&
                !i.date.isBefore(partnership.startDate) &&
                (partnership.endDate == null ||
                    !i.date.isAfter(partnership.endDate!)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        double totalShare = 0;
        double totalPaid = 0;
        final results = <({Income income, Distribution dist})>[];
        for (final inc in incomes) {
          final dist = provider.distributions.firstWhereOrNull((d) =>
              d.incomeId == inc.id &&
              d.partnerId == partnership.partnerId &&
              d.role == partnership.role);
          if (dist == null) continue;
          results.add((income: inc, dist: dist));
          totalShare += dist.amount;
          if (provider.isDistributionPaid(dist)) totalPaid += dist.amount;
        }

        final unpaid = (totalShare - totalPaid).clamp(0.0, double.infinity);

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: const Text('نتائج الشراكة'),
            actions: [
              IconButton(
                icon: Icon(Icons.description_outlined, color: AppTheme.accentBlue),
                tooltip: 'كشف حساب الشريك',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PartnerStatementScreen(
                      partnerId: partnership.partnerId,
                      initialPlotId: partnership.landPlotId,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.handshake_outlined,
                              color: AppTheme.accentBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(partner?.name ?? '؟',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                  '$roleLabel · ${plot?.name ?? 'موضع محذوف'}',
                                  style: TextStyle(
                                      color: AppTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PartnerStatementScreen(
                                partnerId: partnership.partnerId,
                                initialPlotId: partnership.landPlotId,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.accentBlue),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: Icon(Icons.receipt_long, size: 14, color: AppTheme.accentBlue),
                          label: Text('كشف الحساب',
                              style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                        'نسبة ${partnership.sharePercentage.toStringAsFixed(partnership.sharePercentage % 1 == 0 ? 0 : 1)}% · من ${DateFormat('dd MMM yyyy', 'ar').format(partnership.startDate)}${partnership.endDate != null ? ' إلى ${DateFormat('dd MMM yyyy', 'ar').format(partnership.endDate!)}' : ''}',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    Divider(color: AppTheme.cardBorder, height: 20),
                    Row(
                      children: [
                        _stat('إجمالي الحصص', totalShare, AppTheme.expenseRed),
                        const SizedBox(width: 10),
                        _stat('مدفوع', totalPaid, AppTheme.incomeGreen),
                        const SizedBox(width: 10),
                        _stat('مستحق', unpaid,
                            unpaid > 0
                                ? AppTheme.expenseRed
                                : AppTheme.incomeGreen),
                      ],
                    ),
                    if (unpaid > 0.01) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showBatchPaySheet(
                              context, provider, partner, unpaid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.flash_on, size: 16),
                          label: Text(
                            'سداد كافة المستحقات (${unpaid.formatted} ر.ي) بنقرة واحدة',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('النتائج (${results.length})',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (results.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                      child: Text('لا توجد نتائج في فترة هذه الشراكة',
                          style: TextStyle(color: AppTheme.textMuted))),
                )
              else
                ...results.map((r) => _resultTile(context, provider, r)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${value.formatted} ر.ي',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _resultTile(BuildContext context, FinanceProvider provider,
      ({Income income, Distribution dist}) r) {
    final inc = r.income;
    final d = r.dist;
    final isPaid = provider.isDistributionPaid(d);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isPaid ? AppTheme.incomeGreenDim : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isPaid
                  ? AppTheme.incomeGreen.withValues(alpha: 0.3)
                  : AppTheme.cardBorder),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.savings_outlined,
                color: AppTheme.accentBlue, size: 18),
          ),
          title: Text(inc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text(
              DateFormat('dd MMM yyyy', 'ar').format(inc.date) +
                  (isPaid
                      ? ' · مدفوع'
                      : ' · مستحق'),
              style: TextStyle(
                  color: isPaid ? AppTheme.incomeGreen : AppTheme.expenseRed,
                  fontSize: 10)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${d.amount.formatted} ر.ي',
                  style: TextStyle(
                    color: isPaid ? AppTheme.textMuted : AppTheme.expenseRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: isPaid ? TextDecoration.lineThrough : null,
                  )),
              if (!isPaid) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      showDistributionPaymentSheet(context, provider, d),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.incomeGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('دفع',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBatchPaySheet(BuildContext context, FinanceProvider provider,
      Partner? partner, double unpaidDues) {
    if (partner == null) return;
    DateTime date = DateTime.now();
    final fundingKey = GlobalKey<FundingPickerState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 16,
              ),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: AppTheme.incomeGreen, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سداد مستحقات الشراكة: ${partner.name}',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي المستحق: ${unpaidDues.formatted} ر.ي',
                      style: TextStyle(
                        color: AppTheme.incomeGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
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
                            Text(
                              DateFormat('dd MMM yyyy', 'ar').format(date),
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FundingPicker(
                      pickerKey: fundingKey,
                      provider: provider,
                      requiredTotal: unpaidDues,
                      requiredTotalGetter: () => unpaidDues,
                      autoAmount: unpaidDues,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final picker = fundingKey.currentState;
                          if (picker == null || !picker.validate()) {
                            return;
                          }
                          try {
                            provider.payAllPartnerDistributions(
                              partnerId: partner.id,
                              landPlotId: partnership.landPlotId,
                              date: date,
                              funding: picker.allocations,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'تم سداد كافة مستحقات ${partner.name} بنجاح'),
                                backgroundColor: AppTheme.incomeGreen,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ أثناء السداد: $e'),
                                backgroundColor: AppTheme.expenseRed,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.incomeGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'تأكيد سداد ${unpaidDues.formatted} ر.ي',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
