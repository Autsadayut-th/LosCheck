import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/distance_option.dart';
import '../../models/trip_record.dart';
import '../../database/hive_database.dart';
import '../../providers/app_state_provider.dart';
import '../../services/csv_export_service.dart';
import '../../services/file_share_service.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/rounds_dialog.dart';
import '../../widgets/edit_trip_record_dialog.dart';
import '../../core/theme_extensions.dart';
import '../period_summary_page.dart';
import '../cash_counting_page.dart';

import 'models/trip_fee_models.dart';
import 'widgets/summary_panel.dart';
import 'widgets/distance_action_card.dart';
import 'widgets/record_tile.dart';
import 'widgets/daily_summary_tile.dart';
import 'widgets/period_summary_tile.dart';
import 'widgets/distance_stat_card.dart';

/// หน้าหลักระบบบันทึกค่ารอบรถ (Trip Fee Screen Entrypoint) จัดการข้อมูลและแท็บการทำงาน
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
  List<DailyTripSummary> _dailySummaries = [];
  List<PeriodSummary> _weeklySummaries = [];
  List<PeriodSummary> _monthlySummaries = [];
  DateTime _selectedDate = DateTime.now();
  int _selectedDateTotal = 0;
  int _selectedDateRounds = 0;

  // Memoization: skip recompute when trips list and selected date haven't changed
  List<TripRecord>? _lastComputedTrips;
  DateTime? _lastComputedSelectedDate;

  List<PeriodSummary> _buildPeriodSummaries(
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
      return PeriodSummary(
        periodStart: entry.key,
        totalBaht: records.fold<int>(0, (t, r) => t + r.totalBaht),
        totalRounds: records.fold<int>(0, (t, r) => t + r.rounds),
        recordCount: records.length,
      );
    }).toList()..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return summaries;
  }

  List<DailyTripSummary> _buildDailySummaries(List<TripRecord> trips) {
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
      return DailyTripSummary(
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
          duration: const Duration(seconds: 1),
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
      length: 3,
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
                  labelColor: const Color(0xFF33BCB4),
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: const Color(0xFF33BCB4),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: kanitTextStyle(fontWeight: FontWeight.normal, fontSize: 15),
                  tabs: [
                    Tab(
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.edit_note, size: 28),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.01,
                                child: Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: const Text('บันทึกค่ารอบ'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.calculate_outlined, size: 28),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.01,
                                child: Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: const Text('นับเงิน'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.analytics_outlined, size: 28),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.01,
                                child: Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: const Text('สรุปและรายงาน'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLogTripTab(context, trips, selectedRecords),
                  const CashCountingPage(),
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
                child: SummaryPanel(
                  totalBaht: _selectedDateTotal,
                  totalRounds: _selectedDateRounds,
                  canClear: selectedRecords.isNotEmpty,
                  canExport: trips.isNotEmpty,
                  onClear: _clearSelectedDate,
                  onExport: () => _exportCsv(trips),
                  dateLabel: DailySummaryTile.formatDate(
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
                  return DistanceActionCard(
                    option: option,
                    onTap: () => _logInstantTrip(option),
                    onEdit: () => _logCustomTrip(option),
                  );
                }, childCount: _options.length),
              ),
              SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 18 : 32)),
              SliverToBoxAdapter(
                child: Text(
                  'ประวัติ ${DailySummaryTile.formatDate(_selectedDate)}',
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
                    return RecordTile(
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

  List<DistanceStats> _buildDistanceStats(List<TripRecord> trips) {
    final stats = <String, DistanceStats>{};
    for (final record in trips) {
      stats.putIfAbsent(
        record.distanceLabel,
        () => DistanceStats(label: record.distanceLabel, count: 0, total: 0),
      );
      stats[record.distanceLabel]!.count += record.rounds;
      stats[record.distanceLabel]!.total += record.totalBaht;
    }
    return stats.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  Widget _buildReportsTab(
    BuildContext context,
    List<DailyTripSummary> dailySummaries,
    List<PeriodSummary> weeklySummaries,
    List<PeriodSummary> monthlySummaries,
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
              // ── ปุ่มสรุปยอดตามช่วงวันที่ ──────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [const Color(0xFF1A8A82), const Color(0xFF239089)]
                          : [const Color(0xFF33BCB4), const Color(0xFF4DB6AC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PeriodSummaryPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.date_range,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'สรุปยอดตามช่วงวันที่',
                                    style: kanitTextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'เลือกวันที่เริ่ม - วันที่จบ ดูยอดรวม + รายวัน',
                                    style: kanitTextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── สถิติตามระยะทาง ─────────────────
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
                    (ctx, idx) => DistanceStatCard(stat: distanceStats[idx]),
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
                        DailySummaryTile(summary: dailySummaries[idx]),
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
                    (ctx, idx) => PeriodSummaryTile(
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
                    (ctx, idx) => PeriodSummaryTile(
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

String _formatNumericDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
