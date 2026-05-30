import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/customer_record.dart';
import '../models/trip_record.dart';

class SupabaseSyncService {
  SupabaseSyncService._();

  static SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) {
      return null;
    }
    return Supabase.instance.client;
  }

  static bool get isEnabled => _client != null;

  static Future<void> saveTripRecord(TripRecord record) async {
    final client = _client;
    if (client == null) {
      return;
    }

    await client.from('trip_records').insert(record.toSupabaseJson());
  }

  static Future<void> saveCustomerRecord(CustomerRecord record) async {
    final client = _client;
    if (client == null) {
      return;
    }

    await client.from('customers').insert(record.toSupabaseJson());
  }
}
