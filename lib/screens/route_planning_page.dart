import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_record.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import '../core/design_tokens.dart';
import '../core/theme_extensions.dart';

class RoutePlanningPage extends StatefulWidget {
  const RoutePlanningPage({super.key});

  @override
  State<RoutePlanningPage> createState() => _RoutePlanningPageState();
}

class _RoutePlanningPageState extends State<RoutePlanningPage> {
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
  final TextEditingController _latController = TextEditingController(text: '13.7563');
  final TextEditingController _lngController = TextEditingController(text: '100.5018');

  @override
  void initState() {
    super.initState();
    _tryGetGPSLocation();
  }

  @override
  void dispose() {
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
            content: Text('ไม่สามารถดึงตำแหน่งได้ กรุณาเปิดสิทธิ์ GPS หรือใส่พิกัดด้วยตัวเอง'),
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
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = cos;
    final a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // TSP Greedy sequence calculation
  List<CustomerRecord> _calculateGreedyRoute(double startLat, double startLng, List<CustomerRecord> targets) {
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
          final dist = _calculateDistance(currentLat, currentLng, target.latitude!, target.longitude!);
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
        // Fallback for targets without valid coords (should be filtered out anyway)
        result.addAll(pool);
        break;
      }
    }

    return result;
  }

  void _startNavigation(List<CustomerRecord> allCustomers) {
    // Parse start coordinates
    final parsedLat = double.tryParse(_latController.text) ?? _currentLat;
    final parsedLng = double.tryParse(_lngController.text) ?? _currentLng;

    // Filter selected customers that have coordinates
    final selectedTargets = allCustomers.where((c) {
      return _selectedCustomerPhones.contains(c.phone) && c.latitude != null && c.longitude != null;
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
        _remainingQueue = _calculateGreedyRoute(_currentLat, _currentLng, selectedTargets);
      } else {
        // In manual mode, we respect the selection order or default db order
        _remainingQueue = List.from(selectedTargets);
      }

      _isNavigating = true;
    });
  }

  void _toggleRouteMode(bool isAuto) {
    if (!_isNavigating) {
      setState(() => _isAutoMode = isAuto);
      return;
    }

    setState(() {
      _isAutoMode = isAuto;
      if (isAuto && _remainingQueue.isNotEmpty) {
        // Recalculate route dynamically starting from current location or last completed coordinates
        final double pivotLat = _completedQueue.isNotEmpty && _completedQueue.last.latitude != null
            ? _completedQueue.last.latitude!
            : _currentLat;
        final double pivotLng = _completedQueue.isNotEmpty && _completedQueue.last.longitude != null
            ? _completedQueue.last.longitude!
            : _currentLng;
        _remainingQueue = _calculateGreedyRoute(pivotLat, pivotLng, _remainingQueue);
      }
    });
  }

  void _completeActiveDestination() {
    if (_remainingQueue.isEmpty) return;

    setState(() {
      final completed = _remainingQueue.removeAt(0);
      _completedQueue.add(completed);

      // If in Auto Mode, dynamically recalculate next step from completed customer's location
      if (_isAutoMode && _remainingQueue.isNotEmpty && completed.latitude != null && completed.longitude != null) {
        _remainingQueue = _calculateGreedyRoute(completed.latitude!, completed.longitude!, _remainingQueue);
      }
    });
  }

  void _resetNavigation() {
    setState(() {
      _isNavigating = false;
      _remainingQueue = [];
      _completedQueue = [];
    });
  }

  Future<void> _openGoogleMaps(CustomerRecord customer) async {
    if (customer.latitude == null || customer.longitude == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${customer.latitude},${customer.longitude}',
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

    return Padding(
      padding: DesignTokens.paddingM,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 8),
              Text(
                'วางแผนเส้นทางนำทาง',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingM),

          // Start coordinates setup card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: DesignTokens.borderRadiusLg,
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: DesignTokens.paddingM,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'จุดเริ่มต้นเดินทาง (ตำแหน่งของคุณ)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isFetchingLocation ? null : _manualFetchGPS,
                    icon: _isFetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isFetchingLocation ? 'กำลังดึงพิกัด GPS...' : 'ใช้ตำแหน่งปัจจุบันของคุณ (GPS)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingM),

          // Selection settings & mode toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'เลือกลูกค้าจัดส่ง',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              // Segmented Auto/Manual toggle
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
          const SizedBox(height: 8),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อหรือเบอร์โทร...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 10),

          // Customer selection list
          Expanded(
            child: filteredCustomers.isEmpty
                ? Center(
                    child: Text(
                      customers.isEmpty ? 'ไม่มีข้อมูลลูกค้าในระบบ' : 'ไม่พบข้อมูลลูกค้าที่ค้นหา',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusLg),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final hasCoords = customer.latitude != null && customer.longitude != null;
                        final isSelected = _selectedCustomerPhones.contains(customer.phone);

                        return CheckboxListTile(
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
                              decoration: hasCoords ? null : TextDecoration.lineThrough,
                              color: hasCoords ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer.phone),
                              Text(
                                customer.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (!hasCoords)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '⚠️ ไม่มีพิกัด (กรุณาเพิ่มพิกัดในหน้าลูกค้า)',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          secondary: CircleAvatar(
                            backgroundColor: hasCoords
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.grey.shade300,
                            child: Icon(
                              Icons.person,
                              color: hasCoords
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Colors.grey.shade600,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // Start Route navigation button
          ElevatedButton(
            onPressed: _selectedCustomerPhones.isEmpty
                ? null
                : () => _startNavigation(customers),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMd),
            ),
            child: Text(
              'เริ่มนำทาง (${_selectedCustomerPhones.length} จุด)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationScreen() {
    final double pivotLat = _completedQueue.isNotEmpty && _completedQueue.last.latitude != null
        ? _completedQueue.last.latitude!
        : _currentLat;
    final double pivotLng = _completedQueue.isNotEmpty && _completedQueue.last.longitude != null
        ? _completedQueue.last.longitude!
        : _currentLng;

    if (_remainingQueue.isEmpty) {
      return _buildCompletionCard();
    }

    final activeCustomer = _remainingQueue.first;
    final activeDistance = activeCustomer.latitude != null && activeCustomer.longitude != null
        ? _calculateDistance(pivotLat, pivotLng, activeCustomer.latitude!, activeCustomer.longitude!)
        : 0.0;

    final totalRemaining = _remainingQueue.length;
    final totalCompleted = _completedQueue.length;
    final totalPlanned = totalRemaining + totalCompleted;
    final progress = totalPlanned > 0 ? totalCompleted / totalPlanned : 0.0;

    return Padding(
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

          // Linear Progress Bar
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(10),
            minHeight: 10,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),

          // Active Customer Highlight Box
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: DesignTokens.borderRadiusLg,
              side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            child: Padding(
              padding: DesignTokens.paddingL,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'จุดหมายปัจจุบัน (Active)',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        'ห่าง ~${activeDistance.toStringAsFixed(2)} กม.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    activeCustomer.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'เบอร์โทร: ${activeCustomer.phone}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ที่อยู่: ${activeCustomer.address}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openGoogleMaps(activeCustomer),
                          icon: const Icon(Icons.navigation),
                          label: const Text('เปิดนำทาง Maps'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Routing Mode Selector during navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'คิวที่เหลือ (${totalRemaining - 1} จุดหมาย)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
          const SizedBox(height: 10),

          // Reorderable list or display list
          Expanded(
            child: _isAutoMode
                ? ListView.builder(
                    itemCount: _remainingQueue.length - 1,
                    itemBuilder: (context, idx) {
                      final itemIdx = idx + 1;
                      final customer = _remainingQueue[itemIdx];

                      // Compute sequential distance
                      final double prevLat = _remainingQueue[idx].latitude!;
                      final double prevLng = _remainingQueue[idx].longitude!;
                      final double distance = _calculateDistance(
                        prevLat,
                        prevLng,
                        customer.latitude!,
                        customer.longitude!,
                      );

                      return _QueueItemCard(
                        index: itemIdx + totalCompleted,
                        name: customer.name,
                        address: customer.address,
                        phone: customer.phone,
                        distanceLabel: 'ระยะห่างจากจุดก่อนหน้า ~${distance.toStringAsFixed(2)} กม.',
                        trailing: Icon(Icons.lock_clock, color: Colors.grey.shade400),
                      );
                    },
                  )
                : ReorderableListView.builder(
                    itemCount: _remainingQueue.length - 1,
                    onReorder: (oldIndex, newIndex) {
                      // Adjust indices because we skip active element (index 0) in rendering
                      final actualOld = oldIndex + 1;
                      final actualNew = newIndex >= _remainingQueue.length ? _remainingQueue.length - 1 : newIndex + 1;
                      
                      setState(() {
                        if (actualOld < actualNew) {
                          final item = _remainingQueue.removeAt(actualOld);
                          _remainingQueue.insert(actualNew - 1, item);
                        } else {
                          final item = _remainingQueue.removeAt(actualOld);
                          _remainingQueue.insert(actualNew, item);
                        }
                      });
                    },
                    itemBuilder: (context, idx) {
                      final itemIdx = idx + 1;
                      final customer = _remainingQueue[itemIdx];

                      // Compute distance in manual list
                      final double prevLat = _remainingQueue[idx].latitude!;
                      final double prevLng = _remainingQueue[idx].longitude!;
                      final double distance = _calculateDistance(
                        prevLat,
                        prevLng,
                        customer.latitude!,
                        customer.longitude!,
                      );

                      return _QueueItemCard(
                        key: ValueKey(customer.phone),
                        index: itemIdx + totalCompleted,
                        name: customer.name,
                        address: customer.address,
                        phone: customer.phone,
                        distanceLabel: 'ระยะห่าง ~${distance.toStringAsFixed(2)} กม.',
                        trailing: const Icon(Icons.drag_handle),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // Cancel Navigation Reset Button
          TextButton.icon(
            onPressed: _resetNavigation,
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            label: const Text('ยกเลิกแผนการเดินทาง', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard() {
    return Padding(
      padding: DesignTokens.paddingL,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusXl),
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
                child: const Icon(Icons.emoji_events, size: 80, color: Colors.green),
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
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _resetNavigation,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
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
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            '$index',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('โทร: $phone | $address', maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              distanceLabel,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
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
