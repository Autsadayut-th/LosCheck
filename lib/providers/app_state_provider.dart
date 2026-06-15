import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';
import '../database/hive_database.dart';

class AppStateProvider extends ChangeNotifier {
  List<CustomerRecord> _customers = [];
  List<TripRecord> _trips = [];
  bool _isLoading = true;
  String? _error;

  int _completedDeliveryPoints = 0;
  double _completedRouteDistance = 0.0;

  StreamSubscription<List<CustomerRecord>>? _customerSubscription;
  StreamSubscription<List<TripRecord>>? _tripSubscription;

  List<CustomerRecord> get customers => _customers;
  List<TripRecord> get trips => _trips;
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
  }

  void _checkLoadingComplete() {
    if (_isLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> loadNavigationStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayKey();
      final savedDate = prefs.getString(_prefKeyDate);
      
      if (savedDate != todayStr) {
        // Reset daily stats
        _completedDeliveryPoints = 0;
        _completedRouteDistance = 0.0;
        await prefs.setString(_prefKeyDate, todayStr);
        await prefs.setInt(_prefKeyPoints, 0);
        await prefs.setDouble(_prefKeyDistance, 0.0);
      } else {
        _completedDeliveryPoints = prefs.getInt(_prefKeyPoints) ?? 0;
        _completedRouteDistance = prefs.getDouble(_prefKeyDistance) ?? 0.0;
      }
      notifyListeners();
    } catch (_) {
      // SharedPreferences failures fall back to default (0)
    }
  }

  Future<void> recordRouteCompletion(int points, double distance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayKey();
      final savedDate = prefs.getString(_prefKeyDate);

      if (savedDate != todayStr) {
        _completedDeliveryPoints = points;
        _completedRouteDistance = distance;
        await prefs.setString(_prefKeyDate, todayStr);
      } else {
        _completedDeliveryPoints += points;
        _completedRouteDistance += distance;
      }

      await prefs.setInt(_prefKeyPoints, _completedDeliveryPoints);
      await prefs.setDouble(_prefKeyDistance, _completedRouteDistance);
      notifyListeners();
    } catch (_) {
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
    super.dispose();
  }
}
