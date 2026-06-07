import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/web.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/customer_record.dart';
import '../models/trip_record.dart';

part 'app_database.g.dart';

@DataClassName('CustomerRecordData')
class CustomerRecords extends Table {
  TextColumn get phone => text()();
  TextColumn get name => text()();
  TextColumn get address => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {phone};
}

@DataClassName('TripRecordData')
class TripRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get distanceLabel => text()();
  IntColumn get rateBaht => integer()();
  IntColumn get rounds => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [CustomerRecords, TripRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Add future schema migrations here
      // Example: if (from < 2) { await m.addColumn(customerRecords, customerRecords.email); }
    },
  );

  // Customer operations
  Future<void> insertCustomer(CustomerRecord record) {
    return into(customerRecords).insert(
      CustomerRecordsCompanion(
        phone: Value(record.phone),
        name: Value(record.name),
        address: Value(record.address),
        createdAt: Value(record.createdAt),
      ),
      onConflict: DoUpdate(
        (_) => CustomerRecordsCompanion(
          name: Value(record.name),
          address: Value(record.address),
          createdAt: Value(record.createdAt),
        ),
      ),
    );
  }

  Future<List<CustomerRecordData>> getAllCustomers() {
    return select(customerRecords).get();
  }

  Future<CustomerRecordData?> getCustomer(String phone) {
    return (select(
      customerRecords,
    )..where((t) => t.phone.equals(phone))).getSingleOrNull();
  }

  Future<void> updateCustomer(CustomerRecord record) {
    return update(customerRecords).replace(
      CustomerRecordsCompanion(
        phone: Value(record.phone),
        name: Value(record.name),
        address: Value(record.address),
        createdAt: Value(record.createdAt),
      ),
    );
  }

  Future<void> deleteCustomer(String phone) {
    return (delete(customerRecords)..where((t) => t.phone.equals(phone))).go();
  }

  Future<void> deleteAllCustomers() {
    return delete(customerRecords).go();
  }

  Stream<List<CustomerRecordData>> watchAllCustomers() {
    return select(customerRecords).watch();
  }

  // Trip operations
  Future<void> insertTrip(TripRecord record) {
    return into(tripRecords).insert(
      TripRecordsCompanion(
        distanceLabel: Value(record.distanceLabel),
        rateBaht: Value(record.rateBaht),
        rounds: Value(record.rounds),
        createdAt: Value(record.createdAt),
      ),
    );
  }

  Future<List<TripRecordData>> getAllTrips() {
    return select(tripRecords).get();
  }

  Future<List<TripRecordData>> getTripsByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return (select(tripRecords)..where(
          (t) =>
              t.createdAt.isBiggerOrEqualValue(startOfDay) &
              t.createdAt.isSmallerThanValue(endOfDay),
        ))
        .get();
  }

  Future<void> deleteTrip(int id) {
    return (delete(tripRecords)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAllTrips() {
    return delete(tripRecords).go();
  }

  Future<void> deleteTripsByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return (delete(tripRecords)..where(
          (t) =>
              t.createdAt.isBiggerOrEqualValue(startOfDay) &
              t.createdAt.isSmallerThanValue(endOfDay),
        ))
        .go();
  }

  Stream<List<TripRecordData>> watchAllTrips() {
    return select(tripRecords).watch();
  }

  // Aggregate queries (SQL-based for performance)
  Future<int> getTotalTodayRounds() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final result =
        await (select(tripRecords)..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(startOfDay) &
                  t.createdAt.isSmallerThanValue(endOfDay),
            ))
            .map((trip) => trip.rounds)
            .get();

    return result.fold<int>(0, (sum, rounds) => sum + rounds);
  }

  Future<int> getTotalTodayBaht() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final result =
        await (select(tripRecords)..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(startOfDay) &
                  t.createdAt.isSmallerThanValue(endOfDay),
            ))
            .get();

    return result.fold<int>(
      0,
      (sum, trip) => sum + (trip.rounds * trip.rateBaht),
    );
  }

  Future<int> getTotalCustomers() async {
    return (select(customerRecords)..limit(1)).get().then((result) {
      if (result.isEmpty) return 0;
      return select(customerRecords).get().then((records) => records.length);
    });
  }

  Future<int> getTotalRevenue() async {
    final trips = await select(tripRecords).get();
    return trips.fold<int>(
      0,
      (sum, trip) => sum + (trip.rounds * trip.rateBaht),
    );
  }

  Future<int> getTotalRounds() async {
    final trips = await select(tripRecords).get();
    return trips.fold<int>(0, (sum, trip) => sum + trip.rounds);
  }

  Future<Map<String, DistanceStat>> getDistanceStats() async {
    final trips = await select(tripRecords).get();
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
}

class DistanceStat {
  final String label;
  int count;
  int total;

  DistanceStat({required this.label, required this.count, required this.total});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (kIsWeb) {
      return WebDatabase('loscheck_db');
    } else {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'app.db'));
      return NativeDatabase(file);
    }
  });
}

// Application-level single instance for simple usage from UI code.
final AppDatabase appDatabase = AppDatabase();
