import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets.dart';

class PartnerStatementScreen extends StatefulWidget {
  final String partnerId;
  final String? initialPlotId;

  const PartnerStatementScreen({
    super.key,
    required this.partnerId,
    this.initialPlotId,
  });

  @override
  State<PartnerStatementScreen> createState() => _PartnerStatementScreenState();
}

class _PartnerStatementScreenState extends State<PartnerStatementScreen> {
  String? _selectedPlotId;
  String _periodFilter = 'all'; // 'all', 'month', 'year'

  @override
  void initState() {
    super.initState();
    _selectedPlotId = widget.initialPlotId;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final partner =
            provider.partners.firstWhereOrNull((p) => p.id == widget.partnerId);

        if (partner == null) {
          return Scaffold(
            backgroundColor: context.dynamicScaffoldBg,
            appBar: AppBar(title: const Text('كشف حساب الشريك')),
            body: Center(
              child: Text('لم يتم العثور على بيانات الشريك',
                  style: TextStyle(color: AppTheme.textMuted)),
            ),
          );
        }

        // Gather all ledger transactions for this partner
        final ledgerEntries = _buildLedger(provider, partner);

        // Calculate Totals
        final totalShare = ledgerEntries
            .where((e) => e.isDistribution)
            .fold(0.0, (s, e) => s + e.credit);

        final totalPaid = ledgerEntries
            .where((e) => e.isDistribution && e.isPaid)
            .fold(0.0, (s, e) => s + e.credit);

        final unpaidDues = (totalShare - totalPaid).clamp(0.0, double.infinity);

        // Personal debts or other movements
        final otherDebits = ledgerEntries
            .where((e) => !e.isDistribution)
            .fold(0.0, (s, e) => s + e.debit);
        final otherCredits = ledgerEntries
            .where((e) => !e.isDistribution)
            .fold(0.0, (s, e) => s + e.credit);

        // Net balance: (what partner is owed) - (what partner owes)
        final netBalance = (totalShare + otherCredits) - (totalPaid + otherDebits);

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: Text('كشف حساب: ${partner.name}'),
            actions: [
              IconButton(
                icon: Icon(Icons.share, color: AppTheme.accentBlue),
                tooltip: 'نسخ ومشاركة كشف الحساب',
                onPressed: () => _shareStatement(
                    context, partner, ledgerEntries, totalShare, totalPaid, netBalance),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPartnerHeaderCard(partner, provider),
                const SizedBox(height: 12),
                _buildFilterBar(provider),
                const SizedBox(height: 12),
                _buildFinancialSummaryCards(
                    totalShare, totalPaid, unpaidDues, netBalance),
                if (unpaidDues > 0.01) ...[
                  const SizedBox(height: 14),
                  _buildOneClickPayoutBanner(
                      context, provider, partner, unpaidDues),
                ],
                const SizedBox(height: 20),
                _buildLedgerSection(context, provider, partner, ledgerEntries),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartnerHeaderCard(Partner partner, FinanceProvider provider) {
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
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlueDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person,
                    color: AppTheme.accentBlue, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (partner.phone != null && partner.phone!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone,
                              size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(partner.phone!,
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: 4,
                children: partner.roles.map((r) {
                  final label = r == 'client'
                      ? 'عميل'
                      : r == 'supplier'
                          ? 'مورد'
                          : r == 'worker'
                              ? 'عامل'
                              : r == 'water'
                                  ? 'سقيا'
                                  : r;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 10)),
                  );
                }).toList(),
              ),
            ],
          ),
          if (partner.notes != null && partner.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: AppTheme.cardBorder, height: 1),
            const SizedBox(height: 8),
            Text(
              'ملاحظات: ${partner.notes}',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar(FinanceProvider provider) {
    return Row(
      children: [
        // Plot Filter
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedPlotId,
                isExpanded: true,
                hint: Text('جميع المواضع',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('🌾 جميع المواضع',
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12)),
                  ),
                  ...provider.landPlots.map((p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text('🌱 ${p.name}',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12)),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedPlotId = v),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Period Filter
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _periodFilter,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('كل الفترات',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 12))),
                  DropdownMenuItem(
                      value: 'month',
                      child: Text('هذا الشهر',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 12))),
                  DropdownMenuItem(
                      value: 'year',
                      child: Text('هذا العام',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 12))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _periodFilter = v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryCards(double totalShare, double totalPaid,
      double unpaidDues, double netBalance) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'إجمالي نصيب الشريك',
                value: totalShare.formatted,
                unit: 'ر.ي',
                color: AppTheme.accentBlue,
                icon: Icons.pie_chart_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                title: 'المسدد والمستلم',
                value: totalPaid.formatted,
                unit: 'ر.ي',
                color: AppTheme.incomeGreen,
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unpaidDues > 0.01
                  ? AppTheme.accentBlue.withValues(alpha: 0.5)
                  : AppTheme.cardBorder,
              width: unpaidDues > 0.01 ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('صافي المستحقات المتبقية للشريك',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        unpaidDues.formatted,
                        style: TextStyle(
                          color: unpaidDues > 0.01
                              ? AppTheme.incomeGreen
                              : AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('ر.ي',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: unpaidDues > 0.01
                      ? AppTheme.incomeGreen.withValues(alpha: 0.15)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unpaidDues > 0.01 ? 'له مستحقات' : 'الحساب متوازن',
                  style: TextStyle(
                    color: unpaidDues > 0.01
                        ? AppTheme.incomeGreen
                        : AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 4),
              Text(unit,
                  style:
                      TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOneClickPayoutBanner(BuildContext context,
      FinanceProvider provider, Partner partner, double unpaidDues) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentBlue.withValues(alpha: 0.2),
            AppTheme.card,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flash_on, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سداد مستحقات الشريك بنقرة واحدة',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text('تسديد ${unpaidDues.formatted} ر.ي كاملة بضغطة زر',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showQuickPayoutSheet(
                context, provider, partner, unpaidDues),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('سداد الآن',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerSection(BuildContext context, FinanceProvider provider,
      Partner partner, List<_LedgerEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('سجل حركات الحساب التفصيلي',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text('${entries.length} حركة',
                style:
                    TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long, color: AppTheme.textMuted, size: 40),
                SizedBox(height: 10),
                Text('لا توجد حركات مسجلة لهذا الشريك في الفترة المحددة',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          )
        else
          ...entries.map((entry) => _ledgerTile(context, provider, entry)),
      ],
    );
  }

  Widget _ledgerTile(
      BuildContext context, FinanceProvider provider, _LedgerEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: entry.isPaid
                  ? AppTheme.incomeGreen.withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entry.isPaid ? Icons.check_circle : Icons.hourglass_top,
              color: entry.isPaid ? AppTheme.incomeGreen : Colors.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                    Text(
                      '${entry.credit.formatted} ر.ي',
                      style: TextStyle(
                        color: entry.isPaid
                            ? AppTheme.incomeGreen
                            : AppTheme.accentBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat('yyyy/MM/dd', 'ar').format(entry.date),
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                    if (entry.plotName != null) ...[
                      const SizedBox(width: 6),
                      Text('• ${entry.plotName}',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ],
                ),
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(entry.notes!,
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
          if (entry.isDistribution && !entry.isPaid) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _paySingleDistribution(
                  context, provider, entry.distributionId!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlueDim,
                foregroundColor: AppTheme.accentBlue,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('دفع',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  void _paySingleDistribution(
      BuildContext context, FinanceProvider provider, String distributionId) {
    final d =
        provider.distributions.firstWhereOrNull((x) => x.id == distributionId);
    if (d == null) return;
    showDistributionPaymentSheet(context, provider, d);
  }

  void _showQuickPayoutSheet(BuildContext context, FinanceProvider provider,
      Partner partner, double unpaidDues) {
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
                            'سداد مجمع لمستحقات الشريك: ${partner.name}',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'إجمالي المستحق للسداد: ${unpaidDues.formatted} ر.ي',
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
                              landPlotId: _selectedPlotId,
                              date: date,
                              funding: picker.allocations,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'تم سداد مستحقات ${partner.name} بنجاح'),
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

  void _shareStatement(
      BuildContext context,
      Partner partner,
      List<_LedgerEntry> entries,
      double totalShare,
      double totalPaid,
      double netBalance) {
    final nowStr = DateFormat('yyyy/MM/dd', 'ar').format(DateTime.now());
    final buffer = StringBuffer();
    buffer.writeln('📄 *كشف حساب الشريك: ${partner.name}*');
    buffer.writeln('📅 تاريخ التقرير: $nowStr');
    if (partner.phone != null && partner.phone!.isNotEmpty) {
      buffer.writeln('📱 هاتف: ${partner.phone}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('💰 *الملخص المالي:*');
    buffer.writeln('• إجمالي الأرباح المستحقة: ${totalShare.formatted} ر.ي');
    buffer.writeln('• إجمالي المبالغ المسددة والمستلمة: ${totalPaid.formatted} ر.ي');
    buffer.writeln('• صافي الرصيد المتبقي له: ${(totalShare - totalPaid).formatted} ر.ي');
    buffer.writeln('--------------------------------');
    buffer.writeln('📋 *سجل العمليات:*');

    for (final e in entries) {
      final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(e.date);
      final statusStr = e.isPaid ? '✅ مسدد' : '⏳ معلق';
      buffer.writeln('- $dateStr: ${e.title} (${e.credit.formatted} ر.ي) - $statusStr');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('تطبيق إدارة المزارع والمالية');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ نص كشف الحساب للحافظة للمشاركة عبر واتساب'),
        backgroundColor: AppTheme.accentBlue,
      ),
    );
  }

  List<_LedgerEntry> _buildLedger(FinanceProvider provider, Partner partner) {
    final entries = <_LedgerEntry>[];

    // 1. Distributions
    final distributions = provider.distributions
        .where((d) => d.partnerId == partner.id)
        .toList();

    for (final d in distributions) {
      final inc = provider.incomes.firstWhereOrNull((i) => i.id == d.incomeId);
      final plot = inc?.landPlotId != null
          ? provider.landPlots.firstWhereOrNull((p) => p.id == inc!.landPlotId)
          : null;

      if (_selectedPlotId != null && inc?.landPlotId != _selectedPlotId) {
        continue;
      }

      final isPaid = provider.isDistributionPaid(d);
      final date = d.paidDate ?? inc?.date ?? DateTime.now();
      if (_matchesPeriod(date)) {
        entries.add(_LedgerEntry(
          date: date,
          title: 'حصة أرباح من: ${inc?.title ?? 'إيراد'}',
          credit: d.amount,
          debit: 0,
          isPaid: isPaid,
          isDistribution: true,
          distributionId: d.id,
          plotName: plot?.name,
          notes: isPaid
              ? 'تم التسديد بتاريخ ${d.paidDate != null ? DateFormat('yyyy/MM/dd', 'ar').format(d.paidDate!) : ''}'
              : 'في انتظار السداد',
        ));
      }
    }

    // Sort by date descending
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  bool _matchesPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_periodFilter) {
      case 'month':
        return date.year == now.year && date.month == now.month;
      case 'year':
        return date.year == now.year;
      default:
        return true;
    }
  }
}

class _LedgerEntry {
  final DateTime date;
  final String title;
  final double credit;
  final double debit;
  final bool isPaid;
  final bool isDistribution;
  final String? distributionId;
  final String? plotName;
  final String? notes;

  _LedgerEntry({
    required this.date,
    required this.title,
    required this.credit,
    required this.debit,
    required this.isPaid,
    this.isDistribution = false,
    this.distributionId,
    this.plotName,
    this.notes,
  });
}
