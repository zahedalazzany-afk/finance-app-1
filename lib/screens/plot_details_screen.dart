import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'income_detail_screen.dart';

class PlotDetailsScreen extends StatelessWidget {
  final LandPlot plot;
  const PlotDetailsScreen({super.key, required this.plot});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: Text(
          plot.name,
          style: TextStyle(
            color: context.dynamicTextPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final incomes = provider.incomes
              .where((i) => i.landPlotId == plot.id)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final events = provider.landEvents
              .where((e) => e.landPlotId == plot.id)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final works = provider.workRecords
              .where((w) => w.landPlotId == plot.id)
              .toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));
          final partnerships = provider.partnerships
              .where((p) => p.landPlotId == plot.id)
              .toList();

          final eventsCost = events.fold(
              0.0,
              (s, e) =>
                  s +
                  provider
                      .expensesForEvent(e.id)
                      .fold(0.0, (ss, ex) => ss + ex.amount));
          final laborCost = works.fold(0.0, (s, w) => s + w.totalAmount);
          final totalCosts = eventsCost + laborCost;
          final totalIncomeAmount = incomes.fold(0.0, (s, i) => s + i.amount);
          final netProfit = totalIncomeAmount - totalCosts;
          final profitMargin = totalIncomeAmount > 0
              ? (netProfit / totalIncomeAmount * 100)
              : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Plot Overview Hero Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.dynamicCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.dynamicCardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                            color: AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.terrain_rounded,
                              color: AppTheme.accentBlue, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plot.name,
                                style: TextStyle(
                                  color: context.dynamicTextPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    landPlotCategoryLabel(plot.category),
                                    style: TextStyle(
                                      color: context.dynamicTextSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(context, 'المساحة: ${plot.area.formatted} م²'),
                        _chip(context, '${plot.numPlots} أتلام/لبنة'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Net Profit Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: netProfit >= 0
                      ? AppTheme.incomeGreen.withValues(alpha: 0.08)
                      : AppTheme.expenseRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: netProfit >= 0
                        ? AppTheme.incomeGreen.withValues(alpha: 0.3)
                        : AppTheme.expenseRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              netProfit >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: netProfit >= 0
                                  ? AppTheme.incomeGreen
                                  : AppTheme.expenseRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'صافي ربحية الموضع',
                              style: TextStyle(
                                color: context.dynamicTextPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (netProfit >= 0
                                    ? AppTheme.incomeGreen
                                    : AppTheme.expenseRed)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            netProfit >= 0 ? 'ربح صافي' : 'عجز / خسارة',
                            style: TextStyle(
                              color: netProfit >= 0
                                  ? AppTheme.incomeGreen
                                  : AppTheme.expenseRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${netProfit >= 0 ? "+" : ""}${netProfit.formattedFull}',
                          style: TextStyle(
                            color: netProfit >= 0
                                ? AppTheme.incomeGreen
                                : AppTheme.expenseRed,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('ر.ي',
                              style: TextStyle(
                                color: context.dynamicTextSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                        const Spacer(),
                        if (totalIncomeAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'هامش الربح: ${profitMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: profitMargin >= 0
                                    ? AppTheme.incomeGreen
                                    : AppTheme.expenseRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _profitItem(
                              context,
                              'الإيرادات',
                              totalIncomeAmount.formattedFull,
                              AppTheme.incomeGreen),
                        ),
                        Container(
                            width: 1,
                            height: 28,
                            color: context.dynamicCardBorder),
                        Expanded(
                          child: _profitItem(
                              context,
                              'إجمالي التكاليف',
                              totalCosts.formattedFull,
                              AppTheme.expenseRed),
                        ),
                      ],
                    ),
                    if (totalCosts > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'تفصيل التكاليف: أحداث وعمليات (${eventsCost.formattedFull}) · عمالة (${laborCost.formattedFull})',
                        style: TextStyle(
                            color: context.dynamicTextMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Mini Stats Strip
              Row(
                children: [
                  _stat(context, 'الإيرادات', incomes.length.toString(),
                      AppTheme.incomeGreen),
                  const SizedBox(width: 8),
                  _stat(context, 'قيمة الإيرادات',
                      totalIncomeAmount.formattedFull, AppTheme.accentBlue),
                  const SizedBox(width: 8),
                  _stat(
                      context,
                      'الأحداث',
                      '${events.length} (${eventsCost.formattedFull})',
                      Colors.orange.shade800),
                ],
              ),

              _sectionTitle(context, 'الإيرادات (${incomes.length})',
                  Icons.trending_up_outlined),
              if (incomes.isEmpty)
                _empty(context, 'لا توجد إيرادات مرتبطة بهذا الموضع')
              else
                ...incomes.map((income) {
                  final fully = income.isFullyPaid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.dynamicCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                IncomeDetailScreen(incomeId: income.id),
                          ),
                        ),
                        title: Text(
                          income.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy', 'ar').format(income.date)} · مستلم ${income.receivedAmount.formattedFull}',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${income.amount.formattedFull} ر.ي',
                              style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              fully
                                  ? 'مكتمل'
                                  : 'متبقي ${income.remainingAmount.formattedFull}',
                              style: TextStyle(
                                color: fully
                                    ? AppTheme.incomeGreen
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              _sectionTitle(
                  context, 'الأحداث (${events.length})', Icons.event_note),
              if (events.isEmpty)
                _empty(context, 'لا توجد أحداث على هذا الموضع')
              else
                ...events.map((event) {
                  final exps = provider.expensesForEvent(event.id);
                  final wages = exps
                      .where((e) => e.workerId != null)
                      .fold(0.0, (s, e) => s + e.amount);
                  final other = exps
                      .where((e) => e.workerId == null)
                      .fold(0.0, (s, e) => s + e.amount);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.dynamicCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.eventType,
                                  style: TextStyle(
                                    color: context.dynamicTextPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormat('dd MMM yyyy', 'ar').format(event.date)} · أجور ${wages.formattedFull} · مصاريف ${other.formattedFull}',
                                  style: TextStyle(
                                    color: context.dynamicTextMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${(wages + other).formattedFull} ر.ي',
                            style: TextStyle(
                              color: AppTheme.expenseRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              _sectionTitle(context, 'سجل العمل (${works.length})',
                  Icons.work_history_outlined),
              if (works.isEmpty)
                _empty(context, 'لا توجد سجلات عمل على هذا الموضع')
              else
                ...works.map((w) {
                  final partner = provider.partners
                      .firstWhereOrNull((p) => p.id == w.partnerId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.dynamicCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partner?.name ?? 'عمل بدون عامل محدد',
                                  style: TextStyle(
                                    color: context.dynamicTextPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormat('dd/MM/yyyy').format(w.startTime)} · ${w.durationHours.plain} ساعة',
                                  style: TextStyle(
                                    color: context.dynamicTextMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (w.totalAmount > 0)
                            Text(
                              '${w.totalAmount.formattedFull} ر.ي',
                              style: TextStyle(
                                color: context.dynamicTextSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

              _sectionTitle(context, 'الشراكات (${partnerships.length})',
                  Icons.handshake_outlined),
              if (partnerships.isEmpty)
                _empty(context, 'لا توجد شراكات على هذا الموضع')
              else
                ...partnerships.map((p) {
                  final partner = provider.partners
                      .firstWhereOrNull((pt) => pt.id == p.partnerId);
                  final active = p.isActiveAt(DateTime.now());
                  final roleLabel =
                      provider.partnershipTypeById(p.role)?.name ?? p.role;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.dynamicCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${partner?.name ?? '؟'} · $roleLabel',
                                  style: TextStyle(
                                    color: context.dynamicTextPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'نسبة ${p.sharePercentage.toStringAsFixed(p.sharePercentage % 1 == 0 ? 0 : 1)}% · من ${DateFormat('dd/MM/yyyy').format(p.startDate)}${p.endDate != null ? ' إلى ${DateFormat('dd/MM/yyyy').format(p.endDate!)}' : ''}',
                                  style: TextStyle(
                                    color: context.dynamicTextMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (active
                                      ? AppTheme.incomeGreen
                                      : context.dynamicTextMuted)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              active ? 'نشطة' : 'منتهية',
                              style: TextStyle(
                                color: active
                                    ? AppTheme.incomeGreen
                                    : context.dynamicTextMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(BuildContext context, String text, {Color? color}) {
    final effectiveColor = color ?? context.dynamicTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color != null
              ? color.withValues(alpha: 0.3)
              : context.dynamicCardBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: effectiveColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _stat(
      BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.dynamicCardBorder),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: context.dynamicTextMuted, fontSize: 10),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: context.dynamicTextSecondary, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.dynamicTextMuted, fontSize: 12),
      ),
    );
  }

  Widget _profitItem(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: context.dynamicTextMuted, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          '$value ر.ي',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
