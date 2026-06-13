import 'dart:async';
import 'package:flutter/material.dart';

import '../models/trip_record.dart';
import '../models/customer_record.dart';
import '../database/hive_database.dart';
import '../widgets/shimmer_loading.dart';
import '../core/design_tokens.dart';
import '../core/theme_extensions.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder so the dashboard stays in sync whenever trips or
    // customers change in the DB. No manual init/refresh needed.
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<TripRecord>>(
            stream: appDatabase.watchAllTrips(),
            builder: (context, tripsSnapshot) {
              return StreamBuilder<List<CustomerRecord>>(
                stream: appDatabase.watchAllCustomers(),
                builder: (context, customersSnapshot) {
                  if (tripsSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      customersSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return _buildLoading();
                  }

                  if (tripsSnapshot.hasError || customersSnapshot.hasError) {
                    return _buildError(
                      tripsSnapshot.error ?? customersSnapshot.error,
                    );
                  }

                  final tripRecords = tripsSnapshot.data ?? const [];
                  final customerRecords = customersSnapshot.data ?? const [];

                  return _DashboardContent(
                    tripRecords: tripRecords,
                    customerRecords: customerRecords,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: DesignTokens.paddingM,
      child: SingleChildScrollView(
        child: Column(
          children: const [
            SkeletonCard(height: 120),
            SizedBox(height: DesignTokens.spacingM),
            SkeletonCard(height: 120),
            SizedBox(height: DesignTokens.spacingL),
            SkeletonCard(height: 80),
            SizedBox(height: DesignTokens.spacingXs2),
            SkeletonCard(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด: ${error ?? 'ไม่ทราบสาเหตุ'}'),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.tripRecords,
    required this.customerRecords,
  });

  final List<TripRecord> tripRecords;
  final List<CustomerRecord> customerRecords;

  int get _totalTripRecords => tripRecords.length;
  int get _totalCustomerRecords => customerRecords.length;
  int get _totalRevenue =>
      tripRecords.fold<int>(0, (sum, record) => sum + record.totalBaht);
  int get _totalRounds =>
      tripRecords.fold<int>(0, (sum, record) => sum + record.rounds);

  List<_DistanceStats> get _distanceStats {
    final stats = <String, _DistanceStats>{};
    for (final record in tripRecords) {
      stats.putIfAbsent(
        record.distanceLabel,
        () => _DistanceStats(label: record.distanceLabel, count: 0, total: 0),
      );
      stats[record.distanceLabel]!.count += record.rounds;
      stats[record.distanceLabel]!.total += record.totalBaht;
    }
    return stats.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingM,
      child: ListView(
        children: [
          FadeInSlide(
            delay: Duration.zero,
            child: Text(
              'ภาพรวม',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingL),
          FadeInSlide(
            delay: const Duration(milliseconds: 100),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'รายได้รวม',
                    value: '$_totalRevenue',
                    unit: 'บาท',
                    icon: Icons.attach_money,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingM),
                Expanded(
                  child: _StatCard(
                    title: 'รอบรวม',
                    value: '$_totalRounds',
                    unit: 'รอบ',
                    icon: Icons.local_shipping,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spacingM),
          FadeInSlide(
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'รายการทั้งหมด',
                    value: '$_totalTripRecords',
                    unit: 'รายการ',
                    icon: Icons.receipt_long,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingM),
                Expanded(
                  child: _StatCard(
                    title: 'ลูกค้าทั้งหมด',
                    value: '$_totalCustomerRecords',
                    unit: 'คน',
                    icon: Icons.people,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXl),
          FadeInSlide(
            delay: const Duration(milliseconds: 300),
            child: Text(
              'สถิติตามระยะทาง',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingM),
          if (_distanceStats.isEmpty)
            FadeInSlide(
              delay: const Duration(milliseconds: 400),
              child: emptyState(
                context,
                icon: Icons.bar_chart_outlined,
                title: 'ยังไม่มีสถิติ',
                message: 'เพิ่มรายการเดินทางเพื่อดูสถิติ',
              ),
            )
          else
            ..._distanceStats.asMap().entries.map((entry) {
              final index = entry.key;
              final stat = entry.value;
              return FadeInSlide(
                delay: Duration(milliseconds: 400 + index * 100),
                child: _DistanceStatCard(stat: stat),
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
    required this.textColor,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Gradient gradient;
  final Color textColor;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _controller.drive(Tween(begin: 1.0, end: 0.98)),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: DesignTokens.borderRadiusXl,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.textColor.withValues(alpha: 0.8),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: widget.textColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.value,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: widget.textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.unit,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.textColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DistanceStatCard extends StatelessWidget {
  const _DistanceStatCard({required this.stat});

  final _DistanceStats stat;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: DesignTokens.spacingXs2),
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusLg),
      child: Padding(
        padding: DesignTokens.paddingM,
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(DesignTokens.spacingS),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(width: DesignTokens.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacingXs),
                  Text(
                    '${stat.count} รอบ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${stat.total} ฿',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceStats {
  _DistanceStats({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  int count;
  int total;
}

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

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
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
      opacity: _controller.drive(Tween<double>(begin: 0.0, end: 1.0)),
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
