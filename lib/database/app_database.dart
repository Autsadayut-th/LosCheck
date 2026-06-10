import 'package:drift/drift.dart';

import '../models/customer_record.dart';
import '../models/trip_record.dart';
import 'connection/connection.dart';

part 'app_database.g.dart';

@DataClassName('CustomerRecordData')
class CustomerRecords extends Table {
  TextColumn get phone => text()();
  TextColumn get name => text()();
  TextColumn get address => text()();
  TextColumn get imageUrl => text().nullable()();
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
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // v1 -> v2: add nullable imageUrl column for customer records.
      // The generated column reference (`customerRecords.imageUrl`) is not
      // available until build_runner has run, so we describe the column
      // inline using Drift's DSL and cast through `dynamic` to keep the
      // migration code compilable pre-generation.
      if (from < 2) {
        await m.addColumn(customerRecords, customerRecords.imageUrl);
      }
    },
  );

  // Customer operations
  Future<void> insertCustomer(CustomerRecord record) {
    return into(customerRecords).insert(
      CustomerRecordsCompanion(
        phone: Value(record.phone),
        name: Value(record.name),
        address: Value(record.address),
        imageUrl: Value(record.imageUrl),
        createdAt: Value(record.createdAt),
      ),
      onConflict: DoUpdate(
        (_) => CustomerRecordsCompanion(
          name: Value(record.name),
          address: Value(record.address),
          imageUrl: Value(record.imageUrl),
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
        imageUrl: Value(record.imageUrl),
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
  /// Returns the newly-inserted row id.
  Future<int> insertTrip(TripRecord record) {
    return into(tripRecords).insert(
      TripRecordsCompanion(
        distanceLabel: Value(record.distanceLabel),
        rateBaht: Value(record.rateBaht),
        rounds: Value(record.rounds),
        createdAt: Value(record.createdAt),
      ),
    );
  }

  Future<void> updateTrip(TripRecord record) async {
    if (record.id == null) {
      throw ArgumentError('Cannot update trip without id');
    }
    await (update(tripRecords)..where((t) => t.id.equals(record.id!))).write(
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
    // Use exclusive start-of-next-day instead of `23:59:59` so records
    // created at the millisecond of the last second of the day are not
    // silently dropped.
    final startOfNextDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(const Duration(days: 1));
    return (select(tripRecords)..where(
          (t) =>
              t.createdAt.isBiggerOrEqualValue(startOfDay) &
              t.createdAt.isSmallerThanValue(startOfNextDay),
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
    final startOfNextDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(const Duration(days: 1));
    return (delete(tripRecords)..where(
          (t) =>
              t.createdAt.isBiggerOrEqualValue(startOfDay) &
              t.createdAt.isSmallerThanValue(startOfNextDay),
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
    // Exclusive start-of-next-day to avoid losing records that land on
    // `23:59:59.500` (or any other fractional second of the day).
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    final result =
        await (select(tripRecords)..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(startOfDay) &
                  t.createdAt.isSmallerThanValue(startOfNextDay),
            ))
            .map((trip) => trip.rounds)
            .get();

    return result.fold<int>(0, (sum, rounds) => sum + rounds);
  }

  Future<int> getTotalTodayBaht() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    final result =
        await (select(tripRecords)..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(startOfDay) &
                  t.createdAt.isSmallerThanValue(startOfNextDay),
            ))
            .get();

    return result.fold<int>(
      0,
      (sum, trip) => sum + (trip.rounds * trip.rateBaht),
    );
  }

  Future<int> getTotalCustomers() async {
    final countExp = customerRecords.phone.count();
    final query = selectOnly(customerRecords)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
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

// Application-level single instance for simple usage from UI code.
final AppDatabase appDatabase = AppDatabase();
