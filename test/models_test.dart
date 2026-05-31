import 'package:flutter_test/flutter_test.dart';
import 'package:loscheck/models/trip_record.dart';
import 'package:loscheck/models/customer_record.dart';
import 'package:loscheck/services/csv_export_service.dart';

void main() {
  group('TripRecord', () {
    final now = DateTime(2025, 6, 15, 10, 30);

    test('totalBaht computes rounds * rateBaht', () {
      final record = TripRecord(
        distanceLabel: '0-300 เมตร',
        rateBaht: 5,
        rounds: 4,
        createdAt: now,
      );
      expect(record.totalBaht, 20);
    });

    test('isSameDay returns true for same date', () {
      final record = TripRecord(
        distanceLabel: '0-300 เมตร',
        rateBaht: 5,
        rounds: 1,
        createdAt: now,
      );
      expect(record.isSameDay(DateTime(2025, 6, 15, 23, 59)), isTrue);
      expect(record.isSameDay(DateTime(2025, 6, 16)), isFalse);
    });

    test('toJson / fromJson roundtrip without supabaseId', () {
      final record = TripRecord(
        distanceLabel: '301-500 เมตร',
        rateBaht: 10,
        rounds: 3,
        createdAt: now,
      );
      final json = record.toJson();
      expect(json.containsKey('supabaseId'), isFalse);

      final restored = TripRecord.fromJson(json);
      expect(restored.distanceLabel, '301-500 เมตร');
      expect(restored.rateBaht, 10);
      expect(restored.rounds, 3);
      expect(restored.createdAt, now);
      expect(restored.supabaseId, isNull);
    });

    test('toJson / fromJson roundtrip with supabaseId', () {
      final record = TripRecord(
        distanceLabel: '0-300 เมตร',
        rateBaht: 5,
        rounds: 2,
        createdAt: now,
        supabaseId: 42,
      );
      final json = record.toJson();
      expect(json['supabaseId'], 42);

      final restored = TripRecord.fromJson(json);
      expect(restored.supabaseId, 42);
    });

    test('toSupabaseJson uses snake_case keys', () {
      final record = TripRecord(
        distanceLabel: 'มากกว่า 3 กิโลเมตร',
        rateBaht: 25,
        rounds: 1,
        createdAt: now,
      );
      final json = record.toSupabaseJson();
      expect(json['distance_label'], 'มากกว่า 3 กิโลเมตร');
      expect(json['rate_baht'], 25);
      expect(json['rounds'], 1);
      expect(json.containsKey('created_at'), isTrue);
    });

    test('fromSupabaseJson parses Supabase response', () {
      final json = {
        'id': 99,
        'distance_label': '501 เมตร - 3 กิโลเมตร',
        'rate_baht': 15,
        'rounds': 5,
        'created_at': '2025-06-15T10:30:00.000',
      };
      final record = TripRecord.fromSupabaseJson(json);
      expect(record.supabaseId, 99);
      expect(record.distanceLabel, '501 เมตร - 3 กิโลเมตร');
      expect(record.rateBaht, 15);
      expect(record.rounds, 5);
    });
  });

  group('CustomerRecord', () {
    final now = DateTime(2025, 6, 15, 14, 0);

    test('toJson / fromJson roundtrip without supabaseId', () {
      final record = CustomerRecord(
        phone: '0812345678',
        name: 'สมชาย',
        address: '123 ถนนสุขุมวิท',
        createdAt: now,
      );
      final json = record.toJson();
      expect(json.containsKey('supabaseId'), isFalse);

      final restored = CustomerRecord.fromJson(json);
      expect(restored.phone, '0812345678');
      expect(restored.name, 'สมชาย');
      expect(restored.address, '123 ถนนสุขุมวิท');
      expect(restored.createdAt, now);
      expect(restored.supabaseId, isNull);
    });

    test('toJson / fromJson roundtrip with supabaseId', () {
      final record = CustomerRecord(
        phone: '0899999999',
        name: 'มานี',
        address: '45 ถนนสีลม',
        createdAt: now,
        supabaseId: 7,
      );
      final json = record.toJson();
      expect(json['supabaseId'], 7);

      final restored = CustomerRecord.fromJson(json);
      expect(restored.supabaseId, 7);
    });

    test('toSupabaseJson uses snake_case keys', () {
      final record = CustomerRecord(
        phone: '0812345678',
        name: 'สมชาย',
        address: '123 ถนนสุขุมวิท',
        createdAt: now,
      );
      final json = record.toSupabaseJson();
      expect(json['phone'], '0812345678');
      expect(json['name'], 'สมชาย');
      expect(json['address'], '123 ถนนสุขุมวิท');
      expect(json.containsKey('created_at'), isTrue);
    });

    test('fromSupabaseJson parses Supabase response', () {
      final json = {
        'id': 12,
        'phone': '0899999999',
        'name': 'มานี',
        'address': '45 ถนนสีลม',
        'created_at': '2025-06-15T14:00:00.000',
      };
      final record = CustomerRecord.fromSupabaseJson(json);
      expect(record.supabaseId, 12);
      expect(record.phone, '0899999999');
      expect(record.name, 'มานี');
      expect(record.address, '45 ถนนสีลม');
    });
  });

  group('CsvExportService', () {
    test('exportTripRecords generates CSV with header and data', () {
      final records = [
        TripRecord(
          distanceLabel: '0-300 เมตร',
          rateBaht: 5,
          rounds: 3,
          createdAt: DateTime(2025, 1, 15, 9, 5),
        ),
        TripRecord(
          distanceLabel: '301-500 เมตร',
          rateBaht: 10,
          rounds: 2,
          createdAt: DateTime(2025, 1, 15, 14, 30),
        ),
      ];
      final csv = CsvExportService.exportTripRecords(records);
      final lines = csv.trim().split('\n');
      expect(lines.length, 3);
      expect(lines[0], 'วันที่,ระยะทาง,อัตรา (บาท),จำนวนรอบ,รวม (บาท)');
      expect(lines[1], '15/01/2025 09:05,0-300 เมตร,5,3,15');
      expect(lines[2], '15/01/2025 14:30,301-500 เมตร,10,2,20');
    });

    test('exportCustomerRecords generates CSV with header and data', () {
      final records = [
        CustomerRecord(
          phone: '0812345678',
          name: 'สมชาย',
          address: '123 ถนนสุขุมวิท',
          createdAt: DateTime(2025, 3, 1, 8, 0),
        ),
      ];
      final csv = CsvExportService.exportCustomerRecords(records);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[0], 'วันที่,เบอร์โทร,ชื่อ,ที่อยู่');
      expect(lines[1], '01/03/2025 08:00,0812345678,สมชาย,123 ถนนสุขุมวิท');
    });

    test('exportTripRecords returns only header for empty list', () {
      final csv = CsvExportService.exportTripRecords([]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 1);
      expect(lines[0], 'วันที่,ระยะทาง,อัตรา (บาท),จำนวนรอบ,รวม (บาท)');
    });

    test('escape handles commas and quotes in values', () {
      final records = [
        CustomerRecord(
          phone: '081',
          name: 'ชื่อ, นามสกุล',
          address: 'บ้าน "เลขที่" 1',
          createdAt: DateTime(2025, 1, 1, 0, 0),
        ),
      ];
      final csv = CsvExportService.exportCustomerRecords(records);
      final lines = csv.trim().split('\n');
      expect(lines[1], contains('"ชื่อ, นามสกุล"'));
      expect(lines[1], contains('"บ้าน ""เลขที่"" 1"'));
    });
  });
}
