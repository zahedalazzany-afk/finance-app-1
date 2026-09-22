import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/data_export_import_button.dart';
import 'pest_form_screen.dart';

class PestsScreen extends StatefulWidget {
  const PestsScreen({super.key});

  @override
  State<PestsScreen> createState() => _PestsScreenState();
}

class _PestsScreenState extends State<PestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'الكل';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getBadgeColor(String type) {
    switch (type) {
      case 'حشرية':
        return Colors.orange.shade800;
      case 'فطرية':
        return const Color(0xFF9C27B0);
      case 'أكاروسية':
        return AppTheme.expenseRed;
      case 'حشائش':
        return AppTheme.incomeGreen;
      case 'بكتيرية':
        return Colors.teal.shade700;
      case 'فيروسية':
        return Colors.indigo.shade700;
      default:
        return AppTheme.accentBlue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'حشرية':
        return Icons.pest_control_outlined;
      case 'فطرية':
        return Icons.spa_outlined;
      case 'أكاروسية':
        return Icons.bug_report_outlined;
      case 'حشائش':
        return Icons.grass_outlined;
      case 'بكتيرية':
        return Icons.coronavirus_outlined;
      case 'فيروسية':
        return Icons.biotech_outlined;
      default:
        return Icons.healing_outlined;
    }
  }

  void _confirmDelete(
      BuildContext context, FinanceProvider provider, Pest pest) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.dynamicCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الآفة',
            style: TextStyle(
                color: context.dynamicTextPrimary,
                fontWeight: FontWeight.w700)),
        content: Text('هل أنت متأكد من حذف "${pest.name}"؟',
            style: TextStyle(color: context.dynamicTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.deletePest(pest.id);
              Navigator.pop(context);
            },
            child:
                Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allPests = provider.pests;

    final pests = allPests.where((p) {
      if (_selectedType != 'الكل' && p.type != _selectedType) return false;
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final nameMatches = p.name.toLowerCase().contains(q);
      final symptomsMatch =
          p.symptoms != null && p.symptoms!.toLowerCase().contains(q);
      final notesMatch =
          p.notes != null && p.notes!.toLowerCase().contains(q);
      return nameMatches || symptomsMatch || notesMatch;
    }).toList();

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        backgroundColor: context.dynamicScaffoldBg,
        elevation: 0,
        title: const Text(
          'دليل الآفات والأمراض الزراعية',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          DataExportImportButton(
            label: 'الآفات',
            buildRows: () =>
                provider.pests.map((e) => e.toJson()).toList(),
            csvHeaders: const ['الاسم', 'النوع', 'الأعراض', 'طرق العلاج'],
            csvKeys: const ['name', 'type', 'symptoms', 'notes'],
            onImport: (rows) async {
              for (final row in rows) {
                try {
                  final pest = Pest.fromJson(row);
                  if (provider.pests.any((e) => e.id == pest.id)) continue;
                  provider.addPest(pest);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero Summary Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Colors.teal.withValues(alpha: 0.12),
                  context.dynamicCardBg,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.dynamicCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Colors.teal, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دليل الوقاية والتشخيص الحقلي',
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'سجل مرجعي شامل للأعراض، طرق المكافحة، والمواد الفعالة الموصى بها',
                        style: TextStyle(
                          color: context.dynamicTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.dynamicSurfaceBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.dynamicCardBorder),
                  ),
                  child: Column(
                    children: [
                      Text('الآفات',
                          style: TextStyle(
                              color: context.dynamicTextMuted, fontSize: 10)),
                      Text(
                        '${allPests.length}',
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.dynamicTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.dynamicCardBg,
                hintText: 'بحث باسم الآفة، الأعراض، أو طرق المكافحة...',
                hintStyle:
                    TextStyle(color: context.dynamicTextMuted, fontSize: 12),
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

          // Types Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['الكل', ...pestTypes].map((cat) {
                final isSelected = _selectedType == cat;
                final color = cat == 'الكل'
                    ? AppTheme.accentBlue
                    : _getBadgeColor(cat);
                final count = cat == 'الكل'
                    ? allPests.length
                    : allPests.where((p) => p.type == cat).length;

                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$cat ($count)'),
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: isSelected ? color : context.dynamicTextSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : context.dynamicCardBorder,
                    ),
                    backgroundColor: context.dynamicCardBg,
                    onSelected: (_) => setState(() => _selectedType = cat),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Pest List
          Expanded(
            child: pests.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pest_control_outlined,
                              color: context.dynamicTextMuted, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty || _selectedType != 'الكل'
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'لا توجد آفات زراعية مسجلة',
                            style: TextStyle(
                              color: context.dynamicTextSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أضف آفة جديدة بالضغط على الزر بالأسفل',
                            style: TextStyle(
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
                    itemCount: pests.length,
                    itemBuilder: (context, index) {
                      final pest = pests[index];
                      return _buildPestCard(context, provider, pest);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PestFormScreen()),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('آفة جديدة',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildPestCard(
      BuildContext context, FinanceProvider provider, Pest pest) {
    final badgeColor = _getBadgeColor(pest.type);
    final badgeIcon = _getTypeIcon(pest.type);
    final links = provider.pestIngredientsFor(pest.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.dynamicCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dynamicCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon, Name, Type Capsule & Options
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(badgeIcon, color: badgeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pest.name,
                        style: TextStyle(
                          color: context.dynamicTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pest.type,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: context.dynamicTextSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'تعديل',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PestFormScreen(pest: pest),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.expenseRed),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'حذف',
                      onPressed: () => _confirmDelete(context, provider, pest),
                    ),
                  ],
                ),
              ],
            ),

            // Symptoms Box
            if (pest.symptoms != null && pest.symptoms!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: context.dynamicTextPrimary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: 'الأعراض الظاهرية: ',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: pest.symptoms!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Treatment Notes Box
            if (pest.notes != null && pest.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.incomeGreen.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        size: 16, color: AppTheme.incomeGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: context.dynamicTextPrimary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: 'طرق المكافحة والعلاج: ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.incomeGreen),
                            ),
                            TextSpan(text: pest.notes!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Recommended Active Ingredients
            if (links.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.science_outlined,
                      size: 15, color: AppTheme.accentBlue),
                  const SizedBox(width: 6),
                  Text(
                    'المواد الفعالة الموصى بها (${links.length}):',
                    style: TextStyle(
                      color: context.dynamicTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: links.map((link) {
                  final ing = provider.chemicalIngredients
                      .firstWhereOrNull((i) => i.id == link.ingredientId);
                  if (ing == null) return const SizedBox.shrink();
                  final isInsecticide = ing.type == 'حشري';
                  final color = isInsecticide
                      ? Colors.orange.shade800
                      : AppTheme.incomeGreen;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isInsecticide
                              ? Icons.bug_report
                              : Icons.eco_outlined,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ing.name,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (link.dosage != null && link.dosage!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: context.dynamicCardBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'الجرعة: ${link.dosage}',
                              style: TextStyle(
                                color: context.dynamicTextMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
