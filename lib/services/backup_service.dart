import 'dart:convert';
import 'package:intl/intl.dart';

import '../database/hive_database.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';

class BackupService {
  static const String _version = '1.0';

  /// Export all data as JSON string (for backup/migration)
  static Future<String> exportToJson() async {
    final customers = await appDatabase.getAllCustomers();
    final trips = await appDatabase.getAllTrips();

    final data = {
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': customers
          .map(
            (c) => {
              'phone': c.phone,
              'name': c.name,
              'address': c.address,
              'createdAt': c.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'trips': trips
          .map(
            (t) => {
              'distanceLabel': t.distanceLabel,
              'rateBaht': t.rateBaht,
              'rounds': t.rounds,
              'createdAt': t.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };

    return jsonEncode(data);
  }

  /// Generate a backup filename with timestamp
  static String generateBackupFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'loscheck_backup_${formatter.format(now)}.json';
  }

  static Future<void> importFromJson(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Validate version
      final version = data['version'] as String?;
      if (version != _version) {
        throw Exception(
          'Invalid backup version: $version (expected: $_version)',
        );
      }

      // ล้างข้อมูลเก่าทั้งหมดก่อนอิมพอร์ตตามข้อกำหนดในการเขียนทับ
      await clearAllData();

      final customersList = data['customers'] as List<dynamic>?;
      if (customersList != null) {
        for (final customerData in customersList) {
          final customer = CustomerRecord(
            phone: customerData['phone'] as String,
            name: customerData['name'] as String,
            address: customerData['address'] as String,
            createdAt: DateTime.parse(customerData['createdAt'] as String),
          );
          await appDatabase.insertCustomer(customer);
        }
      }

      // Import trips
      final tripsList = data['trips'] as List<dynamic>?;
      if (tripsList != null) {
        for (final tripData in tripsList) {
          final trip = TripRecord(
            distanceLabel: tripData['distanceLabel'] as String,
            rateBaht: tripData['rateBaht'] as int,
            rounds: tripData['rounds'] as int,
            createdAt: DateTime.parse(tripData['createdAt'] as String),
          );
          await appDatabase.insertTrip(trip);
        }
      }
    } catch (e) {
      throw Exception('Failed to import backup: ${e.toString()}');
    }
  }

  /// Clear all data (use with caution)
  static Future<void> clearAllData() async {
    await appDatabase.deleteAllCustomers();
    await appDatabase.deleteAllTrips();
  }

  /// Merge backup data (append instead of replace)
  static Future<void> mergeFromJson(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Merge customers
      final customersList = data['customers'] as List<dynamic>?;
      if (customersList != null) {
        for (final customerData in customersList) {
          final customer = CustomerRecord(
            phone: customerData['phone'] as String,
            name: customerData['name'] as String,
            address: customerData['address'] as String,
            createdAt: DateTime.parse(customerData['createdAt'] as String),
          );
          await appDatabase.insertCustomer(customer);
        }
      }

      // Merge trips
      final tripsList = data['trips'] as List<dynamic>?;
      if (tripsList != null) {
        for (final tripData in tripsList) {
          final trip = TripRecord(
            distanceLabel: tripData['distanceLabel'] as String,
            rateBaht: tripData['rateBaht'] as int,
            rounds: tripData['rounds'] as int,
            createdAt: DateTime.parse(tripData['createdAt'] as String),
          );
          await appDatabase.insertTrip(trip);
        }
      }
    } catch (e) {
      throw Exception('Failed to merge backup: ${e.toString()}');
    }
  }
}
