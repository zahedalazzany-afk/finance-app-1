import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();

  static void showWalletForm(BuildContext context, FinanceProvider provider,
      {Wallet? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetContext.dynamicCardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  existing == null ? 'إضافة محفظة / خزينة جديدة' : 'تعديل بيانات المحفظة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: sheetContext.dynamicTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameController,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: sheetContext.dynamicTextPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: sheetContext.dynamicSurfaceBg,
                    labelText: 'اسم المحفظة أو الخزينة *',
                    hintText: 'مثال: الخزينة الرئيسية، بنك الكريمي، محفظة كاش...',
                    hintStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: sheetContext.dynamicTextMuted,
                      fontSize: 12,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: sheetContext.dynamicTextSecondary,
                    ),
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: sheetContext.dynamicCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: sheetContext.dynamicCardBorder),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المحفظة' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: sheetContext.dynamicTextPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: sheetContext.dynamicSurfaceBg,
                    labelText: 'ملاحظات وتفاصيل الحساب',
                    hintText: 'رقم الحساب، جهة الصرف، أو ملاحظات إضافية (اختياري)',
                    hintStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: sheetContext.dynamicTextMuted,
                      fontSize: 12,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: sheetContext.dynamicTextSecondary,
                    ),
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: sheetContext.dynamicCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: sheetContext.dynamicCardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (existing != null) {
                      existing.name = nameController.text.trim();
                      existing.notes = notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim();
                      provider.updateWallet(existing);
                    } else {
                      provider.addWallet(Wallet(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ));
                    }
                    Navigator.pop(sheetContext);
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
                    existing == null ? 'حفظ المحفظة' : 'تحديث البيانات',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletsScreenState extends State<WalletsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'positive', 'negative', 'zero'
  String _sortBy = 'balance_desc'; // 'balance_desc', 'balance_asc', 'activity', 'name'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteWallet(
      BuildContext context, FinanceProvider provider, Wallet wallet, double balance) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف المحفظة',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: context.dynamicTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من رغبتك في حذف محفظة "${wallet.name}"؟',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: context.dynamicTextSecondary,
                fontSize: 14,
              ),
            ),
            if (balance != 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (balance > 0 ? AppTheme.incomeGreen : AppTheme.expenseRed)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (balance > 0 ? AppTheme.incomeGreen : AppTheme.expenseRed)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: balance > 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تنبيه: الرصيد الحالي للمحفظة هو ${balance.formatted} ر.ي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: balance > 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () {
              final deleted = provider.deleteWallet(wallet.id);
              Navigator.pop(context);
              if (!deleted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لا يمكن حذف المحفظة لأنها مرتبطة بعمليات مالية'),
                  ),
                );
              }
            },
            child: Text(
              'تأكيد الحذف',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: AppTheme.expenseRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allWallets = provider.wallets;
    final totalBalance = provider.totalWalletsBalance;

    // Calculate metrics
    final positiveWallets =
        allWallets.where((w) => provider.walletBalance(w.id) > 0.001).toList();
    final negativeWallets =
        allWallets.where((w) => provider.walletBalance(w.id) < -0.001).toList();
    final zeroWallets = allWallets
        .where((w) => provider.walletBalance(w.id).abs() <= 0.001)
        .toList();

    // Top wallet by balance
    Wallet? topWallet;
    double topBalance = -double.infinity;
    for (final w in allWallets) {
      final bal = provider.walletBalance(w.id);
      if (bal > topBalance) {
        topBalance = bal;
        topWallet = w;
      }
    }

    // Filter wallets
    var filtered = allWallets.where((w) {
      final bal = provider.walletBalance(w.id);
      if (_selectedFilter == 'positive' && bal <= 0.001) return false;
      if (_selectedFilter == 'negative' && bal >= -0.001) return false;
      if (_selectedFilter == 'zero' && bal.abs() > 0.001) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final nameMatch = w.name.toLowerCase().contains(q);
        final notesMatch = w.notes?.toLowerCase().contains(q) ?? false;
        return nameMatch || notesMatch;
      }
      return true;
    }).toList();

    // Sort wallets
    if (_sortBy == 'balance_desc') {
      filtered.sort((a, b) =>
          provider.walletBalance(b.id).compareTo(provider.walletBalance(a.id)));
    } else if (_sortBy == 'balance_asc') {
      filtered.sort((a, b) =>
          provider.walletBalance(a.id).compareTo(provider.walletBalance(b.id)));
    } else if (_sortBy == 'name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'activity') {
      filtered.sort((a, b) {
        final aCount = provider.getPaymentsForWallet(a.id).length +
            provider.getExpensePaymentsForWallet(a.id).length +
            provider.getMovementsForWallet(a.id).length;
        final bCount = provider.getPaymentsForWallet(b.id).length +
            provider.getExpensePaymentsForWallet(b.id).length +
            provider.getMovementsForWallet(b.id).length;
        return bCount.compareTo(aCount);
      });
    }

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'الخزائن والمحافظ المالية',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          DataExportImportButton(
            label: 'المحافظ',
            buildRows: () =>
                provider.wallets.map((e) => e.toJson()).toList(),
            csvHeaders: const ['الاسم', 'ملاحظات'],
            csvKeys: const ['name', 'notes'],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final wallet = Wallet.fromJson(row);
                  if (provider.wallets.any((e) => e.id == wallet.id)) continue;
                  provider.addWallet(wallet);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero Treasury / Liquidity Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.14),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.account_balance_rounded,
                            color: AppTheme.accentBlue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي السيولة النقدية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: context.dynamicTextSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  totalBalance.formatted,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: totalBalance >= 0
                                        ? AppTheme.incomeGreen
                                        : AppTheme.expenseRed,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ر.ي',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: context.dynamicTextSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (totalBalance >= 0
                                ? AppTheme.incomeGreen
                                : AppTheme.expenseRed)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (totalBalance >= 0
                                  ? AppTheme.incomeGreen
                                  : AppTheme.expenseRed)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            totalBalance >= 0
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            size: 13,
                            color: totalBalance >= 0
                                ? AppTheme.incomeGreen
                                : AppTheme.expenseRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            totalBalance >= 0 ? 'فائض سيولة' : 'عجز مالي',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: totalBalance >= 0
                                  ? AppTheme.incomeGreen
                                  : AppTheme.expenseRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // Breakdown Metrics Strip
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatBox(
                        context,
                        title: 'إجمالي المحافظ',
                        count: '${allWallets.length} خزائن',
                        color: AppTheme.accentBlue,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniStatBox(
                        context,
                        title: 'برصيد مالي',
                        count: '${positiveWallets.length} محفظة',
                        color: AppTheme.incomeGreen,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniStatBox(
                        context,
                        title: 'ذات عجز/سحب',
                        count: '${negativeWallets.length} محفظة',
                        color: negativeWallets.isNotEmpty
                            ? AppTheme.expenseRed
                            : context.dynamicTextMuted,
                        icon: Icons.trending_down_rounded,
                      ),
                    ),
                  ],
                ),
                if (topWallet != null && topBalance > 0 && totalBalance > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.dynamicSurfaceBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'أكبر محفظة: ${topWallet.name} (${topBalance.formatted} ر.ي) تمثل ${(topBalance / totalBalance * 100).toStringAsFixed(0)}% من السيولة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: context.dynamicTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: context.dynamicTextPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.dynamicCardBg,
                hintText: 'بحث باسم المحفظة أو الملاحظات...',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: context.dynamicTextMuted,
                  fontSize: 12,
                ),
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

          // Filter Segmented Chips & Sort Menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'الكل (${allWallets.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'positive',
                          'موجبة (${positiveWallets.length})',
                          color: AppTheme.incomeGreen,
                        ),
                        if (negativeWallets.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'negative',
                            'عجز (${negativeWallets.length})',
                            color: AppTheme.expenseRed,
                          ),
                        ],
                        if (zeroWallets.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'zero',
                            'صفرية (${zeroWallets.length})',
                            color: context.dynamicTextMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Sort Menu
                PopupMenuButton<String>(
                  color: context.dynamicCardBg,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.dynamicCardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: const Icon(Icons.sort_rounded, size: 18),
                  ),
                  tooltip: 'ترتيب حسب',
                  onSelected: (val) => setState(() => _sortBy = val),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'balance_desc',
                      child: Text(
                        'الأعلى رصيداً',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'balance_desc'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'balance_desc'
                              ? AppTheme.accentBlue
                              : context.dynamicTextPrimary,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'balance_asc',
                      child: Text(
                        'الأقل رصيداً',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'balance_asc'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'balance_asc'
                              ? AppTheme.accentBlue
                              : context.dynamicTextPrimary,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'activity',
                      child: Text(
                        'الأكثر حركات وعمليات',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: _sortBy == 'activity'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortBy == 'activity'
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
          ),

          const SizedBox(height: 8),

          // Wallets List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: context.dynamicTextMuted,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد محافظ مطابقة للبحث'
                                : 'لا توجد محافظ مسجلة حتى الآن',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: context.dynamicTextSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أضف أول محفظة أو خزينة نقدية بالضغط على الزر بالأسفل',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: context.dynamicTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final wallet = filtered[index];
                      return _buildWalletCard(
                          context, provider, wallet, totalBalance, index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => WalletsScreen.showWalletForm(context, provider),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'محفظة جديدة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildMiniStatBox(
    BuildContext context, {
    required String title,
    required String count,
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
          const SizedBox(height: 3),
          Text(
            count,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: context.dynamicTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String key,
    String label, {
    Color? color,
  }) {
    final isSelected = _selectedFilter == key;
    final activeColor = color ?? AppTheme.accentBlue;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: activeColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: isSelected ? activeColor : context.dynamicTextSecondary,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? activeColor : context.dynamicCardBorder,
      ),
      backgroundColor: context.dynamicCardBg,
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildWalletCard(BuildContext context, FinanceProvider provider,
      Wallet wallet, double totalBalance, int index) {
    final balance = provider.walletBalance(wallet.id);
    final payments = provider.getPaymentsForWallet(wallet.id);
    final expensePayments = provider.getExpensePaymentsForWallet(wallet.id);
    final movements = provider.getMovementsForWallet(wallet.id);

    final totalInflow = payments.fold(0.0, (s, p) => s + p.amount);
    final txCount = payments.length + expensePayments.length + movements.length;

    // Proportion of total positive funds
    double percentage = 0.0;
    if (totalBalance > 0 && balance > 0) {
      percentage = (balance / totalBalance) * 100;
    }

    final isPositive = balance >= 0;
    final cardColor = isPositive ? AppTheme.incomeGreen : AppTheme.expenseRed;

    // Palette accents for visual interest
    final List<Color> badgeColors = [
      AppTheme.accentBlue,
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF06B6D4),
    ];
    final badgeColor = badgeColors[index % badgeColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
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
              builder: (_) => WalletDetailScreen(walletId: wallet.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon, Name, Notes, Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: badgeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.name,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (wallet.notes != null && wallet.notes!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            wallet.notes!,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: context.dynamicTextMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: context.dynamicCardBg,
                    icon: Icon(
                      Icons.more_vert,
                      color: context.dynamicTextMuted,
                      size: 20,
                    ),
                    onSelected: (v) {
                      if (v == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WalletDetailScreen(walletId: wallet.id),
                          ),
                        );
                      } else if (v == 'edit') {
                        WalletsScreen.showWalletForm(context, provider,
                            existing: wallet);
                      } else if (v == 'delete') {
                        _confirmDeleteWallet(
                            context, provider, wallet, balance);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('كشف الحساب والعمليات',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('تعديل البيانات',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: AppTheme.expenseRed),
                            SizedBox(width: 8),
                            Text(
                              'حذف المحفظة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: AppTheme.expenseRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Balance Display Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد الصافي الحالي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: context.dynamicTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            balance.formatted,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: cardColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ر.ي',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: context.dynamicTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPositive ? 'رصيد متاح' : 'عجز مالي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: cardColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              // Percentage Progress Bar if positive & totalBalance > 0
              if (totalBalance > 0 && balance > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: context.dynamicSurfaceBg,
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نسبة المحفظة من إجمالي السيولة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextMuted,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: badgeColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Footer: Inflow metrics and open transactions trigger
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.input_rounded,
                        size: 14,
                        color: context.dynamicTextMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'الوارد: ${totalInflow.formatted} ر.ي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: context.dynamicTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.dynamicCardBorder,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$txCount حركة مسجلة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: context.dynamicTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'كشف الحساب',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppTheme.accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 11,
                        color: AppTheme.accentBlue,
                      ),
                    ],
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

class WalletDetailScreen extends StatefulWidget {
  final String walletId;
  const WalletDetailScreen({super.key, required this.walletId});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

typedef _WalletDetailScreen = WalletDetailScreen;

class _WalletTransactionItem {
  final String id;
  final DateTime date;
  final String type;
  final String category; // 'inflows', 'expenses_wages', 'movements'
  final String title;
  final String? subtitle;
  final String? fundingTag;
  final String? note;
  final double amount;
  final bool isPositive;
  final IconData icon;
  final Color color;

  const _WalletTransactionItem({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.title,
    this.subtitle,
    this.fundingTag,
    this.note,
    required this.amount,
    required this.isPositive,
    required this.icon,
    required this.color,
  });
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  String _selectedTab = 'all'; // 'all', 'inflows', 'expenses_wages', 'movements'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final wallet =
            provider.wallets.firstWhereOrNull((w) => w.id == widget.walletId);
        if (wallet == null) {
          return Scaffold(
            backgroundColor: context.dynamicScaffoldBg,
            appBar: AppBar(title: const Text('تفاصيل المحفظة')),
            body: Center(
              child: Text('المحفظة غير موجودة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: context.dynamicTextSecondary,
                  )),
            ),
          );
        }

        final balance = provider.walletBalance(widget.walletId);
        final payments = provider.getPaymentsForWallet(widget.walletId);
        final expensePayments =
            provider.getExpensePaymentsForWallet(widget.walletId);
        final withdrawals = provider.getMovementsForWallet(widget.walletId);
        final expenses = provider.getExpensesForWallet(widget.walletId);
        final zakatList = provider.zakatPayments
            .where((z) => z.walletId == widget.walletId)
            .toList();

        final allItems = <_WalletTransactionItem>[];
        final walletDebtSources = provider.debtFundingSources
            .where((s) => s.walletId == widget.walletId)
            .toList();
        final walletDebtSourceIds = walletDebtSources.map((s) => s.id).toSet();
        final accountedDebtSourceIds = <String>{};

        // 1. دفعات إيراد مستلمة (Inflows)
        for (final p in payments) {
          final inc =
              provider.incomes.firstWhereOrNull((i) => i.id == p.incomeId);
          allItems.add(_WalletTransactionItem(
            id: 'inc_pay_${p.id}',
            date: p.date,
            type: 'income_payment',
            category: 'inflows',
            title: 'دفعة إيراد مقبوضة',
            subtitle: inc != null ? 'إيراد: ${inc.title}' : 'إيراد مستلم',
            fundingTag: null,
            note: p.notes,
            amount: p.amount,
            isPositive: true,
            icon: Icons.payments_outlined,
            color: context.dynamicIncomeGreen,
          ));
        }

        // 2. دفعات مصروف مباشرة من هذه المحفظة
        for (final p in expensePayments) {
          final exp =
              provider.expenses.firstWhereOrNull((e) => e.id == p.expenseId);
          allItems.add(_WalletTransactionItem(
            id: 'exp_pay_${p.id}',
            date: p.date,
            type: 'expense_direct',
            category: 'expenses_wages',
            title: 'دفعة مصروف مباشر',
            subtitle: exp != null ? 'مصروف: ${exp.title}' : (p.notes ?? 'مصروف'),
            fundingTag: null,
            note: p.notes,
            amount: p.amount,
            isPositive: false,
            icon: Icons.receipt_long_outlined,
            color: context.dynamicExpenseRed,
          ));
        }

        // 3. مصروفات مستقطعة من دفعات إيرادات هذه المحفظة أو من ديونها المستلمة
        final walletPaymentIds = payments.map((p) => p.id).toSet();
        for (final e in expenses) {
          final allocatedAmount = e.allocations
              .where((a) =>
                  (a.paymentId != null && walletPaymentIds.contains(a.paymentId)) ||
                  (a.debtSettlementId != null && walletDebtSourceIds.contains(a.debtSettlementId)))
              .fold(0.0, (s, a) => s + a.amount);
          if (allocatedAmount > 0.001) {
            final firstAlloc = e.allocations.firstWhereOrNull((a) =>
                (a.paymentId != null && walletPaymentIds.contains(a.paymentId)) ||
                (a.debtSettlementId != null && walletDebtSourceIds.contains(a.debtSettlementId)));
            String? tag;
            if (firstAlloc?.paymentId != null) {
              final p = payments.firstWhereOrNull(
                  (pay) => pay.id == firstAlloc!.paymentId);
              final inc =
                  provider.incomes.firstWhereOrNull((i) => i.id == p?.incomeId);
              if (inc != null) {
                tag = 'مستقطع من دفعة: ${inc.title}';
              }
            } else if (firstAlloc?.debtSettlementId != null) {
              tag = 'مستقطع من: الديون المستلمة (تمويل مؤقت)';
            }
            allItems.add(_WalletTransactionItem(
              id: 'exp_alloc_${e.id}',
              date: e.date,
              type: 'expense_alloc',
              category: 'expenses_wages',
              title: e.title,
              subtitle: e.category.isNotEmpty ? 'تصنيف: ${e.category}' : null,
              fundingTag: tag,
              note: e.note,
              amount: allocatedAmount,
              isPositive: false,
              icon: Icons.shopping_bag_outlined,
              color: context.dynamicExpenseRed,
            ));
          }
        }

        // 4. دفعات الزكاة
        for (final z in zakatList) {
          allItems.add(_WalletTransactionItem(
            id: 'zakat_${z.id}',
            date: z.date,
            type: 'zakat',
            category: 'expenses_wages',
            title: 'دفعة زكاة مسددة',
            subtitle: z.recipient != null && z.recipient!.isNotEmpty
                ? 'المستحق: ${z.recipient}'
                : (z.recipientCategory ?? 'مصرف زكاة'),
            fundingTag: null,
            note: z.notes,
            amount: z.amount,
            isPositive: false,
            icon: Icons.volunteer_activism_outlined,
            color: const Color(0xFF10B981),
          ));
        }

        // 5. حركات الصرف والمسحوبات وسداد العمال والديون
        for (final m in withdrawals) {
          final isDistribution =
              m.distributionId != null || m.creditorType == 'p';
          final isPurchase = m.purchaseId != null;
          final isWorker = m.creditorType == 'w';
          final isDebt = m.debtId != null;

          String? tag;
          if (m.funding.isNotEmpty) {
            final alloc = m.funding.first;
            if (alloc.paymentId != null) {
              final pay = provider.incomePayments
                  .firstWhereOrNull((ip) => ip.id == alloc.paymentId);
              final inc =
                  provider.incomes.firstWhereOrNull((i) => i.id == pay?.incomeId);
              if (inc != null) tag = 'مستقطع من إيراد: ${inc.title}';
            } else if (alloc.debtSettlementId != null) {
              final settlement = provider.personalDebtSettlements
                  .firstWhereOrNull((s) => s.id == alloc.debtSettlementId);
              final debt = settlement != null
                  ? provider.personalDebts
                      .firstWhereOrNull((d) => d.id == settlement.debtId)
                  : null;
              final person = debt != null
                  ? provider.partners.firstWhereOrNull((p) => p.id == debt.personId)
                  : null;
              final personName = person?.name ?? '';
              tag = personName.isNotEmpty
                  ? 'مستقطع من استلام ديون وأقساط: $personName'
                  : 'مستقطع من دفعة استلام ديون وأقساط';
            }
          }

          if (isWorker) {
            final worker =
                provider.workers.firstWhereOrNull((w) => w.id == m.creditorId);
            allItems.add(_WalletTransactionItem(
              id: 'worker_${m.id}',
              date: m.date,
              type: 'wage_payout',
              category: 'expenses_wages',
              title: 'سداد أجور عمال',
              subtitle: worker != null
                  ? 'العامل: ${worker.name}'
                  : (m.note ?? 'أجور عمال'),
              fundingTag: tag,
              note: m.note,
              amount: m.amount.abs(),
              isPositive: false,
              icon: Icons.badge_outlined,
              color: const Color(0xFFE11D48),
            ));
          } else if (isDistribution) {
            final partner =
                provider.partners.firstWhereOrNull((p) => p.id == m.creditorId);
            allItems.add(_WalletTransactionItem(
              id: 'dist_${m.id}',
              date: m.date,
              type: 'distribution',
              category: 'movements',
              title: 'دفع حصة شريك / أرباح',
              subtitle: partner != null
                  ? 'الشريك: ${partner.name}'
                  : (m.note ?? 'حصة شريك'),
              fundingTag: tag,
              note: m.note,
              amount: m.amount.abs(),
              isPositive: false,
              icon: Icons.groups_outlined,
              color: const Color(0xFF8B5CF6),
            ));
          } else if (isPurchase) {
            allItems.add(_WalletTransactionItem(
              id: 'purch_${m.id}',
              date: m.date,
              type: 'purchase',
              category: 'movements',
              title: 'فاتورة شراء / مورد',
              subtitle: m.note ?? 'سداد مشتريات بضاعة',
              fundingTag: tag,
              note: m.note,
              amount: m.amount.abs(),
              isPositive: false,
              icon: Icons.shopping_cart_outlined,
              color: const Color(0xFFF97316),
            ));
          } else if (isDebt) {
            final debt =
                provider.personalDebts.firstWhereOrNull((d) => d.id == m.debtId);
            final person =
                provider.partners.firstWhereOrNull((p) => p.id == debt?.personId);
            final personName = person?.name ?? '';
            final isReceipt =
                m.amount < 0 || (m.note != null && m.note!.contains('استلام'));
            if (isReceipt) {
              final match = walletDebtSources.firstWhereOrNull((s) =>
                  !accountedDebtSourceIds.contains(s.id) &&
                  s.debtId == m.debtId &&
                  (s.amount - m.amount.abs()).abs() < 0.01);
              if (match != null) {
                accountedDebtSourceIds.add(match.id);
              }
              allItems.add(_WalletTransactionItem(
                id: 'debt_in_${m.id}',
                date: m.date,
                type: 'debt_receipt',
                category: 'inflows',
                title: personName.isNotEmpty
                    ? 'استلام ديون وأقساط من $personName'
                    : 'استلام ديون وأقساط',
                subtitle: personName.isNotEmpty
                    ? 'المصدر: $personName'
                    : (m.note ?? 'استلام ديون وأقساط'),
                fundingTag: tag ?? 'إيراد مؤقت (ديون مستلمة)',
                note: m.note,
                amount: m.amount.abs(),
                isPositive: true,
                icon: Icons.handshake_outlined,
                color: const Color(0xFFF59E0B),
              ));
            } else {
              allItems.add(_WalletTransactionItem(
                id: 'debt_out_${m.id}',
                date: m.date,
                type: 'debt_payment',
                category: 'movements',
                title: personName.isNotEmpty
                    ? 'دفع ديون وأقساط إلى $personName'
                    : 'دفع ديون وأقساط',
                subtitle: personName.isNotEmpty
                    ? 'المستحق: $personName'
                    : (m.note ?? 'دفع ديون وأقساط'),
                fundingTag: tag,
                note: m.note,
                amount: m.amount.abs(),
                isPositive: false,
                icon: Icons.handshake_outlined,
                color: const Color(0xFFF59E0B),
              ));
            }
          } else {
            // General movement
            if (m.amount < 0) {
              allItems.add(_WalletTransactionItem(
                id: 'mov_in_${m.id}',
                date: m.date,
                type: 'movement_in',
                category: 'inflows',
                title: 'توريد / إيداع نقدية',
                subtitle: m.note ?? 'إيداع بالمحفظة',
                fundingTag: tag,
                note: m.note,
                amount: m.amount.abs(),
                isPositive: true,
                icon: Icons.arrow_downward_rounded,
                color: context.dynamicIncomeGreen,
              ));
            } else {
              allItems.add(_WalletTransactionItem(
                id: 'mov_out_${m.id}',
                date: m.date,
                type: 'movement_out',
                category: 'movements',
                title: 'تصريف / سحب نقدية',
                subtitle: m.note ?? 'سحب من المحفظة',
                fundingTag: tag,
                note: m.note,
                amount: m.amount,
                isPositive: false,
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFF06B6D4),
              ));
            }
          }
        }

        // 6. ديون مستلمة للمحفظة (تمويل مؤقت) لم تسجل كحركة نقدية منفصلة
        for (final s in walletDebtSources) {
          if (!accountedDebtSourceIds.contains(s.id)) {
            final debt = provider.personalDebts.firstWhereOrNull((d) => d.id == s.debtId);
            final person = provider.partners.firstWhereOrNull((p) => p.id == debt?.personId);
            final personName = person?.name ?? '';
            final defaultTitle = personName.isNotEmpty
                ? 'استلام ديون وأقساط من $personName'
                : (s.isSettlement ? 'استلام دفعة دين' : 'استلام ديون وأقساط');
            allItems.add(_WalletTransactionItem(
              id: 'debt_source_${s.id}',
              date: s.date,
              type: 'debt_receipt',
              category: 'inflows',
              title: defaultTitle,
              subtitle: s.note?.isNotEmpty == true
                  ? s.note!
                  : (personName.isNotEmpty ? 'المصدر: $personName' : defaultTitle),
              fundingTag: 'إيراد مؤقت (ديون مستلمة)',
              note: s.note,
              amount: s.amount,
              isPositive: true,
              icon: Icons.handshake_outlined,
              color: const Color(0xFFF59E0B),
            ));
          }
        }

        // Sort chronologically (newest first)
        allItems.sort((a, b) => b.date.compareTo(a.date));

        final totalInflow = allItems
            .where((i) => i.isPositive)
            .fold<double>(0.0, (sum, i) => sum + i.amount);
        final totalOutflow = allItems
            .where((i) => !i.isPositive)
            .fold<double>(0.0, (sum, i) => sum + i.amount);

        final allCount = allItems.length;
        final inflowCount =
            allItems.where((i) => i.category == 'inflows').length;
        final expensesWagesCount =
            allItems.where((i) => i.category == 'expenses_wages').length;
        final movementsCount =
            allItems.where((i) => i.category == 'movements').length;

        var filteredItems = allItems;
        if (_selectedTab == 'inflows') {
          filteredItems =
              filteredItems.where((i) => i.category == 'inflows').toList();
        } else if (_selectedTab == 'expenses_wages') {
          filteredItems = filteredItems
              .where((i) => i.category == 'expenses_wages')
              .toList();
        } else if (_selectedTab == 'movements') {
          filteredItems =
              filteredItems.where((i) => i.category == 'movements').toList();
        }

        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          filteredItems = filteredItems.where((i) {
            final titleMatch = i.title.toLowerCase().contains(q);
            final subMatch = i.subtitle?.toLowerCase().contains(q) ?? false;
            final noteMatch = i.note?.toLowerCase().contains(q) ?? false;
            final tagMatch = i.fundingTag?.toLowerCase().contains(q) ?? false;
            final amountMatch = i.amount.toString().contains(q);
            return titleMatch ||
                subMatch ||
                noteMatch ||
                tagMatch ||
                amountMatch;
          }).toList();
        }

        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: Text(wallet.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                ),
                tooltip: _showSearch ? 'إخفاء البحث' : 'بحث في الحركات',
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل المحفظة',
                onPressed: () => WalletsScreen.showWalletForm(context, provider,
                    existing: wallet),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // 1. Balance Header Card with KPIs
              _buildBalanceCard(
                context,
                provider,
                wallet,
                balance,
                totalInflow,
                totalOutflow,
              ),

              // 2. Search Field (when toggled or active)
              if (_showSearch || _searchQuery.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSearchBar(context),
              ],

              const SizedBox(height: 16),

              // 3. Filter Chips Row
              _buildFilterChips(
                context,
                allCount,
                inflowCount,
                expensesWagesCount,
                movementsCount,
              ),

              const SizedBox(height: 16),

              // 4. Section title and count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'سجل الحركات والعمليات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: context.dynamicTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.dynamicCardBorder.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredItems.length} حركة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 5. Transaction list or empty state
              if (filteredItems.isEmpty)
                _buildEmptyState(context)
              else
                ...filteredItems.map(
                    (item) => _buildTransactionCard(context, item)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    FinanceProvider provider,
    Wallet wallet,
    double balance,
    double totalInflow,
    double totalOutflow,
  ) {
    final isSurplus = balance >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8FAFC),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSurplus
              ? context.dynamicIncomeGreen.withValues(alpha: 0.3)
              : context.dynamicExpenseRed.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSurplus
                    ? context.dynamicIncomeGreen
                    : context.dynamicExpenseRed)
                .withValues(alpha: context.isDark ? 0.12 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Wallet icon + name
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: AppTheme.accentBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    if (wallet.notes != null && wallet.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        wallet.notes!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: context.dynamicTextMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => WalletsScreen.showWalletForm(context, provider,
                    existing: wallet),
                icon: Icon(Icons.edit_outlined,
                    size: 20, color: context.dynamicTextMuted),
                tooltip: 'تعديل بيانات المحفظة',
                style: IconButton.styleFrom(
                  backgroundColor: context.dynamicSurfaceBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: context.dynamicCardBorder),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Balance block
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSurplus
                              ? context.dynamicIncomeGreen
                              : context.dynamicExpenseRed,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'الرصيد المتاح حالياً',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: context.dynamicTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${balance.formatted} ر.ي',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isSurplus
                          ? context.dynamicIncomeGreen
                          : context.dynamicExpenseRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSurplus
                      ? context.dynamicIncomeGreen.withValues(alpha: 0.15)
                      : context.dynamicExpenseRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSurplus
                        ? context.dynamicIncomeGreen.withValues(alpha: 0.3)
                        : context.dynamicExpenseRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSurplus
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 14,
                      color: isSurplus
                          ? context.dynamicIncomeGreen
                          : context.dynamicExpenseRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSurplus ? 'رصيد إيجابي' : 'عجز مالي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: isSurplus
                            ? context.dynamicIncomeGreen
                            : context.dynamicExpenseRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            color: context.dynamicCardBorder.withValues(alpha: 0.6),
            height: 1,
          ),
          const SizedBox(height: 14),
          // Side-by-side KPI boxes
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.dynamicIncomeGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.dynamicIncomeGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.dynamicIncomeGreen
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_downward_rounded,
                            color: context.dynamicIncomeGreen, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي الوارد',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: context.dynamicTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${totalInflow.formatted} ر.ي',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: context.dynamicIncomeGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.dynamicExpenseRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.dynamicExpenseRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              context.dynamicExpenseRed.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_upward_rounded,
                            color: context.dynamicExpenseRed, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي المنصرف',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: context.dynamicTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${totalOutflow.formatted} ر.ي',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: context.dynamicExpenseRed,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        style: TextStyle(
          fontFamily: 'Cairo',
          color: context.dynamicTextPrimary,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'بحث في الحركات، العمال، المشاريع، الملاحظات...',
          hintStyle: TextStyle(
            fontFamily: 'Cairo',
            color: context.dynamicTextMuted,
            fontSize: 12,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: context.dynamicTextMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    int allCount,
    int inflowCount,
    int expensesWagesCount,
    int movementsCount,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(
            id: 'all',
            title: 'الكل',
            count: allCount,
            icon: Icons.dashboard_outlined,
            color: AppTheme.accentBlue,
          ),
          const SizedBox(width: 8),
          _buildChip(
            id: 'inflows',
            title: 'المقبوضات والوارد',
            count: inflowCount,
            icon: Icons.arrow_downward_rounded,
            color: context.dynamicIncomeGreen,
          ),
          const SizedBox(width: 8),
          _buildChip(
            id: 'expenses_wages',
            title: 'المصروفات والأجور',
            count: expensesWagesCount,
            icon: Icons.badge_outlined,
            color: context.dynamicExpenseRed,
          ),
          const SizedBox(width: 8),
          _buildChip(
            id: 'movements',
            title: 'حركات الصرف',
            count: movementsCount,
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF06B6D4),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String id,
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedTab == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color : context.dynamicCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : context.dynamicCardBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isSelected ? Colors.white : context.dynamicTextPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : context.dynamicSurfaceBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: isSelected
                      ? Colors.white
                      : context.dynamicTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
      BuildContext context, _WalletTransactionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.dynamicCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),
              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: context.dynamicTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (item.subtitle != null &&
                        item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: context.dynamicTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount & badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.isPositive ? '+' : '-'}${item.amount.formatted} ر.ي',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: item.isPositive
                          ? context.dynamicIncomeGreen
                          : context.dynamicExpenseRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.isPositive
                          ? context.dynamicIncomeGreen.withValues(alpha: 0.12)
                          : context.dynamicExpenseRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isPositive ? 'وارد +' : 'صادر -',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: item.isPositive
                            ? context.dynamicIncomeGreen
                            : context.dynamicExpenseRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Funding source tag if present
          if (item.fundingTag != null && item.fundingTag!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accentBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, size: 13, color: AppTheme.accentBlue),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      item.fundingTag!,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppTheme.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Note if present and distinct from subtitle
          if (item.note != null &&
              item.note!.isNotEmpty &&
              item.note != item.subtitle &&
              !((item.subtitle ?? '').contains(item.note!))) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.notes, size: 13, color: context.dynamicTextMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.note!,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: context.dynamicTextMuted,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // Date row
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 12, color: context.dynamicTextMuted),
              const SizedBox(width: 5),
              Text(
                DateFormat('yyyy/MM/dd · hh:mm a', 'ar').format(item.date),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: context.dynamicTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: context.dynamicCardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.dynamicCardBorder.withValues(alpha: 0.5),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.dynamicSurfaceBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              size: 28,
              color: context.dynamicTextMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد نتائج مطابقة للبحث'
                : 'لا توجد حركات في هذا القسم بعد',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: context.dynamicTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'جرب البحث بكلمات أخرى أو مسح نص البحث'
                : 'ستظهر هنا جميع الحركات المالية المسجلة التابعة لهذه المحفظة فور إضافتها.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: context.dynamicTextMuted,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}