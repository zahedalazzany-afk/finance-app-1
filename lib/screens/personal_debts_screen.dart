import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';
import 'add_personal_debt_screen.dart';
import 'debt_settlement_screen.dart';
import 'person_debt_operations_screen.dart';

class PersonalDebtsScreen extends StatefulWidget {
  const PersonalDebtsScreen({super.key});

  @override
  State<PersonalDebtsScreen> createState() => _PersonalDebtsScreenState();
}

class _PersonalDebtsScreenState extends State<PersonalDebtsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'debtor', 'creditor', 'stale', 'settled'
  String _sortBy = 'net_desc'; // 'net_desc', 'net_asc', 'activity_desc', 'activity_asc', 'name'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()} أسابيع';
    if (diff.inDays < 365) return 'منذ ${(diff.inDays / 30).floor()} شهر';
    return 'منذ أكثر من سنة';
  }

  void _copyPhoneNumber(BuildContext context, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ رقم الهاتف: $phone',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allDebts = provider.personalDebts;

    // تجميع الأشخاص الذين لديهم ديون مسجلة
    final Set<String> personIdsWithDebts = allDebts.map((d) => d.personId).toSet();

    final List<_PersonDebtSummary> summaries = [];
    double grandTotalReceivable = 0; // إجمالي ما لنا على الناس (مدين)
    double grandTotalPayable = 0;    // إجمالي ما علينا للناس (دائن)
    double grandOriginalReceivable = 0;
    double grandOriginalPayable = 0;

    for (final personId in personIdsWithDebts) {
      final pDebts = allDebts.where((d) => d.personId == personId).toList();
      final partner = provider.partners.firstWhereOrNull((p) => p.id == personId);

      double totalReceivable = 0; // متبقي ما عليه لنا (مدين)
      double totalPayable = 0;    // متبقي ما له علينا (دائن)
      double originalReceivable = 0;
      double originalPayable = 0;
      double totalSettledByHim = 0; // ما سدده لنا (سداد ديون عليه)
      double totalSettledToHim = 0; // ما سددناه له (سداد ديون له علينا)
      DateTime latestDate = pDebts.first.date;
      int settlementsCount = 0;

      for (final d in pDebts) {
        final rem = provider.personalDebtRemaining(d.id);
        final sList = provider.settlementsForDebt(d.id);
        final paid = provider.personalDebtPaid(d.id);
        settlementsCount += sList.length;

        if (d.direction == 'receivable') {
          totalReceivable += rem;
          originalReceivable += d.amount;
          totalSettledByHim += paid;
        } else {
          totalPayable += rem;
          originalPayable += d.amount;
          totalSettledToHim += paid;
        }

        if (d.date.isAfter(latestDate)) latestDate = d.date;
        for (final s in sList) {
          if (s.date.isAfter(latestDate)) latestDate = s.date;
        }
      }

      final double totalDebited = originalReceivable + totalSettledToHim; // إجمالي ما عليه
      final double totalCredited = originalPayable + totalSettledByHim;  // إجمالي ما له
      final double netBalance = totalDebited - totalCredited;
      final double netDifference = netBalance.abs();
      final bool isSettled = netDifference <= 0.001;

      // تحديد الحالة بدقة تراكمية: خالص، مدين لنا عليه، أو دائن له علينا
      final String debtStatus;
      if (isSettled) {
        debtStatus = 'settled'; // خالص / متوازن
      } else if (netBalance > 0.001) {
        debtStatus = 'debtor'; // مدين (لنا عليه)
        grandTotalReceivable += netDifference;
      } else {
        debtStatus = 'creditor'; // دائن (له علينا)
        grandTotalPayable += netDifference;
      }

      grandOriginalReceivable += totalDebited;
      grandOriginalPayable += totalCredited;

      summaries.add(_PersonDebtSummary(
        personId: personId,
        partner: partner,
        debts: pDebts,
        totalReceivable: totalReceivable,
        totalPayable: totalPayable,
        originalReceivable: originalReceivable,
        originalPayable: originalPayable,
        totalSettledByHim: totalSettledByHim,
        totalSettledToHim: totalSettledToHim,
        netDifference: netDifference,
        debtStatus: debtStatus,
        isSettled: isSettled,
        latestDate: latestDate,
        settlementsCount: settlementsCount,
      ));
    }

    final debtorCount = summaries.where((s) => s.debtStatus == 'debtor').length;
    final creditorCount = summaries.where((s) => s.debtStatus == 'creditor').length;
    final settledCount = summaries.where((s) => s.isSettled).length;
    final staleCount = summaries.where((s) => s.isStale).length;

    final netGrandTotal = (grandTotalReceivable - grandTotalPayable).abs();
    final isNetDebtor = grandTotalReceivable >= grandTotalPayable;

    // Grand settlement calculations
    final grandOriginalTotal = grandOriginalReceivable + grandOriginalPayable;
    final grandRemainingTotal = grandTotalReceivable + grandTotalPayable;
    final grandTotalSettled = (grandOriginalTotal - grandRemainingTotal).clamp(0.0, double.infinity);
    final grandSettlementRate = grandOriginalTotal > 0
        ? (grandTotalSettled / grandOriginalTotal).clamp(0.0, 1.0)
        : (summaries.isNotEmpty && grandRemainingTotal <= 0.001 ? 1.0 : 0.0);

    // Filter summaries
    var filteredSummaries = summaries.where((s) {
      if (_filterStatus == 'debtor' && s.debtStatus != 'debtor') return false;
      if (_filterStatus == 'creditor' && s.debtStatus != 'creditor') return false;
      if (_filterStatus == 'stale' && !s.isStale) return false;
      if (_filterStatus == 'settled' && !s.isSettled) return false;

      if (_searchQuery.isNotEmpty) {
        final name = s.partner?.name.toLowerCase() ?? '';
        final phone = s.partner?.phone?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !phone.contains(query)) return false;
      }
      return true;
    }).toList();

    // Sort summaries
    if (_sortBy == 'net_desc') {
      filteredSummaries.sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        return b.netDifference.compareTo(a.netDifference);
      });
    } else if (_sortBy == 'net_asc') {
      filteredSummaries.sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        return a.netDifference.compareTo(b.netDifference);
      });
    } else if (_sortBy == 'activity_desc') {
      filteredSummaries.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    } else if (_sortBy == 'activity_asc') {
      filteredSummaries.sort((a, b) => a.latestDate.compareTo(b.latestDate));
    } else if (_sortBy == 'name') {
      filteredSummaries.sort((a, b) =>
          (a.partner?.name ?? '').compareTo(b.partner?.name ?? ''));
    }

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'الديون الشخصية والذمم',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'ديون العمال والمشتريات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DebtSettlementScreen(),
                ),
              );
            },
          ),
          DataExportImportButton(
            label: 'الديون الشخصية',
            buildRows: () => context
                .read<FinanceProvider>()
                .personalDebts
                .map((e) => e.toJson())
                .toList(),
            csvHeaders: const ['المبلغ', 'الاتجاه', 'التاريخ', 'ملاحظات'],
            csvKeys: const ['amount', 'direction', 'date', 'note'],
            onImport: (rows) async {
              final prov = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final debt = PersonalDebt.fromJson(row);
                  if (prov.personalDebts.any((e) => e.id == debt.id)) {
                    continue;
                  }
                  prov.addPersonalDebt(debt);
                } catch (_) {}
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'إضافة دين لشخص',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddPersonalDebtScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: summaries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.handshake_outlined,
                        size: 56,
                        color: AppTheme.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'لا توجد ديون شخصية مسجلة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.dynamicTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سجل مستحقاتك لدى الآخرين أو التزاماتك للأشخاص والشركاء لمتابعتها بدقة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: context.dynamicTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddPersonalDebtScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'تسجيل دين جديد',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                // كرت ملخص الموقف المالي العام للديون (Hero Financial Position Card)
                _buildGrandOverviewCard(
                  context: context,
                  grandTotalReceivable: grandTotalReceivable,
                  grandTotalPayable: grandTotalPayable,
                  netGrandTotal: netGrandTotal,
                  isNetDebtor: isNetDebtor,
                  totalPersons: summaries.length,
                  debtorCount: debtorCount,
                  creditorCount: creditorCount,
                  staleCount: staleCount,
                  settledCount: settledCount,
                  grandOriginalTotal: grandOriginalTotal,
                  grandTotalSettled: grandTotalSettled,
                  grandSettlementRate: grandSettlementRate,
                ),
                const SizedBox(height: 14),

                // حقل البحث السريع
                TextField(
                  controller: _searchController,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: context.dynamicTextPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الشخص أو رقم الهاتف...',
                    hintStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: context.dynamicTextMuted,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
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
                    filled: true,
                    fillColor: context.dynamicCardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.dynamicCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.dynamicCardBorder),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
                const SizedBox(height: 10),

                // شرائح تصفية الحالة وقائمة الفرز
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _statusChip('all', 'الكل (${summaries.length})'),
                            const SizedBox(width: 6),
                            _statusChip(
                              'debtor',
                              'لنا عليهم ($debtorCount)',
                              activeColor: AppTheme.incomeGreen,
                            ),
                            const SizedBox(width: 6),
                            _statusChip(
                              'creditor',
                              'لهم علينا ($creditorCount)',
                              activeColor: AppTheme.expenseRed,
                            ),
                            if (staleCount > 0) ...[
                              const SizedBox(width: 6),
                              _statusChip(
                                'stale',
                                'متأخرة 30+ يوم ($staleCount)',
                                activeColor: Colors.orange,
                              ),
                            ],
                            if (settledCount > 0) ...[
                              const SizedBox(width: 6),
                              _statusChip(
                                'settled',
                                'خالصة ($settledCount)',
                                activeColor: context.dynamicTextMuted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      color: context.dynamicCardBg,
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: context.dynamicCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.dynamicCardBorder),
                        ),
                        child: const Icon(Icons.sort_rounded, size: 18),
                      ),
                      tooltip: 'ترتيب الحسابات',
                      onSelected: (val) => setState(() => _sortBy = val),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'net_desc',
                          child: Text(
                            'الأعلى مديونية (الصافي)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: _sortBy == 'net_desc'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _sortBy == 'net_desc'
                                  ? AppTheme.accentBlue
                                  : context.dynamicTextPrimary,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'net_asc',
                          child: Text(
                            'الأقل مديونية',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: _sortBy == 'net_asc'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _sortBy == 'net_asc'
                                  ? AppTheme.accentBlue
                                  : context.dynamicTextPrimary,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'activity_desc',
                          child: Text(
                            'الأحدث حركة ونشاطاً',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: _sortBy == 'activity_desc'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _sortBy == 'activity_desc'
                                  ? AppTheme.accentBlue
                                  : context.dynamicTextPrimary,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'activity_asc',
                          child: Text(
                            'الأقدم حركة (للمتابعة)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: _sortBy == 'activity_asc'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _sortBy == 'activity_asc'
                                  ? AppTheme.accentBlue
                                  : context.dynamicTextPrimary,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'name',
                          child: Text(
                            'أبجدياً بالاسم',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: _sortBy == 'name'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _sortBy == 'name'
                                  ? AppTheme.accentBlue
                                  : context.dynamicTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // قائمة الأشخاص
                if (filteredSummaries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: context.dynamicTextMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'لا توجد بيانات ضمن هذا التصنيف',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: context.dynamicTextSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredSummaries.asMap().entries.map((entry) =>
                      _buildPersonCard(
                        context: context,
                        summary: entry.value,
                        index: entry.key,
                      )),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddPersonalDebtScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'تسجيل دين',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _statusChip(String key, String label, {Color? activeColor}) {
    final selected = _filterStatus == key;
    final color = activeColor ?? AppTheme.accentBlue;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterStatus = key),
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? color : context.dynamicTextSecondary,
      ),
      selectedColor: color.withValues(alpha: 0.15),
      backgroundColor: context.dynamicCardBg,
      side: BorderSide(
        color: selected ? color : context.dynamicCardBorder,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildGrandOverviewCard({
    required BuildContext context,
    required double grandTotalReceivable,
    required double grandTotalPayable,
    required double netGrandTotal,
    required bool isNetDebtor,
    required int totalPersons,
    required int debtorCount,
    required int creditorCount,
    required int staleCount,
    required int settledCount,
    required double grandOriginalTotal,
    required double grandTotalSettled,
    required double grandSettlementRate,
  }) {
    final isSettled =
        grandTotalReceivable <= 0.001 && grandTotalPayable <= 0.001;
    final highlightColor = isSettled
        ? AppTheme.incomeGreen
        : (isNetDebtor ? AppTheme.incomeGreen : AppTheme.expenseRed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            highlightColor.withValues(alpha: 0.12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: highlightColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 22,
                      color: highlightColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'صافي المركز المالي للديون',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: context.dynamicTextPrimary,
                        ),
                      ),
                      Text(
                        '$totalPersons شخص مسجل في الذمم',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: context.dynamicTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: highlightColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: highlightColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSettled
                          ? Icons.check_circle_outline
                          : (isNetDebtor
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded),
                      size: 13,
                      color: highlightColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSettled
                          ? 'الحسابات متوازنة'
                          : (isNetDebtor ? 'فائض مستحق لك' : 'التزام مستحق عليك'),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: highlightColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big Net Amount Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                netGrandTotal.formattedFull,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: highlightColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ريال يمني',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.dynamicTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isSettled
                ? 'جميع الديون الشخصية مسددة بالكامل وليس عليك أو لك أي ذمم معلقة.'
                : (isNetDebtor
                    ? 'إجمالي ما لك في ذمة الآخرين يفوق ما عليك بمقدار ${netGrandTotal.formatted} ر.ي'
                    : 'إجمالي التزاماتك للآخرين تفوق ما لك بمقدار ${netGrandTotal.formatted} ر.ي'),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: context.dynamicTextSecondary,
            ),
          ),

          // Global Settlement Progress Bar
          if (grandOriginalTotal > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.dynamicSurfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.dynamicCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'نسبة التسوية والتحصيل العامة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.dynamicTextPrimary,
                        ),
                      ),
                      Text(
                        '${(grandSettlementRate * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: grandSettlementRate,
                      minHeight: 6,
                      backgroundColor: context.dynamicCardBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.accentBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تمت تسوية ${grandTotalSettled.formatted} ر.ي من إجمالي ${grandOriginalTotal.formatted} ر.ي مسجل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: context.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Three Metric Boxes
          Row(
            children: [
              Expanded(
                child: _buildMiniStatBox(
                  context,
                  title: 'لنا عليهم (مدين)',
                  amount: grandTotalReceivable.formatted,
                  subtitle: '$debtorCount أشخاص',
                  color: AppTheme.incomeGreen,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatBox(
                  context,
                  title: 'لهم علينا (دائن)',
                  amount: grandTotalPayable.formatted,
                  subtitle: '$creditorCount أشخاص',
                  color: AppTheme.expenseRed,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatBox(
                  context,
                  title: 'متأخرة 30+ يوم',
                  amount: '$staleCount حسابات',
                  subtitle: 'تتطلب المتابعة',
                  color: staleCount > 0 ? Colors.orange : context.dynamicTextMuted,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatBox(
    BuildContext context, {
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amount,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: context.dynamicTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: context.dynamicTextSecondary,
              fontSize: 9,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// بناء كرت الشخص المالي التفاعلي المطور
  Widget _buildPersonCard({
    required BuildContext context,
    required _PersonDebtSummary summary,
    required int index,
  }) {
    final name = summary.partner?.name ?? 'شخص غير معروف';
    final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(summary.latestDate);
    final timeAgo = _formatTimeAgo(summary.latestDate);

    // تجهيز نصوص وألوان الحالة
    final Color statusColor;
    final Color statusBg;
    final String statusText;
    final IconData statusIcon;

    if (summary.isSettled) {
      statusColor = AppTheme.incomeGreen;
      statusBg = AppTheme.incomeGreen.withValues(alpha: 0.12);
      statusText = 'خالص / متوازن';
      statusIcon = Icons.check_circle_outline;
    } else if (summary.debtStatus == 'debtor') {
      statusColor = AppTheme.incomeGreen;
      statusBg = AppTheme.incomeGreen.withValues(alpha: 0.12);
      statusText = 'مدين (لنا عليه)';
      statusIcon = Icons.arrow_downward_rounded;
    } else if (summary.debtStatus == 'creditor') {
      statusColor = AppTheme.expenseRed;
      statusBg = AppTheme.expenseRed.withValues(alpha: 0.12);
      statusText = 'دائن (له علينا)';
      statusIcon = Icons.arrow_upward_rounded;
    } else {
      statusColor = Colors.grey;
      statusBg = Colors.grey.withValues(alpha: 0.12);
      statusText = 'متوازن';
      statusIcon = Icons.balance;
    }

    final hasPhone =
        summary.partner?.phone != null && summary.partner!.phone!.isNotEmpty;

    // في النموذج التراكمي المباشر: ما عليه = إجمالي ما قيد عليه، وما له = إجمالي ما قيد له
    final double displayReceivable = summary.totalDebited;
    final double displayPayable = summary.totalCredited;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: summary.isStale
              ? Colors.orange.withValues(alpha: 0.4)
              : (summary.isSettled
                  ? context.dynamicCardBorder
                  : statusColor.withValues(alpha: 0.3)),
          width: summary.isStale ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonDebtOperationsScreen(
                personId: summary.personId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس الكرت: الصورة الرمزية، الاسم، الهاتف، وشارة الحالة
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1) : '؟',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
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
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: context.dynamicTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (summary.isStale) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule,
                                        size: 11, color: Colors.orange),
                                    SizedBox(width: 3),
                                    Text(
                                      'راكدة',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 9,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (hasPhone) ...[
                              InkWell(
                                onTap: () => _copyPhoneNumber(
                                    context, summary.partner!.phone!),
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_outlined,
                                        size: 12,
                                        color: context.dynamicTextSecondary),
                                    const SizedBox(width: 3),
                                    Text(
                                      summary.partner!.phone!,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        color: context.dynamicTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('•',
                                  style: TextStyle(
                                      color: context.dynamicTextMuted)),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
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
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // المستطيل المالي المنظم:
              // في الجهة اليمنى: الفرق في المبلغ والمركز الحالي
              // في الجهة اليسرى: تفصيل (ما له وما عليه)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.dynamicSurfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.dynamicCardBorder),
                ),
                child: Row(
                  children: [
                    // الجهة اليمنى: صافي المبلغ فقط بدون نص توضيحي
                    Expanded(
                      flex: 6,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${summary.netDifference.formattedFull} ر.ي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: summary.isSettled
                                ? context.dynamicTextMuted
                                : (summary.debtStatus == 'creditor'
                                    ? AppTheme.expenseRed
                                    : AppTheme.incomeGreen),
                          ),
                        ),
                      ),
                    ),

                    // خط فاصل عمودي أنيق
                    Container(
                      height: 44,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: context.dynamicCardBorder,
                    ),

                    // الجهة اليسرى: مبلغ (عليه) ومبلغ (له)
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'عليه:',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.dynamicTextSecondary,
                                ),
                              ),
                              Text(
                                '${displayReceivable.formatted} ر.ي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: displayReceivable > 0
                                      ? AppTheme.incomeGreen
                                      : context.dynamicTextMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'له:',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.dynamicTextSecondary,
                                ),
                              ),
                              Text(
                                '${displayPayable.formatted} ر.ي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: displayPayable > 0
                                      ? AppTheme.expenseRed
                                      : context.dynamicTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // شريط تقدم السداد الخاص بالشخص
              if (summary.baselineTotal > 0 || summary.isSettled) ...[
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          summary.settlementLabelText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: summary.isSettled
                                ? AppTheme.incomeGreen
                                : context.dynamicTextSecondary,
                          ),
                        ),
                        Text(
                          summary.settlementDetailText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            color: summary.isSettled
                                ? AppTheme.incomeGreen
                                : context.dynamicTextMuted,
                            fontWeight: summary.isSettled
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.settlementRate,
                        minHeight: 4,
                        backgroundColor: context.dynamicSurfaceBg,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          summary.isSettled
                              ? AppTheme.incomeGreen
                              : (summary.debtStatus == 'creditor'
                                  ? AppTheme.expenseRed
                                  : AppTheme.incomeGreen),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // شريط العمليات والأزرار السريعة
              Row(
                children: [
                  Text(
                    '${summary.debts.length} قيود • ${summary.settlementsCount} دفعة • آخر حركة: $dateStr',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: context.dynamicTextMuted,
                    ),
                  ),
                  const Spacer(),
                  // زر كشف الحساب والعمليات
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonDebtOperationsScreen(
                            personId: summary.personId,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 14),
                    label: const Text(
                      'كشف الحساب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // زر إضافة دين سريع لهذا الشخص
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    tooltip: 'إضافة دين جديد لهذا الشخص',
                    color: AppTheme.accentBlue,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddPersonalDebtScreen(
                            initialPersonId: summary.personId,
                            initialDirection: summary.debtStatus == 'creditor'
                                ? 'payable'
                                : 'receivable',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonDebtSummary {
  final String personId;
  final Partner? partner;
  final List<PersonalDebt> debts;
  final double totalReceivable; // مدين لنا (متبقي)
  final double totalPayable;    // دائن لنا (متبقي)
  final double originalReceivable;
  final double originalPayable;
  final double totalSettledByHim; // ما سدده لنا
  final double totalSettledToHim; // ما سددناه له
  final double netDifference;
  final String debtStatus; // 'debtor', 'creditor', 'settled', 'balanced'
  final bool isSettled;
  final DateTime latestDate;
  final int settlementsCount;

  _PersonDebtSummary({
    required this.personId,
    required this.partner,
    required this.debts,
    required this.totalReceivable,
    required this.totalPayable,
    required this.originalReceivable,
    required this.originalPayable,
    required this.totalSettledByHim,
    required this.totalSettledToHim,
    required this.netDifference,
    required this.debtStatus,
    required this.isSettled,
    required this.latestDate,
    required this.settlementsCount,
  });

  // محاسبياً: إجمالي ما قُيّد عليه (أصل ديونه لنا + دفعات سددناها له)
  double get totalDebited => originalReceivable + totalSettledToHim;

  // محاسبياً: إجمالي ما قُيّد له (أصل ديونه علينا + دفعات سددها لنا)
  double get totalCredited => originalPayable + totalSettledByHim;

  // إجمالي أصل الالتزام (ما عليه إن كان مديناً، أو ما له إن كان دائناً)
  double get baselineTotal =>
      debtStatus == 'creditor' ? totalCredited : totalDebited;

  // المبلغ المسدد (المسدد منه إن كان مديناً، أو المسدد له إن كان دائناً)
  double get settledAmount =>
      debtStatus == 'creditor' ? totalDebited : totalCredited;

  // متوافق مع الاستخدامات السابقة
  double get originalTotal => baselineTotal;
  double get settledTotal => settledAmount;

  // نسبة السداد المطابقة 100% بين له وعليه
  double get settlementRate {
    if (isSettled) return 1.0;
    if (baselineTotal <= 0.001) return 0.0;
    return (settledAmount / baselineTotal).clamp(0.0, 1.0);
  }

  // نص تفصيل السداد المطابق تماماً
  String get settlementDetailText {
    if (isSettled) {
      final amount = totalDebited > 0.001 ? totalDebited : totalCredited;
      return 'تمت التسوية بالكامل (${amount.formatted} ر.ي)';
    }
    if (debtStatus == 'creditor') {
      return 'مسدد له: ${settledAmount.formatted} من ${baselineTotal.formatted} ر.ي';
    } else {
      return 'مسدد منه: ${settledAmount.formatted} من ${baselineTotal.formatted} ر.ي';
    }
  }

  // نص عنوان نسبة السداد
  String get settlementLabelText {
    if (isSettled) {
      return 'حالة السداد: خالص بالكامل (100%)';
    }
    final percent = (settlementRate * 100).toStringAsFixed(0);
    if (debtStatus == 'creditor') {
      return 'نسبة المسدد له: $percent%';
    } else {
      return 'نسبة المسدد منه: $percent%';
    }
  }

  int get daysSinceLastActivity =>
      DateTime.now().difference(latestDate).inDays;
  bool get isStale => !isSettled && daysSinceLastActivity >= 30;
}

