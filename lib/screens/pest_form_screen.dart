import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class _IngredientEntry {
  String? ingredientId;
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();

  void dispose() {
    dosageController.dispose();
    instructionsController.dispose();
  }
}

class PestFormScreen extends StatefulWidget {
  final Pest? pest;
  const PestFormScreen({super.key, this.pest});

  @override
  State<PestFormScreen> createState() => _PestFormScreenState();
}

class _PestFormScreenState extends State<PestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _symptomsController;
  late final TextEditingController _notesController;
  late String _selectedType;
  final List<_IngredientEntry> _ingredientEntries = [];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.pest?.name ?? '');
    _symptomsController =
        TextEditingController(text: widget.pest?.symptoms ?? '');
    _notesController =
        TextEditingController(text: widget.pest?.notes ?? '');
    _selectedType = widget.pest?.type ?? pestTypes.first;
    if (widget.pest != null) {
      final provider = context.read<FinanceProvider>();
      for (final link in provider.pestIngredientsFor(widget.pest!.id)) {
        final entry = _IngredientEntry()
          ..ingredientId = link.ingredientId
          ..dosageController.text = link.dosage ?? ''
          ..instructionsController.text = link.instructions ?? '';
        _ingredientEntries.add(entry);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symptomsController.dispose();
    _notesController.dispose();
    for (final entry in _ingredientEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();

    final pest = Pest(
      id: widget.pest?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      type: _selectedType,
      symptoms: _symptomsController.text.trim().isEmpty
          ? null
          : _symptomsController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (widget.pest == null) {
      provider.addPest(pest);
    } else {
      provider.updatePest(pest);
    }

    final entries = _ingredientEntries
        .where((e) => e.ingredientId != null)
        .map((e) => {
              'ingredientId': e.ingredientId!,
              'dosage': e.dosageController.text.trim().isEmpty
                  ? null
                  : e.dosageController.text.trim(),
              'instructions': e.instructionsController.text.trim().isEmpty
                  ? null
                  : e.instructionsController.text.trim(),
            })
        .toList();
    provider.savePestIngredients(pest.id, entries);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.pest != null;
    final provider = context.watch<FinanceProvider>();
    final ingredients = provider.chemicalIngredients;

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(title: Text(isEditing ? 'تعديل آفة' : 'إضافة آفة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'اسم الآفة *',
                  hintText: 'اسم الآفة *',
                  prefixIcon: Icon(Icons.bug_report),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'أدخل اسم الآفة' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نوع الآفة *',
                  prefixIcon: Icon(Icons.category),
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                items: pestTypes
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _symptomsController,
                maxLines: 3,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'الأعراض والوصف',
                  hintText: 'الأعراض والوصف (اختياري)',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'طرق العلاج',
                  hintText: 'طرق العلاج / ملاحظات (اختياري)',
                  prefixIcon: Icon(Icons.healing),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.science, color: AppTheme.accentBlue),
                  const SizedBox(width: 8),
                  Text('المواد الفعالة المستخدمة للمعالجة',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              if (ingredients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppTheme.textMuted, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا توجد مواد فعالة بعد. أضفها أولاً من شاشة المواد الفعالة',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      setState(
                          () => _ingredientEntries.add(_IngredientEntry()));
                    },
                    icon: Icon(Icons.add_circle,
                        color: AppTheme.accentBlue, size: 30),
                    tooltip: 'إضافة مادة فعالة',
                  ),
                ),
                if (_ingredientEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Center(
                      child: Text('اضغط + لإضافة مادة فعالة',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                ...List.generate(_ingredientEntries.length, (index) {
                  final entry = _ingredientEntries[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: entry.ingredientId,
                                isExpanded: true,
                                hint: Text('اختر المادة الفعالة',
                                    style: TextStyle(
                                        color: AppTheme.textMuted)),
                                decoration: const InputDecoration(
                                  labelText: 'المادة الفعالة',
                                  prefixIcon: Icon(Icons.science),
                                ),
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13),
                                items: ingredients.map((i) {
                                  final isInsecticide = i.type == 'حشري';
                                  return DropdownMenuItem(
                                    value: i.id,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isInsecticide
                                              ? Icons.bug_report
                                              : Icons.eco,
                                          size: 16,
                                          color: isInsecticide
                                              ? AppTheme.expenseRed
                                              : AppTheme.incomeGreen,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(i.name,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => entry.ingredientId = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  entry.dispose();
                                  _ingredientEntries.removeAt(index);
                                });
                              },
                              icon: Icon(Icons.delete,
                                  color: AppTheme.expenseRed, size: 24),
                              tooltip: 'حذف',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: entry.dosageController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'الجرعة',
                            hintText: 'الجرعة / التركيز (اختياري)',
                            prefixIcon: Icon(Icons.science),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: entry.instructionsController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'طريقة الاستخدام',
                            hintText: 'طريقة الاستخدام (اختياري)',
                            prefixIcon: Icon(Icons.menu_book),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: Text(isEditing ? 'تحديث البيانات' : 'حفظ الآفة'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
