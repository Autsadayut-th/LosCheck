import 'dart:math';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_record.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import 'route_planning/route_planning_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  double _currentZoom = 13.0;
  LatLng _mapCenter = const LatLng(13.7563, 100.5018); // Default Bangkok
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

  // Proximity clustering calculation based on Zoom
  double get _clusterDelta {
    if (_currentZoom >= 16) return 0.0; // No clustering at high zoom
    if (_currentZoom >= 14) return 0.005; // ~500m
    if (_currentZoom >= 12) return 0.015; // ~1.5km
    if (_currentZoom >= 10) return 0.04;  // ~4km
    if (_currentZoom >= 8) return 0.12;   // ~12km
    return 0.35;
  }

  List<Marker> _buildMarkers(List<CustomerRecord> customers, bool isDark) {
    final List<Marker> markers = [];
    final double delta = _clusterDelta;

    if (delta == 0.0) {
      // Draw individual customer markers
      for (final customer in customers) {
        if (customer.latitude == null || customer.longitude == null) continue;
        markers.add(_buildSingleCustomerMarker(customer, isDark));
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

    // Grid-based clustering
    final Map<String, List<CustomerRecord>> grid = {};
    for (final customer in customers) {
      if (customer.latitude == null || customer.longitude == null) continue;

      final gridLat = (customer.latitude! / delta).round() * delta;
      final gridLng = (customer.longitude! / delta).round() * delta;
      final key = '${gridLat.toStringAsFixed(5)},${gridLng.toStringAsFixed(5)}';

      grid.putIfAbsent(key, () => []).add(customer);
    }

    // Convert grid clusters to Markers
    grid.forEach((key, items) {
      if (items.isEmpty) return;

      if (items.length == 1) {
        markers.add(_buildSingleCustomerMarker(items.first, isDark));
      } else {
        // Calculate average coordinate for the cluster center
        double sumLat = 0;
        double sumLng = 0;
        for (final item in items) {
          sumLat += item.latitude!;
          sumLng += item.longitude!;
        }
        final clusterCenter = LatLng(sumLat / items.length, sumLng / items.length);

        markers.add(
          Marker(
            point: clusterCenter,
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => _showClusterCustomersBottomSheet(items),
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

  Marker _buildSingleCustomerMarker(CustomerRecord customer, bool isDark) {
    final initials = customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '?';
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
                ? const Color(0xFFFBC02D) // Selected: Amber
                : const Color(0xFF00897B), // Unselected: Teal
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
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
      _mapController.move(LatLng(customer.latitude!, customer.longitude!), 16.0);
    }

    _showCustomerBottomSheet(customer);
  }

  void _showClusterCustomersBottomSheet(List<CustomerRecord> clusterCustomers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.group_work_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ลูกค้าในกลุ่มนี้ (${clusterCustomers.length} ราย)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Customer List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: clusterCustomers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = clusterCustomers[index];
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
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  customer.name.isNotEmpty
                                      ? customer.name.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'โทร: ${customer.phone}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      customer.address,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (customer.imageUrl != null && customer.imageUrl!.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: kIsWeb
                                        ? Image.network(customer.imageUrl!, fit: BoxFit.cover)
                                        : Image.file(
                                            io.File(customer.imageUrl!),
                                            fit: BoxFit.cover,
                                            cacheWidth: 150,
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Actions row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _selectCustomer(customer);
                                },
                                icon: const Icon(Icons.location_searching, size: 16),
                                label: const Text('ระบุพิกัด', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: Theme.of(context).colorScheme.secondary,
                                ),
                                onPressed: () => _callCustomer(customer.phone),
                                icon: const Icon(Icons.phone_outlined, size: 16),
                                label: const Text('โทร', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  elevation: 0,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                                onPressed: () => _openInGoogleMaps(customer),
                                icon: const Icon(Icons.navigation_outlined, size: 16),
                                label: const Text('นำทาง', style: TextStyle(fontSize: 12)),
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
        );
      },
    );
  }

  void _showCustomerBottomSheet(CustomerRecord customer) {
    _scaffoldKey.currentState?.showBottomSheet(
      backgroundColor: Colors.transparent,
      (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
                // Top drag indicator
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
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                          Text(
                            customer.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'เบอร์โทร: ${customer.phone}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ที่อยู่: ${customer.address}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (customer.latitude != null && customer.longitude != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'พิกัด: ${customer.latitude}, ${customer.longitude}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
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
                        Navigator.pop(context);
                        setState(() => _selectedCustomer = null);
                      },
                    ),
                  ],
                ),
                if (customer.imageUrl != null && customer.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                title: Text(
                                  'รูปบ้าน: ${customer.name}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                automaticallyImplyLeading: false,
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                actions: [
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: kIsWeb
                                        ? Image.network(customer.imageUrl!, fit: BoxFit.contain)
                                        : Image.file(
                                            io.File(customer.imageUrl!),
                                            fit: BoxFit.contain,
                                            cacheWidth: 800,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        child: kIsWeb
                            ? Image.network(customer.imageUrl!, fit: BoxFit.cover)
                            : Image.file(
                                io.File(customer.imageUrl!),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callCustomer(customer.phone),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('โทรหา'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Shortcut to route planning page
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoutePlanningPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.route),
                  label: const Text('วางแผนเส้นทางส่งของ'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _callCustomer(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openInGoogleMaps(CustomerRecord customer) async {
    if (customer.latitude == null || customer.longitude == null) return;
    // Use Directions mode for better navigation experience
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${customer.latitude},${customer.longitude}'
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
          _mapCenter = userLatLng;
          _userLocation = userLatLng;
        });
      } else {
        if (!showErrors || !mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถระบุพิกัด GPS ได้ กรุณาเปิดสิทธิ์ GPS ของอุปกรณ์'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!showErrors || !mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการดึงพิกัด: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  void _onSearchChanged(String query, List<CustomerRecord> allCustomers) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    final matched = allCustomers.where((c) {
      return c.name.toLowerCase().contains(queryLower) ||
          c.phone.contains(query) ||
          c.address.toLowerCase().contains(queryLower);
    }).toList();

    setState(() {
      _searchResults = matched;
      _isSearching = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // CartoDB Voyager (Light) / CartoDB Dark Matter (Dark)
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    // Filter customers with valid coordinates
    final customersWithCoords = appState.customers.where((c) => c.latitude != null && c.longitude != null).toList();

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          // Full Screen Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _currentZoom,
              onPositionChanged: (position, hasGesture) {
                if (position.zoom != null && position.zoom != _currentZoom) {
                  setState(() {
                    _currentZoom = position.zoom!;
                  });
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

          // Floating Back Button and Search Bar on Top
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Back circular button
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      radius: 25,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Floating Search Bar Card
                    Expanded(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => _onSearchChanged(val, customersWithCoords),
                          decoration: InputDecoration(
                            hintText: 'ค้นหาชื่อลูกค้า...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('', customersWithCoords);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Search Results Dropdown List
                if (_isSearching && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, left: 62),
                    constraints: const BoxConstraints(maxHeight: 250),
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = _searchResults[index];
                        return ListTile(
                          title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(customer.phone),
                          leading: const Icon(Icons.location_on, color: Color(0xFF00897B)),
                          onTap: () {
                            _selectCustomer(customer);
                          },
                        );
                      },
                    ),
                  )
                else if (_isSearching && _searchResults.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, left: 62),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('ไม่พบข้อมูลลูกค้าที่มีพิกัดแผนที่', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),

          // Zoom Buttons on Bottom Left
          Positioned(
            bottom: 16,
            left: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in_btn',
                  onPressed: () {
                    try {
                      final newZoom = min(_currentZoom + 1.0, 18.0);
                      _mapController.move(_mapController.camera.center, newZoom);
                      setState(() {
                        _currentZoom = newZoom;
                      });
                    } catch (_) {}
                  },
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_btn',
                  onPressed: () {
                    try {
                      final newZoom = max(_currentZoom - 1.0, 3.0);
                      _mapController.move(_mapController.camera.center, newZoom);
                      setState(() {
                        _currentZoom = newZoom;
                      });
                    } catch (_) {}
                  },
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Floating Action Button (FAB) for Current Location
          Positioned(
            bottom: _selectedCustomer != null ? 180 : 16, // Shift up if bottom sheet is shown
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: FloatingActionButton.small(
                heroTag: 'map_my_loc',
                onPressed: _isLocating ? null : _centerOnUser,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: _isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                      )
                    : const Icon(Icons.my_location, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
