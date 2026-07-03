import 'dart:async';
import 'dart:html' as html;
import 'location_service.dart';

LocationService createLocationService() => WebLocationService();

class WebLocationService implements LocationService {
  @override
  Future<Map<String, double>?> getCurrentLocation() async {
    try {
      final position = await html.window.navigator.geolocation.getCurrentPosition();
      final coords = position.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        return {
          'latitude': coords.latitude!.toDouble(),
          'longitude': coords.longitude!.toDouble(),
        };
      }
    } catch (_) {
      // Ignore and return null
    }
    return null;
  }

  @override
  Stream<Map<String, double>> getLocationStream() {
    final controller = StreamController<Map<String, double>>();
    html.window.navigator.geolocation.watchPosition().listen((position) {
      final coords = position.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        controller.add({
          'latitude': coords.latitude!.toDouble(),
          'longitude': coords.longitude!.toDouble(),
        });
      }
    }, onError: (err) {
      controller.addError(err);
    });
    return controller.stream;
  }
}
