import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/finance_provider.dart';
import '../services/google_drive_backup.dart';
import '../theme.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: context.dynamicScaffoldBg,
          appBar: AppBar(
            title: const Text('النسخ الاحتياطي والأمان'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentBlue,
              indicatorWeight: 3,
              labelColor: AppTheme.accentBlue,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.phone_android_rounded, size: 18),
                  text: 'النسخ المحلي والملفات',
                ),
                Tab(
                  icon: Icon(Icons.cloud_outlined, size: 18),
                  text: 'Google Drive',
                ),
                Tab(
                  icon: Icon(Icons.fact_check_outlined, size: 18),
                  text: 'تفاصيل البيانات',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _LocalBackupTab(provider: provider),
              _DriveBackupTab(provider: provider),
              _DataDetailsTab(provider: provider),
            ],
          ),
        );
      },
    );
  }
}

// ======================= HELPER FUNCTIONS =======================

Future<String> _collectAllData() async {
  final prefs = await SharedPreferences.getInstance();
  final data = <String, dynamic>{
    '_version': '1.0',
    '_exportDate': DateTime.now().toIso8601String(),
    '_appName': 'finance_tracker',
  };
  for (final key in prefs.getKeys()) {
    data[key] = prefs.get(key);
  }
  return const JsonEncoder.withIndent('  ').convert(data);
}

Future<bool> _applyData(String jsonStr, BuildContext context) async {
  final decoded = json.decode(jsonStr);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('تنسيق ملف النسخة الاحتياطية غير صالح');
  }
  if (decoded['_appName'] != 'finance_tracker') {
    throw const FormatException('هذا الملف ليس نسخة احتياطية صادرة من التطبيق');
  }
  final version = decoded['_version'];
  if (version is! String || version.isEmpty) {
    throw const FormatException('ملف النسخة الاحتياطية لا يحتوي على إصدار صالح');
  }

  final prefs = await SharedPreferences.getInstance();
  final oldData = <String, Object?>{
    for (final key in prefs.getKeys()) key: prefs.get(key),
  };

  Future<void> restoreSnapshot() async {
    await prefs.clear();
    for (final entry in oldData.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(entry.key, value);
      }
    }
  }

  try {
    await prefs.clear();
    for (final entry in decoded.entries) {
      if (entry.key.startsWith('_')) continue;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is List && value.every((v) => v is String)) {
        await prefs.setStringList(entry.key, List<String>.from(value));
      } else {
        throw FormatException('نوع بيانات غير مدعوم للمفتاح: ${entry.key}');
      }
    }

    await prefs.setString(
        'last_restore_timestamp', DateTime.now().toIso8601String());

    if (context.mounted) {
      // الاستعادة المحلية لا ينبغي أن تستبدلها نسخة قديمة من السحابة مباشرة.
      final provider = context.read<FinanceProvider>();
      await provider.reloadData(syncFromCloud: false);
      await provider.syncAllToCloud();
    }
    return true;
  } catch (_) {
    await restoreSnapshot();
    if (context.mounted) {
      await context.read<FinanceProvider>().reloadData(syncFromCloud: false);
    }
    rethrow;
  }
}

Future<Directory> _getAppBackupDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final backupDir = Directory('${dir.path}/backups');
  if (!await backupDir.exists()) {
    await backupDir.create(recursive: true);
  }
  return backupDir;
}

// ======================= LOCAL BACKUP TAB =======================

class _LocalBackupTab extends StatefulWidget {
  final FinanceProvider provider;
  const _LocalBackupTab({required this.provider});

  @override
  State<_LocalBackupTab> createState() => _LocalBackupTabState();
}

class _LocalBackupTabState extends State<_LocalBackupTab> {
  List<File> _backups = [];
  bool _isLoading = true;
  String? _lastBackupTimeStr;

  @override
  void initState() {
    super.initState();
    _loadLocalBackups();
    _loadLastBackupTime();
  }

  Future<void> _loadLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastBackupTimeStr = prefs.getString('last_backup_timestamp');
    });
  }

  Future<void> _loadLocalBackups() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // في بيئة الويب، لا يوجد نظام ملفات محلي مباشر
        setState(() {
          _backups = [];
          _isLoading = false;
        });
        return;
      }
      final dir = await _getAppBackupDir();
      final files = dir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (!mounted) return;
      setState(() {
        _backups = files;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createLocalBackup({bool showToast = true}) async {
    try {
      final jsonStr = await _collectAllData();
      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_backup_timestamp', DateTime.now().toIso8601String());

      if (!kIsWeb) {
        final dir = await _getAppBackupDir();
        final file = File('${dir.path}/backup_$timestamp.json');
        await file.writeAsString(jsonStr);
      }

      await _loadLastBackupTime();
      await _loadLocalBackups();

      if (mounted && showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم إنشاء النسخة الاحتياطية بنجاح على الجهاز'),
              ],
            ),
            backgroundColor: AppTheme.incomeGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء إنشاء النسخة: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    }
  }

  // تصدير كملف خارجي يُحفظ في أي مكان يختاره المستخدم
  Future<void> _exportBackupFile() async {
    try {
      final jsonStr = await _collectAllData();
      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName = 'farm_finance_backup_$timestamp.json';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مجلد حفظ ملف النسخة الاحتياطية',
        fileName: fileName,
        bytes: utf8.encode(jsonStr),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_backup_timestamp', DateTime.now().toIso8601String());
      _loadLastBackupTime();

      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير وحفظ ملف النسخة الاحتياطية بنجاح'),
            backgroundColor: AppTheme.incomeGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تصدير الملف: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    }
  }

  // استيراد ملف نسخة احتياطية من أي مكان
  Future<void> _importBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'اختر ملف النسخة الاحتياطية (JSON)',
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      String jsonContent;
      final file = result.files.single;
      if (file.bytes != null) {
        jsonContent = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonContent = await File(file.path!).readAsString();
      } else {
        throw const FormatException('تعذر قراءة محتوى الملف');
      }

      if (!mounted) return;
      await _confirmAndRestore(jsonContent, fileName: file.name);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('تعذر الاستيراد',
                style: TextStyle(color: AppTheme.expenseRed)),
            content: Text('الملف المحدد غير صالح أو تالف.\nالتفاصيل: $e',
                style: TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    }
  }

  // نافذة التأكيد الذكية قبل الاسترجاع مع خيار Snapshot آمن
  Future<void> _confirmAndRestore(String jsonStr, {String? fileName}) async {
    bool createSafetySnapshot = true;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orangeAccent, size: 28),
              SizedBox(width: 10),
              Text('تأكيد استرجاع البيانات',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName != null
                    ? 'أنت على وشك استرجاع البيانات من الملف: "$fileName".'
                    : 'سيتم استبدال جميع البيانات الحالية بالبيانات الموجودة في هذه النسخة الاحتياطية.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
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
                        Checkbox(
                          value: createSafetySnapshot,
                          activeColor: AppTheme.accentBlue,
                          onChanged: (v) => setDialogState(
                              () => createSafetySnapshot = v ?? true),
                        ),
                        Expanded(
                          child: Text(
                            'إنشاء لقطة أمان احتياطية تلقائية من البيانات الحالية قبل الاسترجاع (موصى به)',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استرجاع البيانات الآن',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      if (createSafetySnapshot) {
        await _createLocalBackup(showToast: false);
      }

      if (!mounted) return;
      await _applyData(jsonStr, context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.incomeGreen, size: 26),
                SizedBox(width: 8),
                Text('اكتمل الاسترجاع بنجاح',
                    style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            content: Text(
              'تم استرجاع جميع السجلات والبيانات وتحديث الشاشات فورياً.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('تم',
                    style: TextStyle(
                        color: AppTheme.accentBlue,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تطبيق البيانات: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteLocalBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف النسخة الاحتياطية',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد بالتأكيد حذف ملف النسخة الاحتياطية هذا؟',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        _loadLocalBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف النسخة بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر الحذف: $e')),
          );
        }
      }
    }
  }

  String _formatSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes بايت';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} ك.ب';
      return '${(bytes / 1048576).toStringAsFixed(1)} م.ب';
    } catch (_) {
      return '';
    }
  }

  String _formatFileNameDate(String filename) {
    final match =
        RegExp(r'backup_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})')
            .firstMatch(filename);
    if (match == null) return filename;
    try {
      final date =
          DateFormat('yyyy-MM-dd_HH-mm-ss').parse(match.group(1)!);
      return DateFormat('dd MMM yyyy · hh:mm a', 'ar').format(date);
    } catch (_) {
      return filename;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRecords = _calculateTotalRecords(widget.provider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // 1. بطاقة مؤشر الأمان وحالة الحفظ العامة
        _buildSecurityHeaderCard(totalRecords),

        const SizedBox(height: 14),

        // 2. بطاقة الإجراءات السريعة (إنشاء، تصدير، استيراد)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.save_as_outlined,
                      color: AppTheme.accentBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'خيارات النسخ والاستيراد المباشر',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createLocalBackup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.backup_rounded, size: 18),
                      label: const Text('حفظ نسخة الآن',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportBackupFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.incomeGreen,
                        side: BorderSide(color: AppTheme.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('تصدير كملف',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _importBackupFile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.file_open_outlined,
                      color: Colors.orangeAccent, size: 18),
                  label: const Text('استيراد واسترجاع من ملف JSON',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 3. قائمة النسخ المحفوظة على الجهاز
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.folder_zip_outlined,
                    color: AppTheme.accentBlue, size: 18),
                SizedBox(width: 8),
                Text(
                  'النسخ المحفوظة على الجهاز',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            Text(
              '${_backups.length} نسخة',
              style:
                  TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_isLoading)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (_backups.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.folder_open_outlined,
                    color: AppTheme.textMuted, size: 48),
                SizedBox(height: 12),
                Text(
                  'لا توجد نسخ احتياطية محفوظة على هذا الجهاز حتى الآن',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'اضغط على "حفظ نسخة الآن" لإنشاء أول نسخة وحماية بياناتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._backups.map((file) {
            final filename = file.path.split('/').last;
            final dateStr = _formatFileNameDate(filename);
            final sizeStr = _formatSize(file);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.restore_page_outlined,
                      color: AppTheme.accentBlue, size: 20),
                ),
                title: Text(
                  dateStr,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'الحجم: $sizeStr · ملف JSON محلي',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.settings_backup_restore,
                          color: AppTheme.incomeGreen, size: 22),
                      tooltip: 'استرجاع هذه النسخة',
                      onPressed: () async {
                        final content = await file.readAsString();
                        if (mounted) {
                          _confirmAndRestore(content, fileName: filename);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: AppTheme.expenseRed, size: 20),
                      tooltip: 'حذف',
                      onPressed: () => _deleteLocalBackup(file),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSecurityHeaderCard(int totalRecords) {
    DateTime? lastDate;
    if (_lastBackupTimeStr != null) {
      try {
        lastDate = DateTime.parse(_lastBackupTimeStr!);
      } catch (_) {}
    }

    final isSafe = lastDate != null &&
        DateTime.now().difference(lastDate).inDays <= 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSafe
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.orangeAccent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isSafe ? AppTheme.incomeGreen : Colors.orangeAccent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSafe ? Icons.verified_user_rounded : Icons.shield_outlined,
                  color: isSafe ? AppTheme.incomeGreen : Colors.orangeAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSafe ? 'البيانات مؤمّنة ومحمية' : 'يُنصح بعمل نسخة احتياطية',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastDate != null
                          ? 'آخر نسخة: ${DateFormat('dd MMM yyyy · hh:mm a', 'ar').format(lastDate)}'
                          : 'لم يتم أخذ نسخة احتياطية من قبل',
                      style: TextStyle(
                        color: isSafe ? AppTheme.incomeGreen : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      '$totalRecords',
                      style: TextStyle(
                        color: AppTheme.accentBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text('سجل مؤمّن',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======================= DRIVE BACKUP TAB =======================

class _DriveBackupTab extends StatefulWidget {
  final FinanceProvider provider;
  const _DriveBackupTab({required this.provider});

  @override
  State<_DriveBackupTab> createState() => _DriveBackupTabState();
}

class _DriveBackupTabState extends State<_DriveBackupTab> {
  final _drive = DriveBackup();
  List<drive.File> _backups = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _initDrive();
  }

  Future<void> _initDrive() async {
    _email = await _drive.signedInEmail;
    if (!mounted) return;
    setState(() {});
    if (_email != null) {
      _loadBackups();
    }
  }

  Future<void> _loadBackups() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final files = await _drive.listBackups();
      if (!mounted) return;
      setState(() {
        _backups = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر جلب النسخ من Drive: $e')),
      );
    }
  }

  Future<void> _uploadBackup() async {
    if (_email == null) return;
    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      final jsonStr = await _collectAllData();
      await _drive.uploadBackup(jsonStr);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_backup_timestamp', DateTime.now().toIso8601String());

      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفع وحفظ النسخة الاحتياطية على Google Drive بنجاح'),
          backgroundColor: AppTheme.incomeGreen,
        ),
      );
      _loadBackups();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الرفع إلى Google Drive: $e'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
    }
  }

  Future<void> _restoreDriveBackup(drive.File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cloud_download_outlined,
                color: AppTheme.accentBlue, size: 24),
            SizedBox(width: 8),
            Text('استرجاع من Google Drive',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'سيتم استبدال البيانات الحالية بالبيانات المحفوظة في هذه النسخة السحابية. هل ترغب في المتابعة؟',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استرجاع البيانات'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // لقطة أمان محلية قبل استعادة نسخة Drive، حتى يمكن التراجع عملياً
      // إذا كانت النسخة السحابية قديمة أو غير مناسبة.
      await _createLocalBackup(showToast: false);
      final jsonStr = await _drive.downloadBackup(file.id!);
      if (!mounted) return;
      await _applyData(jsonStr, context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم استرجاع البيانات بنجاح من Google Drive'),
            backgroundColor: AppTheme.incomeGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الاسترجاع: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteDriveBackup(drive.File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف النسخة السحابية',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف هذه النسخة من Google Drive؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _drive.deleteBackup(file.id!);
        _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف النسخة السحابية بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر الحذف من Drive: $e')),
          );
        }
      }
    }
  }

  String _formatSize(String? sizeStr) {
    final size = int.tryParse(sizeStr ?? '');
    if (size == null) return '';
    if (size < 1024) return '$size بايت';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} ك.ب';
    return '${(size / 1048576).toStringAsFixed(1)} م.ب';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy · hh:mm a', 'ar').format(date.toLocal());
  }

  Future<void> _doSignIn() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _drive.listBackups();
      final email = await _drive.signedInEmail;
      if (!mounted) return;
      setState(() {
        _email = email;
        _isLoading = false;
      });
      _loadBackups();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الدخول: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_email == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Icon(Icons.cloud_sync_outlined,
                    color: AppTheme.accentBlue, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                'النسخ الاحتياطي السحابي عبر Google Drive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'احفظ بيانات مزرعتك بأمان في حسابك الشخصي على Google Drive للوصول إليها واسترجاعها في أي وقت ومن أي جهاز.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _doSignIn,
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text('تسجيل الدخول بحساب Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // بطاقة حالة الاتصال بالحساب
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.incomeGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cloud_done_rounded,
                        color: AppTheme.incomeGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('متصل بـ Google Drive',
                            style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        Text(
                          _email ?? '',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout,
                        color: AppTheme.textMuted, size: 20),
                    tooltip: 'تسجيل الخروج',
                    onPressed: () async {
                      await _drive.signOut();
                      if (mounted) setState(() => _email = null);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadBackup,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: const Text('رفع نسخة احتياطية جديدة إلى Drive'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_queue_rounded,
                    color: AppTheme.accentBlue, size: 18),
                SizedBox(width: 8),
                Text(
                  'النسخ المحفوظة على Google Drive',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.refresh,
                  color: AppTheme.accentBlue, size: 20),
              onPressed: _loadBackups,
              tooltip: 'تحديث القائمة',
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_isLoading)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (_backups.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_off_rounded,
                    color: AppTheme.textMuted, size: 48),
                SizedBox(height: 12),
                Text(
                  'لا توجد نسخ احتياطية على Google Drive حتى الآن',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'اضغط على الزر أعلاه لرفع نسخة فورية وحفظها في السحابة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._backups.map((file) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.cloud_done_outlined,
                      color: AppTheme.accentBlue, size: 20),
                ),
                title: Text(
                  _formatDate(file.createdTime),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'الحجم: ${_formatSize(file.size)} · Google Drive',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.settings_backup_restore,
                          color: AppTheme.incomeGreen, size: 22),
                      tooltip: 'استرجاع هذه النسخة',
                      onPressed: () => _restoreDriveBackup(file),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: AppTheme.expenseRed, size: 20),
                      tooltip: 'حذف',
                      onPressed: () => _deleteDriveBackup(file),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ======================= DATA DETAILS TAB =======================

class _DataDetailsTab extends StatelessWidget {
  final FinanceProvider provider;
  const _DataDetailsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DataStatItem('المواضع والأراضي الزراعية', provider.landPlots.length,
          Icons.terrain, Colors.lightGreen),
      _DataStatItem('سجلات الإيرادات', provider.incomes.length,
          Icons.arrow_downward, AppTheme.incomeGreen),
      _DataStatItem('سجلات المصروفات', provider.expenses.length,
          Icons.arrow_upward, AppTheme.expenseRed),
      _DataStatItem('فواتير المشتريات', provider.purchases.length,
          Icons.shopping_cart_outlined, Colors.purpleAccent),
      _DataStatItem('المخازن والمستودعات', provider.warehouses.length,
          Icons.warehouse_outlined, Colors.brown),
      _DataStatItem('أصناف المواد والمخزون', provider.storageItems.length,
          Icons.inventory_2_outlined, Colors.amber),
      _DataStatItem('الشركاء والعملاء والموردين', provider.partners.length,
          Icons.people_alt_outlined, Colors.teal),
      _DataStatItem('عقود وأنصبة الشراكات', provider.partnerships.length,
          Icons.handshake_outlined, AppTheme.accentBlue),
      _DataStatItem('العمال والمساعدين', provider.workers.length,
          Icons.engineering_outlined, Colors.indigoAccent),
      _DataStatItem('سجلات أيام وساعات العمل', provider.workRecords.length,
          Icons.timer_outlined, Colors.blueGrey),
      _DataStatItem('المحافظ والحسابات المالية', provider.wallets.length,
          Icons.account_balance_wallet_outlined, Colors.deepOrange),
      _DataStatItem('حركات التغذية والتحويلات',
          provider.moneyMovements.length, Icons.sync_alt, Colors.cyan),
      _DataStatItem('سجلات الديون والالتزامات',
          provider.personalDebts.length, Icons.money_off, Colors.redAccent),
      _DataStatItem('تسويات وسدادات الديون',
          provider.personalDebtSettlements.length, Icons.done_all, Colors.green),
      _DataStatItem('الأحداث والعمليات الزراعية', provider.landEvents.length,
          Icons.calendar_today_outlined, Colors.tealAccent),
      _DataStatItem('أنواع وأصناف الزهرة', provider.zahraTypes.length,
          Icons.eco_outlined, Colors.lightGreenAccent),
    ];

    final total = items.fold<int>(0, (s, e) => s + e.count);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fact_check_rounded,
                    color: AppTheme.accentBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي السجلات المؤرخة بالنظام',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                    Text(
                      '$total سجلاً مسجلاً ومؤمّناً',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'تفصيل محتويات النسخة الاحتياطية:',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((it) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: it.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(it.icon, color: it.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      it.label,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      '${it.count}',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _DataStatItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _DataStatItem(this.label, this.count, this.icon, this.color);
}

int _calculateTotalRecords(FinanceProvider provider) {
  return provider.landPlots.length +
      provider.incomes.length +
      provider.expenses.length +
      provider.purchases.length +
      provider.warehouses.length +
      provider.storageItems.length +
      provider.partners.length +
      provider.partnerships.length +
      provider.workers.length +
      provider.workRecords.length +
      provider.wallets.length +
      provider.moneyMovements.length +
      provider.personalDebts.length +
      provider.personalDebtSettlements.length +
      provider.landEvents.length +
      provider.zahraTypes.length;
}
