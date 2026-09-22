import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';
import 'person_details_screen.dart';
import 'partner_statement_screen.dart';

IconData _roleIcon(String role) {
  switch (role) {
    case 'client':
      return Icons.shopping_bag_outlined;
    case 'supplier':
      return Icons.local_shipping_outlined;
    case 'worker':
      return Icons.engineering_outlined;
    case 'water':
      return Icons.water_drop_outlined;
    default:
      return Icons.person_outline;
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'client':
      return AppTheme.accentBlue;
    case 'supplier':
      return Colors.amber.shade700;
    case 'worker':
      return AppTheme.expenseRed;
    case 'water':
      return Colors.cyan.shade700;
    default:
      return Colors.teal;
  }
}

class ManagePartnersScreen extends StatefulWidget {
  const ManagePartnersScreen({super.key});

  @override
  State<ManagePartnersScreen> createState() => _ManagePartnersScreenState();
}

class _ManagePartnersScreenState extends State<ManagePartnersScreen> {
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'with_dues', 'client', 'supplier', 'worker', 'water'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allPartners = provider.partners;

    // Calculate metrics
    int peopleWithDues = 0;
    double totalOutstandingDues = 0.0;
    for (final p in allPartners) {
      final unpaid = provider.getDistributionsForPartner(p.id).where((d) => !provider.isDistributionPaid(d));
      final sum = unpaid.fold(0.0, (s, d) => s + d.amount);
      if (sum > 0) {
        peopleWithDues++;
        totalOutstandingDues += sum;
      }
    }

    // Filter partners
    final filtered = allPartners.where((p) {
      final unpaid = provider.getDistributionsForPartner(p.id).where((d) => !provider.isDistributionPaid(d));
      final dues = unpaid.fold(0.0, (s, d) => s + d.amount);

      if (_roleFilter == 'with_dues' && dues <= 0) return false;
      if (_roleFilter != 'all' && _roleFilter != 'with_dues' && !p.roles.contains(_roleFilter)) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchPhone = (p.phone ?? '').contains(q);
        final matchNotes = (p.notes ?? '').toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchNotes) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('الأشخاص والجهات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'استيراد من جهات الاتصال',
            onPressed: () => _importFromContact(context),
          ),
          DataExportImportButton(
            label: 'الأشخاص',
            buildRows: () => provider.partners.map((e) => e.toJson()).toList(),
            csvHeaders: const ['الاسم', 'الدور', 'رقم الجوال', 'ملاحظات'],
            csvKeys: const ['name', 'roles', 'phone', 'notes'],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final p = Partner.fromJson(row);
                  if (provider.partners.any((e) => e.id == p.id)) continue;
                  if (provider.partners.any((e) => e.name == p.name)) continue;
                  provider.addPartner(p);
                } catch (_) {}
              }
            },
          ),
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: provider.isDarkMode ? Colors.amber : AppTheme.accentBlue,
            ),
            tooltip: 'تبديل المظهر',
            onPressed: () => provider.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI Metric Header Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'إجمالي الأشخاص',
                    value: '${allPartners.length}',
                    icon: Icons.people_alt_rounded,
                    color: AppTheme.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'أصحاب مستحقات',
                    value: '$peopleWithDues شخص',
                    icon: Icons.pending_actions_rounded,
                    color: peopleWithDues > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'إجمالي المستحقات',
                    value: '${totalOutstandingDues.formatted} ر.ي',
                    icon: Icons.account_balance_wallet_outlined,
                    color: totalOutstandingDues > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: context.dynamicCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.dynamicCardBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم، رقم الجوال أو الملاحظات...',
                  hintStyle: TextStyle(color: context.dynamicTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: context.dynamicTextMuted, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ),

          // Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildRoleFilterChip('الكل (${allPartners.length})', 'all', Icons.people_outline),
                const SizedBox(width: 8),
                _buildRoleFilterChip('له مستحقات ($peopleWithDues)', 'with_dues', Icons.attach_money),
                const SizedBox(width: 8),
                _buildRoleFilterChip('عملاء', 'client', Icons.shopping_bag_outlined),
                const SizedBox(width: 8),
                _buildRoleFilterChip('موردين', 'supplier', Icons.local_shipping_outlined),
                const SizedBox(width: 8),
                _buildRoleFilterChip('عمال', 'worker', Icons.engineering_outlined),
                const SizedBox(width: 8),
                _buildRoleFilterChip('سقاة', 'water', Icons.water_drop_outlined),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Partners List or Empty State
          Expanded(
            child: allPartners.isEmpty
                ? _buildInitialEmptyState(context, provider)
                : filtered.isEmpty
                    ? _buildNoResultsEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          return _buildPartnerCard(context, provider, p);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, provider),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('شخص جديد', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context,
      {required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dynamicCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: TextStyle(color: context.dynamicTextMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String label, String roleKey, IconData icon) {
    final isSelected = _roleFilter == roleKey;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _roleFilter = roleKey),
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : context.dynamicTextSecondary),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : context.dynamicTextSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selectedColor: AppTheme.accentBlue,
      backgroundColor: context.dynamicCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppTheme.accentBlue : context.dynamicCardBorder,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildPartnerCard(BuildContext context, FinanceProvider provider, Partner p) {
    final unpaid = provider.getDistributionsForPartner(p.id).where((d) => !provider.isDistributionPaid(d));
    final totalUnpaid = unpaid.fold(0.0, (s, d) => s + d.amount);
    final primaryRole = p.roles.isNotEmpty ? p.roles.first : 'client';
    final roleColor = _roleColor(primaryRole);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: totalUnpaid > 0
              ? AppTheme.expenseRed.withValues(alpha: 0.3)
              : context.dynamicCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PersonDetailsScreen(personId: p.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with First letter
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.name.isNotEmpty ? p.name.characters.first : '؟',
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (p.phone != null && p.phone!.trim().isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 12, color: context.dynamicTextMuted),
                              const SizedBox(width: 4),
                              Text(
                                p.phone!,
                                style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: p.phone!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ رقم الهاتف')),
                                  );
                                },
                                child: Icon(Icons.copy_rounded, size: 12, color: context.dynamicTextMuted),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // More Menu
                  PopupMenuButton<String>(
                    color: context.dynamicCardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    icon: Icon(Icons.more_vert_rounded, color: context.dynamicTextMuted, size: 20),
                    onSelected: (v) {
                      if (v == 'statement') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PartnerStatementScreen(partnerId: p.id)),
                        );
                      } else if (v == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PersonDetailsScreen(personId: p.id)),
                        );
                      } else if (v == 'edit') {
                        _showForm(context, provider, existing: p);
                      } else if (v == 'delete') {
                        _confirmDelete(context, provider, p);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'statement',
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, color: AppTheme.accentBlue, size: 18),
                            SizedBox(width: 8),
                            Text('كشف الحساب', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: context.dynamicTextPrimary, size: 18),
                            SizedBox(width: 8),
                            Text('التفاصيل والسجل', style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: context.dynamicTextPrimary, size: 18),
                            SizedBox(width: 8),
                            Text('تعديل البيانات', style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: AppTheme.expenseRed, size: 18),
                            SizedBox(width: 8),
                            Text('حذف الشخص', style: TextStyle(color: AppTheme.expenseRed, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Roles Pills & Unpaid Balance Row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...p.roles.map((r) {
                    final c = _roleColor(r);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_roleIcon(r), size: 12, color: c),
                          const SizedBox(width: 4),
                          Text(
                            personRoleLabel(r, partnershipTypes: provider.partnershipTypes),
                            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (totalUnpaid > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.expenseRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending_actions, size: 12, color: AppTheme.expenseRed),
                          const SizedBox(width: 4),
                          Text(
                            'مستحق: ${totalUnpaid.formatted} ر.ي',
                            style: TextStyle(
                              color: AppTheme.expenseRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (p.notes != null && p.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  p.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.dynamicTextMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialEmptyState(BuildContext context, FinanceProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline, color: AppTheme.accentBlue, size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد أشخاص مسجلين بعد',
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أضف العملاء، الموردين، والشركاء أو استوردهم من جهات اتصالك',
            style: TextStyle(color: context.dynamicTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showForm(context, provider),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة شخص'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _importFromContact(context),
                icon: const Icon(Icons.contact_phone_outlined, size: 18),
                label: const Text('استيراد جهة اتصال'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: context.dynamicTextMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'لا يوجد أشخاص يطابقون البحث أو الفلتر',
            style: TextStyle(color: context.dynamicTextSecondary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _roleFilter = 'all';
              });
            },
            child: const Text('إعادة ضبط الفلاتر'),
          ),
        ],
      ),
    );
  }

  void _importFromContact(BuildContext context) async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status == PermissionStatus.permanentlyDenied) {
      _showSettingsDialog(context);
      return;
    }
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم منح صلاحية الوصول لجهات الاتصال')),
      );
      return;
    }
    try {
      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      if (contact != null) {
        final name = contact.displayName ?? '';
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
        final provider = context.read<FinanceProvider>();
        if (provider.partners.any((p) => p.name == name)) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.dynamicCardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('الشخص موجود مسبقاً',
                  style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w700)),
              content: Text('الشخص "$name" موجود بالفعل في قائمتك. هل ترغب في إضافته مجدداً؟',
                  style: TextStyle(color: context.dynamicTextSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة الإضافة')),
              ],
            ),
          );
          if (proceed != true) return;
        }
        _showForm(context, provider, prefillName: name, prefillPhone: phone);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح جهات الاتصال')),
      );
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('صلاحية جهات الاتصال',
            style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'تم رفض صلاحية الوصول لجهات الاتصال بشكل دائم. يرجى تفعيلها من إعدادات الجهاز.',
          style: TextStyle(color: context.dynamicTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              FlutterContacts.permissions.openSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, FinanceProvider provider,
      {Partner? existing, String? prefillName, String? prefillPhone}) {
    final nameController = TextEditingController(text: existing?.name ?? prefillName ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? prefillPhone ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    List<String> roles = List<String>.from(existing?.roles ?? ['client']);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
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
                        color: context.dynamicCardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existing == null ? 'إضافة شخص جديد' : 'تعديل بيانات الشخص',
                    style: TextStyle(
                      color: context.dynamicTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: context.dynamicTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'الاسم *',
                      hintText: 'مثال: محمد أحمد',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: context.dynamicSurfaceBg,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'أدخل الاسم' : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'أدوار الشخص في النظام *',
                    style: TextStyle(
                      color: context.dynamicTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.dynamicSurfaceBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.dynamicCardBorder),
                    ),
                    child: Column(
                      children: [
                        ...[
                          ...personRoles,
                          ...provider.partnershipTypes
                              .where((t) => !personRoles.contains(t.id))
                              .map((t) => t.id),
                        ].map((r) {
                          final isChecked = roles.contains(r);
                          final c = _roleColor(r);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            value: isChecked,
                            title: Row(
                              children: [
                                Icon(_roleIcon(r), color: c, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  personRoleLabel(r, partnershipTypes: provider.partnershipTypes),
                                  style: TextStyle(color: isChecked ? c : context.dynamicTextPrimary, fontWeight: isChecked ? FontWeight.w700 : FontWeight.normal),
                                ),
                              ],
                            ),
                            activeColor: c,
                            onChanged: (_) => setSheetState(() {
                              if (roles.contains(r)) {
                                roles.remove(r);
                              } else {
                                roles.add(r);
                              }
                            }),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: context.dynamicTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'رقم الجوال (اختياري)',
                      hintText: 'مثال: 777000000',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: context.dynamicSurfaceBg,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: context.dynamicTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      hintText: 'أي تفاصيل أو مهام خاصة بالشخص',
                      prefixIcon: const Icon(Icons.notes_outlined),
                      filled: true,
                      fillColor: context.dynamicSurfaceBg,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final name = nameController.text.trim();
                        if (existing == null && provider.partners.any((p) => p.name == name)) {
                          _showError(context, 'هذا الاسم مسجل مسبقاً');
                          return;
                        }
                        if (existing != null && name != existing.name &&
                            provider.partners.any((p) => p.name == name)) {
                          _showError(context, 'هذا الاسم مسجل مسبقاً');
                          return;
                        }
                        if (roles.isEmpty) {
                          _showError(context, 'يرجى اختيار دور واحد على الأقل');
                          return;
                        }
                        if (existing != null) {
                          existing.name = name;
                          existing.roles = roles;
                          existing.phone = phoneController.text.trim().isEmpty ? null : phoneController.text.trim();
                          existing.notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
                          provider.updatePartner(existing);
                        } else {
                          provider.addPartner(Partner(
                            id: const Uuid().v4(),
                            name: name,
                            roles: roles,
                            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          ));
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(existing == null ? 'حفظ الشخص' : 'تحديث البيانات'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تنبيه', style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.w700)),
        content: Text(message, style: TextStyle(color: context.dynamicTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider, Partner p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الشخص', style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'هل تريد حذف "${p.name}"؟ سيتم إزالة ارتباطه من الشراكات والتوزيعات المرتبطة.',
          style: TextStyle(color: context.dynamicTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (provider.deletePartner(p.id)) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف الشخص لوجود شراكات أو توزيعات تاريخية مرتبطة به.')));
              }
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
