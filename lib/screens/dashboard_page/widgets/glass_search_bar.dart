import 'package:flutter/material.dart';
import '../../../core/theme_extensions.dart';

/// แถบค้นหากึ่งโปร่งใส (Glass Search Bar) สำหรับค้นหาชื่อลูกค้าหรือเบอร์โทรศัพท์บนแผนที่
class GlassSearchBar extends StatelessWidget {
  const GlassSearchBar({
    super.key,
    required this.isDark,
    required this.controller,
    required this.onChanged,
  });

  final bool isDark;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: kanitTextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อลูกค้าหรือเบอร์โทร...',
          prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : const Color(0xFF33BCB4)),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
