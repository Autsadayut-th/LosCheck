import 'package:flutter/material.dart';
import '../../../models/distance_option.dart';
import '../../../core/theme_extensions.dart';

/// การ์ดแสดงผลระยะทางแต่ละช่วงสำหรับกดจดบันทึกรอบวิ่งทันที หรือกดระบุจำนวนรอบ
class DistanceActionCard extends StatefulWidget {
  const DistanceActionCard({
    super.key,
    required this.option,
    required this.onTap,
    required this.onEdit,
  });

  final DistanceOption option;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  State<DistanceActionCard> createState() => _DistanceActionCardState();
}

class _DistanceActionCardState extends State<DistanceActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 120),
    vsync: this,
  );

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

    String displayLabel = widget.option.label;
    if (displayLabel == 'ระยะทาง 0-300 เมตร') {
      displayLabel = '0-300 เมตร';
    } else if (displayLabel == 'ระยะทาง 301-500 เมตร') {
      displayLabel = '301-500 เมตร';
    } else if (displayLabel == 'ระยะทาง 501 เมตร - 3 กิโลเมตร') {
      displayLabel = '501 ม. - 3 กม.';
    } else if (displayLabel == 'ระยะทาง มากกว่า 3 กิโลเมตร') {
      displayLabel = 'มากกว่า 3 กม.';
    }

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
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
              width: 1,
            ),
          ),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.01,
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Text(widget.option.label),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF33BCB4).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getDistanceIcon(widget.option.label),
                        size: 20,
                        color: const Color(0xFF33BCB4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Center(
                        child: Text(
                          displayLabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: kanitTextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF33BCB4),
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
                    color: isDark ? Colors.tealAccent : const Color(0xFF33BCB4),
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
