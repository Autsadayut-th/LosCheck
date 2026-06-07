import 'package:flutter/material.dart';

import '../models/trip_record.dart';
import '../models/customer_record.dart';
import '../database/app_database.dart';
import '../widgets/shimmer_loading.dart';
import '../core/design_tokens.dart';
import '../core/theme_extensions.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<TripRecord> _tripRecords = [];
  final List<CustomerRecord> _customerRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final trips = await appDatabase.getAllTrips();
      final customers = await appDatabase.getAllCustomers();
      if (!mounted) return;
      setState(() {
        _tripRecords.clear();
        _tripRecords.addAll(
          trips.map(
            (t) => TripRecord(
              distanceLabel: t.distanceLabel,
              rateBaht: t.rateBaht,
              rounds: t.rounds,
              createdAt: t.createdAt,
            ),
          ),
        );
        _customerRecords.clear();
        _customerRecords.addAll(
          customers.map(
            (c) => CustomerRecord(
              phone: c.phone,
              name: c.name,
              address: c.address,
              createdAt: c.createdAt,
            ),
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  int get _totalTripRecords => _tripRecords.length;
  int get _totalCustomerRecords => _customerRecords.length;
  int get _totalRevenue =>
      _tripRecords.fold<int>(0, (sum, record) => sum + record.totalBaht);
  int get _totalRounds =>
      _tripRecords.fold<int>(0, (sum, record) => sum + record.rounds);

  List<_DistanceStats> get _distanceStats {
    final stats = <String, _DistanceStats>{};
    for (final record in _tripRecords) {
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
    if (_isLoading) {
      return const SafeArea(
        child: Center(
          child: Padding(
            padding: DesignTokens.paddingM,
            child: SingleChildScrollView(
              child: Column(
                children: [
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
          ),
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: DesignTokens.paddingM,
            child: ListView(
              children: [
                Text(
                  'ภาพรวม',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: DesignTokens.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'รายได้รวม',
                        value: '$_totalRevenue',
                        unit: 'บาท',
                        icon: Icons.attach_money,
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade700,
                            Colors.amber.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: DesignTokens.spacingM),
                    Expanded(
                      child: _StatCard(
                        title: 'รอบรวม',
                        value: '$_totalRounds',
                        unit: 'รอบ',
                        icon: Icons.local_shipping,
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade800,
                            Colors.orange.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: DesignTokens.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'รายการทั้งหมด',
                        value: '$_totalTripRecords',
                        unit: 'รายการ',
                        icon: Icons.receipt_long,
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade800, Colors.teal.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: DesignTokens.spacingM),
                    Expanded(
                      child: _StatCard(
                        title: 'ลูกค้าทั้งหมด',
                        value: '$_totalCustomerRecords',
                        unit: 'คน',
                        icon: Icons.people,
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.shade800,
                            Colors.indigo.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: DesignTokens.spacingXl),
                Text(
                  'สถิติตามระยะทาง',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: DesignTokens.spacingM),
                if (_distanceStats.isEmpty)
                  emptyState(
                    context,
                    icon: Icons.bar_chart_outlined,
                    title: 'ยังไม่มีสถิติ',
                    message: 'เพิ่มรายการเดินทางเพื่อดูสถิติ',
                  )
                else
                  ..._distanceStats.map(
                    (stat) => _DistanceStatCard(stat: stat),
                  ),
              ],
            ),
          ),
        ),
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
