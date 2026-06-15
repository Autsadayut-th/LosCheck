import 'location_service.dart';

LocationService createLocationService() => IoLocationService();

class IoLocationService implements LocationService {
  @override
  Future<Map<String, double>?> getCurrentLocation() async {
    return null;
  }
}
