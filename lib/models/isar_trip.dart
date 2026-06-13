import 'package:isar/isar.dart';
import 'trip_record.dart';

part 'isar_trip.g.dart';

@collection
class IsarTrip {
  Id id = Isar.autoIncrement;

  late String distanceLabel;
  late int rateBaht;
  late int rounds;
  late DateTime createdAt;

  // Convert to the existing TripRecord model
  TripRecord toTripRecord() {
    return TripRecord(
      id: id,
      distanceLabel: distanceLabel,
      rateBaht: rateBaht,
      rounds: rounds,
      createdAt: createdAt,
    );
  }

  // Create from the existing TripRecord model
  static IsarTrip fromTripRecord(TripRecord record) {
    return IsarTrip()
      ..id = record.id ?? Isar.autoIncrement
      ..distanceLabel = record.distanceLabel
      ..rateBaht = record.rateBaht
      ..rounds = record.rounds
      ..createdAt = record.createdAt;
  }
}
