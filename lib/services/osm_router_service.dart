import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Container for the parsed OSM map data.
class ParsedOsmMap {
  final Map<int, List<double>> nodes;
  final Map<int, List<int>> adjList;
  ParsedOsmMap(this.nodes, this.adjList);
}

/// Isolate entrypoint for parsing the OSM XML string.
/// Using simple, high-performance index substring parsing instead of DOM/RegExp to save CPU/Memory.
ParsedOsmMap _parseOsmDataIsolate(String xmlString) {
  final Map<int, List<double>> nodes = {};
  final Map<int, List<int>> adjList = {};

  final lines = const LineSplitter().convert(xmlString);

  List<int> currentWayNodes = [];
  bool isCurrentWayHighway = false;

  String? getAttribute(String line, String name) {
    final attr = '$name="';
    final start = line.indexOf(attr);
    if (start == -1) return null;
    final end = line.indexOf('"', start + attr.length);
    if (end == -1) return null;
    return line.substring(start + attr.length, end);
  }

  for (final line in lines) {
    if (line.contains('<node ')) {
      final idStr = getAttribute(line, 'id');
      final latStr = getAttribute(line, 'lat');
      final lonStr = getAttribute(line, 'lon');
      if (idStr != null && latStr != null && lonStr != null) {
        final id = int.tryParse(idStr);
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (id != null && lat != null && lon != null) {
          nodes[id] = [lat, lon];
        }
      }
    } else if (line.contains('<way ')) {
      currentWayNodes = [];
      isCurrentWayHighway = false;
    } else if (line.contains('<nd ')) {
      final refStr = getAttribute(line, 'ref');
      if (refStr != null) {
        final ref = int.tryParse(refStr);
        if (ref != null) {
          currentWayNodes.add(ref);
        }
      }
    } else if (line.contains('<tag ')) {
      final k = getAttribute(line, 'k');
      final v = getAttribute(line, 'v');
      if (k == 'highway') {
        isCurrentWayHighway = true;
      }
    } else if (line.contains('</way>')) {
      if (isCurrentWayHighway && currentWayNodes.length >= 2) {
        for (int i = 0; i < currentWayNodes.length - 1; i++) {
          final u = currentWayNodes[i];
          final v = currentWayNodes[i + 1];
          // Only establish connection if both nodes are parsed
          if (nodes.containsKey(u) && nodes.containsKey(v)) {
            adjList.putIfAbsent(u, () => []).add(v);
            adjList.putIfAbsent(v, () => []).add(u);
          }
        }
      }
    }
  }

  return ParsedOsmMap(nodes, adjList);
}

/// A self-contained sorted priority queue using binary insertion search.
class SimplePriorityQueue<T> {
  final List<T> _elements = [];
  final int Function(T, T) compare;

  SimplePriorityQueue(this.compare);

  bool get isNotEmpty => _elements.isNotEmpty;
  bool get isEmpty => _elements.isEmpty;

  void add(T element) {
    int index = _binarySearch(element);
    if (index < 0) {
      index = ~index;
    }
    _elements.insert(index, element);
  }

  T removeFirst() {
    return _elements.removeAt(0);
  }

  int _binarySearch(T element) {
    int min = 0;
    int max = _elements.length - 1;
    while (min <= max) {
      int mid = min + ((max - min) >> 1);
      int comp = compare(_elements[mid], element);
      if (comp == 0) {
        return mid;
      } else if (comp < 0) {
        min = mid + 1;
      } else {
        max = mid - 1;
      }
    }
    return ~min;
  }
}

class _AStarNode {
  final int id;
  final double g;
  final double f;
  _AStarNode(this.id, this.g, this.f);
}

/// Service that parses local map.osm and solves road-based routing using A*.
class OsmRouterService {
  static final OsmRouterService _instance = OsmRouterService._internal();
  factory OsmRouterService() => _instance;
  OsmRouterService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Map<int, List<double>> _nodes = {};
  Map<int, List<int>> _adjList = {};

  // Roughly the bounds of Nonthaburi / Bangkok map.osm
  static const double minLat = 13.86641;
  static const double maxLat = 13.91549;
  static const double minLng = 100.35135;
  static const double maxLng = 100.43787;

  /// Loads and parses the database map.osm file.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      String xmlString = '';
      
      // Try to read directly from the filesystem (useful during test and development)
      final localFile = File('lib/database/connection/map.osm');
      if (await localFile.exists()) {
        xmlString = await localFile.readAsString();
      } else {
        // Fallback to loading via Flutter rootBundle
        xmlString = await rootBundle.loadString('lib/database/connection/map.osm');
      }

      // Parse XML in background isolate to keep UI thread fluid on low-end devices
      final parsedMap = await compute(_parseOsmDataIsolate, xmlString);
      _nodes = parsedMap.nodes;
      _adjList = parsedMap.adjList;
      _isInitialized = true;
      debugPrint('OsmRouterService initialized successfully with ${_nodes.length} nodes.');
    } catch (e) {
      debugPrint('Error initializing OsmRouterService: $e');
      // Set empty but initialized to avoid breaking logic, will fallback to straight lines
      _nodes = {};
      _adjList = {};
      _isInitialized = true;
    }
  }

  /// Calculates Haversine distance in kilometers.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Helper to snap coordinate to nearest node on the highway network.
  /// Iterates only keys in adjList (nodes connected to roads) to speed up search to < 0.1ms.
  int? _findNearestNode(double lat, double lon) {
    if (_adjList.isEmpty) return null;
    int? nearestId;
    double minDistance = double.infinity;
    
    for (final id in _adjList.keys) {
      final coords = _nodes[id];
      if (coords == null) continue;
      final dLat = coords[0] - lat;
      final dLon = coords[1] - lon;
      final dist = dLat * dLat + dLon * dLon;
      if (dist < minDistance) {
        minDistance = dist;
        nearestId = id;
      }
    }
    return nearestId;
  }

  /// Finds shortest road-based route using A* algorithm.
  /// Falls back to straight line [start, end] if out of bounds or search fails.
  List<LatLng> findRoute(LatLng start, LatLng end) {
    if (!_isInitialized || _adjList.isEmpty) {
      return [start, end];
    }

    // Check bounds check with buffer
    const padding = 0.05;
    final isStartInBounds = start.latitude >= (minLat - padding) &&
        start.latitude <= (maxLat + padding) &&
        start.longitude >= (minLng - padding) &&
        start.longitude <= (maxLng + padding);
    final isEndInBounds = end.latitude >= (minLat - padding) &&
        end.latitude <= (maxLat + padding) &&
        end.longitude >= (minLng - padding) &&
        end.longitude <= (maxLng + padding);

    if (!isStartInBounds || !isEndInBounds) {
      return [start, end];
    }

    final startNodeId = _findNearestNode(start.latitude, start.longitude);
    final endNodeId = _findNearestNode(end.latitude, end.longitude);

    if (startNodeId == null || endNodeId == null) {
      return [start, end];
    }

    // Ensure snapped node is within reasonable distance (< 5km)
    final startCoords = _nodes[startNodeId]!;
    final endCoords = _nodes[endNodeId]!;
    final distToStartSnap = _calculateDistance(start.latitude, start.longitude, startCoords[0], startCoords[1]);
    final distToEndSnap = _calculateDistance(end.latitude, end.longitude, endCoords[0], endCoords[1]);
    if (distToStartSnap > 5.0 || distToEndSnap > 5.0) {
      return [start, end];
    }

    if (startNodeId == endNodeId) {
      return [start, end];
    }

    // A* algorithm setup
    final openSet = SimplePriorityQueue<_AStarNode>((a, b) => a.f.compareTo(b.f));
    final Map<int, double> gScore = {startNodeId: 0.0};
    final Map<int, int> cameFrom = {};

    double getHeuristic(int id) {
      final c = _nodes[id]!;
      return _calculateDistance(c[0], c[1], endCoords[0], endCoords[1]);
    }

    openSet.add(_AStarNode(startNodeId, 0.0, getHeuristic(startNodeId)));
    
    int iterations = 0;
    const maxIterations = 10000;
    bool pathFound = false;

    while (openSet.isNotEmpty && iterations < maxIterations) {
      iterations++;
      final current = openSet.removeFirst().id;

      if (current == endNodeId) {
        pathFound = true;
        break;
      }

      final currentG = gScore[current] ?? double.infinity;
      final neighbors = _adjList[current] ?? const [];

      for (final neighbor in neighbors) {
        final neighborCoords = _nodes[neighbor]!;
        final currCoords = _nodes[current]!;
        final stepDist = _calculateDistance(
          currCoords[0],
          currCoords[1],
          neighborCoords[0],
          neighborCoords[1],
        );
        final tentativeG = currentG + stepDist;

        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeG;
          final f = tentativeG + getHeuristic(neighbor);
          openSet.add(_AStarNode(neighbor, tentativeG, f));
        }
      }
    }

    if (!pathFound) {
      return [start, end];
    }

    // Reconstruct route
    final List<LatLng> path = [];
    path.add(end);

    int? curr = endNodeId;
    while (curr != null) {
      final c = _nodes[curr]!;
      path.add(LatLng(c[0], c[1]));
      curr = cameFrom[curr];
    }

    path.add(start);
    return path.reversed.toList();
  }

  /// Helper to calculate the cumulative route distance.
  double calculateRouteDistance(List<LatLng> route) {
    if (route.isEmpty) return 0.0;
    double total = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      total += _calculateDistance(
        route[i].latitude,
        route[i].longitude,
        route[i + 1].latitude,
        route[i + 1].longitude,
      );
    }
    return total;
  }
}
