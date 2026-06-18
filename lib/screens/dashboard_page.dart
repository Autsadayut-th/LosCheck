import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trip_record.dart';
import '../models/customer_record.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import '../core/design_tokens.dart';
import 'route_planning_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main Dashboard Page (merged with Map)
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    try {
      final appState = Provider.of<AppStateProvider>(context);
      return _buildContent(context, appState);
    } catch (_) {
      return ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: Consumer<AppStateProvider>(
          builder: (context, appState, _) => _buildContent(context, appState),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context, AppStateProvider appState) {
    if (appState.isLoading) {
      return const _LoadingView();
    }
    if (appState.error != null) {
      return _ErrorView(error: appState.error);
    }
    return _DashboardMapContent(
      tripRecords: appState.trips,
      customerRecords: appState.customers,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error views
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด: ${error ?? 'ไม่ทราบสาเหตุ'}'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main merged content widget
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardMapContent extends StatefulWidget {
  const _DashboardMapContent({
    required this.tripRecords,
    required this.customerRecords,
  });

  final List<TripRecord> tripRecords;
  final List<CustomerRecord> customerRecords;

  @override
  State<_DashboardMapContent> createState() => _DashboardMapContentState();
}

class _DashboardMapContentState extends State<_DashboardMapContent> {
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

  // ── Computed stats ──────────────────────────────────────────────────────────
  int get _totalRevenue =>
      widget.tripRecords.fold<int>(0, (sum, r) => sum + r.totalBaht);
  int get _totalItems => widget.tripRecords.length;
  int get _totalRounds =>
      widget.tripRecords.fold<int>(0, (sum, r) => sum + r.rounds);
  int get _totalCustomers => widget.customerRecords.length;

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
                    colors: [Color(0xFF00897B), Color(0xFFFBC02D)],
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
                ? const Color(0xFFFBC02D)
                : const Color(0xFF00897B),
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
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.group_work_outlined,
                      color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ลูกค้าในกลุ่มนี้ (${items.length} ราย)',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx2, idx) {
                  final c = items[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  Theme.of(ctx2).colorScheme.primaryContainer,
                              child: Text(
                                c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: Theme.of(ctx2)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  Text('โทร: ${c.phone}',
                                      style: TextStyle(
                                          color: Theme.of(ctx2)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withOpacity(0.8),
                                          fontSize: 12)),
                                  Text(c.address,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor:
                                    Theme.of(ctx2).colorScheme.primary,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _selectCustomer(c);
                              },
                              icon: const Icon(Icons.location_searching,
                                  size: 16),
                              label: const Text('ระบุพิกัด',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor:
                                    Theme.of(ctx2).colorScheme.secondary,
                              ),
                              onPressed: () => _callCustomer(c.phone),
                              icon: const Icon(Icons.phone_outlined, size: 16),
                              label: const Text('โทร',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                elevation: 0,
                                backgroundColor: Theme.of(ctx2)
                                    .colorScheme
                                    .primaryContainer,
                                foregroundColor: Theme.of(ctx2)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                              onPressed: () => _openInGoogleMaps(c),
                              icon: const Icon(Icons.navigation_outlined,
                                  size: 16),
                              label: const Text('นำทาง',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerSheet(CustomerRecord customer) {
    _scaffoldKey.currentState?.showBottomSheet(
      backgroundColor: Colors.transparent,
      (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        Theme.of(ctx).colorScheme.primaryContainer,
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('เบอร์โทร: ${customer.phone}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('ที่อยู่: ${customer.address}',
                            style: const TextStyle(fontSize: 14)),
                        if (customer.latitude != null &&
                            customer.longitude != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'พิกัด: ${customer.latitude}, ${customer.longitude}',
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedCustomer = null);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callCustomer(customer.phone),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('โทรหา'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openInGoogleMaps(customer),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('นำทาง'),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RoutePlanningPage()),
                  );
                },
                icon: const Icon(Icons.route),
                label: const Text('วางแผนเส้นทางส่งของ'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    final customersWithCoords = widget.customerRecords
        .where((c) => c.latitude != null && c.longitude != null)
        .toList();

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
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Search Bar on top ─────────────────────────────────────────
                _GlassSearchBar(
                  isDark: isDark,
                  controller: _searchController,
                  onChanged: (v) =>
                      _onSearchChanged(v, customersWithCoords),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left: Revenue, Items, Rounds (vertical column) ───────
                    _GlassStatGroup(
                      isDark: isDark,
                      isVertical: true,
                      children: [
                        _MiniStat(
                          icon: Icons.attach_money,
                          value: '$_totalRevenue ฿',
                          label: 'รายได้',
                          color: const Color(0xFFF2994A),
                        ),
                        _HorizontalDivider(isDark: isDark),
                        _MiniStat(
                          icon: Icons.receipt_long,
                          value: '$_totalItems',
                          label: 'รายการ',
                          color: const Color(0xFF11998E),
                        ),
                        _HorizontalDivider(isDark: isDark),
                        _MiniStat(
                          icon: Icons.local_shipping,
                          value: '$_totalRounds',
                          label: 'รอบ',
                          color: const Color(0xFFF857A6),
                        ),
                      ],
                    ),

                    // ── Right: Total Customers ─────────────────────────────
                    _GlassStatGroup(
                      isDark: isDark,
                      children: [
                        _MiniStat(
                          icon: Icons.people,
                          value: '$_totalCustomers',
                          label: 'ลูกค้า',
                          color: const Color(0xFF7F00FF),
                        ),
                      ],
                    ),
                  ],
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
                              color: Color(0xFF00897B)),
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

          // ── Zoom buttons (bottom-left) ────────────────────────────────────
          Positioned(
            bottom: 110,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'dash_zoom_in',
                  onPressed: () {
                    try {
                      final z = min(_currentZoom + 1.0, 18.0);
                      _mapController.move(
                          _mapController.camera.center, z);
                      setState(() => _currentZoom = z);
                    } catch (_) {}
                  },
                  backgroundColor:
                      Theme.of(context).colorScheme.surface,
                  foregroundColor:
                      Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'dash_zoom_out',
                  onPressed: () {
                    try {
                      final z = max(_currentZoom - 1.0, 3.0);
                      _mapController.move(
                          _mapController.camera.center, z);
                      setState(() => _currentZoom = z);
                    } catch (_) {}
                  },
                  backgroundColor:
                      Theme.of(context).colorScheme.surface,
                  foregroundColor:
                      Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // ── My-location FAB (bottom-right) ───────────────────────────────
          Positioned(
            bottom: 110,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'dash_my_loc',
              onPressed: _isLocating ? null : _centerOnUser,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.0, color: Colors.white),
                    )
                  : const Icon(Icons.my_location, size: 20),
            ),
          ),

          // ── Bottom CTA panel ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomActionPanel(isDark: isDark),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Action Panel  (Map + Route Planning CTAs)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActionPanel extends StatelessWidget {
  const _BottomActionPanel({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
        : Colors.white.withOpacity(0.96);

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Row(
          children: [
            // Route Planning
            Expanded(
              child: _ActionButton(
                icon: Icons.navigation_rounded,
                label: 'วางแผนและนำทาง',
                subtitle: 'จัดเส้นทางส่งของ',
                gradient: const LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF26C6DA)],
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
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      duration: const Duration(milliseconds: 120), vsync: this);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _ctrl.drive(Tween(begin: 1.0, end: 0.97)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Stat Group  (frosted-glass card holding MiniStats)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassStatGroup extends StatelessWidget {
  const _GlassStatGroup({
    required this.isDark,
    required this.children,
    this.isVertical = false,
  });
  final bool isDark;
  final List<Widget> children;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: isVertical
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.55)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.6),
        ),
      ),
      child: isVertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark
          ? Colors.white.withOpacity(0.15)
          : Colors.black.withOpacity(0.1),
    );
  }
}

class _HorizontalDivider extends StatelessWidget {
  const _HorizontalDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: 32,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isDark
          ? Colors.white.withOpacity(0.15)
          : Colors.black.withOpacity(0.1),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Search Bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSearchBar extends StatelessWidget {
  const _GlassSearchBar({
    required this.isDark,
    required this.controller,
    required this.onChanged,
  });

  final bool isDark;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.55)
            : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.6),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อลูกค้า...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FadeInSlide  (kept here for backward compat if referenced elsewhere)
// ─────────────────────────────────────────────────────────────────────────────

class FadeInSlide extends StatefulWidget {
  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: widget.duration, vsync: this);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity:
          _controller.drive(Tween<double>(begin: 0.0, end: 1.0)),
      child: SlideTransition(
        position: _controller.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: widget.child,
      ),
    );
  }
}
