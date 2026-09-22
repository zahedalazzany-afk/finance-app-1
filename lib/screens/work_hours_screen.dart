import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/data_export_import_button.dart';

enum WorkFilterTab { all, billable, internal, unpaid, paid }
enum WorkDatePeriod { all, today, thisWeek, thisMonth, custom }

class WorkHoursScreen extends StatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  State<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen> {
  // فلترة
  WorkFilterTab _activeTab = WorkFilterTab.all;
  WorkDatePeriod _datePeriod = WorkDatePeriod.all;
  DateTimeRange? _customDateRange;
  String? _selectedPlotId;
  String _searchQuery = '';

  // حالة مؤقت العمل والري المباشر (Live Timer)
  bool _isTimerRunning = false;
  DateTime? _timerStart;
  String? _timerPlotId;
  double? _timerRate;
  String? _timerNote;
  Timer? _timerTicker;
  Duration _elapsedDuration = Duration.zero;
  bool _isTimerExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTimer();
  }

  @override
  void dispose() {
    _timerTicker?.cancel();
    super.dispose();
  }

  // استرجاع حالة المؤقت إن كانت هناك جلسة قيد التشغيل سابقاً
  Future<void> _loadSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final startIso = prefs.getString('work_timer_start_time');
    if (startIso != null) {
      final parsed = DateTime.tryParse(startIso);
      if (parsed != null) {
        if (!mounted) return;
        setState(() {
          _timerStart = parsed;
          _timerPlotId = prefs.getString('work_timer_plot_id');
          _timerRate = prefs.getDouble('work_timer_rate');
          _timerNote = prefs.getString('work_timer_note');
          _isTimerRunning = true;
          _elapsedDuration = DateTime.now().difference(parsed);
        });
        _startTicker();
      }
    }
  }

  void _startTicker() {
    _timerTicker?.cancel();
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _timerStart == null) return;
      setState(() {
        _elapsedDuration = DateTime.now().difference(_timerStart!);
      });
    });
  }

  Future<void> _startLiveTimer({
    required String plotId,
    double? hourlyRate,
    String? note,
  }) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('work_timer_start_time', now.toIso8601String());
    await prefs.setString('work_timer_plot_id', plotId);
    if (hourlyRate != null) {
      await prefs.setDouble('work_timer_rate', hourlyRate);
    } else {
      await prefs.remove('work_timer_rate');
    }
    if (note != null && note.isNotEmpty) {
      await prefs.setString('work_timer_note', note);
    } else {
      await prefs.remove('work_timer_note');
    }

    if (!mounted) return;
    setState(() {
      _timerStart = now;
      _timerPlotId = plotId;
      _timerRate = hourlyRate;
      _timerNote = note;
      _isTimerRunning = true;
      _elapsedDuration = Duration.zero;
      _isTimerExpanded = true;
    });
    _startTicker();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم بدء مؤقت جلسة العمل والري بنجاح'),
        backgroundColor: AppTheme.incomeGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _stopAndSaveTimer(FinanceProvider provider) async {
    if (_timerStart == null) return;
    final start = _timerStart!;
    final end = DateTime.now();
    final plotId = _timerPlotId;
    final rate = _timerRate;
    final note = _timerNote;

    // إيقاف وتصفير المؤقت المحفوظ
    _timerTicker?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('work_timer_start_time');
    await prefs.remove('work_timer_plot_id');
    await prefs.remove('work_timer_rate');
    await prefs.remove('work_timer_note');

    if (!mounted) return;
    setState(() {
      _isTimerRunning = false;
      _timerStart = null;
      _timerPlotId = null;
      _timerRate = null;
      _timerNote = null;
      _elapsedDuration = Duration.zero;
    });

    // فتح نموذج الإضافة جاهزاً ومملوءاً
    _showForm(
      context,
      provider,
      initialPlotId: plotId,
      initialStart: start,
      initialEnd: end,
      initialRate: rate,
      initialNote: note,
    );
  }

  Future<void> _cancelLiveTimer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إلغاء المؤقت', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل أنت متأكد من إلغاء جلسة العمل الجارية دون حفظ؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('نعم، إلغاء', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timerTicker?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('work_timer_start_time');
      await prefs.remove('work_timer_plot_id');
      await prefs.remove('work_timer_rate');
      await prefs.remove('work_timer_note');

      if (!mounted) return;
      setState(() {
        _isTimerRunning = false;
        _timerStart = null;
        _timerPlotId = null;
        _timerRate = null;
        _timerNote = null;
        _elapsedDuration = Duration.zero;
      });
    }
  }

  void _openStartTimerDialog(FinanceProvider provider) {
    String? plotId = provider.landPlots.isNotEmpty ? provider.landPlots.first.id : null;
    final rateController = TextEditingController(text: '1000');
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final selectedPlot = provider.landPlots.firstWhereOrNull((p) => p.id == plotId);
          final isBillable = selectedPlot?.category == 'partnered' || selectedPlot?.category == 'client';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: AppTheme.accentBlue, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'بدء عداد جلسة عمل / ري مباشرة',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'سيبدأ العداد بالعد الفوري في الخلفية، ويمكنك إيقافه وحفظ السجل عند انتهاء الري.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  SheetDropdown<String>(
                    label: 'الموضع / الأرض المستهدفة',
                    labelAbove: true,
                    value: plotId,
                    items: provider.landPlots.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${landPlotCategoryLabel(p.category)})'),
                      );
                    }).toList(),
                    onChanged: (v) => setSheetState(() => plotId = v),
                  ),
                  if (isBillable) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'سعر الساعة (ر.ي)',
                        hintText: '1000',
                        prefixIcon: Icon(Icons.attach_money, color: AppTheme.incomeGreen),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: noteController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'ملاحظة أولية (اختياري)',
                      hintText: 'مثال: ري قاعة الحبة...',
                      prefixIcon: Icon(Icons.notes, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (plotId == null) return;
                        final rate = isBillable ? (double.tryParse(rateController.text.trim()) ?? 0.0) : null;
                        Navigator.pop(ctx);
                        _startLiveTimer(
                          plotId: plotId!,
                          hourlyRate: rate,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        'تشغيل العداد الآن',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allRecords = provider.workRecords;
    final plotMap = {for (var p in provider.landPlots) p.id: p};
    final incomeMap = {for (var i in provider.incomes) i.id: i};

    // حساب الإحصائيات العامة لكامل السجلات
    final totalMinutesAll = allRecords.fold<int>(0, (s, r) => s + r.durationMinutes);
    int billableMinutesAll = 0;
    double totalBillableExpectedAll = 0.0;
    double totalCollectedAll = 0.0;
    double totalRemainingDebtAll = 0.0;

    for (final r in allRecords) {
      if (r.hourlyRate != null && r.hourlyRate! > 0) {
        billableMinutesAll += r.durationMinutes;
        totalBillableExpectedAll += r.totalAmount;
      }
      if (r.incomeId != null) {
        final inc = incomeMap[r.incomeId];
        if (inc != null) {
          totalCollectedAll += inc.receivedAmount;
          totalRemainingDebtAll += inc.remainingAmount;
        }
      }
    }
    final internalMinutesAll = totalMinutesAll - billableMinutesAll;

    // تطبيق الفلاتر
    final filteredRecords = allRecords.where((r) {
      // 1. فلتر الموضع
      if (_selectedPlotId != null && r.landPlotId != _selectedPlotId) {
        return false;
      }

      // 2. فلتر الفترة الزمنية
      final now = DateTime.now();
      final recordDate = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      switch (_datePeriod) {
        case WorkDatePeriod.all:
          break;
        case WorkDatePeriod.today:
          final today = DateTime(now.year, now.month, now.day);
          if (recordDate != today) return false;
          break;
        case WorkDatePeriod.thisWeek:
          final weekStart = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday % 7));
          if (recordDate.isBefore(weekStart)) return false;
          break;
        case WorkDatePeriod.thisMonth:
          if (r.startTime.year != now.year || r.startTime.month != now.month) return false;
          break;
        case WorkDatePeriod.custom:
          if (_customDateRange != null) {
            final s = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
            final e = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
            if (recordDate.isBefore(s) || recordDate.isAfter(e)) return false;
          }
          break;
      }

      // 3. فلتر البحث النصي
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final pName = (plotMap[r.landPlotId]?.name ?? '').toLowerCase();
        final note = (r.note ?? '').toLowerCase();
        final dateStr = DateFormat('yyyy-MM-dd dd/MM', 'ar').format(r.startTime).toLowerCase();
        if (!pName.contains(q) && !note.contains(q) && !dateStr.contains(q)) {
          return false;
        }
      }

      // 4. فلتر التبويب
      final plot = plotMap[r.landPlotId];
      final isBillable = r.hourlyRate != null && r.hourlyRate! > 0;
      final isInternal = !isBillable || plot?.category == 'owned';
      final inc = r.incomeId != null ? incomeMap[r.incomeId] : null;

      switch (_activeTab) {
        case WorkFilterTab.all:
          return true;
        case WorkFilterTab.billable:
          return isBillable;
        case WorkFilterTab.internal:
          return isInternal;
        case WorkFilterTab.unpaid:
          return inc != null && inc.remainingAmount > 0.01;
        case WorkFilterTab.paid:
          return inc != null && inc.isFullyPaid;
      }
    }).toList();

    // تجميع السجلات حسب اليوم تنازلياً
    final grouped = <DateTime, List<WorkRecord>>{};
    for (final r in filteredRecords) {
      final day = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      grouped.putIfAbsent(day, () => []).add(r);
    }
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('سجل العمل والري'),
        actions: [
          // زر مؤقت العمل السريع في شريط التطبيق
          IconButton(
            tooltip: _isTimerRunning ? 'المؤقت نشط الآن' : 'بدء مؤقت ري',
            icon: Badge(
              isLabelVisible: _isTimerRunning,
              backgroundColor: AppTheme.incomeGreen,
              smallSize: 8,
              child: Icon(
                _isTimerRunning ? Icons.timer : Icons.timer_outlined,
                color: _isTimerRunning ? AppTheme.incomeGreen : null,
              ),
            ),
            onPressed: () {
              if (_isTimerRunning) {
                setState(() => _isTimerExpanded = true);
              } else {
                _openStartTimerDialog(provider);
              }
            },
          ),
          DataExportImportButton(
            label: 'سجلات العمل',
            buildRows: () => provider.workRecords.map((e) => e.toJson()).toList(),
            csvHeaders: const [
              'الموضع', 'بداية العمل', 'نهاية العمل', 'سعر الساعة', 'ملاحظات'
            ],
            csvKeys: const [
              'landPlotId', 'startTime', 'endTime', 'hourlyRate', 'note'
            ],
            onImport: (rows) async {
              final prov = context.read<FinanceProvider>();
              for (final row in rows) {
                try {
                  final rec = WorkRecord.fromJson(row);
                  if (prov.workRecords.any((e) => e.id == rec.id)) continue;
                  prov.addWorkRecord(rec);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. بطاقة عداد الجلسة الحية (Live Timer Card) إذا كان نشطاً
          if (_isTimerRunning)
            _buildActiveTimerCard(provider, plotMap)
          else if (_isTimerExpanded)
            _buildInactiveTimerPrompt(provider),

          // 2. شريط المؤشرات المالية والتشغيلية (KPIs)
          _buildKpiSummaryBar(
            totalMinutes: totalMinutesAll,
            billableMinutes: billableMinutesAll,
            internalMinutes: internalMinutesAll,
            totalBillableAmount: totalBillableExpectedAll,
            totalCollected: totalCollectedAll,
            totalRemainingDebt: totalRemainingDebtAll,
            totalSessionsCount: allRecords.length,
          ),

          // 3. شريط البحث والفلترة السريعة
          _buildSearchAndFilterSection(provider, plotMap),

          // 4. قائمة السجلات المجمعة حسب اليوم
          Expanded(
            child: sortedDays.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: sortedDays.length,
                    itemBuilder: (context, index) {
                      final day = sortedDays[index];
                      final dayRecords = grouped[day]!
                        ..sort((a, b) => b.startTime.compareTo(a.startTime));
                      return _buildDayGroupCard(
                        context: context,
                        provider: provider,
                        day: day,
                        records: dayRecords,
                        plotMap: plotMap,
                        incomeMap: incomeMap,
                        isFirst: index == 0,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, provider),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('سجل جديد', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // بطاقة مؤقت الري النشط حالياً
  Widget _buildActiveTimerCard(FinanceProvider provider, Map<String, LandPlot> plotMap) {
    final plot = plotMap[_timerPlotId];
    final hoursElapsed = _elapsedDuration.inMinutes / 60.0;
    final estimatedCost = (_timerRate ?? 0.0) * hoursElapsed;

    final hrs = _elapsedDuration.inHours.toString().padLeft(2, '0');
    final mins = (_elapsedDuration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (_elapsedDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.incomeGreen.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.incomeGreen.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'جلسة ري وتشغيل نشطة الآن',
                style: TextStyle(
                  color: AppTheme.incomeGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                'بدأ ${_formatTimeWithAmPm(_timerStart!)}',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plot?.name ?? 'موضع غير محدد',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (_timerRate != null && _timerRate! > 0)
                    Text(
                      'سعر الساعة: ${_timerRate!.formatted} ر.ي · التقديري: ${estimatedCost.formatted} ر.ي',
                      style: TextStyle(color: AppTheme.incomeGreen, fontSize: 11),
                    ),
                ],
              ),
              // عداد الوقت الرقمي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  '$hrs:$mins:$secs',
                  style: TextStyle(
                    color: AppTheme.incomeGreen,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _stopAndSaveTimer(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.incomeGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('إيقاف وحفظ السجل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _cancelLiveTimer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.expenseRed,
                  side: BorderSide(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('إلغاء', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // بطاقة دعوة لبدء مؤقت تشغيل حي إن كان مغلقاً
  Widget _buildInactiveTimerPrompt(FinanceProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accentBlueDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.water_drop_outlined, color: AppTheme.accentBlue, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تشغيل المضخة الآن؟ ابدأ المؤقت لحساب الوقت تلقائياً',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
          TextButton.icon(
            onPressed: () => _openStartTimerDialog(provider),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('بدء العداد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 14, color: AppTheme.textMuted),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _isTimerExpanded = false),
          ),
        ],
      ),
    );
  }

  // 1. شريط المؤشرات المالية والتشغيلية (KPIs)
  Widget _buildKpiSummaryBar({
    required int totalMinutes,
    required int billableMinutes,
    required int internalMinutes,
    required double totalBillableAmount,
    required double totalCollected,
    required double totalRemainingDebt,
    required int totalSessionsCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildKpiCard(
              title: 'إجمالي الساعات',
              value: _formatToHrsMins(totalMinutes),
              sub: '$totalSessionsCount جلسة مسجلة',
              icon: Icons.access_time_rounded,
              accentColor: AppTheme.accentBlue,
              bgDimColor: AppTheme.accentBlueDim,
            ),
            const SizedBox(width: 8),
            _buildKpiCard(
              title: 'مبيعات المياه (مفوتر)',
              value: '${totalBillableAmount.formattedFull} ر.ي',
              sub: _formatToHrsMins(billableMinutes),
              icon: Icons.receipt_long_outlined,
              accentColor: AppTheme.incomeGreen,
              bgDimColor: AppTheme.incomeGreenDim,
            ),
            const SizedBox(width: 8),
            _buildKpiCard(
              title: 'الديون المتبقية (آجل)',
              value: '${totalRemainingDebt.formattedFull} ر.ي',
              sub: totalRemainingDebt > 0 ? 'مطلوب تحصيله' : 'خالصة تماماً',
              icon: Icons.warning_amber_rounded,
              accentColor: AppTheme.expenseRed,
              bgDimColor: AppTheme.expenseRedDim,
              isAlert: totalRemainingDebt > 0,
            ),
            const SizedBox(width: 8),
            _buildKpiCard(
              title: 'المبالغ المحصلة',
              value: '${totalCollected.formattedFull} ر.ي',
              sub: 'تم استلامها نقداً',
              icon: Icons.check_circle_outline,
              accentColor: Colors.tealAccent,
              bgDimColor: Colors.teal.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 8),
            _buildKpiCard(
              title: 'العمل الداخلي (تحت اليد)',
              value: _formatToHrsMins(internalMinutes),
              sub: 'ري مزارع ملك',
              icon: Icons.agriculture_outlined,
              accentColor: Colors.amber,
              bgDimColor: Colors.amber.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color accentColor,
    required Color bgDimColor,
    bool isAlert = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? accentColor.withValues(alpha: 0.4) : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgDimColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentColor, size: 14),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isAlert ? accentColor : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // 2. شريط البحث والفلترة
  Widget _buildSearchAndFilterSection(
    FinanceProvider provider,
    Map<String, LandPlot> plotMap,
  ) {
    final selectedPlot = plotMap[_selectedPlotId];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // شريط البحث وتصفية الموضع
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: TextField(
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'بحث بالموضع، الملاحظات...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // منتقي الموضع
              GestureDetector(
                onTap: () => _showPlotPicker(provider),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _selectedPlotId != null
                        ? AppTheme.accentBlue.withValues(alpha: 0.15)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedPlotId != null
                          ? AppTheme.accentBlue
                          : AppTheme.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.terrain,
                        size: 16,
                        color: _selectedPlotId != null
                            ? AppTheme.accentBlue
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedPlotId != null
                            ? (selectedPlot?.name ?? 'الموضع')
                            : 'الموضع',
                        style: TextStyle(
                          color: _selectedPlotId != null
                              ? AppTheme.accentBlue
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: _selectedPlotId != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (_selectedPlotId != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _selectedPlotId = null),
                          child: Icon(Icons.close, size: 14, color: AppTheme.accentBlue),
                        ),
                      ] else ...[
                        Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.textSecondary),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // صف تبويبات الفلاتر السريعة والمدة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('الكل', WorkFilterTab.all),
                const SizedBox(width: 6),
                _buildFilterChip('مبيعات مياه (مفوتر)', WorkFilterTab.billable),
                const SizedBox(width: 6),
                _buildFilterChip('داخلي (تحت اليد)', WorkFilterTab.internal),
                const SizedBox(width: 6),
                _buildFilterChip('آجل / غير مسدد', WorkFilterTab.unpaid),
                const SizedBox(width: 6),
                _buildFilterChip('مسدد بالكامل', WorkFilterTab.paid),
                const SizedBox(width: 10),
                Container(width: 1, height: 18, color: AppTheme.cardBorder),
                const SizedBox(width: 10),
                // فلترة الفترة
                _buildDatePeriodDropdown(),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, WorkFilterTab tab) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePeriodDropdown() {
    String label = 'كل الفترات';
    switch (_datePeriod) {
      case WorkDatePeriod.all:
        label = 'كل الفترات';
        break;
      case WorkDatePeriod.today:
        label = 'اليوم';
        break;
      case WorkDatePeriod.thisWeek:
        label = 'هذا الأسبوع';
        break;
      case WorkDatePeriod.thisMonth:
        label = 'هذا الشهر';
        break;
      case WorkDatePeriod.custom:
        label = _customDateRange != null
            ? '${DateFormat('MM/dd').format(_customDateRange!.start)} - ${DateFormat('MM/dd').format(_customDateRange!.end)}'
            : 'فترة مخصصة';
        break;
    }

    return PopupMenuButton<WorkDatePeriod>(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _datePeriod != WorkDatePeriod.all
              ? AppTheme.accentBlue.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _datePeriod != WorkDatePeriod.all
                ? AppTheme.accentBlue
                : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 14,
              color: _datePeriod != WorkDatePeriod.all ? AppTheme.accentBlue : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: _datePeriod != WorkDatePeriod.all ? AppTheme.accentBlue : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: _datePeriod != WorkDatePeriod.all ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
      onSelected: (period) async {
        if (period == WorkDatePeriod.custom) {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(
              data: AppTheme.theme.copyWith(
                colorScheme: ColorScheme.dark(
                  primary: AppTheme.accentBlue,
                  surface: AppTheme.card,
                ),
              ),
              child: child!,
            ),
          );
          if (range != null) {
            setState(() {
              _datePeriod = WorkDatePeriod.custom;
              _customDateRange = range;
            });
          }
        } else {
          setState(() {
            _datePeriod = period;
            _customDateRange = null;
          });
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: WorkDatePeriod.all, child: Text('كل الفترات')),
        PopupMenuItem(value: WorkDatePeriod.today, child: Text('اليوم فقط')),
        PopupMenuItem(value: WorkDatePeriod.thisWeek, child: Text('هذا الأسبوع')),
        PopupMenuItem(value: WorkDatePeriod.thisMonth, child: Text('هذا الشهر')),
        PopupMenuItem(value: WorkDatePeriod.custom, child: Text('تحديد فترة مخصصة...')),
      ],
    );
  }

  void _showPlotPicker(FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.clear_all, color: AppTheme.textSecondary),
                title: Text('جميع المواضع', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                onTap: () {
                  setState(() => _selectedPlotId = null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.landPlots.length,
                  itemBuilder: (ctx, index) {
                    final p = provider.landPlots[index];
                    final isSelected = p.id == _selectedPlotId;
                    return ListTile(
                      leading: Icon(
                        Icons.terrain,
                        color: isSelected ? AppTheme.accentBlue : AppTheme.textSecondary,
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          color: isSelected ? AppTheme.accentBlue : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        landPlotCategoryLabel(p.category),
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      trailing: isSelected ? Icon(Icons.check, color: AppTheme.accentBlue) : null,
                      onTap: () {
                        setState(() => _selectedPlotId = p.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // بطاقة مجموعة اليوم (Day Group)
  Widget _buildDayGroupCard({
    required BuildContext context,
    required FinanceProvider provider,
    required DateTime day,
    required List<WorkRecord> records,
    required Map<String, LandPlot> plotMap,
    required Map<String, Income> incomeMap,
    required bool isFirst,
  }) {
    final dayMinutes = records.fold<int>(0, (s, r) => s + r.durationMinutes);
    final dayBillableTotal = records.fold<double>(0.0, (s, r) => s + r.totalAmount);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isFirst,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: AppTheme.accentBlue,
          collapsedIconColor: AppTheme.textMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlueDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calendar_month, color: AppTheme.accentBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE، dd MMMM yyyy', 'ar').format(day),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${records.length} جلسات · ${_formatToHrsMins(dayMinutes)}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        if (dayBillableTotal > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· ${dayBillableTotal.formattedFull} ر.ي',
                            style: TextStyle(
                              color: AppTheme.incomeGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            ...records.map((r) => _buildRecordItem(context, provider, r, plotMap, incomeMap)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // بطاقة جلسة عمل منفردة
  Widget _buildRecordItem(
    BuildContext context,
    FinanceProvider provider,
    WorkRecord r,
    Map<String, LandPlot> plotMap,
    Map<String, Income> incomeMap,
  ) {
    final plot = plotMap[r.landPlotId];
    final income = r.incomeId != null ? incomeMap[r.incomeId] : null;
    final isBillable = r.hourlyRate != null && r.hourlyRate! > 0;

    // تحديد لون الحالة
    Color statusColor;
    if (isBillable && income != null) {
      statusColor = income.isFullyPaid
          ? AppTheme.incomeGreen
          : (income.receivedAmount > 0 ? Colors.orange : AppTheme.expenseRed);
    } else {
      statusColor = AppTheme.accentBlue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plot?.name ?? 'موضع غير معروف',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryBadge(plot?.category ?? 'owned'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTimeWithAmPm(r.startTime)} - ${_formatTimeWithAmPm(r.endTime)}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlueDim,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatToHrsMins(r.durationMinutes),
                            style: TextStyle(
                              color: AppTheme.accentBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // قائمة الإجراءات
              PopupMenuButton<String>(
                color: AppTheme.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
                onSelected: (v) {
                  if (v == 'edit') _showForm(context, provider, existing: r);
                  if (v == 'delete') _confirmDelete(context, provider, r);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('تعديل')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppTheme.expenseRed), SizedBox(width: 8), Text('حذف', style: TextStyle(color: AppTheme.expenseRed))])),
                ],
              ),
            ],
          ),

          // تفاصيل الفاتورة ومبيعات المياه إن وجدت
          if (isBillable && income != null) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سعر الساعة: ${r.hourlyRate?.formatted} ر.ي',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                    Text(
                      'الإجمالي: ${income.amount.formattedFull} ر.ي',
                      style: TextStyle(
                        color: AppTheme.incomeGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                _buildPaymentStatusChip(income),
              ],
            ),
            // شريط إجراءات السداد السريع إذا كان غير مسدد بالكامل
            if (!income.isFullyPaid) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'متبقي آجل: ${income.remainingAmount.formattedFull} ر.ي',
                    style: TextStyle(color: AppTheme.expenseRed, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showQuickCollectSheet(context, provider, r, income),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.incomeGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 30),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 14),
                    label: const Text('تحصيل سريع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],

          if (r.note != null && r.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.notes, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    r.note!,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    Color bg;
    Color fg;
    switch (category) {
      case 'client':
        bg = AppTheme.incomeGreenDim;
        fg = AppTheme.incomeGreen;
        break;
      case 'partnered':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber;
        break;
      default:
        bg = AppTheme.accentBlueDim;
        fg = AppTheme.accentBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        landPlotCategoryLabel(category),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPaymentStatusChip(Income income) {
    if (income.isFullyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.incomeGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: AppTheme.incomeGreen),
            SizedBox(width: 4),
            Text('مسدد بالكامل', style: TextStyle(color: AppTheme.incomeGreen, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (income.receivedAmount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'مسدد جزئياً (${income.receivedAmount.formatted})',
          style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.expenseRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('غير مسدد (آجل)', style: TextStyle(color: AppTheme.expenseRed, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.work_history_outlined, color: AppTheme.textMuted, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد سجلات عمل مطابقة',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'يمكنك تغيير خيارات البحث والفلترة أو إضافة سجل جديد بالضغط على +',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // نافذة التحصيل السريع
  void _showQuickCollectSheet(
    BuildContext context,
    FinanceProvider provider,
    WorkRecord record,
    Income income,
  ) {
    final remaining = income.remainingAmount;
    final amountController = TextEditingController(text: remaining.toStringAsFixed(0));
    final noteController = TextEditingController(text: 'تحصيل قيمة ري');
    DateTime date = DateTime.now();
    String? walletId = income.walletId ?? provider.defaultWallet()?.id ?? (provider.wallets.isNotEmpty ? provider.wallets.first.id : null);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, color: AppTheme.incomeGreen, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'تحصيل قيمة جلسة ري',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المتبقي المطلوب تحصيله: ${remaining.formattedFull} ر.ي',
                      style: TextStyle(color: AppTheme.expenseRed, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.incomeGreen, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'المبلغ المستلم نقدًا',
                        prefixIcon: Icon(Icons.attach_money, color: AppTheme.incomeGreen),
                      ),
                      validator: (v) {
                        final a = tryParseFlexible(v ?? '') ?? 0;
                        if (a <= 0) return 'أدخل المبلغ المحصل';
                        if (a > remaining + 0.01) return 'المبلغ يتجاوز المتبقي (${remaining.formattedFull})';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SheetDropdown<String>(
                      label: 'المحفظة / الخزينة المستلمة',
                      labelAbove: true,
                      value: walletId,
                      items: provider.wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                      onChanged: (v) => setSheetState(() => walletId = v),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date), style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'ملاحظة التحصيل',
                        prefixIcon: Icon(Icons.notes, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final amount = tryParseFlexible(amountController.text) ?? 0;
                          final payment = IncomePayment(
                            id: const Uuid().v4(),
                            incomeId: income.id,
                            amount: amount,
                            date: date,
                            notes: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                          );
                          provider.addIncomePayment(payment);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم تحصيل مبلغ ${amount.formattedFull} ر.ي بنجاح'),
                              backgroundColor: AppTheme.incomeGreen,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.incomeGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('تأكيد التحصيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // نافذة الإضافة والتعديل المطورة لسجل العمل
  void _showForm(
    BuildContext context,
    FinanceProvider provider, {
    WorkRecord? existing,
    String? initialPlotId,
    DateTime? initialStart,
    DateTime? initialEnd,
    double? initialRate,
    String? initialNote,
  }) {
    final formKey = GlobalKey<FormState>();
    String? landPlotId = existing?.landPlotId ?? initialPlotId;
    DateTime selectedDate = existing?.startTime ?? initialStart ?? DateTime.now();

    TimeOfDay startTime;
    if (existing != null) {
      startTime = TimeOfDay(hour: existing.startTime.hour, minute: existing.startTime.minute);
    } else if (initialStart != null) {
      startTime = TimeOfDay(hour: initialStart.hour, minute: initialStart.minute);
    } else {
      final last = provider.lastWorkEndOn(selectedDate);
      if (last != null) {
        final next = last.add(const Duration(minutes: 1));
        startTime = TimeOfDay(hour: next.hour, minute: next.minute);
      } else {
        startTime = const TimeOfDay(hour: 8, minute: 0);
      }
    }

    TimeOfDay endTime;
    if (existing != null) {
      endTime = TimeOfDay(hour: existing.endTime.hour, minute: existing.endTime.minute);
    } else if (initialEnd != null) {
      endTime = TimeOfDay(hour: initialEnd.hour, minute: initialEnd.minute);
    } else {
      endTime = TimeOfDay(hour: (startTime.hour + 1) % 24, minute: startTime.minute);
    }

    final noteController = TextEditingController(text: existing?.note ?? initialNote ?? '');
    final rateController = TextEditingController(
      text: existing?.hourlyRate?.toString() ?? initialRate?.toString() ?? '1000',
    );

    String? walletId;
    if (existing?.incomeId != null) {
      final inc = provider.incomes.firstWhereOrNull((i) => i.id == existing!.incomeId);
      walletId = inc?.walletId;
    }
    if (walletId == null && provider.wallets.isNotEmpty) {
      walletId = provider.defaultWallet()?.id ?? provider.wallets.first.id;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          int calculateDuration() {
            final s = DateTime(2024, 1, 1, startTime.hour, startTime.minute);
            var e = DateTime(2024, 1, 1, endTime.hour, endTime.minute);
            if (e.isBefore(s)) e = e.add(const Duration(days: 1));
            return e.difference(s).inMinutes;
          }

          void applyQuickDuration(int minutes) {
            final s = DateTime(2024, 1, 1, startTime.hour, startTime.minute);
            final e = s.add(Duration(minutes: minutes));
            setSheetState(() {
              endTime = TimeOfDay(hour: e.hour, minute: e.minute);
            });
          }

          final selectedPlot = provider.landPlots.firstWhereOrNull((p) => p.id == landPlotId);
          final isBillable = selectedPlot?.category == 'partnered' || selectedPlot?.category == 'client';

          double estimatedAmount = 0.0;
          if (isBillable) {
            final rate = double.tryParse(rateController.text.trim()) ?? 0.0;
            estimatedAmount = rate * (calculateDuration() / 60.0);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(
                          existing == null ? Icons.add_alarm_rounded : Icons.edit_calendar_rounded,
                          color: AppTheme.accentBlue,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          existing == null ? 'إضافة سجل عمل وري' : 'تعديل سجل العمل',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SheetDropdown<String>(
                      label: 'الموضع / الأرض',
                      labelAbove: true,
                      error: landPlotId == null,
                      hint: 'اختر الموضع',
                      value: landPlotId,
                      items: provider.landPlots.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (${landPlotCategoryLabel(p.category)})'),
                        );
                      }).toList(),
                      onChanged: (v) => setSheetState(() => landPlotId = v),
                    ),
                    const SizedBox(height: 12),
                    Text('التاريخ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (ctx, child) => Theme(
                            data: AppTheme.theme.copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: AppTheme.accentBlue,
                                surface: AppTheme.card,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) {
                          setSheetState(() {
                            selectedDate = d;
                            if (existing == null && initialStart == null) {
                              final last = provider.lastWorkEndOn(d);
                              if (last != null) {
                                final next = last.add(const Duration(minutes: 1));
                                startTime = TimeOfDay(hour: next.hour, minute: next.minute);
                                endTime = TimeOfDay(hour: (next.hour + 1) % 24, minute: next.minute);
                              }
                            }
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 18),
                            const SizedBox(width: 10),
                            Text(DateFormat('EEEE، dd MMMM yyyy', 'ar').format(selectedDate),
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _timePicker(context, 'وقت البداية', startTime, (t) {
                            setSheetState(() {
                              startTime = t;
                              if (existing == null && initialEnd == null) {
                                endTime = TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);
                              }
                            });
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _timePicker(context, 'وقت النهاية', endTime, (t) {
                            setSheetState(() => endTime = t);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // أزرار المدة السريعة
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Text('مدة سريعة: ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          _quickDurationChip('+30 د', () => applyQuickDuration(30)),
                          const SizedBox(width: 6),
                          _quickDurationChip('+ساعة', () => applyQuickDuration(60)),
                          const SizedBox(width: 6),
                          _quickDurationChip('+ساعتان', () => applyQuickDuration(120)),
                          const SizedBox(width: 6),
                          _quickDurationChip('+3 ساعات', () => applyQuickDuration(180)),
                          const SizedBox(width: 6),
                          _quickDurationChip('+4 ساعات', () => applyQuickDuration(240)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // عرض إجمالي الوقت
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlueDim,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time_filled, color: AppTheme.accentBlue, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'إجمالي الوقت: ${_formatToHrsMins(calculateDuration())}',
                            style: TextStyle(
                              color: AppTheme.accentBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isBillable) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'سعر الساعة (ر.ي) *',
                          hintText: '1000',
                          prefixIcon: Icon(Icons.attach_money, color: AppTheme.incomeGreen),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        validator: (v) {
                          if (isBillable) {
                            if (v == null || v.isEmpty) return 'أدخل سعر الساعة';
                            if (double.tryParse(v) == null) return 'قيمة غير صحيحة';
                            if (double.parse(v) <= 0) return 'يجب أن يكون أكبر من صفر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SheetDropdown<String>(
                        label: 'المحفظة المستهدفة للإيراد *',
                        labelAbove: true,
                        hint: 'اختر المحفظة',
                        value: walletId,
                        items: provider.wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                        onChanged: (v) => setSheetState(() => walletId = v),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.incomeGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('إجمالي قيمة الفاتورة المتوقعة:',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            Text(
                              '${estimatedAmount.formattedFull} ر.ي',
                              style: TextStyle(
                                color: AppTheme.incomeGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      maxLines: 2,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات وتفاصيل',
                        hintText: 'أي ملاحظات خاصة بري هذا اليوم...',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final lid = landPlotId;
                          if (lid == null) {
                            _showError(context, 'تعذر الحفظ', 'اختر الموضع أولاً');
                            return;
                          }
                          if (isBillable && walletId == null) {
                            _showError(context, 'تعذر الحفظ', 'اختر المحفظة لربط الفاتورة بها');
                            return;
                          }

                          final now = DateTime.now();
                          final fStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
                          var fEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);
                          if (fEnd.isBefore(fStart)) fEnd = fEnd.add(const Duration(days: 1));

                          if (fStart.isAfter(now.add(const Duration(minutes: 5)))) {
                            _showError(context, 'تعذر الحفظ', 'وقت البداية في المستقبل!');
                            return;
                          }

                          final durationMins = fEnd.difference(fStart).inMinutes;
                          if (durationMins <= 0) {
                            _showError(context, 'تعذر الحفظ', 'وقت النهاية يجب أن يكون بعد وقت البداية');
                            return;
                          }

                          final durationHrs = durationMins / 60.0;
                          final rate = isBillable ? (double.tryParse(rateController.text.trim()) ?? 0.0) : 0.0;
                          final totalAmt = rate * durationHrs;

                          String? incomeId = existing?.incomeId;

                          if (isBillable) {
                            final incomeTitle = 'مبيعات مياه - ${selectedPlot?.name ?? ''} (${durationHrs.toStringAsFixed(1)} س)';
                            if (incomeId != null) {
                              final existingInc = provider.incomes.firstWhereOrNull((i) => i.id == incomeId);
                              if (existingInc != null) {
                                existingInc.title = incomeTitle;
                                existingInc.amount = totalAmt;
                                existingInc.date = fStart;
                                existingInc.landPlotId = lid;
                                existingInc.walletId = walletId;
                                provider.updateIncome(existingInc);
                              } else {
                                final newInc = Income(
                                  id: const Uuid().v4(),
                                  title: incomeTitle,
                                  amount: totalAmt,
                                  date: fStart,
                                  source: 'مبيعات مياه',
                                  landPlotId: lid,
                                  walletId: walletId,
                                  status: 'pending',
                                );
                                provider.addIncome(newInc);
                                incomeId = newInc.id;
                              }
                            } else {
                              final newInc = Income(
                                id: const Uuid().v4(),
                                title: incomeTitle,
                                amount: totalAmt,
                                date: fStart,
                                source: 'مبيعات مياه',
                                landPlotId: lid,
                                walletId: walletId,
                                status: 'pending',
                              );
                              provider.addIncome(newInc);
                              incomeId = newInc.id;
                            }
                          } else {
                            if (incomeId != null) {
                              provider.deleteIncome(incomeId);
                              incomeId = null;
                            }
                          }

                          final draft = WorkRecord(
                            id: existing?.id ?? const Uuid().v4(),
                            landPlotId: lid,
                            startTime: fStart,
                            endTime: fEnd,
                            note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                            hourlyRate: isBillable ? rate : null,
                            incomeId: incomeId,
                          );

                          if (provider.workRecordOverlaps(draft, excludeId: existing?.id)) {
                            _showError(context, 'تعذر الحفظ', 'يوجد سجل عمل آخر في وقت متداخل مع هذا السجل');
                            return;
                          }

                          if (existing != null) {
                            provider.updateWorkRecord(draft);
                          } else {
                            provider.addWorkRecord(draft);
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(existing == null ? 'حفظ السجل' : 'تحديث السجل', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _quickDurationChip(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Text(
          text,
          style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _timePicker(BuildContext context, String title, TimeOfDay time, ValueChanged<TimeOfDay> onPicked) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPicked(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: AppTheme.textSecondary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  Text(
                    _formatTimeWithAmPm(DateTime(2024, 1, 1, time.hour, time.minute)),
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatToHrsMins(int totalMinutes) {
    int hrs = totalMinutes ~/ 60;
    int mins = totalMinutes % 60;
    if (hrs > 0 && mins > 0) return '$hrs س $mins د';
    if (hrs > 0) return '$hrs س';
    return '$mins د';
  }

  String _formatTimeWithAmPm(DateTime dateTime) {
    String formatted = DateFormat('hh:mm', 'ar').format(dateTime);
    String amPm = dateTime.hour >= 12 ? 'م' : 'ص';
    return '$formatted $amPm';
  }

  void _showError(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: AppTheme.expenseRed)),
        content: Text(message, style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('حسناً', style: TextStyle(color: AppTheme.accentBlue)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider, WorkRecord r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف السجل', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'هل تريد حذف هذا السجل نهائياً؟ سيتم أيضاً حذف فاتورة الإيراد المرتبطة به إن وجدت.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.deleteWorkRecord(r.id);
              Navigator.pop(context);
            },
            child: Text('حذف', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
