import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';

class ManageZahraTypesScreen extends StatelessWidget {
  const ManageZahraTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('أنواع الزهرات'),
        actions: [
          DataExportImportButton(
            label: 'أنواع الزهرات',
            buildRows: () => context
                .read<FinanceProvider>()
                .zahraTypes
                .map((e) => e.toJson())
                .toList(),
            csvHeaders: const ['الاسم', 'ملاحظات'],
            csvKeys: const ['name', 'notes'],
            onImport: (rows) async {
              final provider = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final item = ZahraType.fromJson(row);
                  if (provider.zahraTypes.any((e) => e.id == item.id)) continue;
                  provider.addZahraType(item);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          if (provider.zahraTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_florist, color: AppTheme.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text('لا توجد أنواع',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.zahraTypes.length,
            itemBuilder: (context, index) {
              final type = provider.zahraTypes[index];
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
                    title: Text(type.name,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: type.notes != null && type.notes!.isNotEmpty
                        ? Text(type.notes!, style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
                        : null,
                    trailing: PopupMenuButton<String>(
                      color: AppTheme.surface,
                      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
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

  void _showForm(BuildContext context, FinanceProvider provider, {ZahraType? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(existing == null ? 'إضافة نوع زهرة' : 'تعديل النوع',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'اسم نوع الزهرة *',
                    hintText: 'اسم النوع',
                    prefixIcon: Icon(Icons.local_florist)),
                validator: (v) => v == null || v.isEmpty ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    hintText: 'ملاحظات (اختياري)',
                    prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (existing != null) {
                      existing.name = nameController.text.trim();
                      existing.notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
                      provider.updateZahraType(existing);
                    } else {
                      provider.addZahraType(ZahraType(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      ));
                    }
                    Navigator.pop(context);
                  },
                  child: Text(existing == null ? 'حفظ' : 'تحديث'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider, ZahraType type) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف النوع', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('سيتم حذف جميع الزهرات المرتبطة بهذا النوع أيضاً. هل تريد حذف "${type.name}"؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (provider.deleteZahraType(type.id)) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف النوع لأنه مستخدم من زهرات موجودة.')));
              }
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
