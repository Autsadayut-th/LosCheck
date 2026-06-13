import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';
import '../database/hive_database.dart';

class AppStateProvider extends ChangeNotifier {
  List<CustomerRecord> _customers = [];
  List<TripRecord> _trips = [];
  bool _isLoading = true;
  String? _error;

  StreamSubscription<List<CustomerRecord>>? _customerSubscription;
  StreamSubscription<List<TripRecord>>? _tripSubscription;

  List<CustomerRecord> get customers => _customers;
  List<TripRecord> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppStateProvider() {
    _init();
  }

  void _init() {
    _isLoading = true;
    _error = null;

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

  @override
  void dispose() {
    _customerSubscription?.cancel();
    _tripSubscription?.cancel();
    super.dispose();
  }
}
