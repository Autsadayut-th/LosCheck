import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

LocationService createLocationService() => IoLocationService();

class IoLocationService implements LocationService {
  @override
  Future<Map<String, double>?> getCurrentLocation() async {
    try {
      // 1. Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // 3. Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (_) {
      return null;
    }
  }
}
