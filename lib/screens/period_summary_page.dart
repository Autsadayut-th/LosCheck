import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip_record.dart';
import '../providers/app_state_provider.dart';
import '../core/design_tokens.dart';
import '../core/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Period Summary Page — เลือกช่วงวันที่ แสดงยอดรวม + รายวัน
// ─────────────────────────────────────────────────────────────────────────────

class PeriodSummaryPage extends StatefulWidget {
  const PeriodSummaryPage({super.key});

  @override
  State<PeriodSummaryPage> createState() => _PeriodSummaryPageState();
}

class _PeriodSummaryPageState extends State<PeriodSummaryPage> {
  DateTimeRange? _selectedRange;
  final _numberFormat = NumberFormat('#,###');

  // ── Computed data ─────────────────────────────────────────────────────────
  List<TripRecord> _filteredTrips = [];
  List<_DailySummary> _dailySummaries = [];
  int _grandTotalBaht = 0;
  int _grandTotalRounds = 0;
  int _grandTotalRecords = 0;

  void _computeSummary(List<TripRecord> allTrips) {
    if (_selectedRange == null) {
      _filteredTrips = [];
      _dailySummaries = [];
      _grandTotalBaht = 0;
      _grandTotalRounds = 0;
      _grandTotalRecords = 0;
      return;
    }

    final start = DateTime(
      _selectedRange!.start.year,
      _selectedRange!.start.month,
      _selectedRange!.start.day,
    );
    final end = DateTime(
      _selectedRange!.end.year,
      _selectedRange!.end.month,
      _selectedRange!.end.day,
      23, 59, 59, 999,
    );

    _filteredTrips = allTrips
        .where((t) =>
            !t.createdAt.isBefore(start) && !t.createdAt.isAfter(end))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Group by day
    final byDay = <DateTime, List<TripRecord>>{};
    for (final trip in _filteredTrips) {
      final dayKey = DateTime(
        trip.createdAt.year,
        trip.createdAt.month,
        trip.createdAt.day,
      );
      byDay.putIfAbsent(dayKey, () => []).add(trip);
    }

    _dailySummaries = byDay.entries.map((entry) {
      final records = entry.value;
      return _DailySummary(
        date: entry.key,
        totalBaht: records.fold<int>(0, (sum, r) => sum + r.totalBaht),
        totalRounds: records.fold<int>(0, (sum, r) => sum + r.rounds),
        recordCount: records.length,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    _grandTotalBaht =
        _filteredTrips.fold<int>(0, (sum, r) => sum + r.totalBaht);
    _grandTotalRounds =
        _filteredTrips.fold<int>(0, (sum, r) => sum + r.rounds);
    _grandTotalRecords = _filteredTrips.length;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day - 15),
            end: now,
          ),
      locale: const Locale('th', 'TH'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF33BCB4),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedRange = picked);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final allTrips = appState.trips;
    _computeSummary(allTrips);

    final isDark = context.isDarkMode;
    final isSmall = context.screenWidth < 380;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'สรุปยอดตามช่วงวันที่',
          style: kanitTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: DesignTokens.containerMaxWidth),
            child: Column(
              children: [
                // ── Date Range Picker Bar ───────────────────────────────
                _DateRangePickerBar(
                  selectedRange: _selectedRange,
                  onPick: _pickDateRange,
                  isDark: isDark,
                  isSmall: isSmall,
                ),

                // ── Content ─────────────────────────────────────────────
                Expanded(
                  child: _selectedRange == null
                      ? _buildEmptyPrompt(context)
                      : _buildSummaryContent(context, isDark, isSmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.date_range_outlined,
                size: 64,
                color: context.colors.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'เลือกช่วงวันที่',
              style: kanitTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กดปุ่มด้านบนเพื่อเลือกวันที่เริ่ม - วันที่จบ\nแล้วดูยอดรวมของช่วงเวลานั้น',
              textAlign: TextAlign.center,
              style: kanitTextStyle(
                fontSize: 14,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                'เลือกช่วงวันที่',
                style: kanitTextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: DesignTokens.borderRadiusMd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryContent(
      BuildContext context, bool isDark, bool isSmall) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: isSmall ? 12 : 16)),

        // ── Grand Total Card ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
            child: _GrandTotalCard(
              totalBaht: _grandTotalBaht,
              totalRounds: _grandTotalRounds,
              totalRecords: _grandTotalRecords,
              totalDays: _dailySummaries.length,
              numberFormat: _numberFormat,
              isDark: isDark,
              isSmall: isSmall,
            ),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: isSmall ? 16 : 24)),

        // ── Section Header ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: context.colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'รายละเอียดแต่ละวัน',
                  style: kanitTextStyle(
                    fontSize: isSmall ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: context.colors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_dailySummaries.length} วัน',
                  style: kanitTextStyle(
                    fontSize: 13,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 12)),

        // ── Daily Breakdown ───────────────────────────────────────
        if (_dailySummaries.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
              child: emptyState(
                context,
                icon: Icons.event_busy_outlined,
                title: 'ไม่มีรายการในช่วงนี้',
                message: 'ไม่พบรายการค่ารอบในช่วงวันที่ที่เลือก',
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _DailySummaryCard(
                    summary: _dailySummaries[index],
                    numberFormat: _numberFormat,
                    isDark: isDark,
                    isSmall: isSmall,
                    isToday: _isToday(_dailySummaries[index].date),
                  );
                },
                childCount: _dailySummaries.length,
              ),
            ),
          ),

        SliverToBoxAdapter(child: SizedBox(height: isSmall ? 24 : 32)),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _DailySummary {
  const _DailySummary({
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

// ─────────────────────────────────────────────────────────────────────────────
// Date Range Picker Bar
// ─────────────────────────────────────────────────────────────────────────────

class _DateRangePickerBar extends StatelessWidget {
  const _DateRangePickerBar({
    required this.selectedRange,
    required this.onPick,
    required this.isDark,
    required this.isSmall,
  });

  final DateTimeRange? selectedRange;
  final VoidCallback onPick;
  final bool isDark;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 20,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: Icon(
                Icons.date_range,
                color: context.colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selectedRange == null
                  ? Text(
                      'กดเพื่อเลือกช่วงวันที่',
                      style: kanitTextStyle(
                        fontSize: 15,
                        color: context.colors.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ช่วงวันที่',
                          style: kanitTextStyle(
                            fontSize: 12,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDate(selectedRange!.start)}  →  ${_formatDate(selectedRange!.end)}',
                          style: kanitTextStyle(
                            fontSize: isSmall ? 14 : 15,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
            ),
            Icon(
              Icons.edit_calendar,
              color: context.colors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${date.day} ${thaiMonths[date.month - 1]} ${date.year + 543}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grand Total Card
// ─────────────────────────────────────────────────────────────────────────────

class _GrandTotalCard extends StatelessWidget {
  const _GrandTotalCard({
    required this.totalBaht,
    required this.totalRounds,
    required this.totalRecords,
    required this.totalDays,
    required this.numberFormat,
    required this.isDark,
    required this.isSmall,
  });

  final int totalBaht;
  final int totalRounds;
  final int totalRecords;
  final int totalDays;
  final NumberFormat numberFormat;
  final bool isDark;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A8A82), const Color(0xFF239089)]
              : [const Color(0xFF33BCB4), const Color(0xFF5CCDC6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.tealAccent : const Color(0xFF33BCB4))
                .withValues(alpha: isDark ? 0.15 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      child: Column(
        children: [
          // ── Main total ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assessment_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                'ยอดรวมทั้งหมด',
                style: kanitTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '฿${numberFormat.format(totalBaht)}',
            style: kanitTextStyle(
              fontSize: isSmall ? 30 : 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: Colors.white.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 12),

          // ── Stats row ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                icon: Icons.repeat,
                value: numberFormat.format(totalRounds),
                label: 'รอบ',
                isSmall: isSmall,
              ),
              _StatItem(
                icon: Icons.receipt_long,
                value: numberFormat.format(totalRecords),
                label: 'รายการ',
                isSmall: isSmall,
              ),
              _StatItem(
                icon: Icons.calendar_today,
                value: '$totalDays',
                label: 'วัน',
                isSmall: isSmall,
              ),
              _StatItem(
                icon: Icons.trending_up,
                value: totalDays > 0
                    ? '฿${numberFormat.format((totalBaht / totalDays).round())}'
                    : '-',
                label: 'เฉลี่ย/วัน',
                isSmall: isSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.isSmall,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: isSmall ? 16 : 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: kanitTextStyle(
            fontSize: isSmall ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: kanitTextStyle(
            fontSize: isSmall ? 10 : 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({
    required this.summary,
    required this.numberFormat,
    required this.isDark,
    required this.isSmall,
    required this.isToday,
  });

  final _DailySummary summary;
  final NumberFormat numberFormat;
  final bool isDark;
  final bool isSmall;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const thaiDays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
    const thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final dayName = thaiDays[summary.date.weekday - 1];
    final dateStr =
        '${summary.date.day} ${thaiMonths[summary.date.month - 1]} ${summary.date.year + 543}';
    final todayLabel = isToday ? ' (วันนี้)' : '';

    final cardColor = isToday
        ? (isDark
            ? const Color(0xFF1A8A82).withValues(alpha: 0.3)
            : const Color(0xFFE0F5F4))
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    final borderColor = isToday
        ? (isDark
            ? Colors.tealAccent.withValues(alpha: 0.3)
            : const Color(0xFF80CBC4))
        : context.colors.borderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 12 : 16,
        vertical: isSmall ? 10 : 12,
      ),
      child: Row(
        children: [
          // ── Day circle ────────────────────────────────────────────
          Container(
            width: isSmall ? 40 : 46,
            height: isSmall ? 40 : 46,
            decoration: BoxDecoration(
              color: isToday
                  ? const Color(0xFF33BCB4)
                  : context.colors.primary.withValues(alpha: 0.1),
              borderRadius: DesignTokens.borderRadiusSm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${summary.date.day}',
                  style: kanitTextStyle(
                    fontSize: isSmall ? 15 : 17,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? Colors.white
                        : context.colors.primary,
                    height: 1.1,
                  ),
                ),
                Text(
                  dayName,
                  style: kanitTextStyle(
                    fontSize: 10,
                    color: isToday
                        ? Colors.white70
                        : context.colors.primary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isSmall ? 10 : 14),

          // ── Details ───────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateStr$todayLabel',
                  style: kanitTextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.totalRounds} รอบ • ${summary.recordCount} รายการ',
                  style: kanitTextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),

          // ── Amount ────────────────────────────────────────────────
          Text(
            '฿${numberFormat.format(summary.totalBaht)}',
            style: kanitTextStyle(
              fontSize: isSmall ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF33BCB4),
            ),
          ),
        ],
      ),
    );
  }
}
