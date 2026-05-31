import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/distance_option.dart';
import '../models/trip_record.dart';
import '../services/csv_export_service.dart';
import '../services/supabase_sync_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/rounds_dialog.dart';

class TripFeePage extends StatefulWidget {
  const TripFeePage({super.key});

  @override
  State<TripFeePage> createState() => _TripFeePageState();
}

class _TripFeePageState extends State<TripFeePage> {
  static const String _storageKey = 'trip_records_v1';
  static const List<DistanceOption> _options = [
    DistanceOption(label: 'ระยะทาง 0-300 เมตร', rateBaht: 5),
    DistanceOption(label: 'ระยะทาง 301-500 เมตร', rateBaht: 10),
    DistanceOption(label: 'ระยะทาง 501 เมตร - 3 กิโลเมตร', rateBaht: 15),
    DistanceOption(label: 'ระยะทาง มากกว่า 3 กิโลเมตร', rateBaht: 25),
  ];

  final List<TripRecord> _records = [];
  bool _isLoading = true;

  int get _todayTotal {
    final now = DateTime.now();
    return _records
        .where((record) => record.isSameDay(now))
        .fold<int>(0, (total, record) => total + record.totalBaht);
  }

  int get _todayRounds {
    final now = DateTime.now();
    return _records
        .where((record) => record.isSameDay(now))
        .fold<int>(0, (total, record) => total + record.rounds);
  }

  List<TripRecord> get _todayRecords {
    final now = DateTime.now();
    return _records.where((record) => record.isSameDay(now)).toList();
  }

  List<_PeriodSummary> get _weeklySummaries {
    return _buildPeriodSummaries((date) {
      final weekStart = date.subtract(Duration(days: date.weekday % 7));
      return DateTime(weekStart.year, weekStart.month, weekStart.day);
    });
  }

  List<_PeriodSummary> get _monthlySummaries {
    return _buildPeriodSummaries(
      (date) => DateTime(date.year, date.month),
    );
  }

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
    }).toList()
      ..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return summaries;
  }

  List<_DailyTripSummary> get _dailySummaries {
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

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecords = prefs.getStringList(_storageKey) ?? [];
    final loadedRecords =
        rawRecords
            .map((rawRecord) => TripRecord.fromJson(jsonDecode(rawRecord)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _records
        ..clear()
        ..addAll(loadedRecords);
      _isLoading = false;
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecords = _records
        .map((record) => jsonEncode(record.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, rawRecords);
  }

  Future<void> _chooseDistance(DistanceOption option) async {
    final rounds = await showDialog<int>(
      context: context,
      builder: (context) => const RoundsDialog(),
    );

    if (rounds == null) {
      return;
    }

    final record = TripRecord(
      distanceLabel: option.label,
      rateBaht: option.rateBaht,
      rounds: rounds,
      createdAt: DateTime.now(),
    );

    setState(() {
      _records.insert(0, record);
    });

    await _saveRecords();
    await SupabaseSyncService.saveTripRecord(
      record,
      onError: _showSyncError,
    );
  }

  void _showSyncError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editRecord(TripRecord record) async {
    final newRounds = await showDialog<int>(
      context: context,
      builder: (context) => RoundsDialog(initialRounds: record.rounds),
    );

    if (newRounds == null || newRounds == record.rounds) return;

    final index = _records.indexOf(record);
    if (index == -1) return;

    final updated = TripRecord(
      distanceLabel: record.distanceLabel,
      rateBaht: record.rateBaht,
      rounds: newRounds,
      createdAt: record.createdAt,
    );

    setState(() {
      _records[index] = updated;
    });
    await _saveRecords();
  }

  Future<void> _deleteRecord(TripRecord record) async {
    final confirmed = await confirmDelete(
      context,
      'ลบรายการนี้?',
      '${record.distanceLabel} • ${record.rounds} รอบ (${record.totalBaht} บาท)',
    );
    if (!confirmed) return;

    setState(() {
      _records.remove(record);
    });
    await _saveRecords();

    if (record.supabaseId != null) {
      await SupabaseSyncService.deleteTripRecord(
        record.supabaseId!,
        onError: _showSyncError,
      );
    }
  }

  Future<void> _exportCsv() async {
    if (_records.isEmpty) return;

    final csv = CsvExportService.exportTripRecords(_records);
    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกข้อมูล CSV แล้ว')),
    );
  }

  Future<void> _clearToday() async {
    final confirmed = await confirmDelete(
      context,
      'ล้างรายการวันนี้ทั้งหมด?',
      'รวม $_todayRounds รอบ ($_todayTotal บาท)',
    );
    if (!confirmed) return;

    setState(() {
      _records.removeWhere((record) => record.isSameDay(DateTime.now()));
    });
    await _saveRecords();
  }

  @override
  Widget build(BuildContext context) {
    final todayRecords = _todayRecords;
    final dailySummaries = _dailySummaries;
    final weeklySummaries = _weeklySummaries;
    final monthlySummaries = _monthlySummaries;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      _SummaryPanel(
                        totalBaht: _todayTotal,
                        totalRounds: _todayRounds,
                        canClear: todayRecords.isNotEmpty,
                        canExport: _records.isNotEmpty,
                        onClear: _clearToday,
                        onExport: _exportCsv,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'เพิ่มค่ารอบ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final option in _options) ...[
                        FilledButton(
                          onPressed: () => _chooseDistance(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${option.rateBaht} บาทต่อบิล • ${option.label}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        'สรุปรายวัน',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (dailySummaries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'ยังไม่มีสรุปรายวัน',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        for (final summary in dailySummaries)
                          _DailySummaryTile(summary: summary),
                      const SizedBox(height: 18),
                      Text(
                        'สรุปรายสัปดาห์',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (weeklySummaries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'ยังไม่มีสรุปรายสัปดาห์',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        for (final summary in weeklySummaries)
                          _PeriodSummaryTile(
                            summary: summary,
                            formatLabel: _formatWeekLabel,
                          ),
                      const SizedBox(height: 18),
                      Text(
                        'สรุปรายเดือน',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (monthlySummaries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'ยังไม่มีสรุปรายเดือน',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        for (final summary in monthlySummaries)
                          _PeriodSummaryTile(
                            summary: summary,
                            formatLabel: _formatMonthLabel,
                          ),
                      const SizedBox(height: 18),
                      Text(
                        'ประวัติวันนี้',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (todayRecords.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'ยังไม่มีรายการวันนี้',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        for (final record in todayRecords)
                          _RecordTile(
                            record: record,
                            onEdit: () => _editRecord(record),
                            onDelete: () => _deleteRecord(record),
                          ),
                    ],
                  ),
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
  });

  final int totalBaht;
  final int totalRounds;
  final bool canClear;
  final bool canExport;
  final VoidCallback onClear;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ยอดรวมวันนี้',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalBaht บาท',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'รวม $totalRounds รอบ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canClear ? onClear : null,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('ล้างวันนี้'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canExport ? onExport : null,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Export CSV'),
                  ),
                ),
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
    return Card(
      child: ListTile(
        title: Text(record.distanceLabel),
        subtitle: Text(
          '${record.rounds} รอบ x ${record.rateBaht} บาทต่อบิล • ${_formatTime(record.createdAt)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${record.totalBaht} บาท',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute น.';
  }
}

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
  const _PeriodSummaryTile({
    required this.summary,
    required this.formatLabel,
  });

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
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

String _formatWeekLabel(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  return '${_formatNumericDate(weekStart)} - ${_formatNumericDate(weekEnd)}';
}

String _formatMonthLabel(DateTime monthStart) {
  return '${_thaiMonths[monthStart.month - 1]} ${monthStart.year}';
}
