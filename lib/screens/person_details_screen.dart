import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'partner_statement_screen.dart';

/// يعرض كل العمليات المرتبطة بشخص (شريك): الشراكات، حصص الإيرادات،
/// الديون الشخصية وتسوياتها، والحركات المالية المرتبطة.
class PersonDetailsScreen extends StatelessWidget {
  final String personId;
  const PersonDetailsScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('عمليات وتفاصيل الشخص'),
        actions: [
          IconButton(
            icon: Icon(Icons.description_outlined, color: AppTheme.accentBlue),
            tooltip: 'كشف حساب الشريك',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PartnerStatementScreen(partnerId: personId),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final person =
              provider.partners.firstWhereOrNull((p) => p.id == personId);
          if (person == null) {
            return Center(
                child: Text('الشخص غير موجود أو تم حذفه',
                    style: TextStyle(color: context.dynamicTextMuted)));
          }

          final partnerships = provider.partnerships
              .where((p) => p.partnerId == personId)
              .toList();
          final distributions = provider.distributions
              .where((d) => d.partnerId == personId)
              .toList()
            ..sort((a, b) =>
                _incomeDate(provider, b).compareTo(_incomeDate(provider, a)));
          final debts = provider.personalDebts
              .where((d) => d.personId == personId)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final purchases = provider.purchases
              .where((p) => p.supplierId == personId)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final relatedMovements = _relatedMovements(
              provider, personId, debts, distributions, purchases);

          final totalDistributions =
              distributions.fold(0.0, (s, d) => s + d.amount);
          final paidDistributions = distributions
              .where((d) => _distributionIsPaid(provider, d))
              .fold(0.0, (s, d) => s + d.amount);
          final totalPurchases =
              purchases.fold(0.0, (s, p) => s + p.netAmount);
          final paidPurchases =
              purchases.fold(0.0, (s, p) => s + p.paidAmount) +
                  provider.creditorSettlementTotal('s', personId);
          final totalDebts = debts.fold(0.0, (s, d) => s + d.amount);
          final paidDebts =
              debts.fold(0.0, (s, d) => s + provider.personalDebtPaid(d.id));
          final totalOperations =
              totalDistributions + totalPurchases + totalDebts;
          final paidOperations = paidDistributions + paidPurchases + paidDebts;
          final balance = (totalOperations - paidOperations)
              .clamp(0.0, double.infinity)
              .toDouble();
          final hasRelated = partnerships.isNotEmpty ||
              distributions.isNotEmpty ||
              purchases.isNotEmpty ||
              debts.isNotEmpty ||
              relatedMovements.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(context, provider, person),
              const SizedBox(height: 14),
              Row(
                children: [
                  _stat(context, 'إجمالي المستحق (له)', totalOperations, AppTheme.expenseRed, Icons.arrow_upward_rounded),
                  const SizedBox(width: 8),
                  _stat(context, 'المسدد (عليه)', paidOperations, AppTheme.incomeGreen, Icons.arrow_downward_rounded),
                  const SizedBox(width: 8),
                  _stat(context, 'المتبقي', balance,
                      balance > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen, Icons.account_balance_wallet_outlined),
                ],
              ),
              const SizedBox(height: 18),
              if (!hasRelated)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.dynamicSurfaceBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.dynamicCardBorder),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          color: context.dynamicTextMuted, size: 48),
                      const SizedBox(height: 12),
                      Text('لا توجد عمليات مسجلة مرتبطة بهذا الشخص',
                          style: TextStyle(
                              color: context.dynamicTextMuted, fontSize: 13)),
                    ],
                  ),
                )
              else ...[
                if (partnerships.isNotEmpty) ...[
                  _sectionTitle(context, 'الشراكات (${partnerships.length})',
                      Icons.handshake_outlined, AppTheme.accentBlue),
                  ...partnerships
                      .map((part) => _partnershipTile(context, provider, part)),
                  const SizedBox(height: 12),
                ],
                if (distributions.isNotEmpty) ...[
                  _sectionTitle(context, 'حصص الإيرادات (${distributions.length})',
                      Icons.savings_outlined, AppTheme.expenseRed),
                  ...distributions
                      .map((d) => _distributionTile(context, provider, d)),
                  const SizedBox(height: 12),
                ],
                if (purchases.isNotEmpty) ...[
                  _sectionTitle(context, 'فواتير المورد (${purchases.length})',
                      Icons.receipt_long_outlined, Colors.amber[700] ?? Colors.amber),
                  ...purchases
                      .map((purchase) => _purchaseTile(context, provider, purchase)),
                  const SizedBox(height: 12),
                ],
                if (debts.isNotEmpty) ...[
                  _sectionTitle(context, 'الديون الشخصية (${debts.length})',
                      Icons.account_balance_outlined, Colors.teal),
                  ...debts.map((debt) => _debtTile(context, provider, debt)),
                  const SizedBox(height: 12),
                ],
                if (relatedMovements.isNotEmpty) ...[
                  _sectionTitle(context, 'الحركات المالية (${relatedMovements.length})',
                      Icons.swap_horiz, Colors.orange),
                  ...relatedMovements
                      .map((m) => _movementTile(context, provider, m)),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  DateTime _incomeDate(FinanceProvider provider, Distribution d) {
    final inc = provider.incomes.firstWhereOrNull((i) => i.id == d.incomeId);
    return inc?.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _distributionIsPaid(FinanceProvider provider, Distribution d) {
    return provider.isDistributionPaid(d);
  }

  List<MoneyMovement> _relatedMovements(
      FinanceProvider provider,
      String personId,
      List<PersonalDebt> debts,
      List<Distribution> distributions,
      List<Purchase> purchases) {
    final debtIds = debts.map((d) => d.id).toSet();
    final distributionIds = distributions.map((d) => d.id).toSet();
    final purchaseIds = purchases.map((p) => p.id).toSet();
    final result = provider.moneyMovements
        .where((m) =>
            m.creditorId == personId ||
            (m.debtId != null && debtIds.contains(m.debtId)) ||
            (m.distributionId != null &&
                distributionIds.contains(m.distributionId)) ||
            (m.purchaseId != null && purchaseIds.contains(m.purchaseId)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return {for (final movement in result) movement.id: movement}
        .values
        .toList();
  }

  Widget _header(
      BuildContext context, FinanceProvider provider, Partner person) {
    final isPartnerRole = (String r) => provider.partnershipTypeById(r) != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    person.name.isNotEmpty ? person.name.substring(0, 1) : '؟',
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name,
                        style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    if (person.phone != null && person.phone!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 12, color: context.dynamicTextMuted),
                          const SizedBox(width: 4),
                          Text(person.phone!,
                              style: TextStyle(
                                  color: context.dynamicTextSecondary, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: person.roles.map((r) {
              final isPart = isPartnerRole(r);
              final color = isPart ? AppTheme.incomeGreen : AppTheme.accentBlue;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Text(
                    personRoleLabel(r,
                        partnershipTypes: provider.partnershipTypes),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
          if (person.notes != null && person.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(person.notes!,
                style: TextStyle(
                    color: context.dynamicTextSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  color: context.dynamicTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.dynamicCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(label,
                      style: TextStyle(color: context.dynamicTextMuted, fontSize: 10, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text('${value.formatted} ر.ي',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnershipTile(
      BuildContext context, FinanceProvider provider, Partnership part) {
    final plot =
        provider.landPlots.firstWhereOrNull((p) => p.id == part.landPlotId);
    final roleLabel =
        provider.partnershipTypeById(part.role)?.name ?? part.role;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.dynamicCardBorder),
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
            child: Icon(Icons.handshake_outlined,
                color: AppTheme.accentBlue, size: 18),
          ),
          title: Text(plot?.name ?? 'موضع محذوف',
              style: TextStyle(
                  color: context.dynamicTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text(
              '$roleLabel · نسبة ${part.sharePercentage.toStringAsFixed(part.sharePercentage % 1 == 0 ? 0 : 1)}%',
              style: TextStyle(color: context.dynamicTextMuted, fontSize: 11)),
          isThreeLine: false,
        ),
      ),
    );
  }

  Widget _distributionTile(
      BuildContext context, FinanceProvider provider, Distribution d) {
    final inc = provider.incomes.firstWhereOrNull((i) => i.id == d.incomeId);
    final isPaid = _distributionIsPaid(provider, d);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isPaid ? AppTheme.incomeGreen.withValues(alpha: 0.08) : context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isPaid
                  ? AppTheme.incomeGreen.withValues(alpha: 0.3)
                  : context.dynamicCardBorder),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.expenseRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.savings_outlined,
                color: AppTheme.expenseRed, size: 18),
          ),
          title: Text(inc?.title ?? 'إيراد محذوف',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.dynamicTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text(
              '${inc != null ? DateFormat('dd MMM yyyy', 'ar').format(inc.date) : '—'} · ${isPaid ? 'مدفوع' : 'مستحق'}',
              style: TextStyle(
                  color: isPaid ? AppTheme.incomeGreen : AppTheme.expenseRed,
                  fontSize: 10)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${d.amount.formatted} ر.ي',
                  style: TextStyle(
                    color: isPaid ? context.dynamicTextMuted : AppTheme.expenseRed,
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
                    child: const Text('سداد الحصة',
                        style: TextStyle(
                            color: Colors.white,
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

  Widget _purchaseTile(BuildContext context, FinanceProvider provider, Purchase purchase) {
    final items = provider.purchaseItemsFor(purchase.id);
    final productsCount = items.length;
    final remaining = purchase.remainingAmount.clamp(0.0, double.infinity);
    final status = remaining <= 0.01
        ? 'مدفوعة'
        : purchase.paidAmount <= 0.01
            ? 'غير مدفوعة'
            : 'مدفوعة جزئياً';
    final statusColor = remaining <= 0.01
        ? AppTheme.incomeGreen
        : purchase.paidAmount <= 0.01
            ? AppTheme.expenseRed
            : Colors.amber[800] ?? Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.dynamicCardBorder),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt_long_outlined,
                color: Colors.amber[800] ?? Colors.amber, size: 18),
          ),
          title: Text(
            purchase.invoiceNumber?.isNotEmpty == true
                ? 'فاتورة ${purchase.invoiceNumber}'
                : 'فاتورة شراء',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: context.dynamicTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          subtitle: Text(
            '${DateFormat('dd MMM yyyy', 'ar').format(purchase.date)} · $status · $productsCount صنف · متبقي: ${remaining.formatted} ر.ي',
            style: TextStyle(color: statusColor, fontSize: 10),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                purchase.discount > 0
                    ? '${purchase.netAmount.formatted} ر.ي'
                    : '${purchase.totalAmount.formatted} ر.ي',
                style: TextStyle(
                    color: context.dynamicTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
              if (purchase.discount > 0)
                Text(
                  'خصم: ${purchase.discount.formatted}',
                  style: TextStyle(
                      color: AppTheme.incomeGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debtTile(
      BuildContext context, FinanceProvider provider, PersonalDebt debt) {
    final remaining = provider.personalDebtRemaining(debt.id);
    final isReceivable = debt.direction == 'receivable';
    final color = isReceivable ? AppTheme.expenseRed : AppTheme.accentBlue;
    final settlements = provider.settlementsForDebt(debt.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.dynamicCardBorder),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            iconColor: context.dynamicTextMuted,
            collapsedIconColor: context.dynamicTextMuted,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isReceivable ? Icons.arrow_forward : Icons.arrow_back,
                  color: color, size: 18),
            ),
            title: Text(
                '${isReceivable ? 'لنا عليه' : 'له علينا'} · ${DateFormat('dd MMM yyyy', 'ar').format(debt.date)}',
                style: TextStyle(
                    color: context.dynamicTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            subtitle: Text(
                '${debt.note ?? 'دين شخصي'} · متبقي: ${remaining.formatted} ر.ي',
                style:
                    TextStyle(color: context.dynamicTextMuted, fontSize: 11)),
            trailing: Text('${debt.amount.formatted} ر.ي',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            children: [
              if (settlements.isEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('لا توجد تسويات',
                      style:
                          TextStyle(color: context.dynamicTextMuted, fontSize: 12)),
                )
              else
                ...settlements.map((s) {
                  final wallet = provider.wallets
                      .firstWhereOrNull((w) => w.id == s.walletId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: AppTheme.incomeGreen, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              'تسديد ${DateFormat('dd/MM/yyyy').format(s.date)}${wallet != null ? ' · ${wallet.name}' : ''}',
                              style: TextStyle(
                                  color: context.dynamicTextSecondary, fontSize: 12)),
                        ),
                        Text('${s.amount.formatted} ر.ي',
                            style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontWeight: FontWeight.w600,
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
  }

  Widget _movementTile(
      BuildContext context, FinanceProvider provider, MoneyMovement m) {
    final wallet = provider.wallets.firstWhereOrNull((w) => w.id == m.walletId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.dynamicCardBorder),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.swap_horiz, color: Colors.orange, size: 18),
          ),
          title: Text(_movementLabel(provider, m),
              style: TextStyle(
                  color: context.dynamicTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text(
              [
                DateFormat('dd MMM yyyy', 'ar').format(m.date),
                if (wallet != null) wallet.name,
                if (m.note != null && m.note!.isNotEmpty) m.note!,
              ].join(' · '),
              style: TextStyle(color: context.dynamicTextMuted, fontSize: 11)),
          trailing: Text('${m.amount.formatted} ر.ي',
              style: TextStyle(
                  color: context.dynamicTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
      ),
    );
  }

  String _movementLabel(FinanceProvider provider, MoneyMovement m) {
    final parts = <String>[
      if (m.creditorType == 'w') 'سلفة عامل',
      if (m.creditorType == 's') 'دفعة مورد',
      if (m.distributionId != null) 'تسديد حصة شريك',
      if (m.debtId != null)
        (m.amount < 0 ? 'استلام ديون وأقساط' : 'دفع ديون وأقساط'),
    ];
    if (m.paymentId != null) parts.add('صرف مقترن بدفعة استلام');
    if (m.incomeId != null && m.distributionId == null) parts.add('إيراد');
    return parts.isNotEmpty ? parts.join(' · ') : 'حركة مالية';
  }
}
