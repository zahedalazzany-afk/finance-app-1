import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets.dart';
import 'personal_debts_screen.dart';

class BatchWagePayoutScreen extends StatefulWidget {
  const BatchWagePayoutScreen({super.key});

  @override
  State<BatchWagePayoutScreen> createState() => _BatchWagePayoutScreenState();
}

class _BatchWagePayoutScreenState extends State<BatchWagePayoutScreen> {
  final Map<String, bool> _selectedWorkers = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _includeAllWorkers = false; // toggle between workers with debt vs all workers
  String? _selectedWalletId;
  String _fundingSource = 'income'; // 'income' (دفعات الإيرادات) | 'debt_settlement' (استلام الديون)
  String? _selectedIncomeId;
  String? _selectedIncomePaymentId;
  String? _selectedDebtSettlementId;
  DateTime _paymentDate = DateTime.now();
  final TextEditingController _noteController =
      TextEditingController(text: 'سداد أجور عمال - من دفعة إيراد');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWorkersState();
    });
  }

  void _initWorkersState() {
    final provider = context.read<FinanceProvider>();
    final defaultWal = provider.defaultWallet()?.id ??
        (provider.wallets.isNotEmpty ? provider.wallets.first.id : null);
    _selectedWalletId = defaultWal;

    for (final w in provider.workers) {
      final debt = provider.workerDebt(w.id);
      final hasDebt = debt > 0.01;
      _selectedWorkers[w.id] = hasDebt;
      _controllers[w.id] =
          TextEditingController(text: hasDebt ? debt.plain : '0');
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  double _totalPayoutAmount() {
    double sum = 0;
    _selectedWorkers.forEach((workerId, isSelected) {
      if (isSelected) {
        final text = _controllers[workerId]?.text.trim() ?? '0';
        final val = double.tryParse(text) ?? 0;
        if (val > 0) sum += val;
      }
    });
    return sum;
  }

  int _selectedCount() {
    return _selectedWorkers.values.where((v) => v).length;
  }

  void _selectAll(List<Worker> workers, bool select) {
    setState(() {
      for (final w in workers) {
        _selectedWorkers[w.id] = select;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final allWorkers = provider.workers;
        final workersWithDebt =
            allWorkers.where((w) => provider.workerDebt(w.id) > 0.01).toList();
        final displayedWorkers =
            _includeAllWorkers ? allWorkers : workersWithDebt;

        // Ensure controllers exist
        for (final w in allWorkers) {
          if (!_controllers.containsKey(w.id)) {
            final debt = provider.workerDebt(w.id);
            _controllers[w.id] =
                TextEditingController(text: debt > 0 ? debt.plain : '0');
            _selectedWorkers[w.id] = debt > 0.01;
          }
        }

        final totalPayout = _totalPayoutAmount();
        final totalIncomeFunding = provider.totalFundingAvailable();
        final totalDebtFunding = provider.totalDebtSettlementFundingAvailable();
        final selectedWallet = provider.wallets
            .firstWhereOrNull((w) => w.id == _selectedWalletId);

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: const Text('السداد المجمع لأجور العمال'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryHeaderCard(displayedWorkers.length, totalPayout),
                const SizedBox(height: 14),
                _buildPaymentSourceCard(
                    provider, totalPayout, totalIncomeFunding, totalDebtFunding, selectedWallet),
                const SizedBox(height: 16),
                _buildWorkersListHeader(displayedWorkers),
                const SizedBox(height: 8),
                if (displayedWorkers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 36, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppTheme.incomeGreen, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد أجور معلقة أو مستحقات متبقية للعمال!',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () =>
                              setState(() => _includeAllWorkers = true),
                          child: const Text('عرض جميع العمال لصرف دفعات مسبقة'),
                        ),
                      ],
                    ),
                  )
                else
                  ...displayedWorkers
                      .map((w) => _buildWorkerPayoutCard(provider, w)),
                const SizedBox(height: 24),
                _buildSubmitButton(context, provider, totalPayout),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryHeaderCard(int workerCount, double totalPayout) {
    final selectedCount = _selectedCount();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي مبلغ السداد المجمع',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        totalPayout.formatted,
                        style: TextStyle(
                          color: AppTheme.incomeGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('ر.ي',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlueDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('العمال المحددون',
                        style: TextStyle(
                            color: AppTheme.accentBlue, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '$selectedCount من $workerCount',
                      style: TextStyle(
                        color: AppTheme.accentBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSourceCard(
    FinanceProvider provider,
    double totalPayout,
    double totalIncomeFunding,
    double totalDebtFunding,
    Wallet? selectedWallet,
  ) {
    // List eligible income payments
    final eligibleIncomePayments = provider.incomePayments
        .where((p) => provider.paymentAvailable(p.id) > 0.001)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // List eligible debt settlements
    final eligibleDebtSettlements = provider.debtFundingSources
      .where((s) => provider.debtFundingAvailable(s.id) > 0.001)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Ensure valid selections
    if (_selectedIncomePaymentId == null ||
        !eligibleIncomePayments.any((p) => p.id == _selectedIncomePaymentId)) {
      if (eligibleIncomePayments.isNotEmpty) {
        _selectedIncomePaymentId = eligibleIncomePayments.first.id;
      } else {
        _selectedIncomePaymentId = null;
      }
    }
    if (_selectedDebtSettlementId == null ||
        !eligibleDebtSettlements.any((s) => s.id == _selectedDebtSettlementId)) {
      if (eligibleDebtSettlements.isNotEmpty) {
        _selectedDebtSettlementId = eligibleDebtSettlements.first.id;
      } else {
        _selectedDebtSettlementId = null;
      }
    }

    // Automatically derive the active wallet from the selected receipt payment
    if (_fundingSource == 'income' && _selectedIncomePaymentId != null) {
      final p = eligibleIncomePayments
          .firstWhereOrNull((ip) => ip.id == _selectedIncomePaymentId);
      final inc = provider.incomes
          .firstWhereOrNull((i) => i.id == p?.incomeId);
      if (inc?.walletId != null) {
        _selectedWalletId = inc!.walletId;
      }
    } else if (_fundingSource == 'debt_settlement' && _selectedDebtSettlementId != null) {
      final s = eligibleDebtSettlements
          .firstWhereOrNull((ds) => ds.id == _selectedDebtSettlementId);
      if (s?.walletId != null) {
        _selectedWalletId = s!.walletId;
      }
    }
    final activeWallet = provider.wallets
        .firstWhereOrNull((w) => w.id == _selectedWalletId);

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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreenDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.link,
                    color: AppTheme.incomeGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مصدر السداد (ربط بدفعات الاستلام)',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'يجب ربط السداد بدفعة استلام نقدية محددة من الإيرادات أو الديون المستلمة',
                      style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main 2-way funding source tabs (No direct wallet option)
          Row(
            children: [
              Expanded(
                child: _buildSourceOptionTab(
                  label: 'دفعات الإيرادات',
                  sublabel: totalIncomeFunding > 0.01
                      ? 'متاح: ${totalIncomeFunding.formatted} ر.ي'
                      : 'لا يوجد رصيد',
                  icon: Icons.trending_up,
                  isSelected: _fundingSource == 'income',
                  color: AppTheme.incomeGreen,
                  onTap: () {
                    setState(() {
                      _fundingSource = 'income';
                      _noteController.text = 'سداد أجور عمال - من دفعة إيراد';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSourceOptionTab(
                  label: 'استلام الديون الشخصية',
                  sublabel: totalDebtFunding > 0.01
                      ? 'متاح: ${totalDebtFunding.formatted} ر.ي'
                      : 'لا يوجد رصيد',
                  icon: Icons.handshake_outlined,
                  isSelected: _fundingSource == 'debt_settlement',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    setState(() {
                      _fundingSource = 'debt_settlement';
                      _noteController.text =
                          'سداد أجور عمال - من دفعة استلام ديون وأقساط';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Specific Payment Selector based on selected source
          if (_fundingSource == 'income') ...[
            if (eligibleIncomePayments.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.expenseRed, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لا توجد حالياً أي دفعات استلام إيرادات بها رصيد متاح للاستقطاع.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Builder(
                builder: (context) {
                  final eligibleIncomes = provider.incomes
                      .where((i) => eligibleIncomePayments.any((p) => p.incomeId == i.id))
                      .toList();
                  if (_selectedIncomeId == null || !eligibleIncomes.any((i) => i.id == _selectedIncomeId)) {
                    if (_selectedIncomePaymentId != null) {
                      final currentPayment = eligibleIncomePayments.firstWhereOrNull((p) => p.id == _selectedIncomePaymentId);
                      _selectedIncomeId = currentPayment?.incomeId ?? (eligibleIncomes.isNotEmpty ? eligibleIncomes.first.id : null);
                    } else if (eligibleIncomes.isNotEmpty) {
                      _selectedIncomeId = eligibleIncomes.first.id;
                    }
                  }

                  final paymentsForSelectedIncome = eligibleIncomePayments
                      .where((p) => p.incomeId == _selectedIncomeId)
                      .toList();

                  if (_selectedIncomePaymentId == null || !paymentsForSelectedIncome.any((p) => p.id == _selectedIncomePaymentId)) {
                    if (paymentsForSelectedIncome.isNotEmpty) {
                      _selectedIncomePaymentId = paymentsForSelectedIncome.first.id;
                    }
                  }

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: eligibleIncomes.any((i) => i.id == _selectedIncomeId) ? _selectedIncomeId : null,
                            isExpanded: true,
                            dropdownColor: AppTheme.card,
                            icon: Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary),
                            hint: Text(
                              'اختر الإيراد',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                            items: eligibleIncomes.map((inc) {
                              final totalAvail = eligibleIncomePayments
                                  .where((p) => p.incomeId == inc.id)
                                  .fold(0.0, (s, p) => s + provider.paymentAvailable(p.id).clamp(0.0, double.infinity));
                              final isPos = totalAvail > 0.001;
                              return DropdownMenuItem(
                                value: inc.id,
                                child: Text(
                                  '${isPos ? "🟢 " : "⚪ "}${inc.title} (المتاح: ${totalAvail.formatted} ر.ي)',
                                  style: TextStyle(
                                    color: isPos ? AppTheme.textPrimary : AppTheme.textMuted,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedIncomeId = v;
                                final newPayments = eligibleIncomePayments
                                    .where((p) => p.incomeId == v)
                                    .toList();
                                _selectedIncomePaymentId = newPayments.isNotEmpty ? newPayments.first.id : null;
                                if (_selectedIncomePaymentId != null) {
                                  final inc = provider.incomes.firstWhereOrNull((i) => i.id == v);
                                  if (inc?.walletId != null) {
                                    _selectedWalletId = inc!.walletId;
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: paymentsForSelectedIncome.any((p) => p.id == _selectedIncomePaymentId)
                                ? _selectedIncomePaymentId
                                : null,
                            isExpanded: true,
                            dropdownColor: AppTheme.card,
                            icon: Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary),
                            hint: Text(
                              'اختر الدفعة المستلمة',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                            items: paymentsForSelectedIncome.map((p) {
                              final rem = provider.paymentAvailable(p.id);
                              final isPos = rem > 0.001;
                              final dateStr = DateFormat('dd MMM yyyy', 'ar').format(p.date);
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  '${isPos ? "🟢 " : "⚪ "}دفعة $dateStr · متاح: ${rem.formatted} ر.ي',
                                  style: TextStyle(
                                    color: isPos ? AppTheme.textPrimary : AppTheme.textMuted,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedIncomePaymentId = v;
                                final p = eligibleIncomePayments
                                    .firstWhereOrNull((ip) => ip.id == v);
                                final inc = provider.incomes
                                    .firstWhereOrNull((i) => i.id == p?.incomeId);
                                if (inc?.walletId != null) {
                                  _selectedWalletId = inc!.walletId;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              if (_selectedIncomePaymentId != null)
                _buildSelectedPaymentInfoCard(
                  title: () {
                    final p = eligibleIncomePayments
                        .firstWhereOrNull((ip) => ip.id == _selectedIncomePaymentId);
                    final inc = provider.incomes
                        .firstWhereOrNull((i) => i.id == p?.incomeId);
                    return inc?.title ?? 'إيراد';
                  }(),
                  date: () {
                    final p = eligibleIncomePayments
                        .firstWhereOrNull((ip) => ip.id == _selectedIncomePaymentId);
                    return p?.date ?? DateTime.now();
                  }(),
                  availableAmount: provider
                      .paymentAvailable(_selectedIncomePaymentId!),
                  totalPayout: totalPayout,
                  walletName: () {
                    final p = eligibleIncomePayments
                        .firstWhereOrNull((ip) => ip.id == _selectedIncomePaymentId);
                    final inc = provider.incomes
                        .firstWhereOrNull((i) => i.id == p?.incomeId);
                    final w = provider.wallets
                        .firstWhereOrNull((wal) => wal.id == inc?.walletId);
                    return w?.name ?? 'المحفظة';
                  }(),
                  accentColor: AppTheme.incomeGreen,
                ),
            ],
          ] else if (_fundingSource == 'debt_settlement') ...[
            if (eligibleDebtSettlements.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFFF59E0B), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'لا توجد حالياً دفعات مستلمة من الديون الشخصية بها رصيد متاح للاستقطاع.',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'توضيح: دفعات استلام الديون هي الدفعات التي قمنا باستلامها من الدائنين / المدينين في شاشة الديون الشخصية (قسم استلام دفعة من الدين).',
                      style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PersonalDebtsScreen()),
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                          'الانتقال لشاشة الديون لتسجيل استلام دفعة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: eligibleDebtSettlements.any((s) => s.id == _selectedDebtSettlementId)
                        ? _selectedDebtSettlementId
                        : null,
                    isExpanded: true,
                    dropdownColor: AppTheme.card,
                    icon: Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary),
                    hint: Text(
                      'اختر دفعة الاستلام من الديون',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    items: eligibleDebtSettlements.map((s) {
                      final debt = provider.personalDebts
                          .firstWhereOrNull((d) => d.id == s.debtId);
                      final person = provider.partners
                          .firstWhereOrNull((p) => p.id == debt?.personId);
                      final rem = provider.debtFundingAvailable(s.id);
                      final dateStr =
                          DateFormat('dd MMM yyyy', 'ar').format(s.date);
                      final isPos = rem > 0.001;
                      final noteText = s.note != null && s.note!.isNotEmpty
                          ? ' (${s.note})'
                          : '';
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${isPos ? "🟢 " : "⚪ "}استلام دين: ${person?.name ?? 'شخص'}$noteText · $dateStr · متاح: ${rem.formatted} ر.ي',
                          style: TextStyle(
                            color: isPos ? AppTheme.textPrimary : AppTheme.textMuted,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedDebtSettlementId = v;
                        final s = eligibleDebtSettlements
                            .firstWhereOrNull((ds) => ds.id == v);
                        if (s?.walletId != null) {
                          _selectedWalletId = s!.walletId;
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedDebtSettlementId != null)
                _buildSelectedPaymentInfoCard(
                  title: () {
                    final s = eligibleDebtSettlements
                        .firstWhereOrNull((ds) => ds.id == _selectedDebtSettlementId);
                    final debt = provider.personalDebts
                        .firstWhereOrNull((d) => d.id == s?.debtId);
                    final person = provider.partners
                        .firstWhereOrNull((p) => p.id == debt?.personId);
                    final noteText = s?.note != null && s!.note!.isNotEmpty
                        ? ' (${s.note})'
                        : '';
                    return 'دين ${person?.name ?? 'شخص'}$noteText';
                  }(),
                  date: () {
                    final s = eligibleDebtSettlements
                        .firstWhereOrNull((ds) => ds.id == _selectedDebtSettlementId);
                    return s?.date ?? DateTime.now();
                  }(),
                  availableAmount: provider
                      .debtFundingAvailable(_selectedDebtSettlementId!),
                  totalPayout: totalPayout,
                  walletName: () {
                    final s = eligibleDebtSettlements
                        .firstWhereOrNull((ds) => ds.id == _selectedDebtSettlementId);
                    final w = provider.wallets
                        .firstWhereOrNull((wal) => wal.id == s?.walletId);
                    return w?.name ?? 'المحفظة';
                  }(),
                  accentColor: const Color(0xFFF59E0B),
                ),
            ],
          ],
          const SizedBox(height: 14),

          // Source Wallet Display (linked directly to the receipt payment)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المحفظة المودع بها الاستلام (جهة الخصم)',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeWallet != null
                            ? '${activeWallet.name} (رصيدها الحالي: ${provider.walletBalance(activeWallet.id).formatted} ر.ي)'
                            : 'لم يتم تحديد محفظة',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Date and Note row
          Row(
            children: [
              // Date picker
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _paymentDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: AppTheme.accentBlue),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy/MM/dd', 'ar').format(_paymentDate),
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Note field
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _noteController,
                  style: TextStyle(
                       color: AppTheme.textPrimary, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'البيان / ملاحظة السداد',
                    prefixIcon: Icon(Icons.note_alt_outlined, size: 16),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOptionTab({
    required String label,
    required String sublabel,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? color : AppTheme.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPaymentInfoCard({
    required String title,
    required DateTime date,
    required double availableAmount,
    required double totalPayout,
    required String walletName,
    required Color accentColor,
  }) {
    final coversAll = availableAmount >= totalPayout - 0.001;
    final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(date);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: coversAll
              ? accentColor.withValues(alpha: 0.4)
              : AppTheme.expenseRed.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                coversAll ? Icons.check_circle_outline : Icons.error_outline,
                color: coversAll ? accentColor : AppTheme.expenseRed,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المتاح من الدفعة: ${availableAmount.formatted} ر.ي',
                style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                'المحفظة: $walletName',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                totalPayout <= 0
                    ? Icons.info_outline
                    : coversAll
                        ? Icons.done_all
                        : Icons.warning_amber_rounded,
                size: 14,
                color: totalPayout <= 0
                    ? AppTheme.textMuted
                    : coversAll
                        ? AppTheme.incomeGreen
                        : AppTheme.expenseRed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  totalPayout <= 0
                      ? 'حدد مبالغ العمال في القائمة بالأسفل للخصم من هذه الدفعة'
                      : coversAll
                          ? 'تغطي كامل مبلغ السداد المطلوب • المتبقي بالدفعة: ${(availableAmount - totalPayout).formatted} ر.ي'
                          : 'المبلغ المطلوب (${totalPayout.formatted} ر.ي) يتجاوز الرصيد المتاح بهذه الدفعة (${availableAmount.formatted} ر.ي)!',
                  style: TextStyle(
                    color: totalPayout <= 0
                        ? AppTheme.textMuted
                        : coversAll
                            ? AppTheme.incomeGreen
                            : AppTheme.expenseRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersListHeader(List<Worker> displayedWorkers) {
    final allSelected = displayedWorkers.isNotEmpty &&
        displayedWorkers.every((w) => _selectedWorkers[w.id] == true);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('قائمة العمال والمبالغ',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('(${displayedWorkers.length})',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _selectAll(displayedWorkers, !allSelected),
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
                size: 16,
              ),
              label: Text(
                allSelected ? 'إلغاء التحديد' : 'تحديد الكل',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              icon: Icon(
                _includeAllWorkers ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: _includeAllWorkers
                    ? AppTheme.accentBlue
                    : AppTheme.textMuted,
                size: 20,
              ),
              tooltip: _includeAllWorkers
                  ? 'عرض العمال ذوي المستحقات فقط'
                  : 'عرض جميع العمال',
              onPressed: () =>
                  setState(() => _includeAllWorkers = !_includeAllWorkers),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkerPayoutCard(FinanceProvider provider, Worker worker) {
    final isSelected = _selectedWorkers[worker.id] ?? false;
    final debt = provider.workerDebt(worker.id);
    final unpaidExpensesCount = provider.expenses
        .where((e) =>
            e.workerId == worker.id &&
            provider.expenseRemainingAmount(e.id) > 0.01)
        .length;

    final controller = _controllers[worker.id]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppTheme.accentBlue.withValues(alpha: 0.6)
              : AppTheme.cardBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: AppTheme.accentBlue,
                  onChanged: (val) {
                    setState(() {
                      _selectedWorkers[worker.id] = val ?? false;
                    });
                  },
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlueDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.engineering,
                      color: AppTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (worker.phone != null && worker.phone!.isNotEmpty)
                            Text(worker.phone!,
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                          if (unpaidExpensesCount > 0) ...[
                            if (worker.phone != null &&
                                worker.phone!.isNotEmpty)
                              Text(' • ',
                                  style: TextStyle(
                                      color: AppTheme.textMuted, fontSize: 11)),
                            Text('$unpaidExpensesCount يومية/أجر معلق',
                                style: TextStyle(
                                    color: AppTheme.expenseRed, fontSize: 11)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('المستحق الحالي',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    Text(
                      '${debt.formatted} ر.ي',
                      style: TextStyle(
                        color: debt > 0
                            ? AppTheme.expenseRed
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isSelected) ...[
              Divider(color: AppTheme.cardBorder, height: 16),
              Row(
                children: [
                  Text('المبلغ المطلوب صرفه:',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                      decoration: const InputDecoration(
                        suffixText: 'ر.ي',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('كامل المبلغ',
                        style: TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      controller.text = debt.plain;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(
      BuildContext context, FinanceProvider provider, double totalPayout) {
    final selectedCount = _selectedCount();

    double availableFunding = 0.0;
    bool hasSelectedPayment = false;
    if (_fundingSource == 'income') {
      if (_selectedIncomePaymentId != null) {
        hasSelectedPayment = true;
        availableFunding = provider.paymentAvailable(_selectedIncomePaymentId!);
      }
    } else if (_fundingSource == 'debt_settlement') {
      if (_selectedDebtSettlementId != null) {
        hasSelectedPayment = true;
        availableFunding =
            provider.debtFundingAvailable(_selectedDebtSettlementId!);
      }
    }

    final hasFundingShortage =
        hasSelectedPayment && totalPayout > availableFunding + 0.001;
    final isEnabled = selectedCount > 0 &&
        totalPayout > 0 &&
        hasSelectedPayment &&
        !hasFundingShortage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFundingShortage && selectedCount > 0 && totalPayout > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.expenseRedDim.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.expenseRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    color: AppTheme.expenseRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المبلغ المطلوب (${totalPayout.formatted} ر.ي) يتجاوز المتاح في الدفعة المختارة (${availableFunding.formatted} ر.ي) بمقدار ${(totalPayout - availableFunding).formatted} ر.ي.',
                    style: TextStyle(
                        color: AppTheme.expenseRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                isEnabled ? () => _confirmPayout(context, provider) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.incomeGreen,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppTheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(
              hasFundingShortage ? Icons.block : Icons.check_circle,
              size: 20,
            ),
            label: Text(
              hasFundingShortage
                  ? 'المبلغ يتجاوز رصيد الدفعة المختارة'
                  : 'تأكيد سداد ${totalPayout.formatted} ر.ي ($selectedCount عمال)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmPayout(BuildContext context, FinanceProvider provider) {
    final payouts = <({String workerId, double amount})>[];
    _selectedWorkers.forEach((workerId, isSelected) {
      if (isSelected) {
        final amount =
            double.tryParse(_controllers[workerId]?.text.trim() ?? '0') ?? 0;
        if (amount > 0.001) {
          payouts.add((workerId: workerId, amount: amount));
        }
      }
    });

    if (payouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبالغ صالحة للعمال المحددين')),
      );
      return;
    }

    if (_fundingSource == 'income' && _selectedIncomePaymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء اختيار دفعة استلام إيراد محددة')),
      );
      return;
    }

    if (_fundingSource == 'debt_settlement' &&
        _selectedDebtSettlementId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء اختيار دفعة استلام ديون وأقساط محددة من شاشة الديون الشخصية')),
      );
      return;
    }

    final total = payouts.fold(0.0, (s, p) => s + p.amount);

    // Build source description and check availability
    String sourceTitle = '';
    String sourceDetails = '';
    String walletName = '';
    double availableFunding = 0.0;

    if (_fundingSource == 'income') {
      final payment = provider.incomePayments
          .firstWhereOrNull((p) => p.id == _selectedIncomePaymentId);
      final inc = provider.incomes
          .firstWhereOrNull((i) => i.id == payment?.incomeId);
      final dateStr = payment != null
          ? DateFormat('yyyy/MM/dd', 'ar').format(payment.date)
          : '';
      final wal = provider.wallets
          .firstWhereOrNull((w) => w.id == inc?.walletId);
      walletName = wal?.name ?? 'المحفظة الافتراضية';
      sourceTitle = 'دفعة استلام إيراد محددة';
      sourceDetails = '${inc?.title ?? 'إيراد'} · تاريخ $dateStr';
      availableFunding =
          provider.paymentAvailable(_selectedIncomePaymentId!);
    } else if (_fundingSource == 'debt_settlement') {
        final settlement = provider.debtFundingSources
          .firstWhereOrNull((s) => s.id == _selectedDebtSettlementId);
      final debt = provider.personalDebts
          .firstWhereOrNull((d) => d.id == settlement?.debtId);
      final person = provider.partners
          .firstWhereOrNull((p) => p.id == debt?.personId);
      final dateStr = settlement != null
          ? DateFormat('yyyy/MM/dd', 'ar').format(settlement.date)
          : '';
      final wal = provider.wallets
          .firstWhereOrNull((w) => w.id == settlement?.walletId);
      walletName = wal?.name ?? 'المحفظة الافتراضية';
      final noteText = settlement?.note != null && settlement!.note!.isNotEmpty
          ? ' · ${settlement.note}'
          : '';
      sourceTitle = 'دفعة استلام ديون وأقساط من شاشة الديون الشخصية';
      sourceDetails = 'دين ${person?.name ?? 'شخص'}$noteText · تاريخ $dateStr';
      availableFunding =
          provider.debtFundingAvailable(_selectedDebtSettlementId!);
    }

    if (total > availableFunding + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'المبلغ الإجمالي المطلوب (${total.formatted} ر.ي) يتجاوز الرصيد المتاح في الدفعة المحددة (${availableFunding.formatted} ر.ي).'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.payments, color: AppTheme.incomeGreen),
            SizedBox(width: 8),
            Text('تأكيد السداد المجمع',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من صرف ${total.formatted} ر.ي إلى ${payouts.length} عمال؟',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link,
                          size: 16, color: AppTheme.accentBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'المصدر: $sourceTitle',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• $sourceDetails',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• المحفظة: $walletName',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• المتاح في الدفعة: ${availableFunding.formatted} ر.ي',
                    style: TextStyle(
                        color: AppTheme.incomeGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• المتبقي في الدفعة بعد السداد: ${(availableFunding - total).formatted} ر.ي',
                    style: TextStyle(
                        color: AppTheme.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                provider.batchPayWorkerWages(
                  workerPayouts: payouts,
                  date: _paymentDate,
                  walletId: _selectedWalletId,
                  fundingSource: _fundingSource,
                  specificIncomePaymentId: _fundingSource == 'income'
                      ? _selectedIncomePaymentId
                      : null,
                  specificDebtSettlementId:
                      _fundingSource == 'debt_settlement'
                          ? _selectedDebtSettlementId
                          : null,
                  note: _noteController.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'تم سداد مستحقات ${payouts.length} عمال بنجاح (${total.formatted} ر.ي)'),
                    backgroundColor: AppTheme.incomeGreen,
                  ),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ أثناء تنفيذ السداد: $e'),
                    backgroundColor: AppTheme.expenseRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.incomeGreen,
              foregroundColor: Colors.black,
            ),
            child: const Text('تأكيد الصرف',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
