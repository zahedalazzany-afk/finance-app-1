import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/data_export_import_button.dart';

class ManageZahrasScreen extends StatelessWidget {
  const ManageZahrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('الزهرات'),
        actions: [
          DataExportImportButton(
            label: 'الزهرات',
            buildRows: () =>
                context.read<FinanceProvider>().zahras.map((e) => e.toJson()).toList(),
            csvHeaders: const ['الاسم', 'نوع الزهرة', 'الوصف'],
            csvKeys: const ['name', 'typeId', 'description'],
            onImport: (rows) async {
              final provider = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final item = Zahra.fromJson(row);
                  if (provider.zahras.any((e) => e.id == item.id)) continue;
                  provider.addZahra(item);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          if (provider.zahras.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, color: AppTheme.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text('لا توجد زهرات',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.zahras.length,
            itemBuilder: (context, index) {
              final zahra = provider.zahras[index];
              final type = provider.zahraTypes
                  .firstWhere((t) => t.id == zahra.typeId, orElse: () => ZahraType(id: '', name: 'غير محدد'));
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
                    title: Text(zahra.name,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.name,
                            style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
                        if (zahra.description != null && zahra.description!.isNotEmpty)
                          Text(zahra.description!,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      color: AppTheme.surface,
                      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
                      onSelected: (v) {
                        if (v == 'edit') _showForm(context, provider, existing: zahra);
                        if (v == 'delete') _confirmDelete(context, provider, zahra);
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
        backgroundColor: AppTheme.incomeGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('زهرة جديدة', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showForm(BuildContext context, FinanceProvider provider, {Zahra? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    String? typeId = existing?.typeId;
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
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Text(existing == null ? 'إضافة زهرة' : 'تعديل الزهرة',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'اسم الزهرة *',
                    hintText: 'اسم الزهرة',
                    prefixIcon: Icon(Icons.eco)),
                validator: (v) => v == null || v.isEmpty ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),
              SheetDropdown<String>(
                label: 'نوع الزهرة *',
                icon: Icons.local_florist,
                hint: 'اختر النوع',
                value: typeId,
                items: provider.zahraTypes
                    .map((t) =>
                        DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => typeId = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                maxLines: 2,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'الوصف',
                    hintText: 'وصف (اختياري)',
                    prefixIcon: Icon(Icons.description)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final tid = typeId;
                    if (tid == null) return;
                    if (existing != null) {
                      existing.name = nameController.text.trim();
                      existing.typeId = tid;
                      existing.description = descController.text.trim().isEmpty ? null : descController.text.trim();
                      provider.updateZahra(existing);
                    } else {
                      provider.addZahra(Zahra(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        typeId: tid,
                        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
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

  void _confirmDelete(BuildContext context, FinanceProvider provider, Zahra zahra) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الزهرة', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف "${zahra.name}"؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (provider.deleteZahra(zahra.id)) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف الزهرة لأنها مستخدمة في سجلات موجودة.')));
              }
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
