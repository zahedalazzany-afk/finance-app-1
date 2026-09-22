import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/data_export_import_button.dart';

class DistributionsScreen extends StatefulWidget {
  const DistributionsScreen({super.key});

  @override
  State<DistributionsScreen> createState() => _DistributionsScreenState();
}

class _DistributionsScreenState extends State<DistributionsScreen> {
  String _filter = 'all'; // 'all', 'pending', 'paid', 'by_partner'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'water':
      case 'ساقي':
        return Colors.blue;
      case 'worker':
      case 'عامل':
        return Colors.amber.shade700;
      case 'partner':
      case 'شريك':
        return AppTheme.accentBlue;
      default:
        return Colors.teal;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'water':
      case 'ساقي':
        return Icons.water_drop_outlined;
      case 'worker':
      case 'عامل':
        return Icons.agriculture_outlined;
      case 'partner':
      case 'شريك':
        return Icons.handshake_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allDists = provider.distributions;

    final pendingDists = allDists.where((d) => !provider.isDistributionPaid(d)).toList();
    final paidDists = allDists.where((d) => provider.isDistributionPaid(d)).toList();
    final totalAmount = allDists.fold(0.0, (s, d) => s + d.amount);
    final paidAmount = provider.paidPartnerTotal;
    final pendingAmount = provider.pendingPartnerTotal;
    final progress = totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 1.0;

    // Filtered by status and search
    List<Distribution> filteredDists = allDists;
    if (_filter == 'pending') {
      filteredDists = pendingDists;
    } else if (_filter == 'paid') {
      filteredDists = paidDists;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filteredDists = filteredDists.where((d) {
        final partner = provider.partners.firstWhereOrNull((p) => p.id == d.partnerId);
        final income = provider.incomes.firstWhereOrNull((i) => i.id == d.incomeId);
        final roleLabel = provider.partnershipTypeById(d.role)?.name ?? d.role;
        return (partner?.name.toLowerCase().contains(q) ?? false) ||
            (income?.title.toLowerCase().contains(q) ?? false) ||
            roleLabel.toLowerCase().contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'توزيعات الشركاء والعاملين',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          DataExportImportButton(
            label: 'التوزيعات',
            buildRows: () => provider.distributions.map((e) => e.toJson()).toList(),
            csvHeaders: const [
              'الإيراد',
              'الشريك',
              'الدور',
              'المبلغ',
              'مدفوع',
              'تاريخ الدفع',
            ],
            csvKeys: const [
              'incomeId',
              'partnerId',
              'role',
              'amount',
              'isPaid',
              'paidDate',
            ],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final d = Distribution.fromJson(row);
                  if (provider.distributions.any((e) => e.id == d.id)) continue;
                  provider.addDistribution(d);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Financial KPI Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.12),
                  context.dynamicCardBg,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.dynamicCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Pending
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.expenseRed.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    color: AppTheme.expenseRed, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'المستحق (غير مدفوع)',
                                  style: TextStyle(
                                    color: context.dynamicTextSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${pendingAmount.formatted} ر.ي',
                              style: TextStyle(
                                color: AppTheme.expenseRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pendingDists.length} حصة بانتظار السداد',
                              style: TextStyle(
                                color: context.dynamicTextMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Paid
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.incomeGreen.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    color: AppTheme.incomeGreen, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'المسدد بالكامل',
                                  style: TextStyle(
                                    color: context.dynamicTextSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${paidAmount.formatted} ر.ي',
                              style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${paidDists.length} حصة تم دفعها',
                              style: TextStyle(
                                color: context.dynamicTextMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نسبة السداد التراكمية',
                      style: TextStyle(
                        color: context.dynamicTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: progress == 1.0
                            ? AppTheme.incomeGreen
                            : AppTheme.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: context.dynamicSurfaceBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? AppTheme.incomeGreen : AppTheme.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.dynamicCardBg,
                hintText: 'بحث باسم الشريك، المحصول، أو الموضع...',
                hintStyle:
                    TextStyle(color: context.dynamicTextMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.dynamicCardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.dynamicCardBorder),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          const SizedBox(height: 8),

          // Filter Segmented Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'الكل (${allDists.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'pending',
                  'المستحق (${pendingDists.length})',
                  activeColor: AppTheme.expenseRed,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'paid',
                  'المسدد (${paidDists.length})',
                  activeColor: AppTheme.incomeGreen,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'by_partner',
                  'تجميع حسب الشركاء',
                  icon: Icons.people_alt_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Body Content
          Expanded(
            child: _filter == 'by_partner'
                ? _buildGroupedByPartnerView(context, provider, allDists)
                : _buildDistributionListView(
                    context, provider, filteredDists),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String key,
    String label, {
    Color? activeColor,
    IconData? icon,
  }) {
    final effectiveColor = activeColor ?? AppTheme.accentBlue;
    final isSel = _filter == key;
    return ChoiceChip(
      avatar: icon != null
          ? Icon(icon,
              size: 16,
              color: isSel ? effectiveColor : context.dynamicTextSecondary)
          : null,
      label: Text(label),
      selected: isSel,
      selectedColor: effectiveColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: isSel ? effectiveColor : context.dynamicTextSecondary,
        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSel ? effectiveColor : context.dynamicCardBorder,
      ),
      backgroundColor: context.dynamicCardBg,
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  // ==================== LIST VIEW (CHRONOLOGICAL) ====================

  Widget _buildDistributionListView(
    BuildContext context,
    FinanceProvider provider,
    List<Distribution> dists,
  ) {
    if (dists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined,
                  color: context.dynamicTextMuted, size: 56),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'لا توجد توزيعات مطابقة للبحث'
                    : 'لا توجد توزيعات مسجلة في هذا القسم',
                style: TextStyle(
                  color: context.dynamicTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group distributions by Date
    final byDate = <DateTime, List<Distribution>>{};
    for (final d in dists) {
      final inc =
          provider.incomes.firstWhereOrNull((i) => i.id == d.incomeId);
      final date = DateTime(
          inc?.date.year ?? 2000, inc?.date.month ?? 1, inc?.date.day ?? 1);
      byDate.putIfAbsent(date, () => []).add(d);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: dates.length,
      itemBuilder: (context, idx) {
        final date = dates[idx];
        final dayDists = byDate[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.dynamicSurfaceBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note,
                            size: 14, color: AppTheme.accentBlue),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy', 'ar').format(date),
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                        height: 1, color: context.dynamicCardBorder),
                  ),
                ],
              ),
            ),
            // Items
            ...dayDists.map((d) => _buildDistributionCard(context, provider, d)),
          ],
        );
      },
    );
  }

  Widget _buildDistributionCard(
    BuildContext context,
    FinanceProvider provider,
    Distribution d,
  ) {
    final partner =
        provider.partners.firstWhereOrNull((p) => p.id == d.partnerId);
    final income =
        provider.incomes.firstWhereOrNull((i) => i.id == d.incomeId);
    final plot = income != null && income.landPlotId != null
        ? provider.landPlots
            .firstWhereOrNull((lp) => lp.id == income.landPlotId)
        : null;
    final roleLabel =
        provider.partnershipTypeById(d.role)?.name ?? d.role;
    final roleColor = _getRoleColor(d.role);
    final roleIcon = _getRoleIcon(d.role);
    final isPaid = provider.isDistributionPaid(d);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid
              ? AppTheme.incomeGreen.withValues(alpha: 0.35)
              : context.dynamicCardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(roleIcon, color: roleColor, size: 22),
                ),
                const SizedBox(width: 12),
                // Partner & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partner?.name ?? 'شريك غير محدد',
                              style: TextStyle(
                                color: context.dynamicTextPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${plot != null ? '${plot.name} · ' : ''}${income?.title ?? 'إيراد محصول'}',
                        style: TextStyle(
                          color: context.dynamicTextMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Amount & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${d.amount.formatted} ر.ي',
                      style: TextStyle(
                        color: isPaid
                            ? context.dynamicTextMuted
                            : AppTheme.expenseRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        decoration:
                            isPaid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppTheme.incomeGreen.withValues(alpha: 0.12)
                            : AppTheme.expenseRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaid
                                ? Icons.check_circle
                                : Icons.hourglass_top_rounded,
                            size: 11,
                            color: isPaid
                                ? AppTheme.incomeGreen
                                : AppTheme.expenseRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaid ? 'مسدد' : 'مستحق',
                            style: TextStyle(
                              color: isPaid
                                  ? AppTheme.incomeGreen
                                  : AppTheme.expenseRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!isPaid || d.paidDate != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isPaid && d.paidDate != null)
                    Row(
                      children: [
                        Icon(Icons.done_all,
                            size: 14, color: AppTheme.incomeGreen),
                        const SizedBox(width: 4),
                        Text(
                          'تاريخ السداد: ${DateFormat('yyyy/MM/dd').format(d.paidDate!)}',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: AppTheme.expenseRed),
                        const SizedBox(width: 4),
                        Text(
                          'مستحق في ذمة المزرعة',
                          style: TextStyle(
                            color: context.dynamicTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  if (!isPaid)
                    ElevatedButton.icon(
                      onPressed: () =>
                          showDistributionPaymentSheet(context, provider, d),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.incomeGreen,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.payments_rounded, size: 14),
                      label: const Text(
                        'سداد الحصة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== GROUPED BY PARTNER VIEW ====================

  Widget _buildGroupedByPartnerView(
    BuildContext context,
    FinanceProvider provider,
    List<Distribution> dists,
  ) {
    final partners = provider.partners;

    final stats = partners.map((partner) {
      final partnerDists =
          dists.where((d) => d.partnerId == partner.id).toList();
      final dueAmount = partnerDists
          .where((d) => !provider.isDistributionPaid(d))
          .fold(0.0, (s, d) => s + d.amount);
      final paidTotal = partnerDists
          .where((d) => provider.isDistributionPaid(d))
          .fold(0.0, (s, d) => s + d.amount);
      final total = dueAmount + paidTotal;

      return {
        'partner': partner,
        'dists': partnerDists,
        'due': dueAmount,
        'paid': paidTotal,
        'total': total,
        'count': partnerDists.length,
      };
    }).where((item) => (item['count'] as int) > 0).toList()
      ..sort((a, b) => (b['due'] as double).compareTo(a['due'] as double));

    if (stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'لا توجد توزيعات مخصصة لشركاء مسجلين',
            style: TextStyle(
                color: context.dynamicTextSecondary,
                fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: stats.length,
      itemBuilder: (context, idx) {
        final item = stats[idx];
        final partner = item['partner'] as Partner;
        final due = item['due'] as double;
        final paid = item['paid'] as double;
        final total = item['total'] as double;
        final count = item['count'] as int;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.dynamicCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.dynamicCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.person,
                            color: AppTheme.accentBlue, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.name,
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$count حصة مسجلة · هاتف: ${partner.phone ?? 'بدون'}',
                            style: TextStyle(
                              color: context.dynamicTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (due > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.expenseRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'مستحق له',
                        style: TextStyle(
                          color: AppTheme.expenseRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.expenseRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مستحق غير مدفوع',
                              style: TextStyle(
                                color: AppTheme.expenseRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            '${due.formatted} ر.ي',
                            style: TextStyle(
                              color: AppTheme.expenseRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.incomeGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تم سداده',
                              style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            '${paid.formatted} ر.ي',
                            style: TextStyle(
                              color: AppTheme.incomeGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.dynamicSurfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.dynamicCardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إجمالي الاستحقاق',
                              style: TextStyle(
                                color: context.dynamicTextSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            '${total.formatted} ر.ي',
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
