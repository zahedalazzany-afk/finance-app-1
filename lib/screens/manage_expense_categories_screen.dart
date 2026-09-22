import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';

class ManageExpenseCategoriesScreen extends StatelessWidget {
  const ManageExpenseCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('تصنيفات المصروفات'),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            itemCount: provider.expenseCategories.length,
            itemBuilder: (context, index) {
              final category = provider.expenseCategories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.category, color: AppTheme.accentBlue, size: 20),
                    ),
                    title: Text(
                      category.name,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: AppTheme.textMuted),
                          onPressed: () => _showDialog(context, provider, existing: category),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 20, color: AppTheme.expenseRed),
                          onPressed: () {
                            provider.deleteExpenseCategory(category.id);
                          },
                        ),
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
        onPressed: () => _showDialog(context, context.read<FinanceProvider>()),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('تصنيف جديد', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showDialog(BuildContext context, FinanceProvider provider,
      {ExpenseCategory? existing}) {
    final controller = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? 'إضافة تصنيف مصروف' : 'تعديل التصنيف',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'اسم التصنيف',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final isDuplicate = provider.expenseCategories.any((c) =>
                    c.name.trim().toLowerCase() == name.toLowerCase() &&
                    (existing == null || c.id != existing.id));
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('اسم هذا التصنيف موجود مسبقاً'),
                      backgroundColor: AppTheme.expenseRed,
                    ),
                  );
                  return;
                }
                if (existing == null) {
                  provider.addExpenseCategory(
                      ExpenseCategory(id: const Uuid().v4(), name: name));
                } else {
                  provider.updateExpenseCategory(
                      ExpenseCategory(id: existing.id, name: name));
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
