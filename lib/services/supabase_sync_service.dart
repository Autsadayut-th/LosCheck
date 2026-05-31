import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';

typedef SyncErrorCallback = void Function(String message);

class SupabaseSyncService {
  SupabaseSyncService._();

  static SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) {
      return null;
    }
    return Supabase.instance.client;
  }

  static bool get isEnabled => _client != null;

  static Future<void> saveTripRecord(
    TripRecord record, {
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) {
      return;
    }

    try {
      await client.from('trip_records').insert(record.toSupabaseJson());
    } catch (e) {
      debugPrint('Supabase sync error (trip_records): $e');
      onError?.call('ไม่สามารถบันทึกค่ารอบไปยัง Supabase ได้');
    }
  }

  static Future<void> saveCustomerRecord(
    CustomerRecord record, {
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) {
      return;
    }

    try {
      await client.from('customers').insert(record.toSupabaseJson());
    } catch (e) {
      debugPrint('Supabase sync error (customers): $e');
      onError?.call('ไม่สามารถบันทึกข้อมูลลูกค้าไปยัง Supabase ได้');
    }
  }
}
