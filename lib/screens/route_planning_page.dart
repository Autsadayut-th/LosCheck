import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_record.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import '../core/design_tokens.dart';
import '../services/osm_router_service.dart';

class RoutePlanningPage extends StatelessWidget {
  const RoutePlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      Provider.of<AppStateProvider>(context, listen: false);
      return const _RoutePlanningPageContent();
    } catch (_) {
      return ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: const _RoutePlanningPageContent(),
      );
    }
  }
}

class _RoutePlanningPageContent extends StatefulWidget {
  const _RoutePlanningPageContent();

  @override
  State<_RoutePlanningPageContent> createState() => _RoutePlanningPageContentState();
}

class _RoutePlanningPageContentState extends State<_RoutePlanningPageContent> {
  // Map Controller
  final MapController _mapController = MapController();

  // Navigation State
  bool _isNavigating = false;
  bool _isAutoMode = true;

  // Selected customers for planning
  final Set<String> _selectedCustomerPhones = {};
  String _searchQuery = '';

  // Coordinates
  double _currentLat = 13.7563; // Default Bangkok Lat
  double _currentLng = 100.5018; // Default Bangkok Lng
  bool _isFetchingLocation = false;

  // Active navigation queues
  List<CustomerRecord> _remainingQueue = [];
  List<CustomerRecord> _completedQueue = [];

  // Controllers for coordinates
  final TextEditingController _latController =
      TextEditingController(text: '13.7563');
  final TextEditingController _lngController =
      TextEditingController(text: '100.5018');

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
    _mapController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _tryGetGPSLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null) {
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
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _manualFetchGPS() async {
    setState(() => _isFetchingLocation = true);
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null) {
        setState(() {
          _currentLat = loc['latitude']!;
          _currentLng = loc['longitude']!;
          _latController.text = _currentLat.toStringAsFixed(6);
          _lngController.text = _currentLng.toStringAsFixed(6);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดึงตำแหน่ง GPS ปัจจุบันสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'ไม่สามารถดึงตำแหน่งได้ กรุณาเปิดสิทธิ์ GPS หรือใส่พิกัดด้วยตัวเอง'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  // Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // TSP Greedy sequence calculation
  List<CustomerRecord> _calculateGreedyRoute(
      double startLat, double startLng, List<CustomerRecord> targets) {
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
              currentLat, currentLng, target.latitude!, target.longitude!);
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
    if (targets.isEmpty) return 0.0;
    
    final startLat = double.tryParse(_latController.text) ?? _currentLat;
    final startLng = double.tryParse(_lngController.text) ?? _currentLng;
    
    final route = _calculateGreedyRoute(startLat, startLng, targets);
    return _calculateRouteDistanceWithOSM(route);
  }

  double _calculateRouteDistanceWithOSM(List<CustomerRecord> sortedRoute) {
    if (sortedRoute.isEmpty) return 0.0;
    
    final startLat = double.tryParse(_latController.text) ?? _currentLat;
    final startLng = double.tryParse(_lngController.text) ?? _currentLng;
    
    double total = 0.0;
    LatLng currentLoc = LatLng(startLat, startLng);
    
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกลูกค้าที่มีพิกัดอย่างน้อย 1 รายการ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _currentLat = parsedLat;
      _currentLng = parsedLng;
      _completedQueue = [];

      if (_isAutoMode) {
        _remainingQueue =
            _calculateGreedyRoute(_currentLat, _currentLng, selectedTargets);
      } else {
        _remainingQueue = List.from(selectedTargets);
      }

      _isNavigating = true;
    });

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
        _remainingQueue =
            _calculateGreedyRoute(pivotLat, pivotLng, _remainingQueue);
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
            completed.latitude!, completed.longitude!, _remainingQueue);
      }

      if (_remainingQueue.isEmpty) {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final totalDist = _calculateTotalRouteDistance(_completedQueue);
        appState.recordRouteCompletion(_completedQueue.length, totalDist);
      }
    });

    // Auto-pan to next destination
    if (_remainingQueue.isNotEmpty &&
        _remainingQueue.first.latitude != null &&
        _remainingQueue.first.longitude != null) {
      _mapController.move(
        LatLng(_remainingQueue.first.latitude!, _remainingQueue.first.longitude!),
        15.0,
      );
    }
  }

  void _resetNavigation() {
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

  Future<void> _openGoogleMapsDirections(CustomerRecord customer) async {
    if (customer.latitude == null || customer.longitude == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$_currentLat,$_currentLng'
      '&destination=${customer.latitude},${customer.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิด Google Maps ได้')),
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
            color: isActive
                ? const Color(0xFFFBC02D)
                : const Color(0xFF00897B),
            icon: isActive ? Icons.star : null,
            label: isActive ? null : '${i + 1}',
            size: isActive ? 48 : 36,
          ),
        ),
      );
    }

    return markers;
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
            color: Colors.black.withOpacity(0.25),
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
        color: Theme.of(context).colorScheme.primary.withOpacity(0.75),
      ),
    ];
  }

  Widget _buildEmbeddedMap() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use non-retina tiles for low-end devices (no {r} suffix)
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(13.7563, 100.5018),
                initialZoom: 12.0,
                maxZoom: 18.0,
                minZoom: 8.0,
              ),
              children: [
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
            // Fit-to-route button
            Positioned(
              bottom: 10,
              right: 10,
              child: FloatingActionButton.small(
                heroTag: 'fitRoute',
                onPressed: _fitMapToRoute,
                tooltip: 'แสดงเส้นทางทั้งหมด',
                child: const Icon(Icons.fit_screen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    if (appState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _isNavigating
                ? _buildNavigationScreen()
                : _buildSetupScreen(appState.customers),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupScreen(List<CustomerRecord> customers) {
    final filteredCustomers = customers.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.phone.contains(_searchQuery);
    }).toList();

    // Selected customers with valid coords for the setup map
    final selectedWithCoords = customers.where((c) {
      return _selectedCustomerPhones.contains(c.phone) &&
          c.latitude != null &&
          c.longitude != null;
    }).toList();

    // Adaptive map height: smaller on compact screens (e.g. Infinix Smart 3)
    final screenHeight = MediaQuery.sizeOf(context).height;
    final mapHeight = screenHeight < 650 ? 160.0 : 220.0;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top: Embedded map preview (setup mode) ──────────────
        if (!isKeyboardOpen)
          SizedBox(
            height: mapHeight,
            child: Stack(
              children: [
                _buildSetupMapPreview(customers),
                // Title overlay
                Positioned(
                  top: 12,
                  left: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'วางแผนเส้นทางนำทาง',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Bottom: Setup UI ──────────────────────────────────────
        // Compact GPS row (always visible, not in a tall Card)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    isDense: true,
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    isDense: true,
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isFetchingLocation ? null : _manualFetchGPS,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isFetchingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Mode toggle row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'เลือกลูกค้าจัดส่ง',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _ModeToggleButton(
                      label: 'จัดออโต้',
                      isSelected: _isAutoMode,
                      onPressed: () => _toggleRouteMode(true),
                    ),
                    _ModeToggleButton(
                      label: 'จัดเอง',
                      isSelected: !_isAutoMode,
                      onPressed: () => _toggleRouteMode(false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อหรือเบอร์โทร...',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Customer list — fills remaining space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: filteredCustomers.isEmpty
                ? Center(
                    child: Text(
                      customers.isEmpty
                          ? 'ไม่มีข้อมูลลูกค้าในระบบ'
                          : 'ไม่พบข้อมูลลูกค้าที่ค้นหา',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : Card(
                    elevation: 1,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: DesignTokens.borderRadiusLg),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(6),
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final hasCoords = customer.latitude != null &&
                            customer.longitude != null;
                        final isSelected =
                            _selectedCustomerPhones.contains(customer.phone);

                        return CheckboxListTile(
                          dense: true,
                          enabled: hasCoords,
                          value: isSelected,
                          onChanged: (bool? val) {
                            setState(() {
                              if (val == true) {
                                _selectedCustomerPhones.add(customer.phone);
                              } else {
                                _selectedCustomerPhones.remove(customer.phone);
                              }
                            });
                          },
                          title: Text(
                            customer.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: hasCoords
                                  ? null
                                  : TextDecoration.lineThrough,
                              color: hasCoords ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            hasCoords
                                ? customer.phone
                                : '${customer.phone} · ⚠️ ไม่มีพิกัด',
                            style: TextStyle(
                              fontSize: 11,
                              color: hasCoords
                                  ? null
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                          secondary: CircleAvatar(
                            radius: 16,
                            backgroundColor: hasCoords
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                : Colors.grey.shade300,
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: hasCoords
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Colors.grey.shade600,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),

        // Start navigation button — pinned at bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ElevatedButton(
            onPressed: _selectedCustomerPhones.isEmpty
                ? null
                : () => _startNavigation(customers),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: DesignTokens.borderRadiusMd),
            ),
            child: Builder(
              builder: (context) {
                final selectedTargets = customers.where((c) {
                  return _selectedCustomerPhones.contains(c.phone) &&
                      c.latitude != null &&
                      c.longitude != null;
                }).toList();
                final totalDist = _calculateTotalRouteDistance(selectedTargets);
                return Text(
                  'เริ่มนำทาง (${_selectedCustomerPhones.length} จุด · ระยะทาง ~${totalDist.toStringAsFixed(1)} กม.)',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                );
              }
            ),
          ),
        ),
      ],
    );
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

    final orderedRoute = _calculateGreedyRoute(_currentLat, _currentLng, selectedTargets);
    final List<LatLng> previewPathPoints = [];
    if (orderedRoute.isNotEmpty) {
      LatLng currentLoc = LatLng(_currentLat, _currentLng);
      final router = OsmRouterService();
      for (final c in orderedRoute) {
        final destination = LatLng(c.latitude!, c.longitude!);
        final segment = router.findRoute(currentLoc, destination);
        if (previewPathPoints.isNotEmpty && segment.isNotEmpty) {
          previewPathPoints.addAll(segment.skip(1));
        } else {
          previewPathPoints.addAll(segment);
        }
        currentLoc = destination;
      }
    }

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
      // All customers (Selected highlighted in Amber, unselected faded Teal)
      for (final c in allCustomers)
        if (c.latitude != null && c.longitude != null)
          Marker(
            point: LatLng(c.latitude!, c.longitude!),
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
                opacity: _selectedCustomerPhones.contains(c.phone) ? 1.0 : 0.65,
                child: _buildPinMarker(
                  color: _selectedCustomerPhones.contains(c.phone)
                      ? const Color(0xFFFBC02D) // Selected: Amber
                      : const Color(0xFF00897B), // Unselected: Teal
                  label: c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  size: 34,
                ),
              ),
            ),
          ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(0),
        bottomRight: Radius.circular(0),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(_currentLat, _currentLng),
          initialZoom: 11.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                ),
              ],
            ),
          MarkerLayer(markers: previewMarkers),
        ],
      ),
    );
  }

  Widget _buildNavigationScreen() {
    final double pivotLat =
        _completedQueue.isNotEmpty && _completedQueue.last.latitude != null
            ? _completedQueue.last.latitude!
            : _currentLat;
    final double pivotLng =
        _completedQueue.isNotEmpty && _completedQueue.last.longitude != null
            ? _completedQueue.last.longitude!
            : _currentLng;

    if (_remainingQueue.isEmpty) {
      return _buildCompletionCard();
    }

    final activeCustomer = _remainingQueue.first;
    double activeDistance = 0.0;
    if (activeCustomer.latitude != null && activeCustomer.longitude != null) {
      final segment = OsmRouterService().findRoute(
        LatLng(pivotLat, pivotLng),
        LatLng(activeCustomer.latitude!, activeCustomer.longitude!),
      );
      activeDistance = OsmRouterService().calculateRouteDistance(segment);
    }

    final totalRemaining = _remainingQueue.length;
    final totalCompleted = _completedQueue.length;
    final totalPlanned = totalRemaining + totalCompleted;
    final progress = totalPlanned > 0 ? totalCompleted / totalPlanned : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top: Embedded live map (40%) ─────────────────────────
        SizedBox(height: 220, child: _buildEmbeddedMap()),

        // ── Bottom: Navigation UI (60%) ──────────────────────────
        Expanded(
          child: Padding(
            padding: DesignTokens.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'คิวเส้นทางจัดส่ง',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'จุดหมายที่ $totalCompleted / $totalPlanned',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress Bar
                LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 10,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),

                // Active Customer Card
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.borderRadiusLg,
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2),
                  ),
                  child: Padding(
                    padding: DesignTokens.paddingM,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'จุดหมายปัจจุบัน (Active)',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              'ห่าง ~${activeDistance.toStringAsFixed(2)} กม.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          activeCustomer.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'เบอร์โทร: ${activeCustomer.phone}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.85),
                          ),
                        ),
                        Text(
                          'ที่อยู่: ${activeCustomer.address}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openGoogleMapsDirections(
                                    activeCustomer),
                                icon: const Icon(Icons.navigation),
                                label: const Text('นำทาง Maps'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 1.5),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                key: const Key('jobCompletedButton'),
                                onPressed: _completeActiveDestination,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('งานเสร็จสิ้น'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Routing Mode Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'คิวที่เหลือ (${totalRemaining - 1} จุดหมาย)',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _ModeToggleButton(
                            label: 'จัดออโต้',
                            isSelected: _isAutoMode,
                            onPressed: () => _toggleRouteMode(true),
                          ),
                          _ModeToggleButton(
                            label: 'จัดเอง',
                            isSelected: !_isAutoMode,
                            onPressed: () => _toggleRouteMode(false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Reorderable / auto queue list
                Expanded(
                  child: _isAutoMode
                      ? ListView.builder(
                          itemCount: _remainingQueue.length - 1,
                          itemBuilder: (context, idx) {
                            final itemIdx = idx + 1;
                            final customer = _remainingQueue[itemIdx];
                            final double prevLat =
                                _remainingQueue[idx].latitude!;
                            final double prevLng =
                                _remainingQueue[idx].longitude!;
                            final segment = OsmRouterService().findRoute(
                              LatLng(prevLat, prevLng),
                              LatLng(customer.latitude!, customer.longitude!),
                            );
                            final double distance = OsmRouterService().calculateRouteDistance(segment);
                            return _QueueItemCard(
                              index: itemIdx + totalCompleted,
                              name: customer.name,
                              address: customer.address,
                              phone: customer.phone,
                              distanceLabel:
                                  'ระยะห่างจากจุดก่อนหน้า ~${distance.toStringAsFixed(2)} กม.',
                              trailing: Icon(Icons.lock_clock,
                                  color: Colors.grey.shade400),
                            );
                          },
                        )
                      : ReorderableListView.builder(
                          itemCount: _remainingQueue.length - 1,
                          onReorder: (oldIndex, newIndex) {
                            final actualOld = oldIndex + 1;
                            final actualNew = newIndex >=
                                    _remainingQueue.length
                                ? _remainingQueue.length - 1
                                : newIndex + 1;
                            setState(() {
                              if (actualOld < actualNew) {
                                final item =
                                    _remainingQueue.removeAt(actualOld);
                                _remainingQueue.insert(actualNew - 1, item);
                              } else {
                                final item =
                                    _remainingQueue.removeAt(actualOld);
                                _remainingQueue.insert(actualNew, item);
                              }
                            });
                          },
                          itemBuilder: (context, idx) {
                            final itemIdx = idx + 1;
                            final customer = _remainingQueue[itemIdx];
                            final double prevLat =
                                _remainingQueue[idx].latitude!;
                            final double prevLng =
                                _remainingQueue[idx].longitude!;
                            final segment = OsmRouterService().findRoute(
                              LatLng(prevLat, prevLng),
                              LatLng(customer.latitude!, customer.longitude!),
                            );
                            final double distance = OsmRouterService().calculateRouteDistance(segment);
                            return _QueueItemCard(
                              key: ValueKey(customer.phone),
                              index: itemIdx + totalCompleted,
                              name: customer.name,
                              address: customer.address,
                              phone: customer.phone,
                              distanceLabel:
                                  'ระยะห่าง ~${distance.toStringAsFixed(2)} กม.',
                              trailing: const Icon(Icons.drag_handle),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),

                // Cancel Navigation Button
                TextButton.icon(
                  onPressed: _resetNavigation,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('ยกเลิกแผนการเดินทาง',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionCard() {
    return Padding(
      padding: DesignTokens.paddingL,
      child: Card(
        elevation: 6,
        shape:
            RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(24),
                child:
                    const Icon(Icons.emoji_events, size: 80, color: Colors.green),
              ),
              const SizedBox(height: 24),
              Text(
                'ยินดีด้วย!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณเดินทางเสร็จสิ้นครบทุกจุดหมายเรียบร้อยแล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CompletionStat(
                    icon: Icons.check_circle,
                    label: 'งานสำเร็จ',
                    value: '${_completedQueue.length} จุด',
                  ),
                  _CompletionStat(
                    icon: Icons.navigation_rounded,
                    label: 'ระยะทางรวม',
                    value: '~${_calculateTotalRouteDistance(_completedQueue).toStringAsFixed(1)} กม.',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _resetNavigation,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'กลับหน้าวางแผนใหม่',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Standalone Widget Classes ──────────────────────────────────────────────

class _CompletionStat extends StatelessWidget {
  const _CompletionStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        foregroundColor: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({
    super.key,
    required this.index,
    required this.name,
    required this.address,
    required this.phone,
    required this.distanceLabel,
    this.trailing,
  });

  final int index;
  final String name;
  final String address;
  final String phone;
  final String distanceLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            '$index',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('โทร: $phone | $address',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              distanceLabel,
              style: TextStyle(
                fontSize: 11,
                color:
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}
