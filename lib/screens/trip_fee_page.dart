import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/distance_option.dart';
import '../models/trip_record.dart';
import '../services/supabase_sync_service.dart';
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
    await SupabaseSyncService.saveTripRecord(record);
  }

  Future<void> _deleteRecord(TripRecord record) async {
    setState(() {
      _records.remove(record);
    });
    await _saveRecords();
  }

  Future<void> _clearToday() async {
    setState(() {
      _records.removeWhere((record) => record.isSameDay(DateTime.now()));
    });
    await _saveRecords();
  }

  @override
  Widget build(BuildContext context) {
    final todayRecords = _todayRecords;
    final dailySummaries = _dailySummaries;

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
                        onClear: _clearToday,
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
    required this.onClear,
  });

  final int totalBaht;
  final int totalRounds;
  final bool canClear;
  final VoidCallback onClear;

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
            OutlinedButton.icon(
              onPressed: canClear ? onClear : null,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('ล้างรายการวันนี้'),
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
  const _RecordTile({required this.record, required this.onDelete});

  final TripRecord record;
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
