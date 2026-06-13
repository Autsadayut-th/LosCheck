import 'package:loscheck/database/isar_database.dart';

class DashboardService {
  static final DashboardService _instance = DashboardService._internal();

  factory DashboardService() {
    return _instance;
  }

  DashboardService._internal();

  late IsarDatabase _database;
  DashboardSummary? _cachedSummary;
  List<DistanceStat>? _cachedDistanceStats;
  DateTime? _lastSummaryUpdate;
  DateTime? _lastDistanceStatsUpdate;

  static const Duration _cacheDuration = Duration(seconds: 30);

  void initialize(IsarDatabase database) {
    _database = database;
  }

  bool _isCacheValid(DateTime? lastUpdate) {
    if (lastUpdate == null) return false;
    return DateTime.now().difference(lastUpdate) < _cacheDuration;
  }

  void invalidateCache() {
    _cachedSummary = null;
    _cachedDistanceStats = null;
    _lastSummaryUpdate = null;
    _lastDistanceStatsUpdate = null;
  }

  Future<DashboardSummary> getSummary() async {
    if (_isCacheValid(_lastSummaryUpdate) && _cachedSummary != null) {
      return _cachedSummary!;
    }

    final totalRevenue = await _database.getTotalRevenue();
    final totalRounds = await _database.getTotalRounds();
    final totalCustomers = await _database.getTotalCustomers();
    final todayRevenue = await _database.getTotalTodayBaht();
    final todayRounds = await _database.getTotalTodayRounds();

    _cachedSummary = DashboardSummary(
      totalRevenue: totalRevenue,
      totalRounds: totalRounds,
      totalCustomers: totalCustomers,
      todayRevenue: todayRevenue,
      todayRounds: todayRounds,
    );
    _lastSummaryUpdate = DateTime.now();

    return _cachedSummary!;
  }

  Future<List<DistanceStat>> getDistanceStats() async {
    if (_isCacheValid(_lastDistanceStatsUpdate) &&
        _cachedDistanceStats != null) {
      return _cachedDistanceStats!;
    }

    final stats = await _database.getDistanceStats();
    _cachedDistanceStats = stats.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    _lastDistanceStatsUpdate = DateTime.now();

    return _cachedDistanceStats!;
  }
}

class DashboardSummary {
  final int totalRevenue;
  final int totalRounds;
  final int totalCustomers;
  final int todayRevenue;
  final int todayRounds;

  DashboardSummary({
    required this.totalRevenue,
    required this.totalRounds,
    required this.totalCustomers,
    required this.todayRevenue,
    required this.todayRounds,
  });
}
