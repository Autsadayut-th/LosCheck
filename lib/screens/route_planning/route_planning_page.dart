import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/customer_record.dart';
import '../../providers/app_state_provider.dart';
import '../../services/location_service.dart';
import '../../core/design_tokens.dart';
import '../../core/theme_extensions.dart';
import '../../services/osm_router_service.dart';
import '../../database/hive_database.dart';

import 'widgets/route_planning_widgets.dart';
import 'widgets/route_planning_setup_view.dart';
import 'widgets/route_planning_navigation_view.dart';

class RoutePlanningPage extends StatelessWidget {
  const RoutePlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      Provider.of<AppStateProvider>(context, listen: false);
      return const RoutePlanningPageContent();
    } catch (_) {
      return ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: const RoutePlanningPageContent(),
      );
    }
  }
}

class RoutePlanningPageContent extends StatefulWidget {
  const RoutePlanningPageContent({super.key});

  @override
  State<RoutePlanningPageContent> createState() =>
      RoutePlanningPageContentState();
}

class RoutePlanningPageContentState extends State<RoutePlanningPageContent> {
  // Map Controller
  final MapController _mapController = MapController();

  // Navigation State
  bool _isNavigating = false;
  bool _isAutoMode = true;

  // Selected customers for planning
  final Set<String> _selectedCustomerPhones = {};
  String _searchQuery = '';

  // Coordinates
  double _currentLat = 13.874324; // Default Nonthaburi Lat
  double _currentLng = 100.40142; // Default Nonthaburi Lng
  bool _isFetchingLocation = false;

  // Active navigation queues
  List<CustomerRecord> _remainingQueue = [];
  List<CustomerRecord> _completedQueue = [];

  // GPS Real-time Tracking
  Timer? _gpsTimer;
  LatLng? _liveGpsPosition; // actual GPS dot on map
  bool _isFollowingGps = true; // auto-pan map to follow GPS

  // Zoom and initialization state
  double _setupZoom = 11.0;
  bool _hasInitializedSelection = false;

  // Route calculations are relatively expensive because they run OSM pathfinding.
  final Map<String, double> _routeDistanceCache = {};
  String? _setupPreviewPathCacheKey;
  List<LatLng>? _setupPreviewPathCacheValue;

  // Controllers for coordinates
  final TextEditingController _latController = TextEditingController(
    text: '13.874324',
  );
  final TextEditingController _lngController = TextEditingController(
    text: '100.40142',
  );

  // ─── Public Getters/Setters & Methods ────────────────────────────

  String get searchQuery => _searchQuery;
  set searchQuery(String val) => setState(() => _searchQuery = val);

  Set<String> get selectedCustomerPhones => _selectedCustomerPhones;
  
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  
  bool get isFetchingLocation => _isFetchingLocation;
  
  double get setupZoom => _setupZoom;
  set setupZoom(double val) => setState(() => _setupZoom = val);
  
  TextEditingController get latController => _latController;
  TextEditingController get lngController => _lngController;
  
  MapController get mapController => _mapController;
  bool get isFollowingGps => _isFollowingGps;
  set isFollowingGps(bool val) => setState(() => _isFollowingGps = val);
  
  List<CustomerRecord> get completedQueue => _completedQueue;
  List<CustomerRecord> get remainingQueue => _remainingQueue;
  bool get isAutoMode => _isAutoMode;
  
  Future<void> manualFetchGPS() => _manualFetchGPS();
  Widget buildSetupMapPreview(List<CustomerRecord> customers) => _buildSetupMapPreview(customers);
  Widget buildEmbeddedMap() => _buildEmbeddedMap();
  double calculateTotalRouteDistance(List<CustomerRecord> targets) => _calculateTotalRouteDistance(targets);
  void toggleRouteMode(bool val) => _toggleRouteMode(val);
  void showNavigationOptions(CustomerRecord c) => _showNavigationOptions(c);
  void completeActiveDestination() => _completeActiveDestination();
  void resetNavigation() => _resetNavigation();
  void fitMapToRoute() => _fitMapToRoute();
  void startNavigation(List<CustomerRecord> allCustomers) => _startNavigation(allCustomers);
  void showEditCustomerSheet(CustomerRecord customer) => _showEditCustomerSheet(customer);
  void confirmDeleteCustomer(CustomerRecord customer) => _confirmDeleteCustomer(customer);
  Future<void> callCustomer(String phone) => _callCustomer(phone);
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) =>
      _calculateDistance(lat1, lon1, lat2, lon2);
  
  void toggleCustomerSelection(String phone, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedCustomerPhones.add(phone);
      } else {
        _selectedCustomerPhones.remove(phone);
      }
    });
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final actualOld = oldIndex + 1;
    final actualNew = newIndex >= _remainingQueue.length
        ? _remainingQueue.length - 1
        : newIndex + 1;
    setState(() {
      if (actualOld < actualNew) {
        final item = _remainingQueue.removeAt(actualOld);
        _remainingQueue.insert(actualNew - 1, item);
      } else {
        final item = _remainingQueue.removeAt(actualOld);
        _remainingQueue.insert(actualNew, item);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tryGetGPSLocation();
    _initOsmRouter();
  }

  Future<void> _initOsmRouter() async {
    await OsmRouterService().initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _mapController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // ─── GPS Real-time Tracking ────────────────────────────────────

  void _startGpsTracking() {
    _gpsTimer?.cancel();
    _updateGpsPosition(); // immediate first update
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateGpsPosition();
    });
  }

  void _stopGpsTracking() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    if (mounted) setState(() => _liveGpsPosition = null);
  }

  Future<void> _updateGpsPosition() async {
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null && mounted) {
        final newPos = LatLng(loc['latitude']!, loc['longitude']!);
        setState(() => _liveGpsPosition = newPos);
        if (_isFollowingGps) {
          _mapController.move(newPos, _mapController.camera.zoom);
        }
      }
    } catch (_) {
      // Silently ignore GPS errors during tracking
    }
  }

  Future<void> _tryGetGPSLocation() async {
    if (!mounted) return;
    setState(() => _isFetchingLocation = true);
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null && mounted) {
        setState(() {
          _currentLat = loc['latitude']!;
          _currentLng = loc['longitude']!;
          _latController.text = _currentLat.toStringAsFixed(6);
          _lngController.text = _currentLng.toStringAsFixed(6);
        });
      }
    } catch (_) {
      // Ignore location errors on init, fall back to default
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _manualFetchGPS() async {
    if (!mounted) return;
    setState(() => _isFetchingLocation = true);
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null && mounted) {
        setState(() {
          _currentLat = loc['latitude']!;
          _currentLng = loc['longitude']!;
          _latController.text = _currentLat.toStringAsFixed(6);
          _lngController.text = _currentLng.toStringAsFixed(6);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดึงตำแหน่ง GPS ปัจจุบันสำเร็จ'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 2500),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถดึงตำแหน่งได้ กรุณาเปิดสิทธิ์ GPS หรือใส่พิกัดด้วยตัวเอง',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  // Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = cos;
    final a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // TSP Greedy sequence calculation
  List<CustomerRecord> _calculateGreedyRoute(
    double startLat,
    double startLng,
    List<CustomerRecord> targets,
  ) {
    final List<CustomerRecord> result = [];
    final List<CustomerRecord> pool = List.from(targets);

    double currentLat = startLat;
    double currentLng = startLng;

    while (pool.isNotEmpty) {
      CustomerRecord? nearest;
      double minDistance = double.infinity;
      int nearestIndex = -1;

      for (int i = 0; i < pool.length; i++) {
        final target = pool[i];
        if (target.latitude != null && target.longitude != null) {
          final dist = _calculateDistance(
            currentLat,
            currentLng,
            target.latitude!,
            target.longitude!,
          );
          if (dist < minDistance) {
            minDistance = dist;
            nearest = target;
            nearestIndex = i;
          }
        }
      }

      if (nearest != null) {
        result.add(nearest);
        currentLat = nearest.latitude!;
        currentLng = nearest.longitude!;
        pool.removeAt(nearestIndex);
      } else {
        result.addAll(pool);
        break;
      }
    }

    return result;
  }

  double _calculateTotalRouteDistance(List<CustomerRecord> targets) {
    return _calculateCachedRouteDistance(targets, optimizeOrder: true);
  }

  double _calculateCompletedRouteDistance(List<CustomerRecord> targets) {
    return _calculateCachedRouteDistance(targets, optimizeOrder: false);
  }

  double _calculateCachedRouteDistance(
    List<CustomerRecord> targets, {
    required bool optimizeOrder,
  }) {
    if (targets.isEmpty) return 0.0;

    final startLat = double.tryParse(_latController.text) ?? _currentLat;
    final startLng = double.tryParse(_lngController.text) ?? _currentLng;
    final route = optimizeOrder
        ? _calculateGreedyRoute(startLat, startLng, targets)
        : List<CustomerRecord>.from(targets);
    final cacheKey = _routeCacheKey(route, startLat, startLng, optimizeOrder);

    final cachedDistance = _routeDistanceCache[cacheKey];
    if (cachedDistance != null) return cachedDistance;

    final distance = _calculateRouteDistanceWithOSM(
      route,
      start: LatLng(startLat, startLng),
    );
    if (_routeDistanceCache.length > 32) {
      _routeDistanceCache.clear();
    }
    _routeDistanceCache[cacheKey] = distance;
    return distance;
  }

  String _routeCacheKey(
    List<CustomerRecord> route,
    double startLat,
    double startLng,
    bool optimizeOrder,
  ) {
    final routeKey = route
        .map(
          (c) =>
              '${c.phone}:${c.latitude?.toStringAsFixed(6)},${c.longitude?.toStringAsFixed(6)}',
        )
        .join('|');
    return '${OsmRouterService().isInitialized}:$optimizeOrder:'
        '${startLat.toStringAsFixed(6)},${startLng.toStringAsFixed(6)}:$routeKey';
  }

  double _calculateRouteDistanceWithOSM(
    List<CustomerRecord> sortedRoute, {
    LatLng? start,
  }) {
    if (sortedRoute.isEmpty) return 0.0;

    double total = 0.0;
    LatLng currentLoc =
        start ??
        LatLng(
          double.tryParse(_latController.text) ?? _currentLat,
          double.tryParse(_lngController.text) ?? _currentLng,
        );

    final router = OsmRouterService();

    for (final customer in sortedRoute) {
      if (customer.latitude != null && customer.longitude != null) {
        final dest = LatLng(customer.latitude!, customer.longitude!);
        final segment = router.findRoute(currentLoc, dest);
        total += router.calculateRouteDistance(segment);
        currentLoc = dest;
      }
    }

    return total;
  }

  void _startNavigation(List<CustomerRecord> allCustomers) {
    final parsedLat = double.tryParse(_latController.text) ?? _currentLat;
    final parsedLng = double.tryParse(_lngController.text) ?? _currentLng;

    final selectedTargets = allCustomers.where((c) {
      return _selectedCustomerPhones.contains(c.phone) &&
          c.latitude != null &&
          c.longitude != null;
    }).toList();

    if (selectedTargets.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกลูกค้าที่มีพิกัดอย่างน้อย 1 รายการ'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _currentLat = parsedLat;
      _currentLng = parsedLng;
      _completedQueue = [];

      if (_isAutoMode) {
        _remainingQueue = _calculateGreedyRoute(
          _currentLat,
          _currentLng,
          selectedTargets,
        );
      } else {
        _remainingQueue = List.from(selectedTargets);
      }

      _isNavigating = true;
      _isFollowingGps = true;
    });

    // Start GPS tracking when navigation begins
    _startGpsTracking();

    // Fit map to show all route points after building the queue
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToRoute());
  }

  void _toggleRouteMode(bool isAuto) {
    if (!_isNavigating) {
      setState(() => _isAutoMode = isAuto);
      return;
    }

    setState(() {
      _isAutoMode = isAuto;
      if (isAuto && _remainingQueue.isNotEmpty) {
        final double pivotLat =
            _completedQueue.isNotEmpty && _completedQueue.last.latitude != null
            ? _completedQueue.last.latitude!
            : _currentLat;
        final double pivotLng =
            _completedQueue.isNotEmpty && _completedQueue.last.longitude != null
            ? _completedQueue.last.longitude!
            : _currentLng;
        _remainingQueue = _calculateGreedyRoute(
          pivotLat,
          pivotLng,
          _remainingQueue,
        );
      }
    });
  }

  void _completeActiveDestination() {
    if (_remainingQueue.isEmpty) return;

    setState(() {
      final completed = _remainingQueue.removeAt(0);
      _completedQueue.add(completed);

      if (_isAutoMode &&
          _remainingQueue.isNotEmpty &&
          completed.latitude != null &&
          completed.longitude != null) {
        _remainingQueue = _calculateGreedyRoute(
          completed.latitude!,
          completed.longitude!,
          _remainingQueue,
        );
      }

      if (_remainingQueue.isEmpty) {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final totalDist = _calculateCompletedRouteDistance(_completedQueue);
        appState.recordRouteCompletion(_completedQueue.length, totalDist);
      }
    });

    // Auto-pan to next destination
    if (_remainingQueue.isNotEmpty &&
        _remainingQueue.first.latitude != null &&
        _remainingQueue.first.longitude != null) {
      _mapController.move(
        LatLng(
          _remainingQueue.first.latitude!,
          _remainingQueue.first.longitude!,
        ),
        15.0,
      );
    }
  }

  void _resetNavigation() {
    _stopGpsTracking();
    setState(() {
      _isNavigating = false;
      _remainingQueue = [];
      _completedQueue = [];
    });
  }

  /// Fit map bounds to show all route points including start location
  void _fitMapToRoute() {
    final List<LatLng> points = [LatLng(_currentLat, _currentLng)];
    for (final c in _remainingQueue) {
      if (c.latitude != null && c.longitude != null) {
        points.add(LatLng(c.latitude!, c.longitude!));
      }
    }
    if (points.length < 2) {
      if (points.length == 1) {
        _mapController.move(points.first, 14.0);
      }
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat - 0.005, minLng - 0.005),
      LatLng(maxLat + 0.005, maxLng + 0.005),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  Future<void> _callCustomer(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showEditCustomerSheet(CustomerRecord customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone);
    final addrCtrl = TextEditingController(text: customer.address);
    final latCtrl = TextEditingController(
      text: customer.latitude?.toString() ?? '',
    );
    final lngCtrl = TextEditingController(
      text: customer.longitude?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'แก้ไขข้อมูลลูกค้า',
                  style: kanitTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'ชื่อลูกค้า'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(labelText: 'ที่อยู่'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final updated = CustomerRecord(
                      phone: customer.phone,
                      name: nameCtrl.text,
                      address: addrCtrl.text,
                      latitude: double.tryParse(latCtrl.text),
                      longitude: double.tryParse(lngCtrl.text),
                      createdAt: customer.createdAt,
                    );
                    await appDatabase.insertCustomer(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCustomer(CustomerRecord customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ลบลูกค้า',
          style: kanitTextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('คุณต้องการลบข้อมูลของ ${customer.name} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              await appDatabase.deleteCustomer(customer.phone);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Shows bottom sheet for selecting navigation app / mode
  Future<void> _showNavigationOptions(CustomerRecord activeCustomer) async {
    final originLat = _liveGpsPosition?.latitude ?? _currentLat;
    final originLng = _liveGpsPosition?.longitude ?? _currentLng;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      ctx,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'เลือกแอปนำทาง',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'ปลายทาง: ${activeCustomer.name}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Google Maps — จุดเดียว
              NavOptionTile(
                icon: Icons.map,
                color: const Color(0xFF4285F4),
                title: 'Google Maps — จุดนี้',
                subtitle: 'เปิดนำทางไปยัง ${activeCustomer.name} ทันที',
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1'
                    '&origin=$originLat,$originLng'
                    '&destination=${activeCustomer.latitude},${activeCustomer.longitude}'
                    '&travelmode=driving',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 8),

              // Google Maps — ทุกจุดพร้อมกัน
              if (_remainingQueue.length > 1)
                NavOptionTile(
                  icon: Icons.alt_route,
                  color: const Color(0xFF34A853),
                  title: 'Google Maps — ทุกจุดที่เหลือ',
                  subtitle:
                      'วางแผน ${_remainingQueue.length} จุดพร้อมกัน (สูงสุด 8 จุด)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openAllWaypointsInGoogleMaps(
                      originLat,
                      originLng,
                      _remainingQueue,
                    );
                  },
                ),
              if (_remainingQueue.length > 1) const SizedBox(height: 8),

              // Waze
              NavOptionTile(
                icon: Icons.assistant_navigation,
                color: const Color(0xFF05C8F7),
                title: 'Waze',
                subtitle: 'เปิด Waze นำทางไปยัง ${activeCustomer.name}',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openWaze(activeCustomer);
                },
              ),
              const SizedBox(height: 8),

              // Call customer
              if (activeCustomer.phone.isNotEmpty)
                NavOptionTile(
                  icon: Icons.phone_outlined,
                  color: Colors.green,
                  title: 'โทรหาลูกค้า',
                  subtitle: activeCustomer.phone,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(
                      'tel:${activeCustomer.phone.replaceAll(RegExp(r'[^0-9]'), '')}',
                    );
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Opens Google Maps with up to 8 waypoints (all remaining destinations)
  Future<void> _openAllWaypointsInGoogleMaps(
    double originLat,
    double originLng,
    List<CustomerRecord> remaining,
  ) async {
    final stops = remaining
        .where((c) => c.latitude != null && c.longitude != null)
        .take(8)
        .toList();
    if (stops.isEmpty) return;

    final destination = stops.last;
    final waypoints = stops.length > 1
        ? stops
              .sublist(0, stops.length - 1)
              .map((c) => '${c.latitude},${c.longitude}')
              .join('|')
        : null;

    var url =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$originLat,$originLng'
        '&destination=${destination.latitude},${destination.longitude}'
        '&travelmode=driving';
    if (waypoints != null) url += '&waypoints=$waypoints';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถเปิด Google Maps ได้'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Opens Waze app for the active destination
  Future<void> _openWaze(CustomerRecord customer) async {
    if (customer.latitude == null || customer.longitude == null) return;
    final wazeUri = Uri.parse(
      'waze://?ll=${customer.latitude},${customer.longitude}&navigate=yes',
    );
    final webUri = Uri.parse(
      'https://waze.com/ul?ll=${customer.latitude},${customer.longitude}&navigate=yes',
    );
    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถเปิด Waze ได้'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ─── Map Builders ──────────────────────────────────────────────

  /// Builds the list of markers for the embedded map
  List<Marker> _buildRouteMarkers() {
    final List<Marker> markers = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Start location marker (blue)
    markers.add(
      Marker(
        point: LatLng(_currentLat, _currentLng),
        width: 44,
        height: 44,
        child: _buildPinMarker(
          color: isDark ? const Color(0xFF42A5F5) : const Color(0xFF1565C0),
          icon: Icons.my_location,
          label: null,
          size: 40,
        ),
      ),
    );

    // Completed customer markers (greyed out)
    for (final customer in _completedQueue) {
      if (customer.latitude == null || customer.longitude == null) continue;
      markers.add(
        Marker(
          point: LatLng(customer.latitude!, customer.longitude!),
          width: 36,
          height: 36,
          child: Opacity(
            opacity: 0.35,
            child: _buildPinMarker(
              color: Colors.grey,
              icon: Icons.check,
              label: null,
              size: 32,
            ),
          ),
        ),
      );
    }

    // Remaining queue markers (teal), active one is highlighted amber
    for (int i = 0; i < _remainingQueue.length; i++) {
      final customer = _remainingQueue[i];
      if (customer.latitude == null || customer.longitude == null) continue;
      final isActive = i == 0;

      markers.add(
        Marker(
          point: LatLng(customer.latitude!, customer.longitude!),
          width: isActive ? 52 : 40,
          height: isActive ? 52 : 40,
          child: _buildPinMarker(
            color: isActive ? const Color(0xFFFBC02D) : const Color(0xFF00897B),
            icon: isActive ? Icons.star : null,
            label: isActive ? null : '${i + 1}',
            size: isActive ? 48 : 36,
          ),
        ),
      );
    }

    // Live GPS position dot (real-time tracking, shown only when available)
    if (_liveGpsPosition != null) {
      markers.add(
        Marker(
          point: _liveGpsPosition!,
          width: 56,
          height: 56,
          child: _buildLiveGpsDot(),
        ),
      );
    }

    return markers;
  }

  /// Animated pulsing dot for live GPS position
  Widget _buildLiveGpsDot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulse ring
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2196F3).withValues(alpha: 0.2),
            border: Border.all(
              color: const Color(0xFF2196F3).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
        ),
        // Inner solid dot
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2196F3),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinMarker({
    required Color color,
    required double size,
    IconData? icon,
    String? label,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * 0.45)
            : Text(
                label ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.38,
                ),
              ),
      ),
    );
  }

  Widget _buildClusterMarker({
    required int count,
    required bool hasSelected,
    required bool allSelected,
    required double size,
  }) {
    final color = allSelected
        ? const Color(0xFFFBC02D) // Amber if all selected
        : const Color(
            0xFF00897B,
          ); // Teal if none or some selected (with a badge)

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38,
              ),
            ),
            if (hasSelected && !allSelected)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(
                      0xFFFBC02D,
                    ), // Amber dot indicating some are selected
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the Polyline connecting start → all remaining destinations along roads
  List<Polyline> _buildRoutePolylines() {
    final source = _isNavigating ? _remainingQueue : <CustomerRecord>[];
    if (source.isEmpty) return [];

    final List<LatLng> pathPoints = [];
    LatLng currentLoc = LatLng(_currentLat, _currentLng);

    final router = OsmRouterService();

    for (final c in source) {
      if (c.latitude != null && c.longitude != null) {
        final destination = LatLng(c.latitude!, c.longitude!);
        final segment = router.findRoute(currentLoc, destination);
        if (pathPoints.isNotEmpty && segment.isNotEmpty) {
          pathPoints.addAll(segment.skip(1));
        } else {
          pathPoints.addAll(segment);
        }
        currentLoc = destination;
      }
    }

    if (pathPoints.length < 2) return [];
    return [
      Polyline(
        points: pathPoints,
        strokeWidth: 3.5,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
      ),
    ];
  }

  Widget _buildEmbeddedMap() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use non-retina tiles for low-end devices (no {r} suffix)
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

    final isTesting =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(13.874324, 100.40142),
            initialZoom: 12.0,
            maxZoom: 18.0,
            minZoom: 8.0,
          ),
          children: [
            if (!isTesting)
              TileLayer(
                urlTemplate: tileUrl,
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.loscheck.app',
                // Performance: reduce tile buffer for low-end devices
                keepBuffer: 1,
                maxNativeZoom: 18,
              ),
            PolylineLayer(polylines: _buildRoutePolylines()),
            MarkerLayer(markers: _buildRouteMarkers()),
          ],
        ),
      ),
    );
  }

  List<LatLng> _getSetupPreviewPathPoints(
    List<CustomerRecord> selectedTargets,
  ) {
    final origin = LatLng(_currentLat, _currentLng);
    final orderedRoute = _calculateGreedyRoute(
      origin.latitude,
      origin.longitude,
      selectedTargets,
    );
    final cacheKey = _routeCacheKey(
      orderedRoute,
      origin.latitude,
      origin.longitude,
      true,
    );

    if (_setupPreviewPathCacheKey == cacheKey &&
        _setupPreviewPathCacheValue != null) {
      return _setupPreviewPathCacheValue!;
    }

    final pathPoints = <LatLng>[];
    if (orderedRoute.isNotEmpty) {
      LatLng currentLoc = origin;
      final router = OsmRouterService();
      for (final c in orderedRoute) {
        final destination = LatLng(c.latitude!, c.longitude!);
        final segment = router.findRoute(currentLoc, destination);
        if (pathPoints.isNotEmpty && segment.isNotEmpty) {
          pathPoints.addAll(segment.skip(1));
        } else {
          pathPoints.addAll(segment);
        }
        currentLoc = destination;
      }
    }

    _setupPreviewPathCacheKey = cacheKey;
    _setupPreviewPathCacheValue = List<LatLng>.unmodifiable(pathPoints);
    return _setupPreviewPathCacheValue!;
  }

  /// Setup mode map preview — shows selected customer pins and route preview
  Widget _buildSetupMapPreview(List<CustomerRecord> allCustomers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    final selectedTargets = allCustomers.where((c) {
      return _selectedCustomerPhones.contains(c.phone) &&
          c.latitude != null &&
          c.longitude != null;
    }).toList();

    final previewPathPoints = _getSetupPreviewPathPoints(selectedTargets);

    final previewMarkers = <Marker>[
      // Start location
      Marker(
        point: LatLng(_currentLat, _currentLng),
        width: 36,
        height: 36,
        child: _buildPinMarker(
          color: isDark ? const Color(0xFF42A5F5) : const Color(0xFF1565C0),
          icon: Icons.my_location,
          size: 32,
        ),
      ),
    ];

    // Clustering logic: Group customers by distance based on current map zoom
    final List<List<CustomerRecord>> clusters = [];
    final double thresholdMeters = (3000 * pow(2.0, 11.0 - _setupZoom))
        .toDouble();
    final distance = const Distance();

    for (final c in allCustomers) {
      if (c.latitude == null || c.longitude == null) continue;
      final cLoc = LatLng(c.latitude!, c.longitude!);

      bool addedToCluster = false;
      for (final cluster in clusters) {
        final firstInCluster = cluster.first;
        final firstLoc = LatLng(
          firstInCluster.latitude!,
          firstInCluster.longitude!,
        );
        if (distance.distance(cLoc, firstLoc) < thresholdMeters) {
          cluster.add(c);
          addedToCluster = true;
          break;
        }
      }

      if (!addedToCluster) {
        clusters.add([c]);
      }
    }

    // Render clusters to markers
    for (final cluster in clusters) {
      if (cluster.isEmpty) continue;

      // Calculate center coordinate of cluster
      double avgLat = 0.0;
      double avgLng = 0.0;
      for (final c in cluster) {
        avgLat += c.latitude!;
        avgLng += c.longitude!;
      }
      avgLat /= cluster.length;
      avgLng /= cluster.length;
      final clusterPoint = LatLng(avgLat, avgLng);

      if (cluster.length == 1) {
        final c = cluster.first;
        final isSelected = _selectedCustomerPhones.contains(c.phone);
        previewMarkers.add(
          Marker(
            point: clusterPoint,
            width: 38,
            height: 38,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedCustomerPhones.contains(c.phone)) {
                    _selectedCustomerPhones.remove(c.phone);
                  } else {
                    _selectedCustomerPhones.add(c.phone);
                  }
                });
              },
              child: Opacity(
                opacity: isSelected ? 1.0 : 0.65,
                child: _buildPinMarker(
                  color: isSelected
                      ? const Color(0xFFFBC02D) // Selected: Amber
                      : const Color(0xFF00897B), // Unselected: Teal
                  label: c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  size: 34,
                ),
              ),
            ),
          ),
        );
      } else {
        final clusterPhones = cluster.map((c) => c.phone).toList();
        final selectedCount = clusterPhones
            .where((p) => _selectedCustomerPhones.contains(p))
            .length;
        final hasSelected = selectedCount > 0;
        final allSelected = selectedCount == cluster.length;
        final isSelectedMode = hasSelected;

        previewMarkers.add(
          Marker(
            point: clusterPoint,
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () {
                final anyUnselected = clusterPhones.any(
                  (p) => !_selectedCustomerPhones.contains(p),
                );
                setState(() {
                  if (anyUnselected) {
                    for (final p in clusterPhones) {
                      _selectedCustomerPhones.add(p);
                    }
                  } else {
                    for (final p in clusterPhones) {
                      _selectedCustomerPhones.remove(p);
                    }
                  }
                });
              },
              child: Opacity(
                opacity: isSelectedMode ? 1.0 : 0.8,
                child: _buildClusterMarker(
                  count: cluster.length,
                  hasSelected: hasSelected,
                  allSelected: allSelected,
                  size: 40,
                ),
              ),
            ),
          ),
        );
      }
    }

    final isTesting =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    return ClipRRect(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(_currentLat, _currentLng),
          initialZoom: _setupZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
          onPositionChanged: (position, hasGesture) {
            if (position.zoom != null && position.zoom != _setupZoom) {
              setState(() {
                _setupZoom = position.zoom!;
              });
            }
          },
        ),
        children: [
          if (!isTesting)
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.loscheck.app',
            ),
          if (previewPathPoints.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: previewPathPoints,
                  strokeWidth: 3.0,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
          MarkerLayer(markers: previewMarkers),
        ],
      ),
    );
  }

  Widget buildCompletionCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPlanned = _completedQueue.length;
    return Padding(
      padding: DesignTokens.paddingL,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE0F2F1),
            width: 1,
          ),
        ),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00897B).withValues(alpha: 0.2),
                    width: 4,
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00897B),
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ยินดีด้วย!',
                style: kanitTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00897B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณเดินทางเสร็จสิ้นครบทุกจุดหมายเรียบร้อยแล้ว',
                textAlign: TextAlign.center,
                style: kanitTextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CompletionStat(
                    icon: Icons.location_on_outlined,
                    label: 'จำนวนจุด',
                    value: '$totalPlanned จุด',
                  ),
                  CompletionStat(
                    icon: Icons.directions_car_outlined,
                    label: 'ระยะทางรวม',
                    value:
                        '${_calculateCompletedRouteDistance(_completedQueue).toStringAsFixed(1)} กม.',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _resetNavigation,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'กลับหน้าวางแผนใหม่',
                    style: kanitTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    if (appState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasInitializedSelection) {
      final isTesting =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (!isTesting && appState.customers.isNotEmpty) {
        for (final c in appState.customers) {
          if (c.latitude != null && c.longitude != null) {
            _selectedCustomerPhones.add(c.phone);
          }
        }
        _hasInitializedSelection = true;
      } else if (isTesting) {
        _hasInitializedSelection = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        title: Text(
          _isNavigating ? 'นำทางจัดส่ง' : 'วางแผนเส้นทาง',
          style: kanitTextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        leading: _isNavigating
            ? IconButton(
                tooltip: 'ยกเลิกแผนการเดินทาง',
                icon: const Icon(Icons.close),
                onPressed: _resetNavigation,
              )
            : const BackButton(),
        actions: _isNavigating
            ? [
                IconButton(
                  tooltip: 'แสดงเส้นทางทั้งหมดบนแผนที่',
                  icon: const Icon(Icons.fit_screen_outlined),
                  onPressed: _fitMapToRoute,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _isNavigating
                ? RoutePlanningNavigationView(state: this)
                : RoutePlanningSetupView(state: this, customers: appState.customers),
          ),
        ),
      ),
    );
  }
}
