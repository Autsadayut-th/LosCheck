import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';

// Manual Hive TypeAdapter for CustomerRecord
class CustomerRecordAdapter extends TypeAdapter<CustomerRecord> {
  @override
  final int typeId = 0;

  @override
  CustomerRecord read(BinaryReader reader) {
    return CustomerRecord(
      phone: reader.readString(),
      name: reader.readString(),
      address: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      imageUrl: reader.read() as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CustomerRecord obj) {
    writer.writeString(obj.phone);
    writer.writeString(obj.name);
    writer.writeString(obj.address);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.write(obj.imageUrl);
  }
}

// Manual Hive TypeAdapter for TripRecord
class TripRecordAdapter extends TypeAdapter<TripRecord> {
  @override
  final int typeId = 1;

  @override
  TripRecord read(BinaryReader reader) {
    return TripRecord(
      distanceLabel: reader.readString(),
      rateBaht: reader.readInt(),
      rounds: reader.readInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, TripRecord obj) {
    writer.writeString(obj.distanceLabel);
    writer.writeInt(obj.rateBaht);
    writer.writeInt(obj.rounds);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

class HiveDatabase {
  static HiveDatabase? _instance;
  bool _isInitialized = false;
  
  // Set this to true in tests to bypass Hive box disk IO and use in-memory maps instead.
  static bool isTesting = false;

  final Map<String, CustomerRecord> _testCustomers = {};
  final Map<int, TripRecord> _testTrips = {};
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

  Box<CustomerRecord> get _customerBox => Hive.box<CustomerRecord>('customers');
  Box<TripRecord> get _tripBox => Hive.box<TripRecord>('trips');

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (isTesting) {
      _isInitialized = true;
      debugPrint('Hive database initialized in test mode (In-Memory)');
      return;
    }
    await Hive.initFlutter();
    
    // Register custom manual TypeAdapters
    Hive.registerAdapter(CustomerRecordAdapter());
    Hive.registerAdapter(TripRecordAdapter());
    
    await Hive.openBox<CustomerRecord>('customers');
    await Hive.openBox<TripRecord>('trips');
    _isInitialized = true;
    debugPrint('Hive database initialized successfully');
  }

  // Customer operations
  Future<void> insertCustomer(CustomerRecord record) async {
    debugPrint('=== insertCustomer Called (Hive) ===');
    if (isTesting) {
      _testCustomers[record.phone] = record;
      _customerStreamController.add(await getAllCustomers());
      return;
    }
    await _customerBox.put(record.phone, record);
  }

  Future<List<CustomerRecord>> getAllCustomers() async {
    if (isTesting) {
      return _testCustomers.values.toList();
    }
    return _customerBox.values.toList();
  }

  Future<CustomerRecord?> getCustomer(String phone) async {
    if (isTesting) {
      return _testCustomers[phone];
    }
    return _customerBox.get(phone);
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
      return _customerBox.values.toList();
    });
  }

  // Trip operations
  Future<int> insertTrip(TripRecord record) async {
    debugPrint('=== insertTrip Called (Hive) ===');
    if (isTesting) {
      final id = _testTripIdCounter++;
      _testTrips[id] = record;
      _tripStreamController.add(await getAllTrips());
      debugPrint('Trip inserted (Test Mode), ID: $id');
      return id;
    }
    final key = await _tripBox.add(record);
    debugPrint('Trip inserted, key/id: $key');
    return key;
  }

  Future<void> updateTrip(TripRecord record) async {
    if (isTesting) {
      if (record.id != null) {
        _testTrips[record.id!] = record;
        _tripStreamController.add(await getAllTrips());
      }
      return;
    }
    if (record.id != null) {
      await _tripBox.put(record.id, record);
    }
  }

  Future<List<TripRecord>> getAllTrips() async {
    if (isTesting) {
      return _testTrips.keys.map((key) {
        final trip = _testTrips[key]!;
        return TripRecord(
          id: key,
          distanceLabel: trip.distanceLabel,
          rateBaht: trip.rateBaht,
          rounds: trip.rounds,
          createdAt: trip.createdAt,
        );
      }).toList();
    }
    return _tripBox.keys.map((key) {
      final trip = _tripBox.get(key)!;
      return TripRecord(
        id: key as int,
        distanceLabel: trip.distanceLabel,
        rateBaht: trip.rateBaht,
        rounds: trip.rounds,
        createdAt: trip.createdAt,
      );
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
        final trip = _tripBox.get(key)!;
        return TripRecord(
          id: key as int,
          distanceLabel: trip.distanceLabel,
          rateBaht: trip.rateBaht,
          rounds: trip.rounds,
          createdAt: trip.createdAt,
        );
      }).toList();
    });
  }

  Future<void> replaceTripsSnapshot(List<TripRecord> records) async {
    if (isTesting) {
      _testTrips.clear();
      for (final r in records) {
        final id = r.id ?? _testTripIdCounter++;
        _testTrips[id] = r;
      }
      _tripStreamController.add(await getAllTrips());
      return;
    }
    await _tripBox.clear();
    for (final r in records) {
      if (r.id != null) {
        await _tripBox.put(r.id, r);
      } else {
        await _tripBox.add(r);
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

  // Batch operations (Bulk write optimizations)
  Future<void> batchInsertTrips(List<TripRecord> records) async {
    if (isTesting) {
      for (final r in records) {
        final id = _testTripIdCounter++;
        _testTrips[id] = r;
      }
      _tripStreamController.add(await getAllTrips());
      return;
    }
    await _tripBox.addAll(records);
  }

  Future<void> batchInsertCustomers(List<CustomerRecord> records) async {
    if (isTesting) {
      for (final r in records) {
        _testCustomers[r.phone] = r;
      }
      _customerStreamController.add(await getAllCustomers());
      return;
    }
    final Map<String, CustomerRecord> dataMap = {
      for (final r in records) r.phone: r
    };
    await _customerBox.putAll(dataMap);
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
