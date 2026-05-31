import 'dart:convert';

import '../models/customer_record.dart';
import '../models/trip_record.dart';

class CsvExportService {
  CsvExportService._();

  static String exportTripRecords(List<TripRecord> records) {
    final buffer = StringBuffer();
    buffer.writeln('วันที่,ระยะทาง,อัตรา (บาท),จำนวนรอบ,รวม (บาท)');
    for (final record in records) {
      buffer.writeln(
        '${_formatDateTime(record.createdAt)},'
        '${_escape(record.distanceLabel)},'
        '${record.rateBaht},'
        '${record.rounds},'
        '${record.totalBaht}',
      );
    }
    return buffer.toString();
  }

  static String exportCustomerRecords(List<CustomerRecord> records) {
    final buffer = StringBuffer();
    buffer.writeln('วันที่,เบอร์โทร,ชื่อ,ที่อยู่');
    for (final record in records) {
      buffer.writeln(
        '${_formatDateTime(record.createdAt)},'
        '${_escape(record.phone)},'
        '${_escape(record.name)},'
        '${_escape(record.address)}',
      );
    }
    return buffer.toString();
  }

  static String generateDataUri(String csvContent) {
    final bytes = utf8.encode(csvContent);
    final base64Data = base64Encode(bytes);
    return 'data:text/csv;charset=utf-8;base64,$base64Data';
  }

  static String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$minute';
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
