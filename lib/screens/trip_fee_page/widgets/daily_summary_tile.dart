import 'package:flutter/material.dart';
import '../models/trip_fee_models.dart';
import '../../../core/theme_extensions.dart';

/// การ์ดแสดงผลสรุปค่ารอบแบบรายวันในแถบรายงาน
class DailySummaryTile extends StatelessWidget {
  const DailySummaryTile({super.key, required this.summary});

  final DailyTripSummary summary;

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
                          formatDate(summary.date),
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

  /// แปลงวันเป็นข้อความที่แสดงผลได้ดี เช่น "วันนี้", "เมื่อวาน" หรือวันที่ฟอร์แมต
  static String formatDate(DateTime date) {
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

  static String _formatNumericDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
