import 'dart:async';
import 'dart:html' as html;
import 'location_service.dart';

LocationService createLocationService() => WebLocationService();

class WebLocationService implements LocationService {
  @override
  Future<Map<String, double>?> getCurrentLocation() async {
    final completer = Completer<Map<String, double>?>();
    try {
      if (html.window.navigator.geolocation != null) {
        html.window.navigator.geolocation.getCurrentPosition(
          (position) {
            final coords = position.coords;
            if (coords != null && coords.latitude != null && coords.longitude != null) {
              completer.complete({
                'latitude': coords.latitude!.toDouble(),
                'longitude': coords.longitude!.toDouble(),
              });
            } else {
              completer.complete(null);
            }
          },
          onError: (error) {
            completer.complete(null);
          },
        );
      } else {
        completer.complete(null);
      }
    } catch (_) {
      completer.complete(null);
    }
    return completer.future;
  }
}
