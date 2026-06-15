import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_record.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  double _currentZoom = 13.0;
  LatLng _mapCenter = const LatLng(13.7563, 100.5018); // Default Bangkok
  bool _isLocating = false;

  CustomerRecord? _selectedCustomer;
  List<CustomerRecord> _searchResults = [];
  bool _isSearching = false;

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
              onTap: () {
                // Zoom in and center on cluster
                _mapController.move(clusterCenter, min(_currentZoom + 2.0, 17.0));
              },
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

  void _showCustomerBottomSheet(CustomerRecord customer) {
    showBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
          child: Padding(
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
                const SizedBox(height: 20),
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
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${customer.latitude},${customer.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _centerOnUser() async {
    setState(() => _isLocating = true);
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null) {
        final userLatLng = LatLng(loc['latitude']!, loc['longitude']!);
        _mapController.move(userLatLng, 15.0);
        setState(() {
          _mapCenter = userLatLng;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถระบุพิกัด GPS ได้ กรุณาเปิดสิทธิ์ GPS ของอุปกรณ์'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการดึงพิกัด: $e')),
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

    final matched = allCustomers.where((c) {
      return c.name.toLowerCase().contains(query.toLowerCase()) || c.phone.contains(query);
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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

          // Floating Action Button (FAB) for Current Location
          Positioned(
            bottom: _selectedCustomer != null ? 180 : 30, // Shift up if bottom sheet is shown
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton(
                onPressed: _isLocating ? null : _centerOnUser,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 6,
                child: _isLocating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
