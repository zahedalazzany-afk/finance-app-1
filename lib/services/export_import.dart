import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ExportImport {
  /// Generates a CSV string from [rows] using [headers] (display) and
  /// [keys] (map keys). Values are escaped for CSV safety.
  static String generateCsv(
    List<Map<String, dynamic>> rows,
    List<String> headers,
    List<String> keys,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsv).join(','));
    for (final row in rows) {
      final cells = keys.map((k) => _escapeCsv('${row[k] ?? ''}'));
      buffer.writeln(cells.join(','));
    }
    return buffer.toString().trimRight();
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Returns the default app-private folder for exports.
  /// Always writable without any storage permission.
  static Future<Directory> defaultExportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/FinanceExports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Exports [rows] as JSON.
  ///
  /// If [askUserFolder] is true it uses the Storage Access Framework
  /// (`saveFile`) so the user chooses a location and the app gets write
  /// access on Android 11+ without requesting broad storage permissions.
  /// Otherwise it writes to the app-private documents folder.
  ///
  /// Returns the saved file path, or null if cancelled.
  static Future<String?> exportJson(
    List<Map<String, dynamic>> rows,
    String baseName, {
    bool askUserFolder = true,
  }) async {
    final content = const JsonEncoder.withIndent('  ').convert(rows);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${baseName}_$stamp.json';
    if (askUserFolder) {
      return _saveViaPicker(fileName, content);
    }
    final dir = await defaultExportDir();
    final file = await File('${dir.path}/$fileName').writeAsString(content);
    return file.path;
  }

  /// Exports [rows] as CSV. See [exportJson] for [askUserFolder] semantics.
  /// The content is written as UTF-8 with a BOM so Arabic opens correctly in
  /// Excel/Sheets.
  static Future<String?> exportCsv(
    List<Map<String, dynamic>> rows,
    String baseName,
    List<String> headers,
    List<String> keys, {
    bool askUserFolder = true,
  }) async {
    final content = '\uFEFF${generateCsv(rows, headers, keys)}';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${baseName}_$stamp.csv';
    if (askUserFolder) {
      return _saveViaPicker(fileName, content);
    }
    final dir = await defaultExportDir();
    final file = await File('${dir.path}/$fileName')
        .writeAsString(content, encoding: utf8);
    return file.path;
  }

  /// Uses the system file saver (SAF). On Android/iOS the plugin needs the
  /// [bytes] and writes the file itself, returning the saved path.
  static Future<String?> _saveViaPicker(
      String fileName, String content) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'اختر مكان حفظ الملف',
      fileName: fileName,
      bytes: utf8.encode(content),
    );
    if (path == null) return null;
    return path;
  }

  /// Lets the user pick a JSON file and returns its decoded list of objects.
  /// Returns null if the user cancels or the file is not valid JSON list.
  static Future<List<Map<String, dynamic>>?> pickAndImportJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'اختر ملف الاستيراد (JSON)',
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    final content = await File(path).readAsString();
    final decoded = json.decode(content);
    if (decoded is! List) {
      throw const FormatException('الملف غير صالح: يجب أن يكون قائمة JSON');
    }
    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Sanitizes a base file name (removes unsafe characters).
  static String sanitizeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
}
