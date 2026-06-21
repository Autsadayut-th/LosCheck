import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../widgets/edit_trip_record_dialog.dart';
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

  // Memoization: skip recompute when trips list and selected date haven't changed
  List<TripRecord>? _lastComputedTrips;
  DateTime? _lastComputedSelectedDate;

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
    // Skip expensive recalculation if the trips list and selected date haven't changed
    if (identical(trips, _lastComputedTrips) && _selectedDate == _lastComputedSelectedDate) return;
    _lastComputedTrips = trips;
    _lastComputedSelectedDate = _selectedDate;

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
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เกิดข้อผิดพลาดในการเลิกทำ: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          duration: const Duration(milliseconds: 2500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
    final result = await showDialog<({int rounds, int rateBaht})>(
      context: context,
      builder: (context) => EditTripRecordDialog(
        initialRounds: record.rounds,
        initialRate: record.rateBaht,
        distanceLabel: record.distanceLabel,
      ),
    );

    if (result == null || (result.rounds == record.rounds && result.rateBaht == record.rateBaht)) return;

    final matchedLabel = _options.firstWhere(
      (opt) => opt.rateBaht == result.rateBaht,
      orElse: () => DistanceOption(label: record.distanceLabel, rateBaht: result.rateBaht),
    ).label;

    final updated = TripRecord(
      id: record.id,
      distanceLabel: matchedLabel,
      rateBaht: result.rateBaht,
      rounds: result.rounds,
      createdAt: record.createdAt,
    );

    try {
      await appDatabase.updateTrip(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบรายการในช่วงเวลาที่เลือก'),
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 2500),
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งออกไฟล์: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  labelColor: const Color(0xFF00897B),
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: const Color(0xFF00897B),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: kanitTextStyle(fontWeight: FontWeight.normal, fontSize: 15),
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

  List<_DistanceStats> _buildDistanceStats(List<TripRecord> trips) {
    final stats = <String, _DistanceStats>{};
    for (final record in trips) {
      stats.putIfAbsent(
        record.distanceLabel,
        () => _DistanceStats(label: record.distanceLabel, count: 0, total: 0),
      );
      stats[record.distanceLabel]!.count += record.rounds;
      stats[record.distanceLabel]!.total += record.totalBaht;
    }
    return stats.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  Widget _buildReportsTab(
    BuildContext context,
    List<_DailyTripSummary> dailySummaries,
    List<_PeriodSummary> weeklySummaries,
    List<_PeriodSummary> monthlySummaries,
  ) {
    final distanceStats = _buildDistanceStats(_lastComputedTrips ?? []);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 380 ? 12 : 20,
          ),
          child: CustomScrollView(
            slivers: [
              // ── สถิติตามระยะทาง (moved from Dashboard) ─────────────────
              SliverToBoxAdapter(
                child: Text(
                  'สถิติตามระยะทาง',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (distanceStats.isEmpty)
                SliverToBoxAdapter(
                  child: emptyState(
                    context,
                    icon: Icons.bar_chart_outlined,
                    title: 'ยังไม่มีสถิติ',
                    message: 'เพิ่มรายการเดินทางเพื่อดูสถิติ',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) => _DistanceStatCard(stat: distanceStats[idx]),
                    childCount: distanceStats.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ── สรุปรายวัน ───────────────────────────────────────────────
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
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) =>
                        _DailySummaryTile(summary: dailySummaries[idx]),
                    childCount: dailySummaries.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ── สรุปรายสัปดาห์ ───────────────────────────────────────────
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
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) => _PeriodSummaryTile(
                      summary: weeklySummaries[idx],
                      formatLabel: _formatWeekLabel,
                    ),
                    childCount: weeklySummaries.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ── สรุปรายเดือน ─────────────────────────────────────────────
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
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) => _PeriodSummaryTile(
                      summary: monthlySummaries[idx],
                      formatLabel: _formatMonthLabel,
                    ),
                    childCount: monthlySummaries.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistanceActionCard extends StatefulWidget {
  const _DistanceActionCard({
    super.key,
    required this.option,
    required this.onTap,
    required this.onEdit,
  });

  final DistanceOption option;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  State<_DistanceActionCard> createState() => _DistanceActionCardState();
}

class _DistanceActionCardState extends State<_DistanceActionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 120),
    vsync: this,
  );

  // Using file-level _getDistanceIcon helper

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _ctrl.drive(Tween(begin: 1.0, end: 0.96)),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F2F1),
              width: 1,
            ),
          ),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getDistanceIcon(widget.option.label),
                        size: 24,
                        color: const Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.option.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: kanitTextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.option.rateBaht} ฿',
                        style: kanitTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(
                    Icons.edit_note,
                    size: 22,
                    color: isDark ? Colors.tealAccent : const Color(0xFF00897B),
                  ),
                  onPressed: widget.onEdit,
                  tooltip: 'ระบุจำนวนรอบ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Distance Stats (migrated from DashboardPage)
// ─────────────────────────────────────────────────────────────────────────────

class _DistanceStats {
  _DistanceStats({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  int count;
  int total;
}

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

class _DistanceStatCard extends StatelessWidget {
  const _DistanceStatCard({required this.stat});
  final _DistanceStats stat;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F2F1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getDistanceIcon(stat.label),
                size: 24,
                color: const Color(0xFF00897B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kanitTextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stat.count} รอบ',
                    style: kanitTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${stat.total} ฿',
              style: kanitTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00897B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'ยอดรวม $dateLabel',
                        style: kanitTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onSelectDate,
                      child: const Icon(
                        Icons.edit_calendar,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalBaht ฿',
                  style: kanitTextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'รวม $totalRounds รอบ',
                  style: kanitTextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canExport)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00897B),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: kanitTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Export CSV'),
                ),
              if (canClear) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade100,
                    visualDensity: VisualDensity.compact,
                    textStyle: kanitTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                  label: const Text('ล้างข้อมูล'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DailySummaryTile extends StatelessWidget {
  const _DailySummaryTile({required this.summary});

  final _DailyTripSummary summary;

  @override
  Widget build(BuildContext context) {
    final onPrimaryContainer = Theme.of(context).colorScheme.onPrimaryContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(summary.date),
                          style: kanitTextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: onPrimaryContainer.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'รวม ${summary.totalRounds} รอบ • ${summary.recordCount} รายการ',
                              style: kanitTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: onPrimaryContainer.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${summary.totalBaht} ฿',
                    style: kanitTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

    final Color leadingColor = switch (record.rateBaht) {
      5 => Colors.blue.shade400,
      10 => Colors.green.shade400,
      15 => Colors.orange.shade400,
      25 => Colors.red.shade400,
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
