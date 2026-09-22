import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class WorkerDetailsScreen extends StatelessWidget {
  final Worker worker;
  const WorkerDetailsScreen({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(title: Text(worker.name)),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final wages = provider.wagesForWorker(worker.id)
            ..sort((a, b) => b.date.compareTo(a.date));
          final total = wages.fold(0.0, (s, e) => s + e.amount);
          // إجمالي تسديدات "ظهر الحساب" (الدفعات التراكمية المرتبطة بالعامل)
          final settlements = provider.moneyMovements
              .where((m) => m.creditorType == 'w' && m.creditorId == worker.id)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final settlementTotal = settlements.fold(0.0, (s, m) => s + m.amount);
          // المسدد = دفعات الأجور المباشرة + تسديدات ظهر الحساب التراكمية
          final paid =
              wages.fold(0.0, (s, e) => s + provider.paidForExpense(e.id)) +
                  settlementTotal;
          final netRemaining = provider.workerDebt(worker.id);

          final entries = <Map<String, dynamic>>[];
          for (final e in wages) {
            final event = provider.landEvents
                .firstWhereOrNull((ev) => ev.id == e.eventId);
            final plot = event == null
                ? null
                : provider.landPlots
                    .firstWhereOrNull((p) => p.id == event.landPlotId);
            final expPaid = provider.paidForExpense(e.id);
            final expRemaining =
                (e.amount - expPaid).clamp(0.0, double.infinity).toDouble();
            final payments = provider.expensePaymentsFor(e.id)
              ..sort((a, b) => b.date.compareTo(a.date));
            entries.add({
              'type': 'wage',
              'date': e.date,
              'expense': e,
              'event': event,
              'plot': plot,
              'expPaid': expPaid,
              'expRemaining': expRemaining,
              'payments': payments,
            });
          }
          for (final m in settlements) {
            final wallet =
                provider.wallets.firstWhereOrNull((w) => w.id == m.walletId);
            entries.add({
              'type': 'settlement',
              'date': m.date,
              'movement': m,
              'wallet': wallet,
            });
          }
          entries.sort((a, b) =>
              (b['date'] as DateTime).compareTo(a['date'] as DateTime));

          return ListView(
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.expenseRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.engineering,
                              color: AppTheme.expenseRed, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(worker.name,
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700)),
                              if (worker.phone != null)
                                Text(worker.phone!,
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (worker.notes != null && worker.notes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(worker.notes!,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statCard('إجمالي الأجور', total, AppTheme.accentBlue),
                  const SizedBox(width: 10),
                  _statCard('المسدد', paid, AppTheme.incomeGreen),
                  const SizedBox(width: 10),
                  _statCard(
                      'المتبقي عليه',
                      netRemaining,
                      netRemaining > 0
                          ? AppTheme.expenseRed
                          : AppTheme.textMuted),
                ],
              ),
              if (settlements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.incomeGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            AppTheme.incomeGreen.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                      'خصم فعات من ظهر الحساب: ${settlements.fold<double>(0, (s, m) => s + m.amount).formattedFull} ر.ي',
                      style: TextStyle(
                          color: AppTheme.incomeGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 20),
              Text('العمليات (${entries.length})',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          color: AppTheme.textMuted, size: 48),
                      SizedBox(height: 12),
                      Text('لا توجد عمليات أجور لهذا العامل',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              else
                ...entries.map((entry) {
                  if (entry['type'] == 'settlement') {
                    final m = entry['movement'] as MoneyMovement;
                    final wallet = entry['wallet'] as Wallet?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.incomeGreen
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.request_quote_outlined,
                                color: AppTheme.incomeGreen, size: 20),
                          ),
                          title: Text('فعة من ظهر الحساب',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          subtitle: Text(
                              [
                                DateFormat('dd MMM yyyy', 'ar')
                                    .format(m.date),
                                if (wallet != null) wallet.name,
                                if (m.note != null &&
                                    m.note!.isNotEmpty &&
                                    m.note !=
                                        'تسديد تراكمي من ظهر الحساب')
                                  m.note!,
                              ].join(' · '),
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11)),
                          trailing: Text(
                              '-${m.amount.formattedFull} ر.ي',
                              style: TextStyle(
                                  color: AppTheme.incomeGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    );
                  }

                  final e = entry['expense'] as Expense;
                  final event = entry['event'] as LandEvent?;
                  final plot = entry['plot'] as LandPlot?;
                  final expRemaining = entry['expRemaining'] as double;
                  final payments =
                      entry['payments'] as List<ExpensePayment>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          iconColor: AppTheme.textMuted,
                          collapsedIconColor: AppTheme.textMuted,
                          title: Text(
                              'أجر ${DateFormat('dd MMM yyyy', 'ar').format(e.date)}',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          subtitle: Text(
                              '${event?.eventType ?? '—'}${plot != null ? ' · ${plot.name}' : ''} · ${(e.wageDays ?? 0).plain} يوم × ${(e.wageRate ?? 0).formattedFull} ر.ي',
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${e.amount.formattedFull} ر.ي',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text(
                                  expRemaining > 0
                                      ? 'متبقي: ${expRemaining.formattedFull}'
                                      : 'مسدد',
                                  style: TextStyle(
                                      color: expRemaining > 0
                                          ? AppTheme.expenseRed
                                          : AppTheme.incomeGreen,
                                      fontSize: 11)),
                            ],
                          ),
                          children: [
                            if (payments.isEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text('لا توجد تسديدات',
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12)),
                              )
                            else
                              ...payments.map((p) {
                                final wallet = provider.wallets
                                    .firstWhereOrNull(
                                        (w) => w.id == p.walletId);
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                          Icons.payments_outlined,
                                          color:
                                              AppTheme.incomeGreen,
                                          size: 15),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                            'تسديد ${DateFormat('dd/MM/yyyy').format(p.date)}${wallet != null ? ' · ${wallet.name}' : ''}',
                                            style: TextStyle(
                                                color: AppTheme
                                                    .textSecondary,
                                                fontSize: 12)),
                                      ),
                                      Text(
                                          '+${p.amount.formattedFull} ر.ي',
                                          style: TextStyle(
                                              color: AppTheme
                                                  .incomeGreen,
                                              fontWeight:
                                                  FontWeight.w600,
                                              fontSize: 12)),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Text(label,
                style:
                    TextStyle(color: AppTheme.textMuted, fontSize: 10),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${value.formattedFull} ر.ي',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
