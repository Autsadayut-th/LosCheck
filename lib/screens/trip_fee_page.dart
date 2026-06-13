import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/distance_option.dart';
import '../models/trip_record.dart';
import '../database/hive_database.dart';
import '../services/csv_export_service.dart';
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

  final List<TripRecord> _records = [];
  List<TripRecord> _selectedDateRecords = [];
  List<_DailyTripSummary> _dailySummaries = [];
  List<_PeriodSummary> _weeklySummaries = [];
  List<_PeriodSummary> _monthlySummaries = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  int _selectedDateTotal = 0;
  int _selectedDateRounds = 0;
  StreamSubscription<List<TripRecord>>? _subscription;

  List<_PeriodSummary> _buildPeriodSummaries(
    DateTime Function(DateTime) keyFn,
  ) {
    final grouped = <DateTime, List<TripRecord>>{};
    for (final record in _records) {
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

  List<_DailyTripSummary> _buildDailySummaries() {
    final summariesByDate = <DateTime, List<TripRecord>>{};

    for (final record in _records) {
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

  void _refreshDerivedData() {
    final selectedDateRecords = <TripRecord>[];
    var selectedDateTotal = 0;
    var selectedDateRounds = 0;

    for (final record in _records) {
      if (record.isSameDay(_selectedDate)) {
        selectedDateRecords.add(record);
        selectedDateTotal += record.totalBaht;
        selectedDateRounds += record.rounds;
      }
    }

    _selectedDateRecords = selectedDateRecords;
    _selectedDateTotal = selectedDateTotal;
    _selectedDateRounds = selectedDateRounds;
    _dailySummaries = _buildDailySummaries();
    _weeklySummaries = _buildPeriodSummaries((date) {
      final weekStart = date.subtract(Duration(days: date.weekday % 7));
      return DateTime(weekStart.year, weekStart.month, weekStart.day);
    });
    _monthlySummaries = _buildPeriodSummaries(
      (date) => DateTime(date.year, date.month),
    );
  }

  @override
  void initState() {
    super.initState();
    _subscription = appDatabase.watchAllTrips().listen((records) {
      if (!mounted) return;
      // Sort records by createdAt descending to show newest first
      final sortedRecords = List<TripRecord>.from(records)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _records.clear();
        _records.addAll(sortedRecords);
        _refreshDerivedData();
        _isLoading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลด: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _chooseDistance(DistanceOption option) async {
    debugPrint('=== _chooseDistance Started ===');
    debugPrint('Option: ${option.label}, Rate: ${option.rateBaht}');

    final rounds = await showDialog<int>(
      context: context,
      builder: (context) => const RoundsDialog(),
    );

    debugPrint('Rounds entered: $rounds');

    if (rounds == null) {
      debugPrint('Rounds dialog cancelled');
      return;
    }

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

    debugPrint('Creating trip record: ${record.distanceLabel}, ${record.rounds} rounds, ${record.totalBaht} baht');
    debugPrint('Selected date: $_selectedDate');
    debugPrint('Created at: $createdAt');
    debugPrint('Database initialized: ${appDatabase.isInitialized}');

    try {
      await appDatabase.insertTrip(record);
      debugPrint('Trip inserted successfully');
      
      // Force refresh derived data
      _refreshDerivedData();
      debugPrint('Derived data refreshed');
      debugPrint('Selected date records count: ${_selectedDateRecords.length}');
    } catch (e) {
      debugPrint('=== Trip Insert Failed ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
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
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _refreshDerivedData();
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

  Future<void> _exportCsv() async {
    if (_records.isEmpty) return;

    final csv = CsvExportService.exportTripRecords(_records);
    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('คัดลอกข้อมูล CSV แล้ว')));
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
    final selectedRecords = _selectedDateRecords;
    final dailySummaries = _dailySummaries;
    final weeklySummaries = _weeklySummaries;
    final monthlySummaries = _monthlySummaries;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 380 ? 12 : 20,
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      if (appDatabase.isUsingInMemory)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.isDarkMode 
                                ? Colors.amber.shade900.withValues(alpha: 0.2)
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
                          canExport: _records.isNotEmpty,
                          onClear: _clearSelectedDate,
                          onExport: _exportCsv,
                          dateLabel: _DailySummaryTile._formatDate(
                            _selectedDate,
                          ),
                          onSelectDate: _selectDate,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      SliverToBoxAdapter(
                        child: Text(
                          'เพิ่มค่ารอบ',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio:
                              MediaQuery.sizeOf(context).width > 600
                              ? 1.2
                              : 0.95,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final option = _options[index];
                          return _DistanceActionCard(
                            option: option,
                            onTap: () => _chooseDistance(option),
                          );
                        }, childCount: _options.length),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      SliverToBoxAdapter(
                        child: Text(
                          'ประวัติ ${_DailySummaryTile._formatDate(_selectedDate)}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
                            message:
                                'เพิ่มรายการเดินทางเพื่อดูสรุปแบบรายสัปดาห์',
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
      ),
    );
  }
}

class _DistanceActionCard extends StatelessWidget {
  const _DistanceActionCard({required this.option, required this.onTap});

  final DistanceOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 6,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${option.rateBaht} ฿',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final actionButtons = [
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          foregroundColor: Colors.white,
        ),
        onPressed: canClear ? onClear : null,
        icon: const Icon(Icons.delete_sweep_outlined),
        label: const Text('ล้างข้อมูล'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.teal.shade800,
        ),
        onPressed: canExport ? onExport : null,
        icon: const Icon(Icons.file_download_outlined),
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 24),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar, color: Colors.white),
                  onPressed: onSelectDate,
                  tooltip: 'เลือกวันที่',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$totalBaht ฿',
              textAlign: TextAlign.center,
              style:
                  (isCompact
                          ? Theme.of(context).textTheme.headlineLarge
                          : Theme.of(context).textTheme.displayMedium)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
            ),
            const SizedBox(height: 4),
            Text(
              'รวม $totalRounds รอบ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 24),
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  actionButtons[0],
                  const SizedBox(height: 8),
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
    final isCompact = MediaQuery.sizeOf(context).width < 380;
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
