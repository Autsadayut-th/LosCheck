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

  // --- Trip Records ---

  static Future<void> saveTripRecord(
    TripRecord record, {
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('trip_records').insert(record.toSupabaseJson());
    } catch (e) {
      debugPrint('Supabase sync error (trip_records): $e');
      onError?.call('ไม่สามารถบันทึกค่ารอบไปยัง Supabase ได้');
    }
  }

  static Future<List<TripRecord>> fetchTripRecords({
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      final data = await client
          .from('trip_records')
          .select()
          .order('created_at', ascending: false);
      return data.map(TripRecord.fromSupabaseJson).toList();
    } catch (e) {
      debugPrint('Supabase fetch error (trip_records): $e');
      onError?.call('ไม่สามารถดึงข้อมูลค่ารอบจาก Supabase ได้');
      return [];
    }
  }

  static Future<void> deleteTripRecord(
    int supabaseId, {
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('trip_records').delete().eq('id', supabaseId);
    } catch (e) {
      debugPrint('Supabase delete error (trip_records): $e');
      onError?.call('ไม่สามารถลบค่ารอบจาก Supabase ได้');
    }
  }

  // --- Customer Records ---

  static Future<void> saveCustomerRecord(
    CustomerRecord record, {
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('customers').insert(record.toSupabaseJson());
    } catch (e) {
      debugPrint('Supabase sync error (customers): $e');
      onError?.call('ไม่สามารถบันทึกข้อมูลลูกค้าไปยัง Supabase ได้');
    }
  }

  static Future<List<CustomerRecord>> fetchCustomerRecords({
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      final data = await client
          .from('customers')
          .select()
          .order('created_at', ascending: false);
      return data.map(CustomerRecord.fromSupabaseJson).toList();
    } catch (e) {
      debugPrint('Supabase fetch error (customers): $e');
      onError?.call('ไม่สามารถดึงข้อมูลลูกค้าจาก Supabase ได้');
      return [];
    }
  }

  static Future<void> deleteCustomerRecord(
    int supabaseId, {
    SyncErrorCallback? onError,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('customers').delete().eq('id', supabaseId);
    } catch (e) {
      debugPrint('Supabase delete error (customers): $e');
      onError?.call('ไม่สามารถลบข้อมูลลูกค้าจาก Supabase ได้');
    }
  }
}
