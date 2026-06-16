import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/distance_option.dart';
import '../models/trip_record.dart';
import '../database/hive_database.dart';
import '../providers/app_state_provider.dart';
import '../services/csv_export_service.dart';
import '../services/file_share_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/rounds_dialog.dart';
import '../core/theme_extensions.dart';

class TripFeePage extends StatefulWidget {
  const TripFeePage({super.key});

  @override
  State<TripFeePage> createState() => _TripFeePageState();
}

class _TripFeePageState extends State<TripFeePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const List<DistanceOption> _options = [
    DistanceOption(label: 'ระยะทาง 0-300 เมตร', rateBaht: 5),
    DistanceOption(label: 'ระยะทาง 301-500 เมตร', rateBaht: 10),
    DistanceOption(label: 'ระยะทาง 501 เมตร - 3 กิโลเมตร', rateBaht: 15),
    DistanceOption(label: 'ระยะทาง มากกว่า 3 กิโลเมตร', rateBaht: 25),
  ];

  List<TripRecord> _selectedDateRecords = [];
  List<_DailyTripSummary> _dailySummaries = [];
  List<_PeriodSummary> _weeklySummaries = [];
  List<_PeriodSummary> _monthlySummaries = [];
  DateTime _selectedDate = DateTime.now();
  int _selectedDateTotal = 0;
  int _selectedDateRounds = 0;

  // Memoization: skip recompute when trips list hasn't changed
  List<TripRecord>? _lastComputedTrips;

  List<_PeriodSummary> _buildPeriodSummaries(
    List<TripRecord> trips,
    DateTime Function(DateTime) keyFn,
  ) {
    final grouped = <DateTime, List<TripRecord>>{};
    for (final record in trips) {
      final key = keyFn(record.createdAt);
      grouped.putIfAbsent(key, () => []).add(record);
    }
    final summaries = grouped.entries.map((entry) {
      final records = entry.value;
      return _PeriodSummary(
        periodStart: entry.key,
        totalBaht: records.fold<int>(0, (t, r) => t + r.totalBaht),
        totalRounds: records.fold<int>(0, (t, r) => t + r.rounds),
        recordCount: records.length,
      );
    }).toList()..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return summaries;
  }

  List<_DailyTripSummary> _buildDailySummaries(List<TripRecord> trips) {
    final summariesByDate = <DateTime, List<TripRecord>>{};

    for (final record in trips) {
      final date = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );
      summariesByDate.putIfAbsent(date, () => []).add(record);
    }

    final summaries = summariesByDate.entries.map((entry) {
      final records = entry.value;
      return _DailyTripSummary(
        date: entry.key,
        totalBaht: records.fold<int>(
          0,
          (total, record) => total + record.totalBaht,
        ),
        totalRounds: records.fold<int>(
          0,
          (total, record) => total + record.rounds,
        ),
        recordCount: records.length,
      );
    }).toList();

    summaries.sort((a, b) => b.date.compareTo(a.date));
    return summaries;
  }

  void _refreshDerivedData(List<TripRecord> trips) {
    // Skip expensive recalculation if the trips list hasn't changed
    if (identical(trips, _lastComputedTrips)) return;
    _lastComputedTrips = trips;

    final selectedDateRecords = <TripRecord>[];
    var selectedDateTotal = 0;
    var selectedDateRounds = 0;

    for (final record in trips) {
      if (record.isSameDay(_selectedDate)) {
        selectedDateRecords.add(record);
        selectedDateTotal += record.totalBaht;
        selectedDateRounds += record.rounds;
      }
    }

    _selectedDateRecords = selectedDateRecords;
    _selectedDateTotal = selectedDateTotal;
    _selectedDateRounds = selectedDateRounds;
    _dailySummaries = _buildDailySummaries(trips);
    _weeklySummaries = _buildPeriodSummaries(trips, (date) {
      final weekStart = date.subtract(Duration(days: date.weekday % 7));
      return DateTime(weekStart.year, weekStart.month, weekStart.day);
    });
    _monthlySummaries = _buildPeriodSummaries(trips,
      (date) => DateTime(date.year, date.month),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _logInstantTrip(DistanceOption option) async {
    final now = DateTime.now();
    final createdAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    final record = TripRecord(
      distanceLabel: option.label,
      rateBaht: option.rateBaht,
      rounds: 1,
      createdAt: createdAt,
    );

    try {
      final insertedId = await appDatabase.insertTrip(record);
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกสำเร็จ: ${option.label} (1 รอบ)'),
          action: SnackBarAction(
            label: 'เลิกทำ',
            onPressed: () async {
              try {
                await appDatabase.deleteTrip(insertedId);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เกิดข้อผิดพลาดในการเลิกทำ: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _logCustomTrip(DistanceOption option) async {
    final rounds = await showDialog<int>(
      context: context,
      builder: (context) => const RoundsDialog(),
    );

    if (rounds == null) return;

    final now = DateTime.now();
    final createdAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    final record = TripRecord(
      distanceLabel: option.label,
      rateBaht: option.rateBaht,
      rounds: rounds,
      createdAt: createdAt,
    );

    try {
      await appDatabase.insertTrip(record);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _editRecord(TripRecord record) async {
    final newRounds = await showDialog<int>(
      context: context,
      builder: (context) => RoundsDialog(initialRounds: record.rounds),
    );

    if (newRounds == null || newRounds == record.rounds) return;

    final updated = TripRecord(
      id: record.id,
      distanceLabel: record.distanceLabel,
      rateBaht: record.rateBaht,
      rounds: newRounds,
      createdAt: record.createdAt,
    );

    try {
      await appDatabase.updateTrip(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _deleteRecord(TripRecord record) async {
    final confirmed = await confirmDelete(
      context,
      'ลบรายการนี้?',
      '${record.distanceLabel} • ${record.rounds} รอบ (${record.totalBaht} บาท)',
    );
    if (!confirmed) return;

    if (record.id != null) {
      try {
        await appDatabase.deleteTrip(record.id!);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _exportCsv(List<TripRecord> trips) async {
    if (trips.isEmpty) return;

    final selectedOption = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'เลือกช่วงเวลาส่งออก CSV',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('ทุกรายการ (ทั้งหมด)'),
                onTap: () => Navigator.pop(context, 'all'),
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('เฉพาะวันนี้'),
                onTap: () => Navigator.pop(context, 'today'),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('สัปดาห์นี้'),
                onTap: () => Navigator.pop(context, 'week'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('เดือนนี้'),
                onTap: () => Navigator.pop(context, 'month'),
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('เลือกช่วงวันที่กำหนดเอง...'),
                onTap: () => Navigator.pop(context, 'custom'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedOption == null) return;

    List<TripRecord> filteredTrips = [];
    String dateRangeLabel = 'all';

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    if (selectedOption == 'all') {
      filteredTrips = trips;
      dateRangeLabel = 'all';
    } else if (selectedOption == 'today') {
      filteredTrips = trips
          .where((t) =>
              t.createdAt.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
              t.createdAt.isBefore(todayEnd))
          .toList();
      dateRangeLabel = DateFormat('yyyy-MM-dd').format(now);
    } else if (selectedOption == 'week') {
      final weekday = now.weekday;
      final weekStart = todayStart.subtract(Duration(days: weekday - 1));
      filteredTrips = trips
          .where((t) =>
              t.createdAt.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
              t.createdAt.isBefore(todayEnd))
          .toList();
      dateRangeLabel =
          'week_${DateFormat('yyyy-MM-dd').format(weekStart)}_to_${DateFormat('yyyy-MM-dd').format(now)}';
    } else if (selectedOption == 'month') {
      final monthStart = DateTime(now.year, now.month, 1);
      filteredTrips = trips
          .where((t) =>
              t.createdAt.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              t.createdAt.isBefore(todayEnd))
          .toList();
      dateRangeLabel = 'month_${DateFormat('yyyy-MM').format(now)}';
    } else if (selectedOption == 'custom') {
      if (!mounted) return;
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        locale: const Locale('th', 'TH'),
      );
      if (pickedRange == null) return;
      final start = DateTime(pickedRange.start.year, pickedRange.start.month, pickedRange.start.day);
      final end = DateTime(
          pickedRange.end.year, pickedRange.end.month, pickedRange.end.day, 23, 59, 59, 999);
      filteredTrips = trips
          .where((t) =>
              t.createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              t.createdAt.isBefore(end))
          .toList();
      dateRangeLabel =
          'custom_${DateFormat('yyyy-MM-dd').format(start)}_to_${DateFormat('yyyy-MM-dd').format(end)}';
    }

    if (filteredTrips.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบรายการในช่วงเวลาที่เลือก'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final csv = CsvExportService.exportTripRecords(filteredTrips);
    final filename = 'loscheck_trips_$dateRangeLabel.csv';

    try {
      await FileShareService.shareOrDownloadText(
        filename: filename,
        content: csv,
        mimeType: 'text/csv',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งออกไฟล์: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearSelectedDate() async {
    final confirmed = await confirmDelete(
      context,
      'ล้างรายการของวันที่เลือกทั้งหมด?',
      'รวม $_selectedDateRounds รอบ ($_selectedDateTotal บาท)',
    );
    if (!confirmed) return;

    try {
      await appDatabase.deleteTripsByDate(_selectedDate);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    try {
      final appState = Provider.of<AppStateProvider>(context);
      return _buildContent(context, appState);
    } catch (_) {
      return ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: Consumer<AppStateProvider>(
          builder: (context, appState, _) => _buildContent(context, appState),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context, AppStateProvider appState) {
    final trips = appState.trips;
    
    if (appState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    _refreshDerivedData(trips);
    final selectedRecords = _selectedDateRecords;
    final dailySummaries = _dailySummaries;
    final weeklySummaries = _weeklySummaries;
    final monthlySummaries = _monthlySummaries;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 1,
              child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.edit_note),
                    text: 'บันทึกค่ารอบ',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics_outlined),
                    text: 'สรุปและรายงาน',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLogTripTab(context, trips, selectedRecords),
                  _buildReportsTab(context, dailySummaries, weeklySummaries, monthlySummaries),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTripTab(
    BuildContext context,
    List<TripRecord> trips,
    List<TripRecord> selectedRecords,
  ) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: EdgeInsets.all(
            isSmallScreen ? 10 : 20,
          ),
          child: CustomScrollView(
            slivers: [
              if (appDatabase.isUsingInMemory)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.isDarkMode 
                        ? Colors.amber.shade900.withOpacity(0.2)
                        : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade700,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: Colors.amber.shade800),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'โหมดออฟไลน์ (In-Memory)',
                                style: TextStyle(
                                  color: context.isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ข้อมูลจะไม่ถูกบันทึกลงเครื่องถาวร กรุณาอย่าปิดบราวเซอร์',
                                style: TextStyle(
                                  color: context.isDarkMode ? Colors.amber.shade100 : Colors.amber.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _SummaryPanel(
                  totalBaht: _selectedDateTotal,
                  totalRounds: _selectedDateRounds,
                  canClear: selectedRecords.isNotEmpty,
                  canExport: trips.isNotEmpty,
                  onClear: _clearSelectedDate,
                  onExport: () => _exportCsv(trips),
                  dateLabel: _DailySummaryTile._formatDate(
                    _selectedDate,
                  ),
                  onSelectDate: _selectDate,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 16 : 28)),
              SliverToBoxAdapter(
                child: Text(
                  'เพิ่มค่ารอบ',
                  style: (isSmallScreen 
                      ? Theme.of(context).textTheme.titleMedium 
                      : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 8 : 16)),
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio:
                      MediaQuery.sizeOf(context).width > 600
                      ? 1.3
                      : (isSmallScreen ? 1.25 : 1.2),
                  crossAxisSpacing: isSmallScreen ? 6 : 8,
                  mainAxisSpacing: isSmallScreen ? 6 : 8,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final option = _options[index];
                  return _DistanceActionCard(
                    option: option,
                    onTap: () => _logInstantTrip(option),
                    onEdit: () => _logCustomTrip(option),
                  );
                }, childCount: _options.length),
              ),
              SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 18 : 32)),
              SliverToBoxAdapter(
                child: Text(
                  'ประวัติ ${_DailySummaryTile._formatDate(_selectedDate)}',
                  style: (isSmallScreen 
                      ? Theme.of(context).textTheme.titleMedium 
                      : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 8 : 12)),
              if (selectedRecords.isEmpty)
                SliverToBoxAdapter(
                  child: emptyState(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'ยังไม่มีรายการในวันนี้',
                    message: 'เพิ่มรายการเดินทางใหม่เพื่อดูรายละเอียด',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((
                    context,
                    index,
                  ) {
                    final record = selectedRecords[index];
                    return _RecordTile(
                      record: record,
                      onEdit: () => _editRecord(record),
                      onDelete: () => _deleteRecord(record),
                    );
                  }, childCount: selectedRecords.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab(
    BuildContext context,
    List<_DailyTripSummary> dailySummaries,
    List<_PeriodSummary> weeklySummaries,
    List<_PeriodSummary> monthlySummaries,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 380 ? 12 : 20,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Text(
                  'สรุปรายวัน',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (dailySummaries.isEmpty)
                SliverToBoxAdapter(
                  child: emptyState(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: 'ยังไม่มีสรุปรายวัน',
                    message: 'เพิ่มรายการเดินทางเพื่อดูสรุปแบบรายวัน',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((
                    context,
                    index,
                  ) {
                    return _DailySummaryTile(
                      summary: dailySummaries[index],
                    );
                  }, childCount: dailySummaries.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              SliverToBoxAdapter(
                child: Text(
                  'สรุปรายสัปดาห์',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (weeklySummaries.isEmpty)
                SliverToBoxAdapter(
                  child: emptyState(
                    context,
                    icon: Icons.date_range_outlined,
                    title: 'ยังไม่มีสรุปรายสัปดาห์',
                    message: 'เพิ่มรายการเดินทางเพื่อดูสรุปแบบรายสัปดาห์',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((
                    context,
                    index,
                  ) {
                    return _PeriodSummaryTile(
                      summary: weeklySummaries[index],
                      formatLabel: _formatWeekLabel,
                    );
                  }, childCount: weeklySummaries.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              SliverToBoxAdapter(
                child: Text(
                  'สรุปรายเดือน',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (monthlySummaries.isEmpty)
                SliverToBoxAdapter(
                  child: emptyState(
                    context,
                    icon: Icons.calendar_month_outlined,
                    title: 'ยังไม่มีสรุปรายเดือน',
                    message: 'เพิ่มรายการเดินทางเพื่อดูสรุปแบบรายเดือน',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((
                    context,
                    index,
                  ) {
                    return _PeriodSummaryTile(
                      summary: monthlySummaries[index],
                      formatLabel: _formatMonthLabel,
                    );
                  }, childCount: monthlySummaries.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistanceActionCard extends StatelessWidget {
  const _DistanceActionCard({
    required this.option,
    required this.onTap,
    required this.onEdit,
  });

  final DistanceOption option;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  IconData _getDistanceIcon(String label) {
    if (label.contains('0-300')) {
      return Icons.directions_walk;
    } else if (label.contains('301-500')) {
      return Icons.motorcycle;
    } else if (label.contains('501')) {
      return Icons.directions_car;
    } else {
      return Icons.local_shipping;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: isSmallScreen ? 3 : 4,
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                left: isSmallScreen ? 4 : 6,
                right: isSmallScreen ? 4 : 6,
                top: isSmallScreen ? 12 : 16,
                bottom: isSmallScreen ? 6 : 8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getDistanceIcon(option.label),
                    size: isSmallScreen ? 20 : 26,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Text(
                        option.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: (isSmallScreen 
                            ? Theme.of(context).textTheme.bodySmall 
                            : Theme.of(context).textTheme.bodyMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 2 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 10 : 12,
                      vertical: isSmallScreen ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${option.rateBaht} ฿',
                      style: (isSmallScreen 
                          ? Theme.of(context).textTheme.bodyMedium 
                          : Theme.of(context).textTheme.titleSmall)
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: Icon(
                Icons.edit_note,
                size: isSmallScreen ? 18 : 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onEdit,
              tooltip: 'ระบุจำนวนรอบ',
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: isSmallScreen ? const Size(28, 28) : const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTripSummary {
  const _DailyTripSummary({
    required this.date,
    required this.totalBaht,
    required this.totalRounds,
    required this.recordCount,
  });

  final DateTime date;
  final int totalBaht;
  final int totalRounds;
  final int recordCount;
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.totalBaht,
    required this.totalRounds,
    required this.canClear,
    required this.canExport,
    required this.onClear,
    required this.onExport,
    required this.dateLabel,
    required this.onSelectDate,
  });

  final int totalBaht;
  final int totalRounds;
  final bool canClear;
  final bool canExport;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final String dateLabel;
  final VoidCallback onSelectDate;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;
    final isCompact = screenWidth < 600;

    final actionButtons = [
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent.shade100,
          side: BorderSide(color: Colors.redAccent.shade100, width: 1.5),
          padding: isSmallScreen 
              ? const EdgeInsets.symmetric(vertical: 8, horizontal: 10)
              : null,
          textStyle: isSmallScreen 
              ? const TextStyle(fontSize: 12, fontWeight: FontWeight.bold) 
              : const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: canClear ? onClear : null,
        icon: Icon(
          Icons.delete_sweep_outlined,
          size: isSmallScreen ? 16 : null,
        ),
        label: const Text('ล้างข้อมูล'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.teal.shade800,
          padding: isSmallScreen 
              ? const EdgeInsets.symmetric(vertical: 8, horizontal: 10)
              : null,
          textStyle: isSmallScreen ? const TextStyle(fontSize: 12) : null,
        ),
        onPressed: canExport ? onExport : null,
        icon: Icon(
          Icons.file_download_outlined,
          size: isSmallScreen ? 16 : null,
        ),
        label: const Text('Export CSV'),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : (isCompact ? 16 : 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ยอดรวม $dateLabel',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (isSmallScreen 
                        ? Theme.of(context).textTheme.titleMedium 
                        : Theme.of(context).textTheme.titleLarge)
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                ),
                IconButton(
                  iconSize: isSmallScreen ? 20 : 24,
                  icon: const Icon(Icons.edit_calendar, color: Colors.white),
                  onPressed: onSelectDate,
                  tooltip: 'เลือกวันที่',
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              '$totalBaht ฿',
              textAlign: TextAlign.center,
              style: (isSmallScreen 
                      ? Theme.of(context).textTheme.headlineMedium 
                      : (isCompact 
                          ? Theme.of(context).textTheme.headlineLarge 
                          : Theme.of(context).textTheme.displayMedium))
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
            ),
            const SizedBox(height: 4),
            Text(
              'รวม $totalRounds รอบ',
              textAlign: TextAlign.center,
              style: (isSmallScreen 
                  ? Theme.of(context).textTheme.bodyMedium 
                  : Theme.of(context).textTheme.titleMedium)
                  ?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 24),
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  actionButtons[0],
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  actionButtons[1],
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: actionButtons[0]),
                  const SizedBox(width: 12),
                  Expanded(child: actionButtons[1]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DailySummaryTile extends StatelessWidget {
  const _DailySummaryTile({required this.summary});

  final _DailyTripSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(_formatDate(summary.date)),
        subtitle: Text(
          'รวม ${summary.totalRounds} รอบ • ${summary.recordCount} รายการ',
        ),
        trailing: Text(
          '${summary.totalBaht} บาท',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return 'วันนี้ (${_formatNumericDate(date)})';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (target == yesterday) {
      return 'เมื่อวาน (${_formatNumericDate(date)})';
    }

    return _formatNumericDate(date);
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final TripRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final totalText = '${record.totalBaht} บาท';

    final Color leadingColor = switch (record.distanceLabel) {
      'ระยะทาง 0-300 เมตร' => Colors.blue.shade400,
      'ระยะทาง 301-500 เมตร' => Colors.green.shade400,
      'ระยะทาง 501 เมตร - 3 กิโลเมตร' => Colors.orange.shade400,
      'ระยะทาง มากกว่า 3 กิโลเมตร' => Colors.red.shade400,
      _ => Colors.grey.shade400,
    };

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: leadingColor,
              width: 6,
            ),
          ),
        ),
        child: ListTile(
          title: Text(record.distanceLabel),
          subtitle: Text(
            isCompact
                ? '${record.rounds} รอบ x ${record.rateBaht} บาทต่อบิล • ${_formatTime(record.createdAt)}\n$totalText'
                : '${record.rounds} รอบ x ${record.rateBaht} บาทต่อบิล • ${_formatTime(record.createdAt)}',
          ),
          trailing: isCompact
              ? PopupMenuButton<_RecordAction>(
                  tooltip: 'เมนูรายการ',
                  onSelected: (action) {
                    switch (action) {
                      case _RecordAction.edit:
                        onEdit();
                      case _RecordAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _RecordAction.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('แก้ไข'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _RecordAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('ลบ'),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'แก้ไขจำนวนรอบ',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'ลบรายการ',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute น.';
  }
}

enum _RecordAction { edit, delete }

String _formatNumericDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class _PeriodSummary {
  const _PeriodSummary({
    required this.periodStart,
    required this.totalBaht,
    required this.totalRounds,
    required this.recordCount,
  });

  final DateTime periodStart;
  final int totalBaht;
  final int totalRounds;
  final int recordCount;
}

class _PeriodSummaryTile extends StatelessWidget {
  const _PeriodSummaryTile({required this.summary, required this.formatLabel});

  final _PeriodSummary summary;
  final String Function(DateTime) formatLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bar_chart_outlined),
        title: Text(formatLabel(summary.periodStart)),
        subtitle: Text(
          'รวม ${summary.totalRounds} รอบ • ${summary.recordCount} รายการ',
        ),
        trailing: Text(
          '${summary.totalBaht} บาท',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

const List<String> _thaiMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

String _formatWeekLabel(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  return '${_formatNumericDate(weekStart)} - ${_formatNumericDate(weekEnd)}';
}

String _formatMonthLabel(DateTime monthStart) {
  return '${_thaiMonths[monthStart.month - 1]} ${monthStart.year}';
}
