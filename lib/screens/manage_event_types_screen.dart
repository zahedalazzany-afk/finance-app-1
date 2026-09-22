import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';

class ManageEventTypesScreen extends StatelessWidget {
  const ManageEventTypesScreen({super.key});

  IconData _eventIcon(String name) {
    switch (name) {
      case 'قلب التربة': return Icons.grass;
      case 'سقي المزروعات': return Icons.water_drop;
      case 'قصة الأشجار': return Icons.content_cut;
      case 'رش المبيدات': return Icons.science;
      default: return Icons.edit_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('أنواع الأحداث'),
        actions: [
          DataExportImportButton(
            label: 'أنواع الأحداث',
            buildRows: () => context
                .read<FinanceProvider>()
                .eventTypesList
                .map((e) => e.toJson())
                .toList(),
            csvHeaders: const ['الاسم'],
            csvKeys: const ['name'],
            onImport: (rows) async {
              final provider = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final item = EventType.fromJson(row);
                  if (provider.eventTypesList.any((e) => e.id == item.id)) continue;
                  provider.addEventType(item);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final types = provider.eventTypesList;
          if (types.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, color: AppTheme.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text('لا توجد أنواع أحداث',
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
              final usageCount = provider.landEvents
                  .where((e) => e.eventType == type.name)
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
                      child: Icon(_eventIcon(type.name), color: AppTheme.accentBlue, size: 20),
                    ),
                    title: Text(type.name,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('$usageCount حدث',
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

  void _showForm(BuildContext context, FinanceProvider provider, {EventType? existing}) {
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
                Text(existing == null ? 'إضافة نوع حدث' : 'تعديل نوع الحدث',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameCtrl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'اسم النوع *',
                    hintText: 'مثال: رش مبيد، سقي...',
                    prefixIcon: Icon(Icons.event_note),
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
                        provider.updateEventType(existing);
                      } else {
                        provider.addEventType(EventType(
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

  void _confirmDelete(BuildContext context, FinanceProvider provider, EventType type) {
    final usageCount = provider.landEvents.where((e) => e.eventType == type.name).length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف نوع الحدث', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          usageCount > 0
              ? 'يوجد $usageCount أحداث تستخدم هذا النوع. هل تريد الحذف؟'
              : 'هل تريد حذف "${type.name}"؟',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.deleteEventType(type.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
