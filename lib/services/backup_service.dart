import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../database/hive_database.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';

class BackupService {
  static const String _version = '1.0';

  /// Decodes JSON on a separate isolate to avoid UI thread jank
  static Map<String, dynamic> _decodeJson(String jsonStr) {
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Export all data as JSON string (for backup/migration)
  static Future<String> exportToJson() async {
    final customers = await appDatabase.getAllCustomers();
    final trips = await appDatabase.getAllTrips();

    final data = {
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': customers.map((c) => c.toJson()).toList(),
      'trips': trips.map((t) => t.toJson()).toList(),
    };

    // Serialize JSON on a background isolate
    return compute(jsonEncode, data);
  }

  /// Generate a backup filename with timestamp
  static String generateBackupFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'loscheck_backup_${formatter.format(now)}.json';
  }

  static Future<void> importFromJson(String jsonData) async {
    try {
      // Decode JSON in background isolate
      final decoded = await compute(_decodeJson, jsonData);
      final data = decoded;

      // Validate version
      final version = data['version'] as String?;
      if (version != _version) {
        throw Exception(
          'Invalid backup version: $version (expected: $_version)',
        );
      }

      // Clear all old data before replacing
      await clearAllData();

      final customersList = data['customers'] as List<dynamic>?;
      if (customersList != null) {
        final List<CustomerRecord> customers = [];
        for (final customerData in customersList) {
          customers.add(CustomerRecord.fromJson(Map<String, dynamic>.from(customerData as Map)));
        }
        // Write all customers to Hive in a single bulk transaction
        await appDatabase.batchInsertCustomers(customers);
      }

      // Import trips
      final tripsList = data['trips'] as List<dynamic>?;
      if (tripsList != null) {
        final List<TripRecord> trips = [];
        for (final tripData in tripsList) {
          trips.add(TripRecord.fromJson(Map<String, dynamic>.from(tripData as Map)));
        }
        // Write all trips to Hive in a single bulk transaction
        await appDatabase.batchInsertTrips(trips);
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
      // Decode JSON in background isolate
      final decoded = await compute(_decodeJson, jsonData);
      final data = decoded;

      // Merge customers
      final customersList = data['customers'] as List<dynamic>?;
      if (customersList != null) {
        final List<CustomerRecord> customers = [];
        for (final customerData in customersList) {
          customers.add(CustomerRecord.fromJson(Map<String, dynamic>.from(customerData as Map)));
        }
        await appDatabase.batchInsertCustomers(customers);
      }

      // Merge trips
      final tripsList = data['trips'] as List<dynamic>?;
      if (tripsList != null) {
        final List<TripRecord> trips = [];
        for (final tripData in tripsList) {
          trips.add(TripRecord.fromJson(Map<String, dynamic>.from(tripData as Map)));
        }
        await appDatabase.batchInsertTrips(trips);
      }
    } catch (e) {
      throw Exception('Failed to merge backup: ${e.toString()}');
    }
  }
}
