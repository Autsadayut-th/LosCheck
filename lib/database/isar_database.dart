import 'dart:async';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/isar_customer.dart';
import '../models/isar_trip.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';

class IsarDatabase {
  static IsarDatabase? _instance;
  Isar? _isar;
  final List<CustomerRecord> _inMemoryCustomers = [];
  final List<TripRecord> _inMemoryTrips = [];
  bool _useInMemory = false;
  final _customerStreamController = StreamController<List<CustomerRecord>>.broadcast();
  final _tripStreamController = StreamController<List<TripRecord>>.broadcast();

  IsarDatabase._();

  static IsarDatabase get instance {
    _instance ??= IsarDatabase._();
    return _instance!;
  }

  Isar get isar {
    if (_isar == null && !_useInMemory) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _isar!;
  }

  bool get isInitialized => _isar != null || _useInMemory;
  
  bool get isUsingInMemory => _useInMemory;

  Future<void> initialize() async {
    try {
      final existing = Isar.getInstance();
      if (existing != null) {
        _isar = existing;
        debugPrint('Using existing Isar instance');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      debugPrint('Initializing Isar database at: ${dir.path}');
      
      _isar = await Isar.open([
        IsarCustomerSchema,
        IsarTripSchema,
      ], directory: dir.path);
      
      debugPrint('Isar database initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Isar database: $e');
      debugPrint('Falling back to in-memory storage');
      _useInMemory = true;
      // Don't rethrow - use in-memory fallback
    }
  }

  // Customer operations
  Future<void> insertCustomer(CustomerRecord record) async {
    debugPrint('=== insertCustomer Called ===');
    debugPrint('Using in-memory: $_useInMemory');
    debugPrint('Record phone: ${record.phone}');
    debugPrint('Record name: ${record.name}');
    
    if (_useInMemory) {
      debugPrint('Using in-memory storage');
      // Remove existing customer with same phone
      _inMemoryCustomers.removeWhere((c) => c.phone == record.phone);
      _inMemoryCustomers.add(record);
      debugPrint('In-memory customers count: ${_inMemoryCustomers.length}');
      // Notify stream listeners
      _customerStreamController.add(List.from(_inMemoryCustomers));
      return;
    }
    
    debugPrint('Using Isar database');
    final isarCustomer = IsarCustomer.fromCustomerRecord(record);
    await _isar!.writeTxn(() async {
      await _isar!.isarCustomers.put(isarCustomer);
    });
    debugPrint('Isar insert completed');
  }

  Future<List<CustomerRecord>> getAllCustomers() async {
    if (_useInMemory) {
      return List.from(_inMemoryCustomers);
    }
    
    final customers = await _isar!.isarCustomers.where().findAll();
    return customers.map((c) => c.toCustomerRecord()).toList();
  }

  Future<CustomerRecord?> getCustomer(String phone) async {
    if (_useInMemory) {
      try {
        return _inMemoryCustomers.firstWhere((c) => c.phone == phone);
      } catch (e) {
        return null;
      }
    }
    
    final customer = await _isar!.isarCustomers
        .where()
        .phoneEqualTo(phone)
        .findFirst();
    return customer?.toCustomerRecord();
  }

  Future<void> updateCustomer(CustomerRecord record) async {
    if (_useInMemory) {
      final index = _inMemoryCustomers.indexWhere((c) => c.phone == record.phone);
      if (index != -1) {
        _inMemoryCustomers[index] = record;
      }
      return;
    }
    
    final isarCustomer = IsarCustomer.fromCustomerRecord(record);
    await _isar!.writeTxn(() async {
      await _isar!.isarCustomers.put(isarCustomer);
    });
  }

  Future<void> deleteCustomer(String phone) async {
    if (_useInMemory) {
      _inMemoryCustomers.removeWhere((c) => c.phone == phone);
      // Notify stream listeners
      _customerStreamController.add(List.from(_inMemoryCustomers));
      return;
    }
    
    await _isar!.writeTxn(() async {
      await _isar!.isarCustomers.where().phoneEqualTo(phone).deleteAll();
    });
  }

  Future<void> deleteAllCustomers() async {
    if (_useInMemory) {
      _inMemoryCustomers.clear();
      // Notify stream listeners
      _customerStreamController.add(List.from(_inMemoryCustomers));
      return;
    }
    
    await _isar!.writeTxn(() async {
      await _isar!.isarCustomers.clear();
    });
  }

  Stream<List<CustomerRecord>> watchAllCustomers() async* {
    if (_useInMemory) {
      yield List.from(_inMemoryCustomers);
      yield* _customerStreamController.stream;
      return;
    }
    
    yield await getAllCustomers();
    yield* _isar!.isarCustomers
        .where()
        .watch(fireImmediately: false)
        .map(
          (customers) => customers.map((c) => c.toCustomerRecord()).toList(),
        );
  }

  // Trip operations
  Future<int> insertTrip(TripRecord record) async {
    debugPrint('=== insertTrip Called ===');
    debugPrint('Using in-memory: $_useInMemory');
    debugPrint('Record: ${record.distanceLabel}, ${record.rounds} rounds, ${record.totalBaht} baht');
    debugPrint('Created at: ${record.createdAt}');
    
    if (_useInMemory) {
      debugPrint('Using in-memory storage');
      final newRecord = TripRecord(
        id: DateTime.now().millisecondsSinceEpoch,
        distanceLabel: record.distanceLabel,
        rateBaht: record.rateBaht,
        rounds: record.rounds,
        createdAt: record.createdAt,
      );
      _inMemoryTrips.add(newRecord);
      debugPrint('In-memory trips count: ${_inMemoryTrips.length}');
      // Notify stream listeners
      _tripStreamController.add(List.from(_inMemoryTrips));
      return newRecord.id!;
    }
    
    debugPrint('Using Isar database');
    final isarTrip = IsarTrip.fromTripRecord(record);
    int id = 0;
    await _isar!.writeTxn(() async {
      id = await _isar!.isarTrips.put(isarTrip);
    });
    debugPrint('Isar insert completed, ID: $id');
    return id;
  }

  Future<void> updateTrip(TripRecord record) async {
    if (_useInMemory) {
      final index = _inMemoryTrips.indexWhere((t) => t.id == record.id);
      if (index != -1) {
        _inMemoryTrips[index] = record;
        // Notify stream listeners
        _tripStreamController.add(List.from(_inMemoryTrips));
      }
      return;
    }
    
    final isarTrip = IsarTrip.fromTripRecord(record);
    await _isar!.writeTxn(() async {
      await _isar!.isarTrips.put(isarTrip);
    });
  }

  Future<List<TripRecord>> getAllTrips() async {
    if (_useInMemory) {
      return List.from(_inMemoryTrips);
    }
    
    final trips = await _isar!.isarTrips.where().findAll();
    return trips.map((t) => t.toTripRecord()).toList();
  }

  Future<List<TripRecord>> getTripsByDate(DateTime date) async {
    if (_useInMemory) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final startOfNextDay = startOfDay.add(const Duration(days: 1));
      return _inMemoryTrips.where((t) {
        return t.createdAt.isAfter(startOfDay) && t.createdAt.isBefore(startOfNextDay);
      }).toList();
    }
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));
    final trips = await _isar!.isarTrips
        .where()
        .filter()
        .createdAtGreaterThan(startOfDay)
        .createdAtLessThan(startOfNextDay)
        .findAll();
    return trips.map((t) => t.toTripRecord()).toList();
  }

  Future<void> deleteTrip(int id) async {
    if (_useInMemory) {
      _inMemoryTrips.removeWhere((t) => t.id == id);
      // Notify stream listeners
      _tripStreamController.add(List.from(_inMemoryTrips));
      return;
    }
    
    await _isar!.writeTxn(() async {
      await _isar!.isarTrips.delete(id);
    });
  }

  Future<void> deleteAllTrips() async {
    if (_useInMemory) {
      _inMemoryTrips.clear();
      // Notify stream listeners
      _tripStreamController.add(List.from(_inMemoryTrips));
      return;
    }
    
    await _isar!.writeTxn(() async {
      await _isar!.isarTrips.clear();
    });
  }

  Future<void> deleteTripsByDate(DateTime date) async {
    if (_useInMemory) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final startOfNextDay = startOfDay.add(const Duration(days: 1));
      _inMemoryTrips.removeWhere((t) {
        return t.createdAt.isAfter(startOfDay) && t.createdAt.isBefore(startOfNextDay);
      });
      // Notify stream listeners
      _tripStreamController.add(List.from(_inMemoryTrips));
      return;
    }
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));
    await _isar!.writeTxn(() async {
      await _isar!.isarTrips
          .where()
          .filter()
          .createdAtGreaterThan(startOfDay)
          .createdAtLessThan(startOfNextDay)
          .deleteAll();
    });
  }

  Stream<List<TripRecord>> watchAllTrips() async* {
    if (_useInMemory) {
      yield List.from(_inMemoryTrips);
      yield* _tripStreamController.stream;
      return;
    }
    
    yield await getAllTrips();
    yield* _isar!.isarTrips
        .where()
        .watch(fireImmediately: false)
        .map((trips) => trips.map((t) => t.toTripRecord()).toList());
  }

  Future<void> replaceTripsSnapshot(List<TripRecord> records) async {
    if (_useInMemory) {
      _inMemoryTrips.clear();
      _inMemoryTrips.addAll(records);
      return;
    }
    
    final existing = await _isar!.isarTrips.where().findAll();
    final existingIds = existing.map((trip) => trip.id).toSet();
    final memoryIds = records
        .map((record) => record.id)
        .whereType<int>()
        .toSet();
    final idsToDelete = existingIds.difference(memoryIds);
    final isarTrips = records.map(IsarTrip.fromTripRecord).toList();

    await _isar!.writeTxn(() async {
      for (final id in idsToDelete) {
        await _isar!.isarTrips.delete(id);
      }
      await _isar!.isarTrips.putAll(isarTrips);
    });
  }

  // Aggregate queries
  Future<int> getTotalTodayRounds() async {
    if (_useInMemory) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final startOfNextDay = startOfDay.add(const Duration(days: 1));
      return _inMemoryTrips.where((t) {
        return t.createdAt.isAfter(startOfDay) && t.createdAt.isBefore(startOfNextDay);
      }).fold<int>(0, (sum, trip) => sum + trip.rounds);
    }
    
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));
    final trips = await _isar!.isarTrips
        .where()
        .filter()
        .createdAtGreaterThan(startOfDay)
        .createdAtLessThan(startOfNextDay)
        .findAll();
    return trips.fold<int>(0, (sum, trip) => sum + trip.rounds);
  }

  Future<int> getTotalTodayBaht() async {
    if (_useInMemory) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final startOfNextDay = startOfDay.add(const Duration(days: 1));
      return _inMemoryTrips.where((t) {
        return t.createdAt.isAfter(startOfDay) && t.createdAt.isBefore(startOfNextDay);
      }).fold<int>(
        0,
        (sum, trip) => sum + (trip.rounds * trip.rateBaht),
      );
    }
    
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));
    final trips = await _isar!.isarTrips
        .where()
        .filter()
        .createdAtGreaterThan(startOfDay)
        .createdAtLessThan(startOfNextDay)
        .findAll();
    return trips.fold<int>(
      0,
      (sum, trip) => sum + (trip.rounds * trip.rateBaht),
    );
  }

  Future<int> getTotalCustomers() async {
    if (_useInMemory) {
      return _inMemoryCustomers.length;
    }
    
    return await _isar!.isarCustomers.where().count();
  }

  Future<int> getTotalRevenue() async {
    if (_useInMemory) {
      return _inMemoryTrips.fold<int>(
        0,
        (sum, trip) => sum + (trip.rounds * trip.rateBaht),
      );
    }
    
    final trips = await _isar!.isarTrips.where().findAll();
    return trips.fold<int>(
      0,
      (sum, trip) => sum + (trip.rounds * trip.rateBaht),
    );
  }

  Future<int> getTotalRounds() async {
    if (_useInMemory) {
      return _inMemoryTrips.fold<int>(0, (sum, trip) => sum + trip.rounds);
    }
    
    final trips = await _isar!.isarTrips.where().findAll();
    return trips.fold<int>(0, (sum, trip) => sum + trip.rounds);
  }

  Future<Map<String, DistanceStat>> getDistanceStats() async {
    if (_useInMemory) {
      final stats = <String, DistanceStat>{};
      for (final trip in _inMemoryTrips) {
        stats.putIfAbsent(
          trip.distanceLabel,
          () => DistanceStat(label: trip.distanceLabel, count: 0, total: 0),
        );
        stats[trip.distanceLabel]!.count += trip.rounds;
        stats[trip.distanceLabel]!.total += (trip.rounds * trip.rateBaht);
      }
      return stats;
    }
    
    final trips = await _isar!.isarTrips.where().findAll();
    final stats = <String, DistanceStat>{};
    for (final trip in trips) {
      stats.putIfAbsent(
        trip.distanceLabel,
        () => DistanceStat(label: trip.distanceLabel, count: 0, total: 0),
      );
      stats[trip.distanceLabel]!.count += trip.rounds;
      stats[trip.distanceLabel]!.total += (trip.rounds * trip.rateBaht);
    }
    return stats;
  }

  // Transaction support
  Future<void> transaction(Future<void> Function() action) async {
    if (_useInMemory) {
      await action();
      return;
    }
    
    await _isar!.writeTxn(() async {
      await action();
    });
  }

  // Batch operations
  Future<void> batchInsertTrips(List<TripRecord> records) async {
    if (_useInMemory) {
      for (final record in records) {
        final newRecord = TripRecord(
          id: DateTime.now().millisecondsSinceEpoch,
          distanceLabel: record.distanceLabel,
          rateBaht: record.rateBaht,
          rounds: record.rounds,
          createdAt: record.createdAt,
        );
        _inMemoryTrips.add(newRecord);
      }
      // Notify stream listeners
      _tripStreamController.add(List.from(_inMemoryTrips));
      return;
    }
    
    await _isar!.writeTxn(() async {
      for (final record in records) {
        final isarTrip = IsarTrip.fromTripRecord(record);
        await _isar!.isarTrips.put(isarTrip);
      }
    });
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

// Application-level single instance for simple usage from UI code.
final IsarDatabase appDatabase = IsarDatabase.instance;
