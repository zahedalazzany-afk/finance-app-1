import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'manage_events_screen.dart';
import 'agricultural_events_screen.dart';

enum AgriEventTypeFilter { all, irrigation, spraying, others }

class AgriculturalCalendarScreen extends StatefulWidget {
  final String? initialPlotId;
  const AgriculturalCalendarScreen({super.key, this.initialPlotId});

  @override
  State<AgriculturalCalendarScreen> createState() => _AgriculturalCalendarScreenState();
}

class _AgriculturalCalendarScreenState extends State<AgriculturalCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  String? _selectedPlotId;
  AgriEventTypeFilter _filter = AgriEventTypeFilter.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _selectedPlotId = widget.initialPlotId;
  }

  bool _isIrrigation(String type) {
    final t = type.trim();
    return t.contains('سقي') || t.contains('ري') || t.contains('ماء');
  }

  bool _isSpraying(String type) {
    final t = type.trim();
    return t.contains('رش') || t.contains('مبيد') || t.contains('تسميد') || t.contains('مكافحة');
  }

  bool _matchesFilter(LandEvent event) {
    if (_selectedPlotId != null && event.landPlotId != _selectedPlotId) return false;
    switch (_filter) {
      case AgriEventTypeFilter.all:
        return true;
      case AgriEventTypeFilter.irrigation:
        return _isIrrigation(event.eventType);
      case AgriEventTypeFilter.spraying:
        return _isSpraying(event.eventType);
      case AgriEventTypeFilter.others:
        return !_isIrrigation(event.eventType) && !_isSpraying(event.eventType);
    }
  }

  List<LandEvent> _eventsForMonth(List<LandEvent> allEvents) {
    return allEvents.where((e) {
      if (e.date.year != _focusedMonth.year || e.date.month != _focusedMonth.month) {
        return false;
      }
      return _matchesFilter(e);
    }).toList();
  }

  List<LandEvent> _eventsForDay(DateTime day, List<LandEvent> allEvents) {
    return allEvents.where((e) {
      final isSameDay = e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day;
      return isSameDay && _matchesFilter(e);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dynamicScaffoldBg,
      appBar: AppBar(
        title: const Text('التقويم الزراعي (ري ورش)'),
        actions: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: Icon(Icons.today, size: 18, color: AppTheme.accentBlue),
            label: Text('اليوم',
                style: TextStyle(
                    color: AppTheme.accentBlue, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final allEvents = provider.landEvents;
          final monthEvents = _eventsForMonth(allEvents);
          final dayEvents = _eventsForDay(_selectedDay, allEvents);

          final irrigationCount =
              monthEvents.where((e) => _isIrrigation(e.eventType)).length;
          final sprayingCount =
              monthEvents.where((e) => _isSpraying(e.eventType)).length;
          final monthTotalCost = monthEvents.fold(0.0, (sum, ev) {
            final expSum = provider
                .expensesForEvent(ev.id)
                .fold(0.0, (s, ex) => s + ex.amount);
            return sum + expSum;
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterBar(provider),
                const SizedBox(height: 12),
                _buildMonthSummaryCards(
                    irrigationCount, sprayingCount, monthTotalCost),
                const SizedBox(height: 16),
                _buildCalendarCard(allEvents),
                const SizedBox(height: 20),
                _buildDayAgenda(context, provider, dayEvents),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDialog(context, context.read<FinanceProvider>()),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('تسجيل عملية زراعية',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildFilterBar(FinanceProvider provider) {
    return Column(
      children: [
        // Land Plot Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedPlotId,
              isExpanded: true,
              icon: Icon(Icons.terrain, color: AppTheme.accentBlue, size: 20),
              hint: Text('جميع المواضع والأراضي',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('🌾 جميع المواضع والأراضي',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                ...provider.landPlots.map(
                  (plot) => DropdownMenuItem<String?>(
                    value: plot.id,
                    child: Text('🌱 ${plot.name}',
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13)),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedPlotId = val),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('الكل', AgriEventTypeFilter.all, Icons.grid_view),
              const SizedBox(width: 8),
              _filterChip('💧 سقي وري', AgriEventTypeFilter.irrigation,
                  Icons.water_drop, Colors.lightBlue),
              const SizedBox(width: 8),
              _filterChip('🧪 رش ومكافحة', AgriEventTypeFilter.spraying,
                  Icons.science, Colors.purpleAccent),
              const SizedBox(width: 8),
              _filterChip('🌿 عمليات أخرى', AgriEventTypeFilter.others,
                  Icons.eco, AppTheme.incomeGreen),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, AgriEventTypeFilter type, IconData icon,
      [Color? activeColor]) {
    final isSelected = _filter == type;
    final color = activeColor ?? AppTheme.accentBlue;
    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? color : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSummaryCards(
      int irrigationCount, int sprayingCount, double totalCost) {
    return Row(
      children: [
        _summaryCard(
          title: 'عمليات الري',
          value: '$irrigationCount',
          unit: 'مرة',
          icon: Icons.water_drop,
          color: Colors.lightBlue,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          title: 'عمليات الرش',
          value: '$sprayingCount',
          unit: 'مرة',
          icon: Icons.science,
          color: Colors.purpleAccent,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          title: 'تكاليف الشهر',
          value: totalCost.formatted,
          unit: 'ر.ي',
          icon: Icons.payments_outlined,
          color: AppTheme.incomeGreen,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(width: 3),
                Text(unit,
                    style:
                        TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(List<LandEvent> allEvents) {
    final monthName = DateFormat('MMMM yyyy', 'ar').format(_focusedMonth);

    // Days calculation
    final firstDayOfMonth = _focusedMonth;
    final lastDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    // Saturday = 6 in DateTime weekday (1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun)
    // We want week starting Saturday:
    // Sat=0, Sun=1, Mon=2, Tue=3, Wed=4, Thu=5, Fri=6
    int weekdayOffset(int weekday) {
      if (weekday == DateTime.saturday) return 0;
      if (weekday == DateTime.sunday) return 1;
      return weekday + 1; // Mon=2, Tue=3, Wed=4, Thu=5, Fri=6
    }

    final startOffset = weekdayOffset(firstDayOfMonth.weekday);
    final totalDays = lastDayOfMonth.day;
    final totalCells = ((startOffset + totalDays) / 7).ceil() * 7;

    const weekLabels = [
      'سبت',
      'أحد',
      'إثنين',
      'ثلاثاء',
      'أربعاء',
      'خميس',
      'جمعة'
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          // Month navigation bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: Icon(Icons.chevron_right,
                    color: AppTheme.textPrimary, size: 28),
                tooltip: 'الشهر السابق',
              ),
              Text(
                monthName,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: Icon(Icons.chevron_left,
                    color: AppTheme.textPrimary, size: 28),
                tooltip: 'الشهر التالي',
              ),
            ],
          ),
          Divider(color: AppTheme.cardBorder, height: 16),
          // Weekday header
          Row(
            children: weekLabels
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.05,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;
              if (dayNumber < 1 || dayNumber > totalDays) {
                return const SizedBox();
              }

              final date = DateTime(
                  _focusedMonth.year, _focusedMonth.month, dayNumber);
              final now = DateTime.now();
              final isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isSelected = date.year == _selectedDay.year &&
                  date.month == _selectedDay.month &&
                  date.day == _selectedDay.day;

              final dayEvs = _eventsForDay(date, allEvents);
              final hasIrrigation =
                  dayEvs.any((e) => _isIrrigation(e.eventType));
              final hasSpraying =
                  dayEvs.any((e) => _isSpraying(e.eventType));
              final hasOthers = dayEvs.any((e) =>
                  !_isIrrigation(e.eventType) && !_isSpraying(e.eventType));

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentBlue.withValues(alpha: 0.25)
                        : (isToday
                            ? AppTheme.surface
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentBlue
                          : (isToday
                              ? AppTheme.accentBlue.withValues(alpha: 0.4)
                              : Colors.transparent),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.accentBlue
                              : (isToday
                                  ? AppTheme.accentBlue
                                  : AppTheme.textPrimary),
                          fontWeight: (isSelected || isToday)
                              ? FontWeight.w800
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasIrrigation)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: Colors.lightBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasSpraying)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: Colors.purpleAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasOthers)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.incomeGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.lightBlue, 'سقي وري'),
              const SizedBox(width: 14),
              _legendDot(Colors.purpleAccent, 'رش ومكافحة'),
              const SizedBox(width: 14),
              _legendDot(AppTheme.incomeGreen, 'أخرى'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildDayAgenda(BuildContext context, FinanceProvider provider,
      List<LandEvent> dayEvents) {
    final formattedDay =
        DateFormat('EEEE، dd MMMM yyyy', 'ar').format(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('جدول عمليات اليوم المختار',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(formattedDay,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openAddDialog(context, provider,
                  initialDate: _selectedDay, initialPlotId: _selectedPlotId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlueDim,
                foregroundColor: AppTheme.accentBlue,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة عملية', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (dayEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available,
                    color: AppTheme.textMuted, size: 40),
                const SizedBox(height: 10),
                Text('لا توجد عمليات زراعية مجدولة في هذا اليوم',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Text('اضغط على "إضافة عملية" لتسجيل ري، رش أو عمل زراعي',
                    style:
                        TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          )
        else
          ...dayEvents.map((event) => _eventCard(context, provider, event)),
      ],
    );
  }

  Widget _eventCard(
      BuildContext context, FinanceProvider provider, LandEvent event) {
    final plot = provider.landPlots.firstWhereOrNull((p) => p.id == event.landPlotId);
    final isIrr = _isIrrigation(event.eventType);
    final isSpray = _isSpraying(event.eventType);

    final color = isIrr
        ? Colors.lightBlue
        : (isSpray ? Colors.purpleAccent : AppTheme.incomeGreen);
    final icon = isIrr
        ? Icons.water_drop
        : (isSpray ? Icons.science : Icons.agriculture);

    final eventExpenses = provider.expensesForEvent(event.id);
    final totalCost = eventExpenses.fold(0.0, (s, e) => s + e.amount);

    final consumptions = provider.inventoryTransactions
        .where((t) => t.eventId == event.id && t.type == 'out')
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => AgriculturalEventsScreen.showEventDetails(context, provider, event),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              event.eventType,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Text(
                                plot?.name ?? 'موضع غير محدد',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        if (event.notes != null && event.notes!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            event.notes!,
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (totalCost > 0)
                    Text(
                      '${totalCost.formatted} ر.ي',
                      style: TextStyle(
                          color: AppTheme.expenseRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                ],
              ),
              if (consumptions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: AppTheme.cardBorder, height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: consumptions.map((t) {
                    final item = provider.storageItems
                        .firstWhereOrNull((s) => s.id == t.itemId);
                    final itemName = item?.name ?? 'مادة';
                    final qtyText = item != null &&
                            item.isPackaged &&
                            item.packageSize != null
                        ? '${(t.quantity * item.packageSize!).formatted} ${item.usageUnit}'
                        : '${t.quantity.formatted} ${item?.unit ?? ''}';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medication_liquid_outlined,
                              size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '$itemName: $qtyText',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openAddDialog(BuildContext context, FinanceProvider provider,
      {DateTime? initialDate, String? initialPlotId}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              const SizedBox(height: 16),
              Text('تسجيل عملية زراعية سريعة',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('اختر نوع العملية للبدء في توثيقها',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.water_drop,
                      color: Colors.lightBlue, size: 22),
                ),
                title: Text('سقي المزروعات (ري)',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text('توثيق ري موضع مع ساعات العمل والعمالة',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  final foundType = provider.eventTypesList.firstWhereOrNull(
                          (t) => t.name.contains('ري') || t.name.contains('سقي'))
                      ?.name ??
                      'ري';
                  AgriculturalEventsScreen.showEventForm(
                    context,
                    provider,
                    initialDate: initialDate ?? _selectedDay,
                    initialPlotId: initialPlotId ?? _selectedPlotId,
                    initialType: foundType,
                  );
                },
              ),
              Divider(color: AppTheme.cardBorder, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.science,
                      color: Colors.purpleAccent, size: 22),
                ),
                title: Text('رش المبيدات والتسميد',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'توثيق رش مبيد حشري/فطري أو تسميد من المخزن',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  final foundType = provider.eventTypesList.firstWhereOrNull(
                          (t) =>
                              t.name.contains('رش') ||
                              t.name.contains('سماد') ||
                              t.name.contains('تسميد') ||
                              t.name.contains('مبيد'))
                      ?.name ??
                      'رش';
                  AgriculturalEventsScreen.showEventForm(
                    context,
                    provider,
                    initialDate: initialDate ?? _selectedDay,
                    initialPlotId: initialPlotId ?? _selectedPlotId,
                    initialType: foundType,
                  );
                },
              ),
              Divider(color: AppTheme.cardBorder, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.agriculture,
                      color: AppTheme.accentBlue, size: 22),
                ),
                title: Text('عمليات زراعية أخرى',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text('تقليم، حراثة، جني، قلب تربة وغيرها...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  final foundType = provider.eventTypesList.firstWhereOrNull(
                          (t) =>
                              !t.name.contains('ري') &&
                              !t.name.contains('سقي') &&
                              !t.name.contains('رش'))
                      ?.name ??
                      (provider.eventTypesList.isNotEmpty
                          ? provider.eventTypesList.first.name
                          : 'أخرى');
                  AgriculturalEventsScreen.showEventForm(
                    context,
                    provider,
                    initialDate: initialDate ?? _selectedDay,
                    initialPlotId: initialPlotId ?? _selectedPlotId,
                    initialType: foundType,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
