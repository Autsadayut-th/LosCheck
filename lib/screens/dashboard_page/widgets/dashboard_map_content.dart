import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/trip_record.dart';
import '../../../models/customer_record.dart';
import '../../../providers/app_state_provider.dart';
import '../../../services/location_service.dart';
import '../../../core/design_tokens.dart';
import '../../../core/theme_extensions.dart';
import '../../route_planning/route_planning_page.dart';

import 'action_button.dart';
import 'glass_search_bar.dart';
import 'cluster_bottom_sheet.dart';
import 'customer_bottom_sheet.dart';

/// วิดเจ็ตหลักที่รวบรวมแผนที่ คอนโทรลเลอร์ ตัวระบุตำแหน่ง และแถบค้นหาลูกค้าเข้าด้วยกัน
class DashboardMapContent extends StatefulWidget {
  const DashboardMapContent({
    super.key,
    required this.tripRecords,
    required this.customerRecords,
  });

  final List<TripRecord> tripRecords;
  final List<CustomerRecord> customerRecords;

  @override
  State<DashboardMapContent> createState() => _DashboardMapContentState();
}

class _DashboardMapContentState extends State<DashboardMapContent> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  double _currentZoom = 13.0;
  final LatLng _mapCenter = const LatLng(13.7563, 100.5018);
  bool _isLocating = false;
  CustomerRecord? _selectedCustomer;
  List<CustomerRecord> _searchResults = [];
  bool _isSearching = false;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnUser(showErrors: false);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Clustering ──────────────────────────────────────────────────────────────
  double get _clusterDelta {
    if (_currentZoom >= 16) return 0.0;
    if (_currentZoom >= 14) return 0.005;
    if (_currentZoom >= 12) return 0.015;
    if (_currentZoom >= 10) return 0.04;
    if (_currentZoom >= 8) return 0.12;
    return 0.35;
  }

  List<Marker> _buildMarkers(List<CustomerRecord> customers, bool isDark) {
    final markers = <Marker>[];
    final delta = _clusterDelta;

    if (delta == 0.0) {
      for (final c in customers) {
        if (c.latitude == null || c.longitude == null) continue;
        markers.add(_buildSingleMarker(c));
      }
      if (_userLocation != null) {
        markers.add(
          Marker(
            point: _userLocation!,
            width: 56,
            height: 56,
            child: _buildUserLocationDot(),
          ),
        );
      }
      return markers;
    }

    final grid = <String, List<CustomerRecord>>{};
    for (final c in customers) {
      if (c.latitude == null || c.longitude == null) continue;
      final gLat = (c.latitude! / delta).round() * delta;
      final gLng = (c.longitude! / delta).round() * delta;
      final key =
          '${gLat.toStringAsFixed(5)},${gLng.toStringAsFixed(5)}';
      grid.putIfAbsent(key, () => []).add(c);
    }

    grid.forEach((_, items) {
      if (items.isEmpty) return;
      if (items.length == 1) {
        markers.add(_buildSingleMarker(items.first));
      } else {
        double sumLat = 0, sumLng = 0;
        for (final item in items) {
          sumLat += item.latitude!;
          sumLng += item.longitude!;
        }
        final center =
            LatLng(sumLat / items.length, sumLng / items.length);
        markers.add(
          Marker(
            point: center,
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => _showClusterSheet(items),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF33BCB4), Color(0xFFF9BE00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 56,
          height: 56,
          child: _buildUserLocationDot(),
        ),
      );
    }
    return markers;
  }

  Marker _buildSingleMarker(CustomerRecord customer) {
    final initials =
        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';
    final isSelected = _selectedCustomer?.phone == customer.phone;

    return Marker(
      point: LatLng(customer.latitude!, customer.longitude!),
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => _selectCustomer(customer),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF9BE00)
                : const Color(0xFF33BCB4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
                color: Colors.white, width: isSelected ? 3 : 2),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocationDot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2196F3).withOpacity(0.2),
            border: Border.all(
              color: const Color(0xFF2196F3).withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2196F3),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectCustomer(CustomerRecord customer) {
    setState(() {
      _selectedCustomer = customer;
      _isSearching = false;
    });
    if (customer.latitude != null && customer.longitude != null) {
      _mapController.move(
          LatLng(customer.latitude!, customer.longitude!), 16.0);
    }
    _showCustomerSheet(customer);
  }

  void _showClusterSheet(List<CustomerRecord> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClusterBottomSheet(
        items: items,
        onSelectCustomer: (c) => _selectCustomer(c),
        onCallCustomer: (phone) => _callCustomer(phone),
        onOpenInGoogleMaps: (c) => _openInGoogleMaps(c),
      ),
    );
  }

  void _showCustomerSheet(CustomerRecord customer) {
    _scaffoldKey.currentState?.showBottomSheet(
      backgroundColor: Colors.transparent,
      (ctx) => CustomerBottomSheet(
        customer: customer,
        onCallCustomer: (phone) => _callCustomer(phone),
        onOpenInGoogleMaps: (c) => _openInGoogleMaps(c),
        onClose: () => setState(() => _selectedCustomer = null),
        onNavigateToRoutePlanning: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoutePlanningPage()),
        ),
      ),
    );
  }

  Future<void> _callCustomer(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openInGoogleMaps(CustomerRecord c) async {
    if (c.latitude == null || c.longitude == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${c.latitude},${c.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _centerOnUser({bool showErrors = true}) async {
    setState(() => _isLocating = true);
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null) {
        final userLatLng = LatLng(loc['latitude']!, loc['longitude']!);
        _mapController.move(userLatLng, 15.0);
        setState(() {
          _userLocation = userLatLng;
        });
      } else {
        if (!showErrors || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('ไม่สามารถระบุพิกัด GPS ได้ กรุณาเปิดสิทธิ์ GPS'),
          ),
        );
      }
    } catch (e) {
      if (!showErrors || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  void _onSearchChanged(
      String query, List<CustomerRecord> customersWithCoords) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _searchResults = customersWithCoords
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.contains(query) ||
              c.address.toLowerCase().contains(q))
          .toList();
      _isSearching = true;
    });
  }

  Widget _buildPillDivider(bool isDark) {
    return Container(
      height: 14,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    final customersWithCoords = widget.customerRecords
        .where((c) => c.latitude != null && c.longitude != null)
        .toList();

    final appState = Provider.of<AppStateProvider>(context);
    final today = DateTime.now();
    final todayTrips = widget.tripRecords.where((t) => t.isSameDay(today));
    final todayRevenue = todayTrips.fold<int>(0, (sum, r) => sum + r.totalBaht);
    final todayRounds = todayTrips.fold<int>(0, (sum, r) => sum + r.rounds);
    final todayCustomers = appState.completedDeliveryPoints;
    final todayDistance = appState.completedRouteDistance;

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          // ── Full-screen Map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _currentZoom,
              onPositionChanged: (pos, _) {
                if (pos.zoom != null && pos.zoom != _currentZoom) {
                  setState(() => _currentZoom = pos.zoom!);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.loscheck.app',
                keepBuffer: 1,
                maxNativeZoom: 18,
              ),
              MarkerLayer(
                markers: _buildMarkers(customersWithCoords, isDark),
              ),
            ],
          ),

          // ── TOP overlay: Search + Stats ──────────────────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Search Bar on top ─────────────────────────────────────────
                GlassSearchBar(
                  isDark: isDark,
                  controller: _searchController,
                  onChanged: (v) =>
                      _onSearchChanged(v, customersWithCoords),
                ),
                const SizedBox(height: 10),

                // ── Floating Summary Card (Compact Horizontal Pill) ───────────
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFE0F5F4),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Revenue
                          Text(
                            '$todayRevenue ฿',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF66D4CE) : const Color(0xFF33BCB4),
                            ),
                          ),
                          _buildPillDivider(isDark),
                          // Rounds
                          const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF33BCB4)),
                          const SizedBox(width: 4),
                          Text(
                            '$todayRounds รอบ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          _buildPillDivider(isDark),
                          // Customers
                          const Icon(Icons.people_outline, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '$todayCustomers คน',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          _buildPillDivider(isDark),
                          // Distance
                          const Icon(Icons.route_outlined, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${todayDistance.toStringAsFixed(1)} กม.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Search Results Dropdown ──────────────────────────────────
                if (_isSearching && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final c = _searchResults[i];
                        return ListTile(
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(c.phone),
                          leading: const Icon(Icons.location_on,
                              color: Color(0xFF33BCB4)),
                          onTap: () => _selectCustomer(c),
                        );
                      },
                    ),
                  )
                else if (_isSearching && _searchResults.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'ไม่พบข้อมูลลูกค้าที่มีพิกัดแผนที่',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),

          // ── Stacked Map Controls (bottom-right) ──────────────────────────
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // My Location
                FloatingActionButton.small(
                  heroTag: 'dash_my_loc',
                  onPressed: _isLocating ? null : _centerOnUser,
                  backgroundColor: const Color(0xFF33BCB4),
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: _isLocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.0, color: Colors.white),
                        )
                      : const Icon(Icons.my_location, size: 18),
                ),
              ],
            ),
          ),

          // ── Bottom CTA panel (Sleek Centered Floating Pill) ──────────────
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: ActionButton(
                  icon: Icons.navigation_rounded,
                  label: 'วางแผนและนำทาง',
                  subtitle: '',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF33BCB4), Color(0xFF66D4CE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RoutePlanningPage()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
