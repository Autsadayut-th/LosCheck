import 'dart:async';
import 'package:flutter/material.dart';

/// Widget สำหรับสร้างอนิเมชันตอนเปิดแสดงผล โดยจะค่อยๆ Fade-in และ Slide ขึ้นจากด้านล่าง
class FadeInSlide extends StatefulWidget {
  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _HomeSlideState extends State<FadeInSlide> {
  // Let's keep it named matching original
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: widget.duration, vsync: this);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity:
          _controller.drive(Tween<double>(begin: 0.0, end: 1.0)),
      child: SlideTransition(
        position: _controller.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: widget.child,
      ),
    );
  }
}
