import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';

class ManagePartnershipTypesScreen extends StatelessWidget {
  const ManagePartnershipTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('أنواع الشراكات'),
        actions: [
          DataExportImportButton(
            label: 'أنواع الشراكات',
            buildRows: () => context
                .read<FinanceProvider>()
                .partnershipTypes
                .map((e) => e.toJson())
                .toList(),
            csvHeaders: const ['الاسم'],
            csvKeys: const ['name'],
            onImport: (rows) async {
              final provider = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final item = PartnershipType.fromJson(row);
                  if (provider.partnershipTypes.any((e) => e.id == item.id)) continue;
                  provider.addPartnershipType(item);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final types = provider.partnershipTypes;
          if (types.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, color: AppTheme.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text('لا توجد أنواع شراكات',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              final usageCount = provider.partnerships
                  .where((p) => p.role == type.id)
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.work, color: AppTheme.accentBlue, size: 20),
                    ),
                    title: Text(type.name,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('$usageCount شراكة',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: PopupMenuButton<String>(
                      color: AppTheme.surface,
                      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                      onSelected: (v) {
                        if (v == 'edit') _showForm(context, provider, existing: type);
                        if (v == 'delete') _confirmDelete(context, provider, type);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text('تعديل', style: TextStyle(color: AppTheme.textPrimary))),
                        PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed))),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, context.read<FinanceProvider>()),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('نوع جديد', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showForm(BuildContext context, FinanceProvider provider, {PartnershipType? existing}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

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
                Text(existing == null ? 'إضافة نوع شراكة' : 'تعديل نوع الشراكة',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameCtrl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'اسم النوع *',
                    hintText: 'مثال: شريك أرض، شريك مالي...',
                    prefixIcon: Icon(Icons.work),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم النوع' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final name = nameCtrl.text.trim();
                      if (existing != null) {
                        existing.name = name;
                        provider.updatePartnershipType(existing);
                      } else {
                        provider.addPartnershipType(PartnershipType(
                          id: const Uuid().v4(),
                          name: name,
                        ));
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white),
                    child: Text(existing == null ? 'حفظ' : 'تحديث'),
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

  void _confirmDelete(BuildContext context, FinanceProvider provider, PartnershipType type) {
    final usageCount = provider.partnerships.where((p) => p.role == type.id).length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف نوع الشراكة', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          usageCount > 0
              ? 'يوجد $usageCount شراكة تستخدم هذا النوع. هل تريد الحذف؟'
              : 'هل تريد حذف "${type.name}"؟',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.deletePartnershipType(type.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
