import 'package:flutter/material.dart';
import '../models/trip_fee_models.dart';
import '../../../core/theme_extensions.dart';

/// การ์ดแสดงสรุปสถิติตามระยะทาง พร้อมจำนวนรอบและยอดเงินรวมของแต่ละระยะทาง
class DistanceStatCard extends StatelessWidget {
  const DistanceStatCard({super.key, required this.stat});
  final DistanceStats stat;

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
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
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
                color: const Color(0xFF33BCB4).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getDistanceIcon(stat.label),
                size: 24,
                color: const Color(0xFF33BCB4),
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
                color: const Color(0xFF33BCB4),
              ),
            ),
          ],
        ),
      ),
    );
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
}
