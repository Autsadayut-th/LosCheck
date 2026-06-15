import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../models/customer_record.dart';
import '../database/hive_database.dart';
import '../providers/app_state_provider.dart';
import '../services/csv_export_service.dart';
import '../services/location_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../core/theme_extensions.dart';
import 'map_page.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late final TabController _tabController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _mapLinkController = TextEditingController();
  final TextEditingController _phoneFilterController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Timer? _filterDebounce;
  String _phoneInput = '';
  String _debouncedPhoneInput = '';
  String _debouncedPhoneFilter = '';
  CustomerSortMethod _sortMethod = CustomerSortMethod.name;

  String get _activePhoneFilter {
    final manualFilter = _debouncedPhoneFilter.trim();
    if (manualFilter.isNotEmpty) {
      return manualFilter;
    }
    return _debouncedPhoneInput.trim();
  }

  List<CustomerRecord> _getFilteredRecords(List<CustomerRecord> customers) {
    final query = _normalizePhone(_activePhoneFilter);
    final filtered = query.isEmpty
        ? customers.toList()
        : customers.where((record) {
            return _normalizePhone(record.phone).contains(query);
          }).toList();

    switch (_sortMethod) {
      case CustomerSortMethod.name:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case CustomerSortMethod.dateAdded:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case CustomerSortMethod.coordinateStatus:
        filtered.sort((a, b) {
          final aHasCoords = a.latitude != null && a.longitude != null;
          final bHasCoords = b.latitude != null && b.longitude != null;
          if (!aHasCoords && bHasCoords) return -1;
          if (aHasCoords && !bHasCoords) return 1;
          return a.name.compareTo(b.name);
        });
        break;
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(() {
      if (mounted) setState(() {});
    });
    _phoneController.addListener(_onPhoneInputChanged);
    _phoneFilterController.addListener(_onPhoneFilterChanged);
    _mapLinkController.addListener(_onMapLinkChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterDebounce?.cancel();
    _phoneController.removeListener(_onPhoneInputChanged);
    _phoneFilterController.removeListener(_onPhoneFilterChanged);
    _mapLinkController.removeListener(_onMapLinkChanged);
    _phoneController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapLinkController.dispose();
    _phoneFilterController.dispose();
    super.dispose();
  }

  void _onPhoneInputChanged() {
    final nextPhoneInput = _phoneController.text;
    final phoneChanged = _phoneInput != nextPhoneInput;
    _phoneInput = nextPhoneInput;

    if (phoneChanged) {
      setState(() {});
    }

    _scheduleFilterRefresh(
      phoneInput: nextPhoneInput,
      phoneFilter: _phoneFilterController.text,
    );
  }

  void _onPhoneFilterChanged() {
    _scheduleFilterRefresh(
      phoneInput: _phoneController.text,
      phoneFilter: _phoneFilterController.text,
    );
  }

  void _scheduleFilterRefresh({
    required String phoneInput,
    required String phoneFilter,
  }) {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _debouncedPhoneInput = phoneInput;
        _debouncedPhoneFilter = phoneFilter;
      });
    });
  }

  void _clearPhoneFilter() {
    _phoneFilterController.clear();
    _filterDebounce?.cancel();
    setState(() {
      _debouncedPhoneFilter = '';
    });
  }

  void _clearActiveFilters() {
    _phoneController.clear();
    _phoneFilterController.clear();
    _filterDebounce?.cancel();
    setState(() {
      _phoneInput = '';
      _debouncedPhoneInput = '';
      _debouncedPhoneFilter = '';
    });
  }

  Future<void> _saveCustomer() async {
    debugPrint('=== Save Customer Started ===');
    debugPrint('Phone: ${_phoneController.text.trim()}');
    debugPrint('Name: ${_nameController.text.trim()}');
    debugPrint('Address: ${_addressController.text.trim()}');
    debugPrint('Form valid: ${_formKey.currentState?.validate()}');

    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    try {
      final latText = _latitudeController.text.trim();
      final lngText = _longitudeController.text.trim();
      final latitude = latText.isNotEmpty ? double.tryParse(latText) : null;
      final longitude = lngText.isNotEmpty ? double.tryParse(lngText) : null;

      final record = CustomerRecord(
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );

      debugPrint('Creating customer record: ${record.phone}, ${record.name}, lat: ${record.latitude}, lng: ${record.longitude}');
      debugPrint('Database initialized: ${appDatabase.isInitialized}');

      // Persist only the newly added/edited record. `insertCustomer` uses
      // onConflict: DoUpdate, so it also doubles as an upsert.
      await appDatabase.insertCustomer(record);
      debugPrint('Customer inserted successfully');
      
      if (!mounted) return;
      setState(() {
        _phoneController.clear();
        _nameController.clear();
        _addressController.clear();
        _latitudeController.clear();
        _longitudeController.clear();
        _phoneFilterController.clear();
        _phoneInput = '';
        _debouncedPhoneInput = '';
        _debouncedPhoneFilter = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลลูกค้าสำเร็จ'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      debugPrint('=== Save Customer Completed Successfully ===');
    } catch (e) {
      debugPrint('=== Save Customer Failed ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _deleteRecord(CustomerRecord record) async {
    final confirmed = await confirmDelete(
      context,
      'ลบข้อมูลลูกค้า?',
      '${record.name} (${record.phone})',
    );
    if (!confirmed) return;

    try {
      await appDatabase.deleteCustomer(record.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบข้อมูลลูกค้าสำเร็จ'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _exportCsv(List<CustomerRecord> customers) async {
    if (customers.isEmpty) return;

    final csv = CsvExportService.exportCustomerRecords(customers);
    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกข้อมูลลูกค้า CSV แล้ว')),
    );
  }

  void _useRecord(CustomerRecord record) {
    setState(() {
      _phoneController.text = record.phone;
      _nameController.text = record.name;
      _addressController.text = record.address;
      _latitudeController.text = record.latitude?.toString() ?? '';
      _longitudeController.text = record.longitude?.toString() ?? '';
      _phoneFilterController.clear();
      _phoneInput = record.phone;
      _debouncedPhoneInput = record.phone;
      _debouncedPhoneFilter = '';
    });
    _tabController.animateTo(1);
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null) {
        setState(() {
          _latitudeController.text = loc['latitude']!.toStringAsFixed(6);
          _longitudeController.text = loc['longitude']!.toStringAsFixed(6);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดึงพิกัด GPS ปัจจุบันสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถดึงพิกัดปัจจุบันได้ กรุณาอนุญาตสิทธิ์เข้าตำแหน่งหรือระบุพิกัดด้วยตัวเอง'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการดึงตำแหน่ง: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onMapLinkChanged() {
    final text = _mapLinkController.text.trim();
    if (text.isEmpty) return;

    final coords = _parseGoogleMapsUrl(text);
    if (coords != null) {
      setState(() {
        _latitudeController.text = coords['latitude']!.toStringAsFixed(6);
        _longitudeController.text = coords['longitude']!.toStringAsFixed(6);
        _mapLinkController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ดึงพิกัดจากลิงก์ Google Maps สำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Map<String, double>? _parseGoogleMapsUrl(String url) {
    try {
      final decodedUrl = Uri.decodeFull(url);
      
      // 1. Query parameters (query= or q=)
      final uri = Uri.tryParse(decodedUrl);
      if (uri != null) {
        final queryParam = uri.queryParameters['query'] ?? uri.queryParameters['q'];
        if (queryParam != null) {
          final parts = queryParam.split(',');
          if (parts.length >= 2) {
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());
            if (lat != null && lng != null) {
              return {'latitude': lat, 'longitude': lng};
            }
          }
        }
      }

      // 2. @lat,lng format
      final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final atMatch = atRegex.firstMatch(decodedUrl);
      if (atMatch != null) {
        final lat = double.tryParse(atMatch.group(1) ?? '');
        final lng = double.tryParse(atMatch.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // 3. /place/lat,lng or search/lat,lng
      final placeRegex = RegExp(r'(?:place|search|maps)\/(-?\d+\.\d+),(-?\d+\.\d+)');
      final placeMatch = placeRegex.firstMatch(decodedUrl);
      if (placeMatch != null) {
        final lat = double.tryParse(placeMatch.group(1) ?? '');
        final lng = double.tryParse(placeMatch.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // 4. Generic lat,lng regex fallback
      final genericRegex = RegExp(r'(-?\d+\.\d+),\s*(-?\d+\.\d+)');
      final genericMatch = genericRegex.firstMatch(decodedUrl);
      if (genericMatch != null) {
        final lat = double.tryParse(genericMatch.group(1) ?? '');
        final lng = double.tryParse(genericMatch.group(2) ?? '');
        if (lat != null && lng != null) {
          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            return {'latitude': lat, 'longitude': lng};
          }
        }
      }
    } catch (_) {
      // Return null on parsing issues
    }
    return null;
  }

  Future<void> _callCustomer(CustomerRecord record) async {
    final phone = record.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่สามารถโทรออกได้')));
    }
  }

  Future<void> _openMap(CustomerRecord record) async {
    final Uri uri;
    if (record.latitude != null && record.longitude != null) {
      // Use Directions mode when coordinates are available
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${record.latitude},${record.longitude}'
        '&travelmode=driving',
      );
    } else {
      // Fallback to Search mode when only address is available
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(record.address)}',
      );
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปิดแผนที่ได้')));
    }
  }

  Future<void> _pickOrViewImage(CustomerRecord record) async {
    if (record.imageUrl != null) {
      // Show existing image
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: kIsWeb
                      ? Image.network(record.imageUrl!, fit: BoxFit.contain)
                      : Image.file(
                          io.File(record.imageUrl!),
                          fit: BoxFit.contain,
                          cacheWidth: 800,
                        ),
                ),
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ปิด'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickNewImage(record);
                    },
                    child: const Text('เปลี่ยนรูป'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      await _pickNewImage(record);
    }
  }

  Future<void> _pickNewImage(CustomerRecord record) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    // Bug fix: preserve latitude and longitude when updating image
    final updated = CustomerRecord(
      phone: record.phone,
      name: record.name,
      address: record.address,
      createdAt: record.createdAt,
      imageUrl: pickedFile.path,
      latitude: record.latitude,
      longitude: record.longitude,
    );

    // Persist only the affected record.
    await appDatabase.insertCustomer(updated);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
    final customers = appState.customers;
    final filteredRecords = _getFilteredRecords(customers);
    final activePhoneFilter = _activePhoneFilter;

    if (appState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 1,
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.search),
                    text: 'รายชื่อลูกค้า',
                  ),
                  Tab(
                    icon: Icon(Icons.person_add),
                    text: 'เพิ่ม/แก้ไขลูกค้า',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSearchTab(context, customers, filteredRecords, activePhoneFilter),
                  _buildFormTab(context, appState),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              key: const Key('addCustomerFab'),
              onPressed: () {
                _phoneController.clear();
                _nameController.clear();
                _addressController.clear();
                _latitudeController.clear();
                _longitudeController.clear();
                _mapLinkController.clear();
                _phoneInput = '';
                _tabController.animateTo(1);
              },
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _buildSearchTab(
    BuildContext context,
    List<CustomerRecord> customers,
    List<CustomerRecord> filteredRecords,
    String activePhoneFilter,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 380 ? 12 : 20,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ข้อมูลลูกค้า',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    PopupMenuButton<CustomerSortMethod>(
                      icon: const Icon(Icons.sort),
                      tooltip: 'จัดเรียงข้อมูล',
                      onSelected: (CustomerSortMethod method) {
                        setState(() {
                          _sortMethod = method;
                        });
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: CustomerSortMethod.name,
                          child: Row(
                            children: [
                              Icon(Icons.sort_by_alpha, color: _sortMethod == CustomerSortMethod.name ? Theme.of(context).colorScheme.primary : null),
                              const SizedBox(width: 8),
                              const Text('เรียงตามชื่อ'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: CustomerSortMethod.dateAdded,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: _sortMethod == CustomerSortMethod.dateAdded ? Theme.of(context).colorScheme.primary : null),
                              const SizedBox(width: 8),
                              const Text('เรียงตามวันที่เพิ่ม'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: CustomerSortMethod.coordinateStatus,
                          child: Row(
                            children: [
                              Icon(Icons.location_off, color: _sortMethod == CustomerSortMethod.coordinateStatus ? Theme.of(context).colorScheme.primary : null),
                              const SizedBox(width: 8),
                              const Text('เรียงตามไม่มีพิกัดก่อน'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'ดูแผนที่ลูกค้า',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MapPage()),
                      ),
                      icon: Icon(Icons.map, color: Theme.of(context).colorScheme.primary),
                    ),
                    if (customers.isNotEmpty)
                      IconButton(
                        tooltip: 'Export CSV',
                        onPressed: () => _exportCsv(customers),
                        icon: const Icon(Icons.file_download_outlined),
                      ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Text(
                  'ค้นหาเบอร์โทร',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: TextField(
                  key: const Key('customerPhoneFilterField'),
                  controller: _phoneFilterController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9+\-\s]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'กรองจากเบอร์โทร',
                    hintText: 'พิมพ์บางส่วนของเบอร์',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _phoneFilterController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'ล้างคำค้นหา',
                            onPressed: _clearPhoneFilter,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activePhoneFilter.isEmpty
                            ? 'ประวัติลูกค้า'
                            : 'ประวัติลูกค้า (${filteredRecords.length} รายการ)',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (activePhoneFilter.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearActiveFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('ล้างตัวกรอง'),
                      ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              if (customers.isEmpty)
                SliverToBoxAdapter(
                  child: emptyState(
                    context,
                    icon: Icons.people_outline,
                    title: 'ยังไม่มีข้อมูลลูกค้า',
                    message: 'เพิ่มลูกค้าใหม่เพื่อเริ่มต้นใช้งาน',
                  ),
                )
              else if (filteredRecords.isEmpty)
                SliverToBoxAdapter(
                  child: emptyState(
                    context,
                    icon: Icons.search_outlined,
                    title: 'ไม่พบเบอร์โทรที่ค้นหา',
                    message: 'ลองค้นหาด้วยเบอร์โทรอื่น',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((
                    context,
                    index,
                  ) {
                    final record = filteredRecords[index];
                    return _CustomerRecordTile(
                      record: record,
                      onUse: () => _useRecord(record),
                      onDelete: () => _deleteRecord(record),
                      onCall: () => _callCustomer(record),
                      onMap: () => _openMap(record),
                      onImage: () => _pickOrViewImage(record),
                    );
                  }, childCount: filteredRecords.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormTab(BuildContext context, AppStateProvider appState) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 380 ? 12 : 20,
          ),
          child: Column(
            children: [
              if (appDatabase.isUsingInMemory)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.isDarkMode 
                      ? Colors.amber.shade900.withOpacity(0.2)
                      : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.shade700,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, color: Colors.amber.shade800),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'โหมดออฟไลน์ (In-Memory)',
                              style: TextStyle(
                                color: context.isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ข้อมูลจะไม่ถูกบันทึกลงเครื่องถาวร กรุณาอย่าปิดบราวเซอร์',
                              style: TextStyle(
                                color: context.isDarkMode ? Colors.amber.shade100 : Colors.amber.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              _CustomerForm(
                formKey: _formKey,
                phoneController: _phoneController,
                nameController: _nameController,
                addressController: _addressController,
                latitudeController: _latitudeController,
                longitudeController: _longitudeController,
                mapLinkController: _mapLinkController,
                canFillDetails: true,
                onSave: _saveCustomer,
                onGetLocation: _fetchCurrentLocation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class _CustomerForm extends StatelessWidget {
  const _CustomerForm({
    required this.formKey,
    required this.phoneController,
    required this.nameController,
    required this.addressController,
    required this.latitudeController,
    required this.longitudeController,
    required this.mapLinkController,
    required this.canFillDetails,
    required this.onSave,
    required this.onGetLocation,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController mapLinkController;
  final bool canFillDetails;
  final VoidCallback onSave;
  final VoidCallback onGetLocation;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 14 : 24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'เพิ่ม/แก้ไข ข้อมูลลูกค้า',
                style: (isSmallScreen 
                    ? Theme.of(context).textTheme.titleMedium 
                    : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 20),
              TextFormField(
                key: const Key('customerPhoneField'),
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 18,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                ],
                decoration: InputDecoration(
                  labelText: 'เบอร์โทร',
                  hintText: 'เช่น 0812345678',
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: isSmallScreen 
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                      : null,
                ),
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  if (phone.isEmpty) {
                    return 'กรุณาใส่เบอร์โทรก่อน';
                  }
                  if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
                    return 'เบอร์โทรต้องมีอย่างน้อย 9 ตัวเลข';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 10 : 16),
              TextFormField(
                key: const Key('customerNameField'),
                controller: nameController,
                enabled: canFillDetails,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                decoration: InputDecoration(
                  labelText: 'ชื่อลูกค้า',
                  hintText: 'กรอกชื่อ',
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: isSmallScreen 
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                      : null,
                ),
                validator: (value) {
                  if (!canFillDetails) {
                    return null;
                  }
                  if ((value ?? '').trim().isEmpty) {
                    return 'กรุณาใส่ชื่อ';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 10 : 16),
              TextFormField(
                key: const Key('customerAddressField'),
                controller: addressController,
                enabled: canFillDetails,
                minLines: isSmallScreen ? 2 : 3,
                maxLines: 5,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                decoration: InputDecoration(
                  labelText: 'ที่อยู่',
                  hintText: 'บ้านเลขที่ / ซอย / ถนน / จุดสังเกต',
                  prefixIcon: const Icon(Icons.location_on),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: isSmallScreen 
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                      : null,
                ),
                validator: (value) {
                  if (!canFillDetails) {
                    return null;
                  }
                  if ((value ?? '').trim().isEmpty) {
                    return 'กรุณาใส่ที่อยู่';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 10 : 16),
              TextFormField(
                key: const Key('customerMapLinkField'),
                controller: mapLinkController,
                enabled: canFillDetails,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                decoration: InputDecoration(
                  labelText: 'ลิงก์แผนที่ Google Maps',
                  hintText: 'วางลิงก์จาก Google Maps เพื่อดึงพิกัดอัตโนมัติ',
                  prefixIcon: const Icon(Icons.link),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: isSmallScreen ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12) : null,
                ),
              ),
              SizedBox(height: isSmallScreen ? 10 : 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('customerLatitudeField'),
                      controller: latitudeController,
                      enabled: canFillDetails,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'เช่น 13.7563',
                        prefixIcon: const Icon(Icons.pin_drop_outlined),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: isSmallScreen ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12) : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final val = double.tryParse(value.trim());
                        if (val == null) return 'ตัวเลขไม่ถูกต้อง';
                        if (val < -90 || val > 90) return 'ต้องอยู่ระหว่าง -90 ถึง 90';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: const Key('customerLongitudeField'),
                      controller: longitudeController,
                      enabled: canFillDetails,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'เช่น 100.5018',
                        prefixIcon: const Icon(Icons.pin_drop_outlined),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: isSmallScreen ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12) : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final val = double.tryParse(value.trim());
                        if (val == null) return 'ตัวเลขไม่ถูกต้อง';
                        if (val < -180 || val > 180) return 'ต้องอยู่ระหว่าง -180 ถึง 180';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onGetLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('ดึงพิกัดจาก GPS ปัจจุบัน'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              FilledButton.icon(
                key: const Key('saveCustomerButton'),
                onPressed: onSave,
                icon: Icon(Icons.save, size: isSmallScreen ? 22 : 28),
                label: Text(
                  'บันทึกข้อมูลลูกค้า',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 12 : 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutlineBorder extends OutlineInputBorder {
  const OutlineBorder({required super.borderRadius})
    : super(borderSide: BorderSide.none);
}

class _CustomerRecordTile extends StatelessWidget {
  const _CustomerRecordTile({
    required this.record,
    required this.onUse,
    required this.onDelete,
    required this.onCall,
    required this.onMap,
    required this.onImage,
  });

  final CustomerRecord record;
  final VoidCallback onUse;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback onMap;
  final VoidCallback onImage;

  Color _getPastelColor(String name) {
    final hash = name.hashCode;
    final double hue = (hash.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.85).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    final String firstLetter = record.name.isNotEmpty ? record.name.substring(0, 1).toUpperCase() : '?';
    final Color avatarBgColor = _getPastelColor(record.name);
    final Color avatarTextColor = HSLColor.fromColor(avatarBgColor).withLightness(0.3).toColor();

    Widget leadingWidget;
    if (record.imageUrl != null && record.imageUrl!.isNotEmpty) {
      leadingWidget = CircleAvatar(
        radius: 24,
        backgroundImage: kIsWeb
            ? NetworkImage(record.imageUrl!)
            : ResizeImage(
                FileImage(io.File(record.imageUrl!)),
                width: 120,
              ) as ImageProvider,
      );
    } else {
      leadingWidget = CircleAvatar(
        radius: 24,
        backgroundColor: avatarBgColor,
        child: Text(
          firstLetter,
          style: TextStyle(
            color: avatarTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 6,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 20,
            vertical: 8,
          ),
          leading: leadingWidget,
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                record.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (record.latitude == null || record.longitude == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ไม่มีพิกัด',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${record.phone}\n${record.address}' +
                  (record.latitude != null && record.longitude != null
                      ? '\nพิกัด: ${record.latitude}, ${record.longitude}'
                      : ''),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          isThreeLine: true,
          onTap: onUse,
          trailing: isCompact
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk_outlined),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: onCall,
                      tooltip: 'โทรออก',
                    ),
                    IconButton(
                      icon: const Icon(Icons.map_outlined),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: onMap,
                      tooltip: 'แผนที่',
                    ),
                    PopupMenuButton<_CustomerAction>(
                      tooltip: 'เมนูลูกค้า',
                      onSelected: (action) {
                        switch (action) {
                          case _CustomerAction.edit:
                            onUse();
                          case _CustomerAction.delete:
                            onDelete();
                          case _CustomerAction.image:
                            onImage();
                          default:
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _CustomerAction.image,
                          child: ListTile(
                            leading: Icon(Icons.image_outlined),
                            title: Text('รูปภาพ'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: _CustomerAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('แก้ไข'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: _CustomerAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline, color: Colors.red),
                            title: Text('ลบ', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    )
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'โทรออก',
                      onPressed: onCall,
                      icon: Icon(
                        Icons.call_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'แผนที่',
                      onPressed: onMap,
                      icon: Icon(
                        Icons.map_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'รูปภาพ',
                      onPressed: onImage,
                      icon: Icon(
                        Icons.image_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'แก้ไขข้อมูล',
                      onPressed: onUse,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'ลบข้อมูลลูกค้า',
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum _CustomerAction { image, edit, delete }

enum CustomerSortMethod {
  name,
  dateAdded,
  coordinateStatus,
}
