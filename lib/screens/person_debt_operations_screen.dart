import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_personal_debt_screen.dart';
import 'partner_statement_screen.dart';

/// شاشة عرض جميع عمليات الديون المرتبطة بشخص معين وفق النموذج التراكمي المباشر (له وعليه)
class PersonDebtOperationsScreen extends StatefulWidget {
  final String personId;
  final String? direction; // اختياري للتوافق

  const PersonDebtOperationsScreen({
    super.key,
    required this.personId,
    this.direction,
  });

  @override
  State<PersonDebtOperationsScreen> createState() =>
      _PersonDebtOperationsScreenState();
}

class _PersonDebtOperationsScreenState
    extends State<PersonDebtOperationsScreen> {
  String _filterType = 'all'; // 'all', 'debited', 'credited'
  bool _sortAscending = false; // false = newest first, true = oldest first
  String _searchQuery = ''; // بحث في الملاحظات أو المبالغ

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final person =
        provider.partners.firstWhereOrNull((p) => p.id == widget.personId);

    // جلب جميع ديون وسندات هذا الشخص
    final debts = provider.personalDebts
        .where((d) => d.personId == widget.personId)
        .toList();

    final debtMap = {for (final d in debts) d.id: d};
    final settlements = provider.personalDebtSettlements
        .where((s) => debtMap.containsKey(s.debtId))
        .toList();

    // حساب المجاميع المالية التراكمية لهذا الشخص
    double originalReceivable = 0; // ديون عليه لنا
    double originalPayable = 0;    // ديون له علينا
    double totalSettledByHim = 0; // سدادات منه
    double totalSettledToHim = 0; // سدادات له

    for (final d in debts) {
      final paid = provider.personalDebtPaid(d.id);
      if (d.direction == 'receivable') {
        originalReceivable += d.amount;
        totalSettledByHim += paid;
      } else {
        originalPayable += d.amount;
        totalSettledToHim += paid;
      }
    }

    // إجمالي ما عليه وإجمالي ما له تراكمياً
    final double totalDebited = originalReceivable + totalSettledToHim;
    final double totalCredited = originalPayable + totalSettledByHim;

    final double netBalance = totalDebited - totalCredited;
    final double netDifference = netBalance.abs();
    final bool isSettled = netDifference <= 0.001;

    final String statusText;
    final Color statusColor;
    final Color statusBg;
    final IconData statusIcon;

    if (isSettled) {
      statusText = 'خالص / متوازن';
      statusColor = AppTheme.incomeGreen;
      statusBg = AppTheme.incomeGreen.withValues(alpha: 0.12);
      statusIcon = Icons.check_circle_outline;
    } else if (netBalance > 0.001) {
      statusText = 'مدين (لنا عليه)';
      statusColor = AppTheme.incomeGreen;
      statusBg = AppTheme.incomeGreen.withValues(alpha: 0.12);
      statusIcon = Icons.arrow_downward;
    } else {
      statusText = 'دائن (له علينا)';
      statusColor = AppTheme.expenseRed;
      statusBg = AppTheme.expenseRed.withValues(alpha: 0.12);
      statusIcon = Icons.arrow_upward;
    }

    // تجميع كافة العمليات في سجل تراكمي موحد (له وعليه)
    final List<_DebtOperationItem> operations = [];

    for (final d in debts) {
      final isReceivable = d.direction == 'receivable';
      final wallet =
          provider.wallets.firstWhereOrNull((w) => w.id == d.walletId);
      String? fundingTag;
      if (d.funding.isNotEmpty) {
        final f = d.funding.first;
        final pay = provider.incomePayments
            .firstWhereOrNull((p) => p.id == f.paymentId);
        final inc =
            provider.incomes.firstWhereOrNull((i) => i.id == pay?.incomeId);
        fundingTag =
            inc != null ? 'ممولة من: ${inc.title}' : 'ممولة من دفعة إيراد';
      }

      operations.add(_DebtOperationItem(
        id: d.id,
        kind: _OpKind.debt,
        date: d.date,
        amount: d.amount,
        note: d.note,
        walletName: wallet?.name,
        fundingTag: fundingTag,
        direction: d.direction,
        isDebited: isReceivable, // عليه (مدين)
        debt: d,
      ));
    }

    for (final s in settlements) {
      final d = debtMap[s.debtId];
      final isReceiptFromHim = d?.direction == 'receivable';
      final isDebited = !isReceiptFromHim;
      final wallet =
          provider.wallets.firstWhereOrNull((w) => w.id == s.walletId);
      String? fundingTag;
      if (s.funding.isNotEmpty) {
        final f = s.funding.first;
        final pay = provider.incomePayments
            .firstWhereOrNull((p) => p.id == f.paymentId);
        final inc =
            provider.incomes.firstWhereOrNull((i) => i.id == pay?.incomeId);
        fundingTag =
            inc != null ? 'ممولة من: ${inc.title}' : 'ممولة من دفعة إيراد';
      }

      operations.add(_DebtOperationItem(
        id: s.id,
        kind: isReceiptFromHim ? _OpKind.receipt : _OpKind.payment,
        date: s.date,
        amount: s.amount,
        note: s.note,
        walletName: wallet?.name,
        fundingTag: fundingTag,
        direction: d?.direction,
        isDebited: isDebited,
        debt: d,
        settlement: s,
      ));
    }

    // الترتيب حسب التاريخ
    operations.sort((a, b) => _sortAscending
        ? a.date.compareTo(b.date)
        : b.date.compareTo(a.date));

    final debitedCount = operations.where((o) => o.isDebited).length;
    final creditedCount = operations.where((o) => !o.isDebited).length;

    // التصفية حسب الفلتر والبحث
    final filteredOps = operations.where((op) {
      if (_filterType == 'debited' && !op.isDebited) return false;
      if (_filterType == 'credited' && op.isDebited) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNote = (op.note ?? '').toLowerCase().contains(q);
        final matchAmount = op.amount.toString().contains(q);
        final matchWallet = (op.walletName ?? '').toLowerCase().contains(q);
        if (!matchNote && !matchAmount && !matchWallet) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person?.name ?? 'عمليات الحساب',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              'حساب تراكمي (له وعليه)',
              style: TextStyle(
                fontSize: 11,
                color: context.dynamicTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'كشف حساب تفصيلي',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PartnerStatementScreen(
                    partnerId: widget.personId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'إضافة عملية جديدة',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPersonalDebtScreen(
                    initialPersonId: widget.personId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // كرت ملخص الحساب التراكمي
                _buildHeaderSummaryCard(
                  context: context,
                  person: person,
                  totalDebited: totalDebited,
                  totalCredited: totalCredited,
                  netBalance: netBalance,
                  netDifference: netDifference,
                  isSettled: isSettled,
                  statusText: statusText,
                  statusColor: statusColor,
                  statusBg: statusBg,
                  statusIcon: statusIcon,
                  operationsCount: operations.length,
                ),
                const SizedBox(height: 14),

                // شريط البحث المباشر
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.dynamicSurfaceBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.dynamicCardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: TextStyle(
                        color: context.dynamicTextPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'بحث في العمليات، الملاحظات، المبالغ...',
                      hintStyle: TextStyle(
                          color: context.dynamicTextMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 19, color: context.dynamicTextMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // شريط أدوات التصفية والترتيب
                Row(
                  children: [
                    Text(
                      'سجل العمليات (${filteredOps.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: context.dynamicTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    // زر الترتيب
                    InkWell(
                      onTap: () =>
                          setState(() => _sortAscending = !_sortAscending),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.dynamicSurfaceBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.dynamicCardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 14,
                              color: AppTheme.accentBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortAscending ? 'الأقدم أولاً' : 'الأحدث أولاً',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.dynamicTextSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // شرائح تصفية نوع العمليات التراكمية
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'الكل (${operations.length})'),
                      const SizedBox(width: 6),
                      _filterChip(
                        'debited',
                        'عليه / مدين ($debitedCount)',
                        color: AppTheme.expenseRed,
                      ),
                      const SizedBox(width: 6),
                      _filterChip(
                        'credited',
                        'له / دائن ($creditedCount)',
                        color: AppTheme.incomeGreen,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // قائمة العمليات
                if (filteredOps.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48,
                            color: context.dynamicTextMuted
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'لا توجد عمليات مطابقة للبحث'
                              : 'لا توجد حركات مسجلة لهذا الشخص',
                          style: TextStyle(
                            color: context.dynamicTextSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() => _searchQuery = ''),
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('مسح البحث',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ...filteredOps.map((op) => _buildOperationItemCard(
                        context: context,
                        provider: provider,
                        op: op,
                        personName: person?.name ?? 'الشخص',
                      )),
              ],
            ),
          ),

          // شريط الأزرار السفلية (دفع له / استلام منه)
          _buildBottomActionButtons(context, person),
        ],
      ),
    );
  }

  Widget _filterChip(
    String type,
    String label, {
    Color? color,
  }) {
    final isSelected = _filterType == type;
    final baseColor = color ?? AppTheme.accentBlue;

    return InkWell(
      onTap: () => setState(() => _filterType = type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? baseColor.withValues(alpha: 0.15)
              : context.dynamicSurfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? baseColor : context.dynamicCardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? baseColor : context.dynamicTextSecondary,
          ),
        ),
      ),
    );
  }

  /// كرت ملخص الحساب التراكمي في أعلى الشاشة
  Widget _buildHeaderSummaryCard({
    required BuildContext context,
    required Partner? person,
    required double totalDebited,
    required double totalCredited,
    required double netBalance,
    required double netDifference,
    required bool isSettled,
    required String statusText,
    required Color statusColor,
    required Color statusBg,
    required IconData statusIcon,
    required int operationsCount,
  }) {
    final name = person?.name ?? 'غير معروف';

    final double balanceRatio;
    if (isSettled) {
      balanceRatio = 1.0;
    } else {
      final maxVal = max(totalDebited, totalCredited);
      final minVal = min(totalDebited, totalCredited);
      balanceRatio = maxVal > 0.001 ? (minVal / maxVal).clamp(0.0, 1.0) : 1.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.25),
                        statusColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name.characters.first : '؟',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: context.dynamicTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (person?.phone != null &&
                              person!.phone!.isNotEmpty) ...[
                            Icon(Icons.phone_outlined,
                                size: 13, color: context.dynamicTextMuted),
                            const SizedBox(width: 4),
                            Text(
                              person.phone!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.dynamicTextSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            '$operationsCount عملية مسجلة',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.dynamicTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // شريط الصافي التراكمي
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'صافي الرصيد المستحق',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.dynamicTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${netDifference.formattedFull} ر.ي',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSettled
                              ? context.dynamicTextMuted
                              : statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.dynamicScaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.dynamicCardBorder),
                  ),
                  child: Text(
                    isSettled
                        ? 'رصيد متعادل / خالص'
                        : (netBalance > 0.001
                            ? 'مستحق لنا (${netDifference.formattedFull} ر.ي)'
                            : 'مستحق له (${netDifference.formattedFull} ر.ي)'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSettled
                          ? AppTheme.incomeGreen
                          : statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // تفصيل ما له وما عليه تراكمياً
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // دائن (له علينا)
                Expanded(
                  child: _metricBox(
                    context: context,
                    label: 'دائن (له علينا)',
                    value: '${totalCredited.formattedFull} ر.ي',
                    subtitle: 'إجمالي ما قُيد له / سُدد منه',
                    valueColor: totalCredited > 0.001
                        ? AppTheme.expenseRed
                        : context.dynamicTextMuted,
                    icon: Icons.arrow_upward_rounded,
                    iconColor: AppTheme.expenseRed,
                  ),
                ),
                const SizedBox(width: 10),

                // مدين (لنا عليه)
                Expanded(
                  child: _metricBox(
                    context: context,
                    label: 'مدين (لنا عليه)',
                    value: '${totalDebited.formattedFull} ر.ي',
                    subtitle: 'إجمالي ما قُيد عليه / دُفع له',
                    valueColor: totalDebited > 0.001
                        ? AppTheme.incomeGreen
                        : context.dynamicTextMuted,
                    icon: Icons.arrow_downward_rounded,
                    iconColor: AppTheme.incomeGreen,
                  ),
                ),
              ],
            ),
          ),

          // مؤشر توازن الحساب
          if (totalDebited > 0.001 || totalCredited > 0.001) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isSettled
                            ? 'حالة التوازن والمطابقة'
                            : (netBalance > 0.001
                                ? 'نسبة ما تم سداده وتغطيته'
                                : 'نسبة ما تم صرفه وتغطيته'),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.dynamicTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isSettled
                            ? '100% متوازن وخالص'
                            : '${(balanceRatio * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSettled
                              ? AppTheme.incomeGreen
                              : statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: balanceRatio,
                      backgroundColor: context.dynamicCardBorder,
                      valueColor: AlwaysStoppedAnimation(
                        isSettled ? AppTheme.incomeGreen : statusColor,
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _metricBox({
    required BuildContext context,
    required String label,
    required String value,
    required String subtitle,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.dynamicTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: context.dynamicTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء كرت العملية التراكمية المفردة (عليه / له)
  Widget _buildOperationItemCard({
    required BuildContext context,
    required FinanceProvider provider,
    required _DebtOperationItem op,
    required String personName,
  }) {
    final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(op.date);
    final isDebited = op.isDebited; // true = عليه (مدين), false = له (دائن)
    final color = isDebited ? AppTheme.expenseRed : AppTheme.incomeGreen;
    final icon = isDebited
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final title = isDebited ? 'عليه (مدين)' : 'له (دائن)';
    final subtitle = isDebited
        ? (op.kind == _OpKind.debt ? 'قيد دين / تسليف' : 'سند صرف ودفع')
        : (op.kind == _OpKind.debt
            ? 'قيد استلام / التزام'
            : 'سند استلام وسداد');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط العنوان
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(color: context.dynamicCardBorder),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '•  $subtitle',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.dynamicTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$dateStr  •  ${op.walletName ?? "المحفظة الافتراضية"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.dynamicTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isDebited ? '-' : '+'}${op.amount.formattedFull} ر.ي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),

            // تفاصيل العملية
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (op.fundingTag != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined,
                              size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              op.fundingTag!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (op.note != null && op.note!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.dynamicScaffoldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Text(
                        op.note!,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.dynamicTextSecondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // شريط الإجراءات: تعديل وحذف
                  Row(
                    children: [
                      const Spacer(),
                      if (op.debt != null) ...[
                        IconButton(
                          tooltip: 'تعديل العملية',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddPersonalDebtScreen(
                                  initialPersonId: widget.personId,
                                  existingDebt: op.debt,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: context.dynamicTextSecondary),
                        ),
                        IconButton(
                          tooltip: 'حذف العملية',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _confirmDeleteDebt(context, provider, op.debt!),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.redAccent),
                        ),
                      ] else if (op.settlement != null) ...[
                        IconButton(
                          tooltip: 'حذف السند',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmDeleteSettlement(
                              context, provider, op.settlement!),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- شريط الأزرار السفلية (دفع له / استلام منه) ---
  Widget _buildBottomActionButtons(
    BuildContext context,
    Partner? person,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.dynamicSurfaceBg,
        border: Border(
          top: BorderSide(color: context.dynamicCardBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // زر دفع له (عليه / مدين)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _showPaymentSheet(context, person),
              icon: const Icon(Icons.arrow_upward_rounded, size: 19),
              label: const Text(
                'دفع له (عليه)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // زر استلام منه (له / دائن)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9768),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _showReceiptSheet(context, person),
              icon: const Icon(Icons.arrow_downward_rounded, size: 19),
              label: const Text(
                'استلام منه (له)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- نافذة تسجيل عملية دفع له (عليه) ---
  void _showPaymentSheet(
    BuildContext context,
    Partner? person,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicSurfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PaymentActionSheet(
        personId: widget.personId,
        personName: person?.name ?? 'الشخص',
      ),
    );
  }

  // --- نافذة تسجيل عملية استلام منه (له) ---
  void _showReceiptSheet(
    BuildContext context,
    Partner? person,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicSurfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReceiptActionSheet(
        personId: widget.personId,
        personName: person?.name ?? 'الشخص',
      ),
    );
  }

  Future<void> _confirmDeleteDebt(
      BuildContext context, FinanceProvider provider, PersonalDebt debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العملية'),
        content: const Text(
            'هل تريد بالتأكيد حذف هذه العملية من سجل الحساب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final deleted = provider.deletePersonalDebt(debt.id);
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن حذف العملية لأنها مرتبطة بسجلات أخرى'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف العملية بنجاح')),
      );
    }
  }

  Future<void> _confirmDeleteSettlement(BuildContext context,
      FinanceProvider provider, PersonalDebtSettlement settlement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السند'),
        content: const Text('هل تريد بالتأكيد حذف هذا السند من سجل الحساب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final deleted = provider.deletePersonalDebtSettlement(settlement.id);
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن حذف السند لأنه مرتبط بعملية مالية أخرى'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف السند بنجاح')),
      );
    }
  }
}

enum _OpKind { debt, receipt, payment }

class _DebtOperationItem {
  final String id;
  final _OpKind kind;
  final DateTime date;
  final double amount;
  final String? note;
  final String? walletName;
  final String? fundingTag;
  final String? direction;
  final bool isDebited; // true = عليه (مدين), false = له (دائن)
  final PersonalDebt? debt;
  final PersonalDebtSettlement? settlement;

  _DebtOperationItem({
    required this.id,
    required this.kind,
    required this.date,
    required this.amount,
    required this.isDebited,
    this.note,
    this.walletName,
    this.fundingTag,
    this.direction,
    this.debt,
    this.settlement,
  });
}

/// نموذج تسجيل عملية دفع له (عليه / مدين)
class _PaymentActionSheet extends StatefulWidget {
  final String personId;
  final String personName;

  const _PaymentActionSheet({
    required this.personId,
    required this.personName,
  });

  @override
  State<_PaymentActionSheet> createState() => _PaymentActionSheetState();
}

class _PaymentActionSheetState extends State<_PaymentActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fundingKey = GlobalKey<FundingPickerState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _selectedWalletId;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final enteredAmount = tryParseFlexible(_amountCtrl.text) ?? 0;

    if (_selectedWalletId == null && provider.wallets.isNotEmpty) {
      _selectedWalletId = provider.wallets.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
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
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.arrow_upward,
                        size: 16, color: Color(0xFFE53935)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دفع مالي إلى ${widget.personName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'حركة (عليه / مدين) تُخصم من المحفظة وتُسجل في حسابه',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.dynamicTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // حقل المبلغ
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'مبلغ الدفع',
                  suffixText: 'ر.ي',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final parsed = tryParseFlexible(v ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // اختيار المحفظة
              DropdownButtonFormField<String>(
                value: _selectedWalletId,
                decoration: const InputDecoration(
                  labelText: 'المحفظة المسحوب منها',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: provider.wallets
                    .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text('${w.name} (${provider.walletBalance(w.id).formatted} ر.ي)'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedWalletId = v),
                validator: (v) => v == null ? 'يرجى اختيار المحفظة' : null,
              ),
              const SizedBox(height: 12),

              // مصدر التمويل
              FundingPicker(
                provider: provider,
                pickerKey: _fundingKey,
                walletFilter: _selectedWalletId,
                requiredTotal: enteredAmount,
              ),
              const SizedBox(height: 12),

              // حقل التاريخ
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الدفع',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                      DateFormat('yyyy/MM/dd', 'ar').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 12),

              // ملاحظة
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'البيان / ملاحظة (اختياري)',
                  hintText: 'مثال: تسليف نقدي، دفعة حساب...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 18),

              // زر التأكيد
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    final amount = tryParseFlexible(_amountCtrl.text) ?? 0;
                    if (amount <= 0) return;

                    final funding =
                        _fundingKey.currentState?.allocations ?? [];
                    final sumFunding =
                        funding.fold(0.0, (s, a) => s + a.amount);
                    if ((sumFunding - amount).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'مجموع مصدر التمويل (${sumFunding.formatted} ر.ي) يجب أن يساوي مبلغ الدفع (${amount.formatted} ر.ي)'),
                      ));
                      return;
                    }

                    // تسجيل عملية الدفع مباشرة في كفة (عليه / مدين)
                    final newDebt = PersonalDebt(
                      id: const Uuid().v4(),
                      personId: widget.personId,
                      direction: 'receivable', // يدين لنا (عليه)
                      amount: amount,
                      date: _selectedDate,
                      walletId: _selectedWalletId!,
                      funding: funding,
                      note: _noteCtrl.text.isEmpty
                          ? 'دفع مالي إلى ${widget.personName}'
                          : _noteCtrl.text,
                    );
                    provider.addPersonalDebt(newDebt);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'تم تسجيل عملية الدفع (عليه) وخصمها من المحفظة بنجاح')),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text(
                    'تأكيد دفع المبلغ (عليه)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نموذج تسجيل عملية استلام منه (له / دائن)
class _ReceiptActionSheet extends StatefulWidget {
  final String personId;
  final String personName;

  const _ReceiptActionSheet({
    required this.personId,
    required this.personName,
  });

  @override
  State<_ReceiptActionSheet> createState() => _ReceiptActionSheetState();
}

class _ReceiptActionSheetState extends State<_ReceiptActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _selectedWalletId;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    if (_selectedWalletId == null && provider.wallets.isNotEmpty) {
      _selectedWalletId = provider.wallets.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
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
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.arrow_downward,
                        size: 16, color: Color(0xFF0D9768)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'استلام مالي من ${widget.personName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'حركة (له / دائن) تُودع في المحفظة وتُسجل في حسابه',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.dynamicTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // حقل المبلغ
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'مبلغ الاستلام',
                  suffixText: 'ر.ي',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final parsed = tryParseFlexible(v ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // المحفظة المودع فيها
              DropdownButtonFormField<String>(
                value: _selectedWalletId,
                decoration: const InputDecoration(
                  labelText: 'المحفظة المودع فيها (حساب الاستلام)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: provider.wallets
                    .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text('${w.name} (${provider.walletBalance(w.id).formatted} ر.ي)'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedWalletId = v),
                validator: (v) => v == null ? 'يرجى اختيار المحفظة' : null,
              ),
              const SizedBox(height: 12),

              // تاريخ الاستلام
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الاستلام',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                      DateFormat('yyyy/MM/dd', 'ar').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 12),

              // ملاحظة
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'البيان / ملاحظة (اختياري)',
                  hintText: 'مثال: سداد دفعة، استلام نقدي...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 18),

              // زر التأكيد
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9768),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    final amount = tryParseFlexible(_amountCtrl.text) ?? 0;
                    if (amount <= 0) return;

                    // تسجيل عملية الاستلام مباشرة في كفة (له / دائن)
                    final newDebt = PersonalDebt(
                      id: const Uuid().v4(),
                      personId: widget.personId,
                      direction: 'payable', // ندين له (له)
                      amount: amount,
                      date: _selectedDate,
                      walletId: _selectedWalletId!,
                      note: _noteCtrl.text.isEmpty
                          ? 'استلام مالي من ${widget.personName}'
                          : _noteCtrl.text,
                    );
                    provider.addPersonalDebt(newDebt);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'تم تسجيل عملية الاستلام (له) وإيداعها في المحفظة بنجاح')),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: const Text(
                    'تأكيد استلام المبلغ (له)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
