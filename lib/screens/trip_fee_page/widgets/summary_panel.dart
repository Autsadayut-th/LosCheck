import 'package:flutter/material.dart';
import '../../../core/theme_extensions.dart';

/// แผงการ์ดสรุปยอดเงินรวมและจำนวนรอบของวันที่เลือก พร้อมตัวเลือก Export CSV และล้างข้อมูล
class SummaryPanel extends StatelessWidget {
  const SummaryPanel({
    super.key,
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF33BCB4), Color(0xFF5CCDC6)],
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
                    foregroundColor: const Color(0xFF33BCB4),
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
