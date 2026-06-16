import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';
import '../models/route_completion_record.dart';
import '../database/hive_database.dart';

class AppStateProvider extends ChangeNotifier {
  List<CustomerRecord> _customers = [];
  List<TripRecord> _trips = [];
  List<RouteCompletionRecord> _routeCompletions = [];
  bool _isLoading = true;
  String? _error;

  int _completedDeliveryPoints = 0;
  double _completedRouteDistance = 0.0;

  StreamSubscription<List<CustomerRecord>>? _customerSubscription;
  StreamSubscription<List<TripRecord>>? _tripSubscription;
  StreamSubscription<List<RouteCompletionRecord>>? _completionSubscription;

  List<CustomerRecord> get customers => _customers;
  List<TripRecord> get trips => _trips;
  List<RouteCompletionRecord> get routeCompletions => _routeCompletions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get completedDeliveryPoints => _completedDeliveryPoints;
  double get completedRouteDistance => _completedRouteDistance;

  static const String _prefKeyPoints = 'completed_delivery_points';
  static const String _prefKeyDistance = 'completed_route_distance';
  static const String _prefKeyDate = 'navigation_stats_date';

  AppStateProvider() {
    _init();
  }

  void _init() {
    _isLoading = true;
    _error = null;
    loadNavigationStats();

    // Listen to customers watch stream
    _customerSubscription = appDatabase.watchAllCustomers().listen(
      (data) {
        _customers = List<CustomerRecord>.from(data)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _checkLoadingComplete();
      },
      onError: (err) {
        _error = err.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    // Listen to trips watch stream
    _tripSubscription = appDatabase.watchAllTrips().listen(
      (data) {
        _trips = List<TripRecord>.from(data)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _checkLoadingComplete();
      },
      onError: (err) {
        _error = err.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    // Listen to route completions watch stream
    _completionSubscription = appDatabase.watchAllRouteCompletions().listen(
      (data) {
        _routeCompletions = List<RouteCompletionRecord>.from(data)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _recalculateTodayStats();
        _checkLoadingComplete();
      },
      onError: (err) {
        _error = err.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _checkLoadingComplete() {
    if (_isLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }

  void _recalculateTodayStats() {
    final today = DateTime.now();
    int pointsSum = 0;
    double distSum = 0.0;
    for (final comp in _routeCompletions) {
      if (comp.isSameDay(today)) {
        pointsSum += comp.points;
        distSum += comp.distance;
      }
    }
    _completedDeliveryPoints = pointsSum;
    _completedRouteDistance = distSum;
  }

  Future<void> loadNavigationStats() async {
    try {
      final comps = await appDatabase.getAllRouteCompletions();
      // If there are no database completion records but legacy SharedPreferences data exists, migrate it
      if (comps.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final todayStr = _getTodayKey();
        final savedDate = prefs.getString(_prefKeyDate);
        if (savedDate == todayStr) {
          final points = prefs.getInt(_prefKeyPoints) ?? 0;
          final distance = prefs.getDouble(_prefKeyDistance) ?? 0.0;
          if (points > 0 || distance > 0.0) {
            final record = RouteCompletionRecord(
              points: points,
              distance: distance,
              createdAt: DateTime.now(),
            );
            await appDatabase.insertRouteCompletion(record);
            // Clear SharedPreferences legacy keys so we don't migrate again
            await prefs.remove(_prefKeyPoints);
            await prefs.remove(_prefKeyDistance);
            await prefs.remove(_prefKeyDate);
          }
        }
      }
    } catch (_) {
      // Gracefully ignore failures during migration
    }
  }

  Future<void> recordRouteCompletion(int points, double distance) async {
    try {
      final record = RouteCompletionRecord(
        points: points,
        distance: distance,
        createdAt: DateTime.now(),
      );
      await appDatabase.insertRouteCompletion(record);
    } catch (_) {
      // Fallback in case of database failures
      _completedDeliveryPoints += points;
      _completedRouteDistance += distance;
      notifyListeners();
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _customerSubscription?.cancel();
    _tripSubscription?.cancel();
    _completionSubscription?.cancel();
    super.dispose();
  }
}
