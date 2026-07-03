import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/design_tokens.dart';
import '../../../core/theme_extensions.dart';

class CompletionStat extends StatelessWidget {
  const CompletionStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF33BCB4), size: 28),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class QueueItemCard extends StatelessWidget {
  const QueueItemCard({
    super.key,
    required this.index,
    required this.name,
    required this.address,
    required this.phone,
    required this.distanceLabel,
    this.trailing,
  });

  final int index;
  final String name;
  final String address;
  final String phone;
  final String distanceLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE0F5F4),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF33BCB4).withValues(alpha: 0.1),
          child: Text(
            '$index',
            style: kanitTextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF33BCB4),
            ),
          ),
        ),
        title: Text(
          name,
          style: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'โทร: $phone | $address',
              style: kanitTextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: Color(0xFF33BCB4),
                ),
                const SizedBox(width: 4),
                Text(
                  distanceLabel,
                  style: kanitTextStyle(
                    fontSize: 11,
                    color: const Color(0xFF33BCB4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}

class NavOptionTile extends StatelessWidget {
  const NavOptionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedGradientButton extends StatefulWidget {
  const AnimatedGradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.isEnabled,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isEnabled;

  @override
  State<AnimatedGradientButton> createState() =>
      _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    final isTesting =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (widget.isEnabled && !isTesting) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedGradientButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isTesting =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (widget.isEnabled && !_controller.isAnimating && !isTesting) {
      _controller.repeat(reverse: true);
    } else if (!widget.isEnabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alignmentValue = _controller.value;
        final beginAlignment =
            Alignment.lerp(
              Alignment.topLeft,
              Alignment.topRight,
              alignmentValue,
            ) ??
            Alignment.topLeft;
        final endAlignment =
            Alignment.lerp(
              Alignment.bottomLeft,
              Alignment.bottomRight,
              alignmentValue,
            ) ??
            Alignment.bottomRight;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isEnabled
                ? LinearGradient(
                    colors: const [
                      Color(0xFF2E7D32),
                      Color(0xFF4CAF50),
                    ], // Green (Enabled)
                    begin: beginAlignment,
                    end: endAlignment,
                  )
                : null,
            color: widget.isEnabled
                ? null
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            boxShadow: widget.isEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              widget.label,
              style: kanitTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: widget.isEnabled
                    ? Colors.white
                    : (isDark ? Colors.white30 : Colors.grey.shade500),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SummaryPillItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const SummaryPillItem({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: kanitTextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

Widget pillDivider(bool isDark) {
  return Container(
    height: 14,
    width: 1,
    color: isDark ? Colors.white24 : Colors.black12,
  );
}
