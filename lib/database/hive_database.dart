import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';

class HiveDatabase {
  static HiveDatabase? _instance;
  bool _isInitialized = false;
  
  // Set this to true in tests to bypass Hive box disk IO and use in-memory maps instead.
  static bool isTesting = false;

  final Map<String, Map> _testCustomers = {};
  final Map<int, Map> _testTrips = {};
  int _testTripIdCounter = 0;

  final _customerStreamController = StreamController<List<CustomerRecord>>.broadcast();
  final _tripStreamController = StreamController<List<TripRecord>>.broadcast();

  HiveDatabase._();

  static HiveDatabase get instance {
    _instance ??= HiveDatabase._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;
  
  bool get isUsingInMemory => isTesting;

  Box<Map> get _customerBox => Hive.box<Map>('customers');
  Box<Map> get _tripBox => Hive.box<Map>('trips');

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (isTesting) {
      _isInitialized = true;
      debugPrint('Hive database initialized in test mode (In-Memory)');
      return;
    }
    await Hive.initFlutter();
    await Hive.openBox<Map>('customers');
    await Hive.openBox<Map>('trips');
    _isInitialized = true;
    debugPrint('Hive database initialized successfully');
  }

  // Customer operations
  Future<void> insertCustomer(CustomerRecord record) async {
    debugPrint('=== insertCustomer Called (Hive) ===');
    if (isTesting) {
      _testCustomers[record.phone] = record.toJson();
      _customerStreamController.add(await getAllCustomers());
      return;
    }
    await _customerBox.put(record.phone, record.toJson());
  }

  Future<List<CustomerRecord>> getAllCustomers() async {
    if (isTesting) {
      return _testCustomers.values
          .map((m) => CustomerRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return _customerBox.values
        .map((m) => CustomerRecord.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<CustomerRecord?> getCustomer(String phone) async {
    if (isTesting) {
      final data = _testCustomers[phone];
      if (data == null) return null;
      return CustomerRecord.fromJson(Map<String, dynamic>.from(data));
    }
    final data = _customerBox.get(phone);
    if (data == null) return null;
    return CustomerRecord.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateCustomer(CustomerRecord record) async {
    await insertCustomer(record);
  }

  Future<void> deleteCustomer(String phone) async {
    if (isTesting) {
      _testCustomers.remove(phone);
      _customerStreamController.add(await getAllCustomers());
      return;
    }
    await _customerBox.delete(phone);
  }

  Future<void> deleteAllCustomers() async {
    if (isTesting) {
      _testCustomers.clear();
      _customerStreamController.add([]);
      return;
    }
    await _customerBox.clear();
  }

  Stream<List<CustomerRecord>> watchAllCustomers() async* {
    if (isTesting) {
      yield await getAllCustomers();
      yield* _customerStreamController.stream;
      return;
    }
    yield await getAllCustomers();
    yield* _customerBox.watch().map((_) {
      return _customerBox.values
          .map((m) => CustomerRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  // Trip operations
  Future<int> insertTrip(TripRecord record) async {
    debugPrint('=== insertTrip Called (Hive) ===');
    if (isTesting) {
      final id = _testTripIdCounter++;
      _testTrips[id] = record.toJson();
      _tripStreamController.add(await getAllTrips());
      debugPrint('Trip inserted (Test Mode), ID: $id');
      return id;
    }
    final jsonMap = record.toJson();
    final key = await _tripBox.add(jsonMap);
    debugPrint('Trip inserted, key/id: $key');
    return key;
  }

  Future<void> updateTrip(TripRecord record) async {
    if (isTesting) {
      if (record.id != null) {
        _testTrips[record.id!] = record.toJson();
        _tripStreamController.add(await getAllTrips());
      }
      return;
    }
    if (record.id != null) {
      await _tripBox.put(record.id, record.toJson());
    }
  }

  Future<List<TripRecord>> getAllTrips() async {
    if (isTesting) {
      return _testTrips.keys.map((key) {
        final map = Map<String, dynamic>.from(_testTrips[key]!);
        return TripRecord.fromJson(map, id: key);
      }).toList();
    }
    return _tripBox.keys.map((key) {
      final map = Map<String, dynamic>.from(_tripBox.get(key)!);
      return TripRecord.fromJson(map, id: key as int);
    }).toList();
  }

  Future<List<TripRecord>> getTripsByDate(DateTime date) async {
    final all = await getAllTrips();
    return all.where((t) => t.isSameDay(date)).toList();
  }

  Future<void> deleteTrip(int id) async {
    if (isTesting) {
      _testTrips.remove(id);
      _tripStreamController.add(await getAllTrips());
      return;
    }
    await _tripBox.delete(id);
  }

  Future<void> deleteAllTrips() async {
    if (isTesting) {
      _testTrips.clear();
      _tripStreamController.add([]);
      return;
    }
    await _tripBox.clear();
  }

  Future<void> deleteTripsByDate(DateTime date) async {
    if (isTesting) {
      final trips = await getAllTrips();
      for (final trip in trips) {
        if (trip.isSameDay(date)) {
          _testTrips.remove(trip.id);
        }
      }
      _tripStreamController.add(await getAllTrips());
      return;
    }
    final trips = await getAllTrips();
    for (final trip in trips) {
      if (trip.isSameDay(date)) {
        await _tripBox.delete(trip.id);
      }
    }
  }

  Stream<List<TripRecord>> watchAllTrips() async* {
    if (isTesting) {
      yield await getAllTrips();
      yield* _tripStreamController.stream;
      return;
    }
    yield await getAllTrips();
    yield* _tripBox.watch().map((_) {
      return _tripBox.keys.map((key) {
        final map = Map<String, dynamic>.from(_tripBox.get(key)!);
        return TripRecord.fromJson(map, id: key as int);
      }).toList();
    });
  }

  Future<void> replaceTripsSnapshot(List<TripRecord> records) async {
    if (isTesting) {
      _testTrips.clear();
      for (final r in records) {
        final id = r.id ?? _testTripIdCounter++;
        _testTrips[id] = r.toJson();
      }
      _tripStreamController.add(await getAllTrips());
      return;
    }
    await _tripBox.clear();
    for (final r in records) {
      if (r.id != null) {
        await _tripBox.put(r.id, r.toJson());
      } else {
        await _tripBox.add(r.toJson());
      }
    }
  }

  // Aggregate queries
  Future<int> getTotalTodayRounds() async {
    final today = DateTime.now();
    final trips = await getTripsByDate(today);
    return trips.fold<int>(0, (sum, trip) => sum + trip.rounds);
  }

  Future<int> getTotalTodayBaht() async {
    final today = DateTime.now();
    final trips = await getTripsByDate(today);
    return trips.fold<int>(0, (sum, trip) => sum + trip.totalBaht);
  }

  Future<int> getTotalCustomers() async {
    if (isTesting) {
      return _testCustomers.length;
    }
    return _customerBox.length;
  }

  Future<int> getTotalRevenue() async {
    final trips = await getAllTrips();
    return trips.fold<int>(0, (sum, trip) => sum + trip.totalBaht);
  }

  Future<int> getTotalRounds() async {
    final trips = await getAllTrips();
    return trips.fold<int>(0, (sum, trip) => sum + trip.rounds);
  }

  Future<Map<String, DistanceStat>> getDistanceStats() async {
    final trips = await getAllTrips();
    final stats = <String, DistanceStat>{};
    for (final trip in trips) {
      stats.putIfAbsent(
        trip.distanceLabel,
        () => DistanceStat(label: trip.distanceLabel, count: 0, total: 0),
      );
      stats[trip.distanceLabel]!.count += trip.rounds;
      stats[trip.distanceLabel]!.total += trip.totalBaht;
    }
    return stats;
  }

  // Transaction support (Simulated)
  Future<void> transaction(Future<void> Function() action) async {
    await action();
  }

  // Batch operations
  Future<void> batchInsertTrips(List<TripRecord> records) async {
    for (final record in records) {
      await insertTrip(record);
    }
  }

  void dispose() {
    _customerStreamController.close();
    _tripStreamController.close();
  }
}

class DistanceStat {
  final String label;
  int count;
  int total;

  DistanceStat({required this.label, required this.count, required this.total});
}

final HiveDatabase appDatabase = HiveDatabase.instance;
