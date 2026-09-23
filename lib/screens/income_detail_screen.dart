import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'add_income_screen.dart';
import 'add_expense_screen.dart';
import 'edit_movement_sheet.dart';
import 'zakat_screen.dart';

class IncomeDetailScreen extends StatefulWidget {
  const IncomeDetailScreen({super.key, required this.incomeId});

  final String incomeId;
  @override
  State<IncomeDetailScreen> createState() => _IncomeDetailScreenState();
}

class _IncomeDetailScreenState extends State<IncomeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<FinanceProvider>()
          .ensureDistributionsForIncome(widget.incomeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final income =
            provider.incomes.firstWhere((i) => i.id == widget.incomeId);
        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: Text(income.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddIncomeScreen(existing: income))),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: AppTheme.expenseRed),
                onPressed: () =>
                    _confirmDelete(context, provider, income),
              ),
            ],
          ),
          body: CustomScrollView(
          slivers: [
            _buildIncomeHeader(context, income, provider),
            _buildSummaryRow(income, provider),
            _buildPaymentHeader(context, income, provider),
            _buildTransactionsList(context, income, provider),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: income.payments
                    .any((p) => provider.paymentAvailable(p.id) > 0)
                ? () => _openAddExpense(context, provider, income)
                : null,
            backgroundColor: income.payments
                    .any((p) => provider.paymentAvailable(p.id) > 0)
                ? AppTheme.expenseRed
                : AppTheme.textMuted,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('إضافة مصروف',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }

  Widget _buildIncomeHeader(BuildContext context, Income income, FinanceProvider provider) {
    String? landPlotName;
    if (income.landPlotId != null) {
      try {
        landPlotName = provider.landPlots
            .firstWhere((p) => p.id == income.landPlotId).name;
      } catch (_) {}
    }
    String? zahraName;
    if (income.zahraId != null) {
      try {
        final zahra = provider.zahras
            .firstWhere((z) => z.id == income.zahraId);
        try {
          final type = provider.zahraTypes
              .firstWhere((t) => t.id == zahra.typeId);
          zahraName = '${zahra.name} (${type.name})';
        } catch (_) {
          zahraName = zahra.name;
        }
      } catch (_) {}
    }
    final hasLocation = landPlotName != null || zahraName != null;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.incomeGreenDim, const Color(0xFF1A2A20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.incomeGreen.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.incomeGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(income.source,
                        style: TextStyle(
                            color: AppTheme.incomeGreen, fontSize: 12)),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd MMM yyyy', 'ar').format(income.date),
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
              if (hasLocation) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (landPlotName != null) ...[
                      Icon(Icons.terrain,
                          color: AppTheme.accentBlue, size: 14),
                      const SizedBox(width: 4),
                      Text(landPlotName,
                          style: TextStyle(
                              color: AppTheme.accentBlue, fontSize: 12)),
                    ],
                    if (zahraName != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.eco,
                          color: AppTheme.incomeGreen, size: 14),
                      const SizedBox(width: 4),
                      Text(zahraName,
                          style: TextStyle(
                              color: AppTheme.incomeGreen, fontSize: 12)),
                    ],
                  ],
                ),
              ],
              if (income.walletId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: AppTheme.accentBlue, size: 14),
                    const SizedBox(width: 4),
                    Text('المحفظة: ${provider.wallets.firstWhereOrNull((w) => w.id == income.walletId)?.name ?? 'محذوفة'}',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${income.amount.formattedFull} ر.ي',
                style: TextStyle(
                  color: AppTheme.incomeGreen,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              if (income.note != null) ...[
                const SizedBox(height: 8),
                Text(income.note!,
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 13)),
              ],
              if (income.landPlotId != null) ...[
                const SizedBox(height: 16),
                _buildBreakdown(income, provider),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdown(Income income, FinanceProvider provider) {
    LandPlot? plot;
    try {
      plot = provider.landPlots.firstWhere((p) => p.id == income.landPlotId);
    } catch (_) {}
    if (plot == null) return const SizedBox.shrink();
    final activePartnerships = provider.getActivePartnershipsForLandPlot(plot.id, income.date);
    if (!plot.hasZakat && activePartnerships.isEmpty) return const SizedBox.shrink();
    final b = computeIncomeBreakdown(income.amount, plot.hasZakat, activePartnerships);
    final dists = provider.getDistributionsForIncome(income.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _bdRow('إجمالي الزهرة', b.gross, AppTheme.textPrimary),
          if (b.zakat > 0) ...[
            _bdRow('الزكاة (5%)', -b.zakat, AppTheme.accentBlue),
            _zakatStatus(income, b.zakat, provider),
          ],
          if (b.partnerShares > 0) ...[
            for (final p in activePartnerships) ...[
              _bdRow(
                '${provider.partnershipTypeById(p.role)?.name ?? p.role}: ${_partnerName(provider, p.partnerId)}',
                -(b.afterZakat * p.sharePercentage / 100),
                AppTheme.accentBlue,
              ),
              _paidStatus(provider, dists, p.role),
            ],
          ],
          Divider(color: AppTheme.cardBorder, height: 12),
          _bdRow('صافي المالك', b.ownerNet, AppTheme.incomeGreen),
        ],
      ),
    );
  }

  Widget _zakatStatus(Income income, double zakatDue, FinanceProvider provider) {
    final paid = provider.zakatPaidForIncome(income.id);
    final remaining = (zakatDue - paid).clamp(0.0, double.infinity);

    if (remaining <= 0) {
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Spacer(),
            Icon(Icons.check_circle, color: AppTheme.incomeGreen, size: 12),
            SizedBox(width: 4),
            Text('خالصة بالكامل',
                style: TextStyle(color: AppTheme.incomeGreen, fontSize: 10)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const Spacer(),
          Icon(
            paid > 0 ? Icons.timelapse : Icons.schedule,
            color: paid > 0 ? Colors.orange : AppTheme.expenseRed,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            paid > 0
                ? 'مدفوع: ${paid.formatted} ر.ي (متبقي: ${remaining.formatted} ر.ي)'
                : 'غير مدفوعة (مستحقة في الذمة)',
            style: TextStyle(
              color: paid > 0 ? Colors.orange : AppTheme.expenseRed,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              showZakatPaymentDialog(
                context,
                provider,
                suggestedAmount: remaining,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.incomeGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'إخراج الآن',
                style: TextStyle(
                  color: AppTheme.incomeGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paidStatus(FinanceProvider provider, List<Distribution> dists, String role) {
    final d = dists.firstWhereOrNull((d) => d.role == role);
    if (d == null) return const SizedBox.shrink();
    if (provider.isDistributionPaid(d)) {
      final dateText = d.paidDate != null
          ? DateFormat('dd MMM', 'ar').format(d.paidDate!)
          : '';
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            const Spacer(),
            Icon(Icons.check_circle, color: AppTheme.incomeGreen, size: 12),
            const SizedBox(width: 4),
            Text('مدفوع $dateText',
                style: TextStyle(color: AppTheme.incomeGreen, fontSize: 10)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const Spacer(),
          Icon(Icons.schedule, color: AppTheme.expenseRed, size: 12),
          const SizedBox(width: 4),
          Text('غير مدفوع', style: TextStyle(color: AppTheme.expenseRed, fontSize: 10)),
        ],
      ),
    );
  }

  String _partnerName(FinanceProvider provider, String? id) {
    if (id == null) return '';
    try {
      return provider.partners.firstWhere((p) => p.id == id).name;
    } catch (_) {
      return '?';
    }
  }

  Widget _bdRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('${amount.formattedFull} ر.ي',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(Income income, FinanceProvider provider) {
    final disbursed = provider.disbursedForIncome(income.id);
    final totalSpent = income.totalExpenses + disbursed;
    final net = income.amount - totalSpent;
    final ratio = income.amount > 0 ? (totalSpent / income.amount) * 100 : 0;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(
          children: [
            Expanded(
                child: _tile('المصروفات والتصريفات',
                    '${totalSpent.formattedFull} ر.ي',
                    AppTheme.expenseRed)),
            const SizedBox(width: 10),
            Expanded(
                child: _tile(
                    'الصافي',
                    '${net.formattedFull} ر.ي',
                    net >= 0
                        ? AppTheme.incomeGreen
                        : AppTheme.expenseRed)),
            const SizedBox(width: 10),
            Expanded(
                child: _tile(
                    'نسبة الصرف',
                    '${ratio.toStringAsFixed(1)}%',
                    AppTheme.accentBlue)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHeader(BuildContext context, Income income, FinanceProvider provider) {
    final received = income.receivedAmount;
    final remaining = income.remainingAmount;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: income.status == 'confirmed'
                  ? AppTheme.incomeGreen.withValues(alpha: 0.4)
                  : AppTheme.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    income.status == 'confirmed' ? Icons.check_circle : Icons.pending,
                    color: income.status == 'confirmed' ? AppTheme.incomeGreen : Colors.orangeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    income.status == 'confirmed' ? 'مكتمل' : 'معلق',
                    style: TextStyle(
                      color: income.status == 'confirmed' ? AppTheme.incomeGreen : Colors.orangeAccent,
                      fontWeight: FontWeight.w700, fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _payTile('المبلغ', income.amount, AppTheme.incomeGreen),
                  const SizedBox(width: 8),
                  _payTile('المستلم', received, AppTheme.accentBlue),
                  const SizedBox(width: 8),
                  _payTile('المتبقي', remaining, remaining > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen),
                ],
              ),
              if (income.status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showAddPaymentSheet(context, provider, income),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('استلام دفعة',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final remaining = income.remainingAmount;
                          provider.addIncomePayment(IncomePayment(
                            id: const Uuid().v4(),
                            incomeId: income.id,
                            amount: remaining,
                            date: DateTime.now(),
                            notes: 'استلام بقية المبلغ',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'تم استلام ${remaining.formattedFull} ر.ي واعتماد الإيراد'),
                              backgroundColor: AppTheme.incomeGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: Text(
                            'بقية المبلغ (${income.remainingAmount.formattedFull})',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.incomeGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context, Income income, FinanceProvider provider) {
    final incomePaymentIds = income.payments.map((p) => p.id).toSet();
    final expenses = provider.getExpensesForIncome(income.id);

    final items = <_TransactionItem>[];
    for (final p in income.payments) {
      String? subtitle = p.notes;
      if (income.walletId != null) {
        final wallet =
            provider.wallets.firstWhereOrNull((w) => w.id == income.walletId);
        final walletName = wallet?.name ?? 'محفظة محذوفة';
        subtitle = subtitle != null ? '$walletName · $subtitle' : walletName;
      }
      final cur = p.currency;
      final rate = p.exchangeRate;
      final displayAmount = cur == baseCurrencyCode
          ? p.amount
          : fromYemeniEquivalent(p.amount, cur, rate);

      items.add(_TransactionItem(
        date: p.date,
        amount: displayAmount,
        type: 'payment',
        title: null,
        subtitle: subtitle,
        category: null,
        paymentId: p.id,
        currency: cur,
        exchangeRate: rate,
      ));
    }
    for (final e in expenses) {
      final relevantAllocations = e.allocations
          .where((a) =>
              a.incomeId == income.id ||
              (a.paymentId != null && incomePaymentIds.contains(a.paymentId)))
          .toList();
      final allocAmount = relevantAllocations.fold(0.0, (s, a) => s + a.amount);
      if (allocAmount > 0) {
        String itemCurrency = e.currency;
        double itemRate = e.exchangeRate;
        if (itemCurrency == baseCurrencyCode && relevantAllocations.isNotEmpty) {
          final allocCurrs = relevantAllocations.map((a) => a.currency).toSet();
          if (allocCurrs.length == 1 && allocCurrs.first != baseCurrencyCode) {
            final firstPayment = provider.incomePayments.firstWhereOrNull((pay) => pay.id == relevantAllocations.first.paymentId);
            if (firstPayment != null && firstPayment.exchangeRate > 0) {
              itemCurrency = firstPayment.currency;
              itemRate = firstPayment.exchangeRate;
            }
          }
        }
        final displayAmount = (itemCurrency != baseCurrencyCode && itemRate > 0)
            ? fromYemeniEquivalent(allocAmount, itemCurrency, itemRate)
            : allocAmount;

        items.add(_TransactionItem(
          date: e.date,
          amount: displayAmount,
          type: 'expense',
          title: e.title,
          subtitle: e.note,
          category: e.category,
          expense: e,
          currency: itemCurrency,
          exchangeRate: itemRate,
        ));
      }
    }
    for (final ep in provider.expensePayments.where((ep) =>
        ep.funding.any((a) =>
            a.incomeId == income.id ||
            (a.paymentId != null && incomePaymentIds.contains(a.paymentId))))) {
      final exp = provider.expenses.firstWhereOrNull((e) => e.id == ep.expenseId);
      final wallet = provider.wallets.firstWhereOrNull((w) => w.id == ep.walletId);
      final relevantFundings = ep.funding
          .where((a) =>
              a.incomeId == income.id ||
              (a.paymentId != null && incomePaymentIds.contains(a.paymentId)))
          .toList();
      final share = relevantFundings.fold(0.0, (s, a) => s + a.amount);
      final effectiveShare = share > 0 ? share : ep.amount;

      String epCurrency = baseCurrencyCode;
      double epRate = 1.0;
      if (relevantFundings.isNotEmpty) {
        final fCurrs = relevantFundings.map((a) => a.currency).toSet();
        if (fCurrs.length == 1 && fCurrs.first != baseCurrencyCode) {
          final firstP = provider.incomePayments.firstWhereOrNull((pay) => pay.id == relevantFundings.first.paymentId);
          if (firstP != null && firstP.exchangeRate > 0) {
            epCurrency = firstP.currency;
            epRate = firstP.exchangeRate;
          }
        }
      }
      final displayShare = (epCurrency != baseCurrencyCode && epRate > 0)
          ? fromYemeniEquivalent(effectiveShare, epCurrency, epRate)
          : effectiveShare;

      items.add(_TransactionItem(
        date: ep.date,
        amount: displayShare,
        type: 'expense_payment',
        title: exp != null ? 'سداد مصروف: ${exp.title}' : 'سداد مصروف',
        subtitle: [
          if (ep.notes != null && ep.notes!.isNotEmpty) ep.notes!,
          if (wallet != null) wallet.name,
        ].join(' · '),
        category: exp?.category ?? 'سداد مصروف',
        expensePaymentId: ep.id,
        currency: epCurrency,
        exchangeRate: epRate,
      ));
    }
    final seenMovementIds = <String>{};
    for (final m in provider.moneyMovements) {
      if (m.amount <= 0) continue;
      final isDirect = m.incomeId == income.id ||
          (m.paymentId != null && incomePaymentIds.contains(m.paymentId));
      final hasFunding = m.funding.any((a) =>
          a.incomeId == income.id ||
          (a.paymentId != null && incomePaymentIds.contains(a.paymentId)));

      if (!isDirect && !hasFunding) continue;
      if (!seenMovementIds.add(m.id)) continue;

      final wallet =
          provider.wallets.firstWhereOrNull((w) => w.id == m.walletId);
      final shareInYemeni = hasFunding
          ? m.funding
              .where((a) =>
                  a.incomeId == income.id ||
                  (a.paymentId != null && incomePaymentIds.contains(a.paymentId)))
              .fold(0.0, (s, a) => s + a.amount)
          : m.amount;

      final effectiveShareInYemeni = shareInYemeni > 0 ? shareInYemeni : m.amount;
      final displayAmount = m.currency == baseCurrencyCode
          ? effectiveShareInYemeni
          : fromYemeniEquivalent(effectiveShareInYemeni, m.currency, m.exchangeRate);

      String title = 'تصريف';
      String category = 'تصريف';

      if (m.distributionId != null) {
        title = 'تسديد حصة شريك';
        final dist = provider.distributions.firstWhereOrNull((d) => d.id == m.distributionId);
        if (dist != null) {
          final pName = provider.partners.firstWhereOrNull((p) => p.id == dist.partnerId)?.name;
          if (pName != null) title = 'تسديد حصة شريك · $pName';
        }
        category = 'حصص شركاء';
      } else if (m.purchaseId != null) {
        title = 'دفعة فاتورة شراء';
        final purchase = provider.purchases.firstWhereOrNull((p) => p.id == m.purchaseId);
        final pName = provider.partners.firstWhereOrNull((p) => p.id == purchase?.supplierId)?.name;
        if (pName != null) title = 'دفعة فاتورة شراء · $pName';
        category = 'مشتريات';
      } else if (m.creditorType != null) {
        title = 'دفعة من ظهر الحساب';
        final cName = m.creditorType == 'w'
            ? provider.workers.firstWhereOrNull((x) => x.id == m.creditorId)?.name
            : provider.partners.firstWhereOrNull((x) => x.id == m.creditorId)?.name;
        if (cName != null) title = 'دفعة من ظهر الحساب · $cName';
        category = 'ظهر الحساب';
      } else if (m.debtId != null) {
        final debt = provider.personalDebts.firstWhereOrNull((d) => d.id == m.debtId);
        final person = debt != null
            ? provider.partners.firstWhereOrNull((p) => p.id == debt.personId)
            : null;
        final pName = person?.name;
        title = pName != null ? 'دفع ديون وأقساط إلى $pName' : 'دفع ديون وأقساط';
        category = 'ديون وأقساط';
      } else if (m.zakatPaymentId != null) {
        title = m.note?.isNotEmpty == true ? m.note! : 'إخراج زكاة';
        category = 'زكاة';
      } else if (m.note != null && m.note!.isNotEmpty) {
        title = m.note!;
        category = wallet?.name ?? 'تصريف';
      } else if (wallet != null) {
        category = wallet.name;
      }

      final subtitleParts = [
        if (m.note != null && m.note!.isNotEmpty && m.note != title) m.note!,
        if (wallet != null) wallet.name,
      ];

      items.add(_TransactionItem(
        date: m.date,
        amount: displayAmount,
        type: 'disburse',
        title: title,
        subtitle: subtitleParts.isNotEmpty ? subtitleParts.join(' · ') : null,
        category: category,
        movementId: m.id,
        currency: m.currency,
        exchangeRate: m.exchangeRate,
      ));
    }
    for (final s in provider.personalDebtSettlements.where((s) =>
        s.funding.any((a) =>
            a.incomeId == income.id ||
            (a.paymentId != null && incomePaymentIds.contains(a.paymentId))))) {
      if (seenMovementIds.any((id) {
        final mov = provider.moneyMovements.firstWhereOrNull((m) => m.id == id);
        return mov?.debtId == s.debtId;
      })) {
        continue;
      }
      final debt = provider.personalDebts.firstWhereOrNull((d) => d.id == s.debtId);
      final person = debt != null ? provider.partners.firstWhereOrNull((p) => p.id == debt.personId) : null;
      final share = s.funding
          .where((a) =>
              a.incomeId == income.id ||
              (a.paymentId != null && incomePaymentIds.contains(a.paymentId)))
          .fold(0.0, (sum, a) => sum + a.amount);
      items.add(_TransactionItem(
        date: s.date,
        amount: share > 0 ? share : s.amount,
        type: 'disburse',
        title: person != null ? 'دفع ديون وأقساط إلى ${person.name}' : 'دفع ديون وأقساط',
        subtitle: s.note,
        category: 'ديون وأقساط',
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          final isPayment = item.type == 'payment';
          final isDisburse = item.type == 'disburse';
          final isExpensePayment = item.type == 'expense_payment';
          final color = isPayment ? AppTheme.incomeGreen : AppTheme.expenseRed;
          final icon = isPayment
              ? Icons.payments
              : (isExpensePayment
                  ? Icons.receipt_long
                  : (isDisburse ? Icons.outbox : Icons.arrow_upward_rounded));
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text('${item.amount.formattedFull} ${currencyLabel(item.currency)}',
                                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                            if (item.currency != baseCurrencyCode && item.exchangeRate > 0)
                              Text(
                                '(${toYemeniEquivalent(item.amount, item.currency, item.exchangeRate).formattedFull} ر.ي)',
                                style: TextStyle(
                                  color: color.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        if (item.title != null)
                          Text(item.title!, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                        Row(
                          children: [
                            Text(
                              isPayment
                                  ? 'دفعة'
                                  : (item.category ??
                                      (isDisburse
                                          ? 'تصريف'
                                          : (isExpensePayment
                                              ? 'سداد مصروف'
                                              : 'مصروف'))),
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                            ),
                            if (isPayment && item.paymentId != null) ...[
                              const SizedBox(width: 8),
                              () {
                                final availYemeni = provider.paymentAvailable(item.paymentId!);
                                final availDisplay = item.currency == baseCurrencyCode
                                    ? availYemeni
                                    : fromYemeniEquivalent(availYemeni, item.currency, item.exchangeRate);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlueDim,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'متاح: ${availDisplay.formattedFull} ${currencyLabel(item.currency)}',
                                    style: TextStyle(
                                      color: availYemeni > 0
                                          ? AppTheme.accentBlue
                                          : AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }(),
                            ],
                            const SizedBox(width: 8),
                            Text(DateFormat('dd MMM yyyy', 'ar').format(item.date),
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                          ],
                        ),
                        if (item.subtitle != null && item.subtitle!.isNotEmpty)
                          Text(item.subtitle!, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (item.type != 'disburse' || item.movementId != null || item.expensePaymentId != null)
                    PopupMenuButton<String>(
                      color: AppTheme.surface,
                      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
                      onSelected: (v) {
                        if (v == 'disburse') {
                          if (isPayment && item.paymentId != null) {
                            _showDisburseSheet(context, provider, income,
                                paymentId: item.paymentId);
                          }
                        }
                        if (v == 'edit') {
                          if (isPayment && item.paymentId != null) {
                            _showEditPaymentSheet(context, provider, income, item.paymentId!);
                          } else if (isDisburse && item.movementId != null) {
                            final movement = provider.moneyMovements
                                .firstWhereOrNull((m) => m.id == item.movementId);
                            if (movement != null) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24)),
                                ),
                                builder: (_) =>
                                    EditMovementSheet(movement: movement),
                              );
                            }
                          } else if (!isPayment && item.expense != null) {
                            _showAddSheet(context, income, provider, existing: item.expense);
                          }
                        }
                        if (v == 'delete') {
                          if (item.expensePaymentId != null) {
                            provider.deleteExpensePayment(item.expensePaymentId!);
                          } else if (isDisburse && item.movementId != null) {
                            _confirmDeleteMovement(context, provider, item.movementId!);
                          } else if (isPayment && item.paymentId != null) {
                            _confirmDeletePayment(context, provider, income, item.paymentId!);
                          } else if (!isPayment && item.expense != null) {
                            provider.deleteExpenseFromIncome(income.id, item.expense!.id);
                          }
                        }
                      },
                      itemBuilder: (_) {
                        return [
                          if (isPayment && item.paymentId != null)
                            PopupMenuItem(value: 'disburse',
                                child: ListTile(
                                  leading: Icon(Icons.outbox, color: AppTheme.expenseRed),
                                  title: Text('تصريف', style: TextStyle(color: AppTheme.expenseRed)),
                                  contentPadding: EdgeInsets.zero,
                                )),
                          if (isPayment || (isDisburse && item.movementId != null) || (!isPayment && item.expense != null))
                            PopupMenuItem(value: 'edit', child: Text('تعديل', style: TextStyle(color: AppTheme.textPrimary))),
                          PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed))),
                        ];
                      },
                    ),
                ],
              ),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _payTile(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('${amount.formattedFull} ر.ي',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }



  void _showAddSheet(
      BuildContext context, Income income, FinanceProvider provider,
      {Expense? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          existing: existing,
          initialIncomeId: income.id,
          initialPaymentId: income.payments
              .firstWhereOrNull((p) => provider.paymentAvailable(p.id) > 0)
              ?.id,
        ),
      ),
    );
  }

  void _openAddExpense(
      BuildContext context, FinanceProvider provider, Income income) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          initialIncomeId: income.id,
          initialPaymentId: income.payments
              .firstWhereOrNull((p) => provider.paymentAvailable(p.id) > 0)
              ?.id,
        ),
      ),
    );
  }

  void _showAddPaymentSheet(BuildContext context, FinanceProvider provider, Income income) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final exchangeRateController = TextEditingController(text: '1');
    String currency = baseCurrencyCode;
    DateTime date = DateTime.now();
    final formKey = GlobalKey<FormState>();
    String? selectedWalletId = income.walletId ?? provider.defaultWallet()?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final incomeWallet = provider.wallets.firstWhereOrNull((w) => w.id == (selectedWalletId ?? income.walletId));
          final rawAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
          final currentRate = double.tryParse(exchangeRateController.text.trim()) ?? 1.0;
          final equivYer = toYemeniEquivalent(rawAmount, currency, currentRate);

          return Padding(
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
                    Row(
                      children: [
                        Icon(Icons.payments, color: AppTheme.incomeGreen, size: 20),
                        const SizedBox(width: 8),
                        Text('استلام دفعة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('المتبقي المطلوب تحصيله: ${income.remainingAmount.formattedFull} ر.ي',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: AppTheme.incomeGreen, fontSize: 18, fontWeight: FontWeight.w700),
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              labelText: 'المبلغ المستلم *',
                              hintText: 'المبلغ',
                              suffixText: currencyLabel(currency),
                              prefixIcon: const Icon(Icons.attach_money),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'أدخل المبلغ';
                              final a = double.tryParse(v);
                              if (a == null || a <= 0) return 'مبلغ غير صحيح';
                              final rateVal = currency == baseCurrencyCode ? 1.0 : (double.tryParse(exchangeRateController.text) ?? 1.0);
                              final inYemeni = toYemeniEquivalent(a, currency, rateVal);
                              if (inYemeni > income.remainingAmount + 0.001) {
                                return 'المعادل (${inYemeni.formattedFull} ر.ي) يتجاوز المتبقي (${income.remainingAmount.formattedFull} ر.ي)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: currency,
                            decoration: const InputDecoration(
                              labelText: 'العملة',
                              prefixIcon: Icon(Icons.currency_exchange, size: 18),
                            ),
                            items: supportedCurrencyCodes
                                .map((code) => DropdownMenuItem(
                                      value: code,
                                      child: Text(currencyLabel(code)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setSheetState(() {
                                currency = val;
                                if (val == baseCurrencyCode) {
                                  exchangeRateController.text = '1';
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (currency != baseCurrencyCode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: exchangeRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'سعر الصرف مقابل الريال اليمني *',
                          helperText: 'يثبت سعر الصرف بتاريخ استلام الدفعة',
                          prefixIcon: Icon(Icons.price_change_outlined),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        validator: (value) {
                          final rate = double.tryParse(value ?? '');
                          if (rate == null || rate <= 0) return 'أدخل سعر صرف صحيح';
                          return null;
                        },
                      ),
                      if (rawAmount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlueDim,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'المبلغ المعادل باليمني: ${equivYer.formattedFull} ر.ي',
                                  style: TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                              colorScheme: ColorScheme.dark(primary: AppTheme.incomeGreen, surface: AppTheme.card),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 18),
                            const SizedBox(width: 12),
                            Text(DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                                style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (provider.wallets.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedWalletId,
                        decoration: const InputDecoration(
                          labelText: 'المحفظة المورد إليها النقد *',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        items: provider.wallets
                            .map((w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Text(w.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => selectedWalletId = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        hintText: 'ملاحظات (اختياري)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final entered = double.parse(amountController.text.trim());
                          final rate = currency == baseCurrencyCode
                              ? 1.0
                              : (double.tryParse(exchangeRateController.text.trim()) ?? 1.0);
                          final equivalentInYemeni = toYemeniEquivalent(entered, currency, rate);

                          if (income.walletId == null && selectedWalletId != null) {
                            income.walletId = selectedWalletId;
                            provider.updateIncome(income);
                          }

                          provider.addIncomePayment(IncomePayment(
                            id: const Uuid().v4(),
                            incomeId: income.id,
                            amount: equivalentInYemeni,
                            date: date,
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            walletId: selectedWalletId ?? income.walletId,
                            currency: currency,
                            exchangeRate: rate,
                          ));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.incomeGreen,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('حفظ الدفعة', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditPaymentSheet(BuildContext context, FinanceProvider provider, Income income, String paymentId) {
    final payment = income.payments.firstWhere((p) => p.id == paymentId);
    final committed = provider.totalExpensesForPayment(paymentId) +
        provider.disbursedForPayment(paymentId);
    final remaining =
        income.remainingAmount > 0 ? income.remainingAmount : 0.0;
    final maxIncrease = payment.amount + remaining;
    String currency = payment.currency;
    final exchangeRateController = TextEditingController(text: payment.exchangeRate.toString());
    final initialForeignAmount = payment.currency == baseCurrencyCode
        ? payment.amount
        : (payment.exchangeRate > 0 ? payment.amount / payment.exchangeRate : payment.amount);
    final amountController = TextEditingController(text: initialForeignAmount.formattedFull);
    final notesController = TextEditingController(text: payment.notes ?? '');
    DateTime date = payment.date;
    final formKey = GlobalKey<FormState>();
    String? selectedWalletId = payment.walletId ?? income.walletId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final rawAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
          final currentRate = double.tryParse(exchangeRateController.text.trim()) ?? 1.0;
          final equivYer = toYemeniEquivalent(rawAmount, currency, currentRate);

          return Padding(
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
                    Row(
                      children: [
                        Icon(Icons.payments, color: AppTheme.incomeGreen, size: 20),
                        const SizedBox(width: 8),
                        Text('تعديل الدفعة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: AppTheme.incomeGreen, fontSize: 18, fontWeight: FontWeight.w700),
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              labelText: 'المبلغ *',
                              hintText: 'المبلغ',
                              suffixText: currencyLabel(currency),
                              prefixIcon: const Icon(Icons.attach_money),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'أدخل المبلغ';
                              final a = double.tryParse(v);
                              if (a == null || a <= 0) return 'مبلغ غير صحيح';
                              final rateVal = currency == baseCurrencyCode ? 1.0 : (double.tryParse(exchangeRateController.text) ?? 1.0);
                              final inYemeni = toYemeniEquivalent(a, currency, rateVal);
                              if (inYemeni < committed - 0.001) {
                                return 'لا يمكن أن يقل عن الملتزم (${committed.formattedFull} ر.ي)';
                              }
                              if (inYemeni > maxIncrease + 0.001) {
                                return 'لا يمكن تجاوز سقف الإيراد (متاح للزيادة: ${remaining.formattedFull} ر.ي)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: currency,
                            decoration: const InputDecoration(
                              labelText: 'العملة',
                              prefixIcon: Icon(Icons.currency_exchange, size: 18),
                            ),
                            items: supportedCurrencyCodes
                                .map((code) => DropdownMenuItem(
                                      value: code,
                                      child: Text(currencyLabel(code)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setSheetState(() {
                                currency = val;
                                if (val == baseCurrencyCode) {
                                  exchangeRateController.text = '1';
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (currency != baseCurrencyCode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: exchangeRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'سعر الصرف مقابل الريال اليمني *',
                          helperText: 'يثبت سعر الصرف بتاريخ العملية',
                          prefixIcon: Icon(Icons.price_change_outlined),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        validator: (value) {
                          final rate = double.tryParse(value ?? '');
                          if (rate == null || rate <= 0) return 'أدخل سعر صرف صحيح';
                          return null;
                        },
                      ),
                      if (rawAmount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlueDim,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'المبلغ المعادل باليمني: ${equivYer.formattedFull} ر.ي',
                                  style: TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (committed > 0 || remaining > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        committed > 0 && remaining > 0
                            ? 'ملتزم: ${committed.formattedFull} ر.ي · متاح للزيادة: ${remaining.formattedFull} ر.ي'
                            : committed > 0
                                ? 'ملتزم بهذا المبلغ: ${committed.formattedFull} ر.ي (تصريفات ومصروفات)'
                                : 'متاح للزيادة: ${remaining.formattedFull} ر.ي',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
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
                              colorScheme: ColorScheme.dark(primary: AppTheme.incomeGreen, surface: AppTheme.card),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 18),
                            const SizedBox(width: 12),
                            Text(DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                                style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (provider.wallets.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedWalletId,
                        decoration: const InputDecoration(
                          labelText: 'المحفظة *',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        items: provider.wallets
                            .map((w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Text(w.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => selectedWalletId = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        hintText: 'ملاحظات (اختياري)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final entered = double.parse(amountController.text.trim());
                          final rate = currency == baseCurrencyCode
                              ? 1.0
                              : (double.tryParse(exchangeRateController.text.trim()) ?? 1.0);
                          final equivalentInYemeni = toYemeniEquivalent(entered, currency, rate);

                          provider.updateIncomePayment(IncomePayment(
                            id: paymentId,
                            incomeId: income.id,
                            amount: equivalentInYemeni,
                            date: date,
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            walletId: selectedWalletId ?? payment.walletId ?? income.walletId,
                            currency: currency,
                            exchangeRate: rate,
                          ));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.incomeGreen,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('تحديث الدفعة', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, FinanceProvider provider, Income income, String paymentId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الدفعة', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف هذه الدفعة؟', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              try {
                provider.deleteIncomePayment(paymentId);
                Navigator.pop(context);
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                );
              }
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMovement(BuildContext context, FinanceProvider provider, String movementId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف التصريف', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف سجل التصريف؟ سيعود المبلغ المتاح للتصريف.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final deleted = provider.deleteMoneyMovement(movementId);
              Navigator.pop(context);
              if (!deleted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا يمكن حذف هذه الحركة منفردة لأنها مرتبطة بعملية أخرى.')),
                );
              }
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }

  void _showDisburseSheet(
      BuildContext context, FinanceProvider provider, Income income,
      {String? paymentId}) {
    final incomeAvailableInYemeni = provider.incomeDisbursable(income.id);
    double maxAllowedInYemeni = incomeAvailableInYemeni;
    String title = 'تصريف من الإيراد';
    IncomePayment? targetPayment;

    if (paymentId != null) {
      targetPayment = income.payments.firstWhereOrNull((p) => p.id == paymentId);
      final paymentAvailableInYemeni = provider.paymentAvailable(paymentId);
      maxAllowedInYemeni = paymentAvailableInYemeni < incomeAvailableInYemeni
          ? paymentAvailableInYemeni
          : incomeAvailableInYemeni;
      title = 'تصريف من الدفعة';
    }

    final currency = targetPayment?.currency ?? baseCurrencyCode;
    final exchangeRate = targetPayment?.exchangeRate ?? 1.0;

    final maxAllowedDisplay = currency == baseCurrencyCode
        ? maxAllowedInYemeni
        : fromYemeniEquivalent(maxAllowedInYemeni, currency, exchangeRate);

    if (maxAllowedInYemeni <= 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('لا يوجد مبلغ متاح', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('لا يوجد مبلغ متاح للتصريف',
              style: TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً', style: TextStyle(color: AppTheme.accentBlue)),
            ),
          ],
        ),
      );
      return;
    }
    // تاريخ الدفعة لا يمكن أن يكون قبل تاريخ استلام الدفعة
    DateTime? paymentDate;
    if (paymentId != null) {
      final payment = income.payments.firstWhereOrNull((p) => p.id == paymentId);
      if (payment != null) paymentDate = payment.date;
    }
    final earliestDate = paymentDate ?? DateTime(2000);
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String inputCurrency = currency;
    DateTime date = paymentDate != null && DateTime.now().isBefore(paymentDate)
        ? paymentDate
        : DateTime.now();
    final formKey = GlobalKey<FormState>();
    // التصريف يتم من محفظة الإيراد نفسها (كل دفعات الإيراد بمحفظة واحدة)
    final sourceWallet = provider.wallets
        .firstWhereOrNull((w) => w.id == income.walletId);
    String? walletId = sourceWallet?.id ?? provider.defaultWallet()?.id;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.outbox, color: AppTheme.expenseRed, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('المتوفر للتصرف: ${maxAllowedDisplay.formattedFull} ${currencyLabel(currency)}',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                if (currency != baseCurrencyCode) ...[
                  const SizedBox(height: 2),
                  Text('سعر الصرف: ${exchangeRate.toStringAsFixed(exchangeRate.truncateToDouble() == exchangeRate ? 0 : 2)} (ما يعادل ${maxAllowedInYemeni.formattedFull} ر.ي)',
                      style: TextStyle(color: AppTheme.accentBlue, fontSize: 11)),
                ],
                const SizedBox(height: 16),
                if (currency != baseCurrencyCode) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: AppTheme.expenseRed, fontSize: 18, fontWeight: FontWeight.w700),
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'مبلغ التصريف (${currencyLabel(inputCurrency)}) *',
                            hintText: 'مبلغ التصريف',
                            prefixIcon: const Icon(Icons.attach_money),
                            suffixText: currencyLabel(inputCurrency),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'أدخل المبلغ';
                            final a = double.tryParse(v);
                            if (a == null || a <= 0) return 'مبلغ غير صحيح';
                            final inYemeni = inputCurrency == baseCurrencyCode
                                ? a
                                : toYemeniEquivalent(a, currency, exchangeRate);
                            if (inYemeni > maxAllowedInYemeni + 0.001) {
                              final allowedStr = inputCurrency == baseCurrencyCode
                                  ? '${maxAllowedInYemeni.formattedFull} ر.ي'
                                  : '${maxAllowedDisplay.formattedFull} ${currencyLabel(currency)}';
                              return 'يتجاوز المتوفر ($allowedStr)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: inputCurrency,
                          decoration: const InputDecoration(
                            labelText: 'العملة',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                          items: [
                            const DropdownMenuItem(
                              value: baseCurrencyCode,
                              child: Text('ر.ي (يمني)', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: currency,
                              child: Text('${currencyLabel(currency)} (أصل الدفعة)', style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                          onChanged: (newC) {
                            if (newC == null || newC == inputCurrency) return;
                            setSheetState(() {
                              final curVal = double.tryParse(amountController.text.trim());
                              if (curVal != null && curVal > 0 && exchangeRate > 0) {
                                if (newC == baseCurrencyCode) {
                                  amountController.text = toYemeniEquivalent(curVal, currency, exchangeRate).plain;
                                } else {
                                  amountController.text = fromYemeniEquivalent(curVal, currency, exchangeRate).plain;
                                }
                              }
                              inputCurrency = newC;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Builder(
                    builder: (_) {
                      final entered = double.tryParse(amountController.text.trim()) ?? 0;
                      if (entered <= 0 || exchangeRate <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            inputCurrency == baseCurrencyCode
                                ? 'يعادل: ${fromYemeniEquivalent(entered, currency, exchangeRate).formatted} ${currencyLabel(currency)} بالعملة الأصلية (سعر الصرف: ${exchangeRate.plain})'
                                : 'يعادل: ${toYemeniEquivalent(entered, currency, exchangeRate).formatted} ر.ي (سعر الصرف: ${exchangeRate.plain})',
                            style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppTheme.expenseRed, fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      labelText: 'مبلغ التصريف (ر.ي) *',
                      hintText: 'مبلغ التصريف',
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: 'ر.ي',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل المبلغ';
                      final a = double.tryParse(v);
                      if (a == null || a <= 0) return 'مبلغ غير صحيح';
                      if (a > maxAllowedDisplay + 0.001) {
                        return 'يتجاوز المتوفر (${maxAllowedDisplay.formattedFull} ر.ي)';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: earliestDate,
                      lastDate: DateTime(2100),
                      builder: (ctx, child) => Theme(
                        data: AppTheme.theme.copyWith(
                          colorScheme: ColorScheme.dark(primary: AppTheme.expenseRed, surface: AppTheme.card),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 18),
                        const SizedBox(width: 12),
                        Text(DateFormat('dd MMM yyyy', 'ar').format(date),
                            style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: AppTheme.accentBlue, size: 16),
                      const SizedBox(width: 8),
                      Text('من المحفظة: ${sourceWallet?.name ?? 'غير محددة'}',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLines: 2,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'سبب التصريف',
                    hintText: 'سبب التصريف (اختياري)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final enteredAmount = double.parse(amountController.text.trim());
                      final equivalentInYemeni = inputCurrency == baseCurrencyCode
                          ? enteredAmount
                          : toYemeniEquivalent(enteredAmount, currency, exchangeRate);
                      provider.addMoneyMovement(MoneyMovement(
                        id: const Uuid().v4(),
                        walletId: walletId!,
                        amount: equivalentInYemeni,
                        date: date,
                        incomeId: income.id,
                        paymentId: paymentId,
                        currency: currency,
                        exchangeRate: exchangeRate,
                        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                      ));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.expenseRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('تصريف', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, FinanceProvider provider, Income income) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الإيراد',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف "${income.title}" ومصروفاته؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              try {
                final deleted = provider.deleteIncome(income.id);
                if (!deleted) return;
                Navigator.pop(context);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                );
              }
            },
            child: Text('حذف',
                style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem {
  final DateTime date;
  final double amount;
  final String type;
  final String? title;
  final String? subtitle;
  final String? category;
  final String? paymentId;
  final String? movementId;
  final String? expensePaymentId;
  final Expense? expense;
  final String currency;
  final double exchangeRate;

  const _TransactionItem({
    required this.date,
    required this.amount,
    required this.type,
    this.title,
    this.subtitle,
    this.category,
    this.paymentId,
    this.movementId,
    this.expensePaymentId,
    this.expense,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  });
}
