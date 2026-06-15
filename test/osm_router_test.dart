import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:loscheck/services/osm_router_service.dart';

void main() {
  group('OsmRouterService Tests', () {
    test('Haversine distance calculation is correct', () {
      final service = OsmRouterService();
      // Distance between Bangkok (13.7563, 100.5018) and Nonthaburi (13.8650, 100.4850)
      // Should be roughly 12-13 km
      final dist = service.calculateRouteDistance([
        const LatLng(13.7563, 100.5018),
        const LatLng(13.8650, 100.4850),
      ]);
      expect(dist, greaterThan(11.0));
      expect(dist, lessThan(14.0));
    });

    test('SimplePriorityQueue works correctly', () {
      final queue = SimplePriorityQueue<int>((a, b) => a.compareTo(b));
      queue.add(5);
      queue.add(1);
      queue.add(3);
      queue.add(2);
      queue.add(4);

      final result = <int>[];
      while (queue.isNotEmpty) {
        result.add(queue.removeFirst());
      }
      expect(result, equals([1, 2, 3, 4, 5]));
    });

    test('OsmRouterService snaps and routes fallback correctly when not initialized', () {
      final service = OsmRouterService();
      expect(service.isInitialized, isFalse);

      final start = const LatLng(13.8767, 100.4480);
      final end = const LatLng(13.8758, 100.4360);
      final path = service.findRoute(start, end);

      // Should fallback directly to straight line
      expect(path, equals([start, end]));
    });
  });
}
