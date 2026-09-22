import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets.dart';

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});

  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final totalDue = provider.totalZakatDue;
        final totalPaid = provider.totalZakatPaid;
        final totalRemaining = provider.totalZakatRemaining;

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: const Text('محاسبة وسجلات الزكاة'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.incomeGreen,
              labelColor: AppTheme.incomeGreen,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.assignment_outlined), text: 'الاستحقاقات'),
                Tab(icon: Icon(Icons.payments_outlined), text: 'سندات الإخراج'),
                Tab(icon: Icon(Icons.menu_book_outlined), text: 'كشف الحساب'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildAccountingHeader(totalDue, totalPaid, totalRemaining),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ZakatEntriesTab(provider: provider),
                    _ZakatPaymentsTab(provider: provider),
                    _ZakatLedgerTab(provider: provider),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddZakatMenu(context, provider),
            backgroundColor: AppTheme.incomeGreen,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: const Text('إجراء زكاة',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }

  Widget _buildAccountingHeader(
      double totalDue, double totalPaid, double totalRemaining) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _headerStatItem(
                  'الواجب في الذمة',
                  'دائن (+)',
                  totalDue,
                  AppTheme.accentBlue,
                  Icons.account_balance_outlined,
                ),
              ),
              Container(width: 1, height: 48, color: AppTheme.cardBorder),
              Expanded(
                child: _headerStatItem(
                  'المُخرَج والمدفوع',
                  'مدين (-)',
                  totalPaid,
                  AppTheme.incomeGreen,
                  Icons.check_circle_outline,
                ),
              ),
              Container(width: 1, height: 48, color: AppTheme.cardBorder),
              Expanded(
                child: _headerStatItem(
                  'المتبقي للصرف',
                  'الرصيد المستحق',
                  totalRemaining,
                  totalRemaining > 0 ? Colors.orange : AppTheme.textMuted,
                  Icons.pending_actions_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStatItem(String title, String subtitle, double amount,
      Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${amount.formatted} ر.ي',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(subtitle,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9)),
      ],
    );
  }

  void _showAddZakatMenu(BuildContext context, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('إجراءات الزكاة المحاسبية',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.incomeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.payments_outlined,
                      color: AppTheme.incomeGreen),
                ),
                title: Text('إخراج زكاة (سند صرف مالي)',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'تسديد دفعة زكاة وسحبها من محفظة لمستحق أو مصرف',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  showZakatPaymentDialog(context, provider);
                },
              ),
              Divider(color: AppTheme.cardBorder),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_task_outlined,
                      color: AppTheme.accentBlue),
                ),
                title: Text('تسجيل استحقاق زكاة يدوي (التزام في الذمة)',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'إضافة وجوب زكاة عروض تجارة أو نقد أو ثمار يدوياً',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddEditZakatEntryDialog(context, provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 1. Tab: استحقاقات الزكاة
// --------------------------------------------------------------------------

class _ZakatEntriesTab extends StatelessWidget {
  final FinanceProvider provider;

  const _ZakatEntriesTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final entries = provider.allZakatEntries;
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('لا توجد استحقاقات زكاة مسجلة',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 6),
            Text(
                'يتم احتساب زكاة الزروع تلقائياً عند تسجيل إيرادات لمواضع عليها زكاة\nأو يمكنك إضافة استحقاق يدوي',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final paid = provider.zakatPaidForEntry(entry);
        final remaining = provider.zakatRemainingForEntry(entry);
        final isAuto = entry.incomeId != null;

        Color statusColor = AppTheme.expenseRed;
        String statusLabel = 'غير مسددة';
        if (remaining <= 0) {
          statusColor = AppTheme.incomeGreen;
          statusLabel = 'خالصة بالكامل';
        } else if (paid > 0) {
          statusColor = Colors.orange;
          statusLabel = 'مسددة جزئياً';
        }

        LandPlot? plot;
        if (entry.landPlotId != null) {
          try {
            plot = provider.landPlots.firstWhere((p) => p.id == entry.landPlotId);
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: remaining <= 0
                  ? AppTheme.cardBorder
                  : statusColor.withValues(alpha: 0.4),
            ),
          ),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape:
                const RoundedRectangleBorder(side: BorderSide.none),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                remaining <= 0
                    ? Icons.check_circle_outline
                    : Icons.volunteer_activism_outlined,
                color: statusColor,
                size: 22,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMMM yyyy', 'ar').format(entry.date),
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                      if (plot != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.terrain,
                            size: 12, color: AppTheme.accentBlue),
                        const SizedBox(width: 4),
                        Text(plot.name,
                            style: TextStyle(
                                color: AppTheme.accentBlue, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الواجب: ${entry.amount.formatted} ر.ي',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'المسدد: ${paid.formatted} ر.ي',
                        style: TextStyle(
                          color: AppTheme.incomeGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'المتبقي: ${remaining.formatted} ر.ي',
                        style: TextStyle(
                          color: remaining > 0 ? Colors.orange : AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.5),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes,
                              size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.notes!,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildPaymentsListForEntry(context, provider, entry),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (remaining > 0)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showZakatPaymentDialog(
                                  context,
                                  provider,
                                  preselectedEntry: entry,
                                  suggestedAmount: remaining,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.incomeGreen,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.payments_outlined, size: 18),
                              label: const Text('إخراج دفعة زكاة',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        if (!isAuto) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => _showAddEditZakatEntryDialog(
                                context, provider,
                                entryToEdit: entry),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.cardBorder,
                              foregroundColor: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            onPressed: () =>
                                _confirmDeleteEntry(context, provider, entry),
                            icon: Icon(Icons.delete_outline,
                                color: AppTheme.expenseRed, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.cardBorder,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsListForEntry(
      BuildContext context, FinanceProvider provider, ZakatEntry entry) {
    final payments = provider.getZakatPaymentsForEntry(entry);
    if (payments.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'لم يتم تسجيل أي سندات صرف أو دفعات لهذا الاستحقاق بعد.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سندات الصرف المخرجة لهذا الاستحقاق:',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...payments.map((p) {
          Wallet? w;
          try {
            w = provider.wallets.firstWhere((wallet) => wallet.id == p.walletId);
          } catch (_) {}
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.check, color: AppTheme.incomeGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.amount.formatted} ر.ي  •  ${p.recipient?.isNotEmpty == true ? p.recipient : (p.recipientCategory ?? "مستحق")}',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${DateFormat('dd/MM/yyyy', 'ar').format(p.date)}  •  المحفظة: ${w?.name ?? "غير محددة"}',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: AppTheme.expenseRed, size: 16),
                  onPressed: () => _confirmDeletePayment(context, provider, p),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _confirmDeleteEntry(
      BuildContext context, FinanceProvider provider, ZakatEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف استحقاق الزكاة',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'هل أنت متأكد من حذف هذا الاستحقاق اليدوي؟ سيتم حذف أي سندات صرف مرتبطة به واسترجاع مبالغها إلى المحافظ.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expenseRed),
            onPressed: () {
              provider.deleteManualZakatEntry(entry.id);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 2. Tab: سندات إخراج الزكاة (المدفوعات)
// --------------------------------------------------------------------------

class _ZakatPaymentsTab extends StatelessWidget {
  final FinanceProvider provider;

  const _ZakatPaymentsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final payments = provider.zakatPayments.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined,
                size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('لم يتم تسجيل أي سندات إخراج زكاة بعد',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 6),
            Text('اضغط على "إجراء زكاة" لتسجيل سند صرف زكاة لمستحق أو جهة',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        Wallet? w;
        try {
          w = provider.wallets.firstWhere((wallet) => wallet.id == payment.walletId);
        } catch (_) {}

        String? linkedTitle;
        if (payment.zakatEntryId != null) {
          final entry = provider.allZakatEntries
              .firstWhereOrNull((e) => e.id == payment.zakatEntryId);
          linkedTitle = entry?.title;
        } else if (payment.incomeId != null) {
          final inc =
              provider.incomes.firstWhereOrNull((i) => i.id == payment.incomeId);
          if (inc != null) linkedTitle = 'زكاة إيراد: ${inc.title}';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.incomeGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.volunteer_activism,
                        color: AppTheme.incomeGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${payment.amount.formatted} ر.ي',
                          style: TextStyle(
                            color: AppTheme.incomeGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'المستفيد: ${payment.recipient?.isNotEmpty == true ? payment.recipient : (payment.recipientCategory ?? "مستحق")}',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: AppTheme.textMuted, size: 20),
                    color: AppTheme.card,
                    onSelected: (val) {
                      if (val == 'edit') {
                        showZakatPaymentDialog(context, provider,
                            paymentToEdit: payment);
                      } else if (val == 'delete') {
                        _confirmDeletePayment(context, provider, payment);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 16, color: AppTheme.textPrimary),
                            SizedBox(width: 8),
                            Text('تعديل',
                                style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: AppTheme.expenseRed),
                            SizedBox(width: 8),
                            Text('حذف',
                                style: TextStyle(color: AppTheme.expenseRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: AppTheme.cardBorder, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMMM yyyy', 'ar').format(payment.date),
                    style:
                        TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 13, color: AppTheme.accentBlue),
                  const SizedBox(width: 4),
                  Text(
                    'المحفظة: ${w?.name ?? "غير محددة"}',
                    style: TextStyle(
                        color: AppTheme.accentBlue, fontSize: 12),
                  ),
                ],
              ),
              if (payment.recipientCategory != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.category_outlined,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'مصرف الزكاة: ${payment.recipientCategory}',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
              if (linkedTitle != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.link,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'عن: $linkedTitle',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes,
                        size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        payment.notes!,
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

void _confirmDeletePayment(
    BuildContext context, FinanceProvider provider, ZakatPayment payment) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('حذف سند إخراج الزكاة',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Text(
        'هل أنت متأكد من حذف هذا السند؟ سيتم إلغاء حركة الصرف واسترجاع المبلغ إلى المحفظة.',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expenseRed),
          onPressed: () {
            provider.deleteZakatPayment(payment.id);
            Navigator.pop(ctx);
          },
          child: const Text('حذف', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

// --------------------------------------------------------------------------
// 3. Tab: كشف الحساب المحاسبي (Ledger / دائن ومدين ورصيد)
// --------------------------------------------------------------------------

class _ZakatLedgerItem {
  final DateTime date;
  final String title;
  final String description;
  final double credit; // دائن (+) وجوب الزكاة
  final double debit; // مدين (-) إخراج وصرف الزكاة
  final double balance; // الرصيد المتبقي التراكمي
  final bool isObligation;

  _ZakatLedgerItem({
    required this.date,
    required this.title,
    required this.description,
    required this.credit,
    required this.debit,
    required this.balance,
    required this.isObligation,
  });
}

class _ZakatLedgerTab extends StatelessWidget {
  final FinanceProvider provider;

  const _ZakatLedgerTab({required this.provider});

  List<_ZakatLedgerItem> _buildLedger() {
    // 1. تجميع كل الحركات (وجوب + صرف) مرتبة زمنياً تصاعدياً
    final events = <_RawZakatEvent>[];

    for (final entry in provider.allZakatEntries) {
      events.add(_RawZakatEvent(
        date: entry.date,
        isObligation: true,
        title: entry.title,
        description: entry.notes ??
            (entry.incomeId != null
                ? 'استحقاق زكاة زروع ناتج عن إيراد محصول'
                : 'استحقاق زكاة يدوي واجب في الذمة'),
        amount: entry.amount,
      ));
    }

    for (final p in provider.zakatPayments) {
      events.add(_RawZakatEvent(
        date: p.date,
        isObligation: false,
        title:
            'سند إخراج زكاة: ${p.recipient?.isNotEmpty == true ? p.recipient : (p.recipientCategory ?? "مستحق")}',
        description:
            'صرف من محفظة: ${provider.wallets.firstWhereOrNull((w) => w.id == p.walletId)?.name ?? "غير محددة"} ${p.notes != null ? "- " + p.notes! : ""}',
        amount: p.amount,
      ));
    }

    // فرز تصاعدي لحساب الرصيد التراكمي
    events.sort((a, b) => a.date.compareTo(b.date));

    double runningBalance = 0.0;
    final ledger = <_ZakatLedgerItem>[];

    for (final ev in events) {
      if (ev.isObligation) {
        runningBalance += ev.amount;
        ledger.add(_ZakatLedgerItem(
          date: ev.date,
          title: ev.title,
          description: ev.description,
          credit: ev.amount,
          debit: 0.0,
          balance: runningBalance,
          isObligation: true,
        ));
      } else {
        runningBalance -= ev.amount;
        ledger.add(_ZakatLedgerItem(
          date: ev.date,
          title: ev.title,
          description: ev.description,
          credit: 0.0,
          debit: ev.amount,
          balance: runningBalance,
          isObligation: false,
        ));
      }
    }

    // إرجاع القائمة فرز تنازلي للعرض للمستخدم (الأحدث أولاً)
    return ledger.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _buildLedger();

    if (ledger.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('لا توجد قيود في دفتر حساب الزكاة بعد',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: ledger.length,
      itemBuilder: (context, index) {
        final item = ledger[index];
        final isCredit = item.isObligation;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCredit
                          ? AppTheme.accentBlue.withValues(alpha: 0.15)
                          : AppTheme.incomeGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: isCredit
                          ? AppTheme.accentBlue
                          : AppTheme.incomeGreen,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMMM yyyy', 'ar').format(item.date),
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCredit
                          ? AppTheme.accentBlue.withValues(alpha: 0.15)
                          : AppTheme.incomeGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCredit ? 'دائن (+ وجوب)' : 'مدين (- سداد)',
                      style: TextStyle(
                        color: isCredit
                            ? AppTheme.accentBlue
                            : AppTheme.incomeGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.description,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCredit ? 'مبلغ الاستحقاق' : 'المبلغ المصروف',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 10),
                        ),
                        Text(
                          '${(isCredit ? item.credit : item.debit).formatted} ر.ي',
                          style: TextStyle(
                            color: isCredit
                                ? AppTheme.accentBlue
                                : AppTheme.incomeGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'الرصيد المتبقي في الذمة',
                          style:
                              TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        ),
                        Text(
                          '${item.balance.formatted} ر.ي',
                          style: TextStyle(
                            color: item.balance > 0
                                ? Colors.orange
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RawZakatEvent {
  final DateTime date;
  final bool isObligation;
  final String title;
  final String description;
  final double amount;

  _RawZakatEvent({
    required this.date,
    required this.isObligation,
    required this.title,
    required this.description,
    required this.amount,
  });
}

// --------------------------------------------------------------------------
// 4. Modal Sheet: تسجيل أو تعديل سند إخراج زكاة (صرف مالي)
// --------------------------------------------------------------------------

void showZakatPaymentDialog(
  BuildContext context,
  FinanceProvider provider, {
  ZakatPayment? paymentToEdit,
  ZakatEntry? preselectedEntry,
  double? suggestedAmount,
}) {
  final amountCtrl = TextEditingController(
    text: paymentToEdit != null
        ? paymentToEdit.amount.toString()
        : (suggestedAmount != null && suggestedAmount > 0
            ? suggestedAmount.toStringAsFixed(2)
            : ''),
  );
  final recipientCtrl =
      TextEditingController(text: paymentToEdit?.recipient ?? '');
  final notesCtrl = TextEditingController(text: paymentToEdit?.notes ?? '');

  DateTime date = paymentToEdit?.date ?? DateTime.now();
  String selectedWalletId = paymentToEdit?.walletId ??
      (provider.wallets.isNotEmpty ? provider.wallets.first.id : '');
  String selectedCategory =
      paymentToEdit?.recipientCategory ?? zakatCategories.first;

  String? selectedEntryId = paymentToEdit?.zakatEntryId ?? preselectedEntry?.id;

  final fundingKey = GlobalKey<FundingPickerState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final double currentAmount = double.tryParse(amountCtrl.text) ?? 0.0;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
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
                    Icon(Icons.volunteer_activism,
                        color: AppTheme.incomeGreen, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      paymentToEdit == null
                          ? 'تسجيل سند إخراج زكاة'
                          : 'تعديل سند إخراج زكاة',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ربط باستحقاق معين (اختياري)
                if (provider.allZakatEntries.isNotEmpty) ...[
                  Text('الاستحقاق المرتبط (اختياري):',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedEntryId,
                        isExpanded: true,
                        dropdownColor: AppTheme.surface,
                        hint: Text('إخراج عام (غير مربوط باستحقاق معين)',
                            style: TextStyle(color: AppTheme.textMuted)),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('إخراج عام (غير مربوط باستحقاق معين)',
                                style: TextStyle(color: AppTheme.textPrimary)),
                          ),
                          ...provider.allZakatEntries.map((e) {
                            final rem = provider.zakatRemainingForEntry(e);
                            return DropdownMenuItem<String?>(
                              value: e.id,
                              child: Text(
                                '${e.title} (متبقي: ${rem.formatted} ر.ي)',
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 13),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setSheetState(() {
                            selectedEntryId = val;
                            if (val != null) {
                              final ent = provider.allZakatEntries
                                  .firstWhereOrNull((e) => e.id == val);
                              if (ent != null) {
                                final rem = provider.zakatRemainingForEntry(ent);
                                if (rem > 0 && amountCtrl.text.isEmpty) {
                                  amountCtrl.text = rem.toStringAsFixed(2);
                                }
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // المبلغ
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                  onChanged: (v) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'مبلغ الزكاة المصروف *',
                    suffixText: 'ر.ي',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // المحفظة المسحوب منها
                Text('المحفظة المسحوب منها المبلغ *',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedWalletId.isNotEmpty ? selectedWalletId : null,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      hint: Text('اختر المحفظة',
                          style: TextStyle(color: AppTheme.textMuted)),
                      items: provider.wallets.map((w) {
                        final bal = provider.walletBalance(w.id);
                        return DropdownMenuItem<String>(
                          value: w.id,
                          child: Text(
                            '${w.name} (الرصيد: ${bal.formatted} ر.ي)',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedWalletId = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // مصرف الزكاة
                Text('مصرف الزكاة الشرعي *',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      items: zakatCategories
                          .map((c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedCategory = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // اسم المستلم / الجهة
                TextField(
                  controller: recipientCtrl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'اسم المستلم أو الجهة (مثلاً: عائلة فلان / جمعية البر)',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // التاريخ
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (ctx, child) => Theme(
                        data: AppTheme.theme.copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: AppTheme.incomeGreen,
                            surface: AppTheme.card,
                          ),
                        ),
                        child: child!,
                      ),
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
                        Text(DateFormat('dd MMMM yyyy', 'ar').format(date),
                            style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // الملاحظات
                TextField(
                  controller: notesCtrl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات إضافية',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // FundingPicker: الاستقطاع من دفعات الإيراد المتاحة
                if (currentAmount > 0) ...[
                  Text('الاستقطاع من دفعات الإيراد (التمويل):',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FundingPicker(
                    pickerKey: fundingKey,
                    provider: provider,
                    walletFilter: selectedWalletId.isNotEmpty
                        ? selectedWalletId
                        : null,
                    requiredTotal: currentAmount,
                    requiredTotalGetter: () => currentAmount,
                    autoAmount: currentAmount,
                  ),
                  const SizedBox(height: 20),
                ],

                // زر الحفظ
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('الرجاء إدخال مبلغ صحيح')),
                        );
                        return;
                      }
                      if (selectedWalletId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('الرجاء تحديد محفظة للسحب')),
                        );
                        return;
                      }

                      List<ExpenseAllocation> allocations = [];
                      if (fundingKey.currentState != null) {
                        if (!fundingKey.currentState!.validate()) return;
                        allocations = fundingKey.currentState!.allocations;
                      }

                      String? linkedIncomeId;
                      if (selectedEntryId != null) {
                        final ent = provider.allZakatEntries
                            .firstWhereOrNull((e) => e.id == selectedEntryId);
                        linkedIncomeId = ent?.incomeId;
                      }

                      if (paymentToEdit == null) {
                        final newPayment = ZakatPayment(
                          id: const Uuid().v4(),
                          zakatEntryId: selectedEntryId,
                          incomeId: linkedIncomeId,
                          amount: amt,
                          date: date,
                          walletId: selectedWalletId,
                          recipient: recipientCtrl.text.trim().isNotEmpty
                              ? recipientCtrl.text.trim()
                              : null,
                          recipientCategory: selectedCategory,
                          notes: notesCtrl.text.trim().isNotEmpty
                              ? notesCtrl.text.trim()
                              : null,
                          funding: allocations,
                        );
                        provider.addZakatPayment(newPayment,
                            funding: allocations);
                      } else {
                        final updated = ZakatPayment(
                          id: paymentToEdit.id,
                          zakatEntryId: selectedEntryId,
                          incomeId: linkedIncomeId,
                          amount: amt,
                          date: date,
                          walletId: selectedWalletId,
                          recipient: recipientCtrl.text.trim().isNotEmpty
                              ? recipientCtrl.text.trim()
                              : null,
                          recipientCategory: selectedCategory,
                          notes: notesCtrl.text.trim().isNotEmpty
                              ? notesCtrl.text.trim()
                              : null,
                          funding: allocations,
                        );
                        provider.updateZakatPayment(updated,
                            funding: allocations);
                      }
                      Navigator.pop(modalCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.incomeGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      paymentToEdit == null ? 'تأكيد وحفظ الصرف' : 'تحديث السند',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// --------------------------------------------------------------------------
// 5. Modal Sheet: إضافة أو تعديل استحقاق زكاة يدوي (التزام في الذمة)
// --------------------------------------------------------------------------

void _showAddEditZakatEntryDialog(
  BuildContext context,
  FinanceProvider provider, {
  ZakatEntry? entryToEdit,
}) {
  final titleCtrl = TextEditingController(
      text: entryToEdit?.title ?? 'زكاة عروض تجارة / نقد');
  final amountCtrl = TextEditingController(
      text: entryToEdit != null ? entryToEdit.amount.toString() : '');
  final notesCtrl = TextEditingController(text: entryToEdit?.notes ?? '');
  DateTime date = entryToEdit?.date ?? DateTime.now();
  String selectedType = entryToEdit?.type ?? 'money';
  String? selectedPlotId = entryToEdit?.landPlotId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
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
                  Icon(Icons.add_task_outlined,
                      color: AppTheme.accentBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    entryToEdit == null
                        ? 'تسجيل استحقاق زكاة يدوي (دين في الذمة)'
                        : 'تعديل استحقاق الزكاة',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // العنوان
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'عنوان الاستحقاق / البيان *',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // المبلغ
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'المبلغ الواجب إخراجه *',
                  suffixText: 'ر.ي',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // نوع الزكاة
              Text('نوع الزكاة:',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    dropdownColor: AppTheme.surface,
                    items: const [
                      DropdownMenuItem(
                          value: 'crops', child: Text('زكاة زروع وثمار')),
                      DropdownMenuItem(
                          value: 'money', child: Text('زكاة مال / نقد')),
                      DropdownMenuItem(
                          value: 'trade', child: Text('زكاة عروض تجارة')),
                      DropdownMenuItem(value: 'other', child: Text('أخرى')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // الموضع الزراعي (اختياري)
              if (provider.landPlots.isNotEmpty) ...[
                Text('الموضع الزراعي (اختياري):',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedPlotId,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      hint: Text('غير مرتبط بموضع',
                          style: TextStyle(color: AppTheme.textMuted)),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('غير مرتبط بموضع',
                              style: TextStyle(color: AppTheme.textPrimary)),
                        ),
                        ...provider.landPlots.map((p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(p.name,
                                  style: TextStyle(
                                      color: AppTheme.textPrimary)),
                            )),
                      ],
                      onChanged: (val) =>
                          setSheetState(() => selectedPlotId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // التاريخ
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (ctx, child) => Theme(
                      data: AppTheme.theme.copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: AppTheme.accentBlue,
                          surface: AppTheme.card,
                        ),
                      ),
                      child: child!,
                    ),
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
                      Text(DateFormat('dd MMMM yyyy', 'ar').format(date),
                          style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ملاحظات
              TextField(
                controller: notesCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'ملاحظات وتفاصيل الاستحقاق',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (title.isEmpty || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('الرجاء إدخال عنوان ومبلغ استحقاق صحيح')),
                      );
                      return;
                    }

                    if (entryToEdit == null) {
                      final newEntry = ZakatEntry(
                        id: const Uuid().v4(),
                        title: title,
                        amount: amt,
                        date: date,
                        type: selectedType,
                        landPlotId: selectedPlotId,
                        notes: notesCtrl.text.trim().isNotEmpty
                            ? notesCtrl.text.trim()
                            : null,
                      );
                      provider.addManualZakatEntry(newEntry);
                    } else {
                      final updated = ZakatEntry(
                        id: entryToEdit.id,
                        incomeId: entryToEdit.incomeId,
                        title: title,
                        amount: amt,
                        date: date,
                        type: selectedType,
                        landPlotId: selectedPlotId,
                        notes: notesCtrl.text.trim().isNotEmpty
                            ? notesCtrl.text.trim()
                            : null,
                      );
                      provider.updateManualZakatEntry(updated);
                    }
                    Navigator.pop(modalCtx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    entryToEdit == null ? 'تسجيل الاستحقاق' : 'تحديث الاستحقاق',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
