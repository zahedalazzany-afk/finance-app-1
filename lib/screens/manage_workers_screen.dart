import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';
import 'worker_details_screen.dart';
import 'batch_wage_payout_screen.dart';

class ManageWorkersScreen extends StatefulWidget {
  const ManageWorkersScreen({super.key});

  @override
  State<ManageWorkersScreen> createState() => _ManageWorkersScreenState();
}

class _ManageWorkersScreenState extends State<ManageWorkersScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'with_wages', 'paid'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allWorkers = provider.workers;

    // Calculate metrics
    int workersWithWages = 0;
    double totalOutstandingWages = 0.0;
    for (final w in allWorkers) {
      final debt = provider.workerDebt(w.id);
      if (debt > 0) {
        workersWithWages++;
        totalOutstandingWages += debt;
      }
    }

    // Filter workers
    final filtered = allWorkers.where((w) {
      final debt = provider.workerDebt(w.id);
      if (_filterType == 'with_wages' && debt <= 0) return false;
      if (_filterType == 'paid' && debt > 0) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = w.name.toLowerCase().contains(q);
        final matchPhone = (w.phone ?? '').contains(q);
        final matchNotes = (w.notes ?? '').toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchNotes) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('عمال الأجر اليومي'),
        actions: [
          IconButton(
            icon: Icon(Icons.payments_outlined, color: AppTheme.incomeGreen),
            tooltip: 'السداد المجمع لأجور العمال',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BatchWagePayoutScreen()),
            ),
          ),
          DataExportImportButton(
            label: 'العمال',
            buildRows: () => provider.workers.map((e) => e.toJson()).toList(),
            csvHeaders: const ['الاسم', 'رقم الجوال', 'ملاحظات'],
            csvKeys: const ['name', 'phone', 'notes'],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final item = Worker.fromJson(row);
                  if (provider.workers.any((e) => e.id == item.id)) continue;
                  if (provider.workers.any((e) => e.name == item.name)) continue;
                  provider.addWorker(item);
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
                    title: 'إجمالي العمال',
                    value: '${allWorkers.length}',
                    icon: Icons.engineering_rounded,
                    color: AppTheme.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'لهم أجور مستحقة',
                    value: '$workersWithWages عامل',
                    icon: Icons.pending_actions_rounded,
                    color: workersWithWages > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'إجمالي الأجور',
                    value: '${totalOutstandingWages.formatted} ر.ي',
                    icon: Icons.payments_rounded,
                    color: totalOutstandingWages > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                  ),
                ),
              ],
            ),
          ),

          // Batch Payout Banner if there are pending wages
          if (totalOutstandingWages > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.incomeGreen.withValues(alpha: 0.12),
                      context.dynamicCardBg,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.incomeGreen.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.incomeGreen.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.flash_on_rounded, color: AppTheme.incomeGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سداد مجمع لأجور العمال',
                            style: TextStyle(
                              color: context.dynamicTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'توزيع وسداد الأجور المستحقة لعدة عمال دفعة واحدة',
                            style: TextStyle(color: context.dynamicTextMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BatchWagePayoutScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.incomeGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('سداد مجمع', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                  hintText: 'بحث باسم العامل أو رقم الجوال...',
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

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('الكل (${allWorkers.length})', 'all', Icons.people_outline),
                const SizedBox(width: 8),
                _buildFilterChip('لهم أجور مستحقة ($workersWithWages)', 'with_wages', Icons.pending_actions),
                const SizedBox(width: 8),
                _buildFilterChip('مسددين بالكامل', 'paid', Icons.check_circle_outline),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Workers List or Empty State
          Expanded(
            child: allWorkers.isEmpty
                ? _buildInitialEmptyState(context, provider)
                : filtered.isEmpty
                    ? _buildNoResultsEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final w = filtered[index];
                          return _buildWorkerCard(context, provider, w);
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
        label: const Text('عامل جديد', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildFilterChip(String label, String type, IconData icon) {
    final isSelected = _filterType == type;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _filterType = type),
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

  Widget _buildWorkerCard(BuildContext context, FinanceProvider provider, Worker w) {
    final debt = provider.workerDebt(w.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: debt > 0
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
          MaterialPageRoute(builder: (_) => WorkerDetailsScreen(worker: w)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Worker Avatar Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (debt > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.engineering_rounded,
                      color: debt > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.name,
                          style: TextStyle(
                            color: context.dynamicTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (w.phone != null && w.phone!.trim().isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 12, color: context.dynamicTextMuted),
                              const SizedBox(width: 4),
                              Text(
                                w.phone!,
                                style: TextStyle(color: context.dynamicTextSecondary, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: w.phone!));
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
                  // Menu
                  PopupMenuButton<String>(
                    color: context.dynamicCardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    icon: Icon(Icons.more_vert_rounded, color: context.dynamicTextMuted, size: 20),
                    onSelected: (v) {
                      if (v == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => WorkerDetailsScreen(worker: w)),
                        );
                      } else if (v == 'edit') {
                        _showForm(context, provider, existing: w);
                      } else if (v == 'delete') {
                        _confirmDelete(context, provider, w);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, color: context.dynamicTextPrimary, size: 18),
                            const SizedBox(width: 8),
                            Text('سجل الأجور والعمليات', style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: context.dynamicTextPrimary, size: 18),
                            const SizedBox(width: 8),
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
                            Text('حذف العامل', style: TextStyle(color: AppTheme.expenseRed, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Status Pill & Notes
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: (debt > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          debt > 0 ? Icons.pending_actions : Icons.check_circle_outline,
                          size: 13,
                          color: debt > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          debt > 0 ? 'مستحق له: ${debt.formatted} ر.ي' : 'الأجور مسددة بالكامل',
                          style: TextStyle(
                            color: debt > 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkerDetailsScreen(worker: w)),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 11),
                    label: const Text('كشف الحساب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),

              if (w.notes != null && w.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  w.notes!,
                  maxLines: 1,
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
            child: Icon(Icons.engineering_outlined, color: AppTheme.accentBlue, size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد عمال مضافين بعد',
            style: TextStyle(
              color: context.dynamicTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أضف عمال الأجر اليومي لتسجيل ساعات العمل والأجور والسدادات',
            style: TextStyle(color: context.dynamicTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showForm(context, provider),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة عامل جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
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
            'لا يوجد عمال يطابقون البحث',
            style: TextStyle(color: context.dynamicTextSecondary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _filterType = 'all';
              });
            },
            child: const Text('إعادة ضبط الفلاتر'),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, FinanceProvider provider, {Worker? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
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
                  existing == null ? 'إضافة عامل أجر يومي' : 'تعديل بيانات العامل',
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
                    labelText: 'اسم العامل *',
                    hintText: 'مثال: أحمد ناصر',
                    prefixIcon: const Icon(Icons.engineering_outlined),
                    filled: true,
                    fillColor: context.dynamicSurfaceBg,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم العامل' : null,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: context.dynamicTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    hintText: 'أي تفاصيل عن العامل أو طبيعة عمله',
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
                      if (provider.workers.any((x) => x.name == name && (existing == null || x.id != existing.id))) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: context.dynamicCardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('تنبيه', style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.w700)),
                            content: Text('اسم العامل "$name" موجود مسبقاً', style: TextStyle(color: context.dynamicTextSecondary)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
                            ],
                          ),
                        );
                        return;
                      }
                      if (existing != null) {
                        existing.name = name;
                        existing.phone = phoneController.text.trim().isEmpty ? null : phoneController.text.trim();
                        existing.notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
                        provider.updateWorker(existing);
                      } else {
                        provider.addWorker(Worker(
                          id: const Uuid().v4(),
                          name: name,
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
                    child: Text(existing == null ? 'حفظ العامل' : 'تحديث البيانات'),
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

  void _confirmDelete(BuildContext context, FinanceProvider provider, Worker w) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف العامل', style: TextStyle(color: context.dynamicTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'هل تريد حذف العامل "${w.name}"؟',
          style: TextStyle(color: context.dynamicTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (provider.deleteWorker(w.id)) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف العامل لأن لديه سجلات مرتبطة.')));
              }
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
