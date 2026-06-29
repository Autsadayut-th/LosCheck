import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Reverse geocoding service using OpenStreetMap Nominatim (free, no API key).
/// Caches results to avoid excessive API calls.
class ReverseGeocodingService {
  ReverseGeocodingService._();
  static final ReverseGeocodingService instance = ReverseGeocodingService._();

  final Map<String, String> _cache = {};
  final HttpClient _client = HttpClient();

  /// Minimum distance (in degrees) to trigger a new lookup.
  /// ~0.001° ≈ 111 meters — avoids re-fetching for tiny GPS drifts.
  static const double _minDeltaDeg = 0.001;
  double? _lastLat;
  double? _lastLng;
  String? _lastResult;

  /// Returns a human-readable address string for the given coordinates.
  /// Example: "บางบัวทอง, นนทบุรี" or "Lat, Lng" on failure.
  Future<String> getAddress(double lat, double lng) async {
    // Skip lookup if position barely changed
    if (_lastLat != null &&
        _lastLng != null &&
        (lat - _lastLat!).abs() < _minDeltaDeg &&
        (lng - _lastLng!).abs() < _minDeltaDeg &&
        _lastResult != null) {
      return _lastResult!;
    }

    // Round to 4 decimal places for cache key (~11m precision)
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) {
      _lastLat = lat;
      _lastLng = lng;
      _lastResult = _cache[key];
      return _lastResult!;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=14&addressdetails=1'
        '&accept-language=th',
      );

      final request = await _client.getUrl(uri);
      request.headers.set('User-Agent', 'LosCheck/1.1.0');
      final response = await request.close().timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final address = json['address'] as Map<String, dynamic>?;

        if (address != null) {
          final result = _formatThaiAddress(address);
          _cache[key] = result;
          _lastLat = lat;
          _lastLng = lng;
          _lastResult = result;
          return result;
        }
      }
    } catch (_) {
      // Network error — return fallback silently
    }

    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Formats Nominatim address fields into a concise Thai-style address.
  String _formatThaiAddress(Map<String, dynamic> address) {
    // Priority: subdistrict > suburb > city_district > city > county > state
    final subdistrict =
        address['subdistrict'] ?? address['suburb'] ?? address['village'];
    final district = address['city_district'] ??
        address['city'] ??
        address['town'] ??
        address['county'];
    final province = address['state'] ?? address['state_district'];

    final parts = <String>[];
    if (subdistrict != null) parts.add(subdistrict.toString());
    if (district != null && district != subdistrict) {
      parts.add(district.toString());
    }
    if (province != null && province != district) {
      parts.add(province.toString());
    }

    if (parts.isEmpty) {
      return address['display_name']?.toString().split(',').take(2).join(', ') ??
          'ไม่ทราบที่อยู่';
    }

    // Keep it short — max 2 parts (e.g., "บางบัวทอง, นนทบุรี")
    return parts.take(2).join(', ');
  }
}
