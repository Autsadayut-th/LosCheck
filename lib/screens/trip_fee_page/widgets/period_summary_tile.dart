import 'package:flutter/material.dart';
import '../models/trip_fee_models.dart';

/// การ์ดแสดงผลสรุปยอดตามรายสัปดาห์ หรือรายเดือนในแถบรายงาน
class PeriodSummaryTile extends StatelessWidget {
  const PeriodSummaryTile({
    super.key,
    required this.summary,
    required this.formatLabel,
  });

  final PeriodSummary summary;
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
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
