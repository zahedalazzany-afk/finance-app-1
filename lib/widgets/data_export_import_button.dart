import 'package:flutter/material.dart';
import '../services/export_import.dart';
import '../theme.dart';

typedef RowsProvider = List<Map<String, dynamic>> Function();
typedef ImportHandler = Future<void> Function(List<Map<String, dynamic>> rows);

/// A reusable button that offers Export JSON / Export CSV / Import JSON
/// for the current screen's data.
class DataExportImportButton extends StatelessWidget {
  const DataExportImportButton({
    super.key,
    required this.label,
    required this.buildRows,
    required this.csvHeaders,
    required this.csvKeys,
    required this.onImport,
    this.askUserFolder = true,
    this.importConfirmation = true,
  });

  final String label;
  final RowsProvider buildRows;
  final List<String> csvHeaders;
  final List<String> csvKeys;
  final ImportHandler onImport;
  final bool askUserFolder;
  final bool importConfirmation;

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.dynamicCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dynamicCardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('تصدير / استيراد $label',
                style: TextStyle(
                    color: context.dynamicTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _option(
              context,
              icon: Icons.description_outlined,
              iconColor: context.dynamicAccentBlue,
              title: 'تصدير JSON',
              subtitle: 'ملف يُعاد استيراده لاحقاً',
              onTap: () => _exportJson(context),
            ),
            _option(
              context,
              icon: Icons.table_chart_outlined,
              iconColor: context.dynamicIncomeGreen,
              title: 'تصدير CSV',
              subtitle: 'فتح في Excel للمعاينة',
              onTap: () => _exportCsv(context),
            ),
            _option(
              context,
              icon: Icons.file_open_outlined,
              iconColor: context.dynamicExpenseRed,
              title: 'استيراد JSON',
              subtitle: 'اختيار ملف موجود',
              onTap: () => _importJson(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context,
      {required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title,
          style: TextStyle(
              color: context.dynamicTextPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: context.dynamicTextMuted, fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _exportJson(BuildContext context) async {
    try {
      final rows = buildRows();
      final base = ExportImport.sanitizeName(label);
      final path = await ExportImport.exportJson(
        rows,
        base,
        askUserFolder: askUserFolder,
      );
      if (path == null) return; // cancelled
      _notify(context, 'تم تصدير JSON بنجاح: $path', isError: false);
    } catch (e) {
      _notify(context, 'خطأ في التصدير: $e', isError: true);
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final rows = buildRows();
      final base = ExportImport.sanitizeName(label);
      final path = await ExportImport.exportCsv(
        rows,
        base,
        csvHeaders,
        csvKeys,
        askUserFolder: askUserFolder,
      );
      if (path == null) return; // cancelled
      _notify(context, 'تم تصدير CSV بنجاح: $path', isError: false);
    } catch (e) {
      _notify(context, 'خطأ في التصدير: $e', isError: true);
    }
  }

  Future<void> _importJson(BuildContext context) async {
    try {
      if (importConfirmation) {
        final confirmed = await _confirm(context);
        if (!confirmed) return;
      }
      final rows = await ExportImport.pickAndImportJson();
      if (rows == null) return; // cancelled
      await onImport(rows);
      _notify(context, 'تم استيراد البيانات بنجاح', isError: false);
    } catch (e) {
      _notify(context, 'خطأ في الاستيراد: $e', isError: true);
    }
  }

  Future<bool> _confirm(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.dynamicCardBg,
        title: Text('استيراد البيانات',
            style: TextStyle(color: ctx.dynamicTextPrimary)),
        content: Text(
          'سيتم دمج بيانات الملف المحدد مع بيانات $label الحالية (بدون حذف). متابعة؟',
          style: TextStyle(color: ctx.dynamicTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('استيراد',
                  style: TextStyle(color: ctx.dynamicAccentBlue))),
        ],
      ),
    );
    return result ?? false;
  }

  void _notify(BuildContext context, String message, {required bool isError}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 3),
        backgroundColor:
            isError ? Colors.red.shade800 : context.dynamicIncomeGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'تصدير / استيراد',
      icon: Icon(Icons.import_export, color: context.dynamicAccentBlue),
      onPressed: () => _showOptions(context),
    );
  }
}
