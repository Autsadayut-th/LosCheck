import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../models/customer_record.dart';
import '../database/hive_database.dart';
import '../providers/app_state_provider.dart';
import '../services/csv_export_service.dart';
import '../services/file_share_service.dart';
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
  String _debouncedPhoneFilter = '';
  CustomerSortMethod _sortMethod = CustomerSortMethod.name;
  String? _selectedImagePath;

  String get _activePhoneFilter {
    return _debouncedPhoneFilter.trim();
  }

  List<CustomerRecord> _getFilteredRecords(List<CustomerRecord> customers) {
    final query = _activePhoneFilter.toLowerCase();
    final normalizedQuery = _normalizePhone(query);

    final filtered = query.isEmpty
        ? customers.toList()
        : customers.where((record) {
            final matchesName = record.name.toLowerCase().contains(query);
            final matchesPhone = normalizedQuery.isNotEmpty &&
                _normalizePhone(record.phone).contains(normalizedQuery);
            return matchesName || matchesPhone;
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
    _phoneFilterController.addListener(_onPhoneFilterChanged);
    _mapLinkController.addListener(_onMapLinkChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterDebounce?.cancel();
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

  void _onPhoneFilterChanged() {
    _scheduleFilterRefresh(
      phoneFilter: _phoneFilterController.text,
    );
  }

  void _scheduleFilterRefresh({
    required String phoneFilter,
  }) {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
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
    _phoneFilterController.clear();
    _filterDebounce?.cancel();
    setState(() {
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
        imageUrl: _selectedImagePath,
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
        _selectedImagePath = null;
        _phoneFilterController.clear();
        _debouncedPhoneFilter = '';
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลลูกค้าสำเร็จ'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 2500),
        ),
      );
      debugPrint('=== Save Customer Completed Successfully ===');
    } catch (e) {
      debugPrint('=== Save Customer Failed ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบข้อมูลลูกค้าสำเร็จ'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 2500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _exportCsv(List<CustomerRecord> customers) async {
    if (customers.isEmpty) return;

    final csv = CsvExportService.exportCustomerRecords(customers);
    
    try {
      await FileShareService.shareOrDownloadText(
        filename: 'loscheck_customers.csv',
        content: csv,
        mimeType: 'text/csv',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งออกไฟล์: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _useRecord(CustomerRecord record) {
    setState(() {
      _phoneController.text = record.phone;
      _nameController.text = record.name;
      _addressController.text = record.address;
      _latitudeController.text = record.latitude?.toString() ?? '';
      _longitudeController.text = record.longitude?.toString() ?? '';
      _selectedImagePath = record.imageUrl;
      _phoneFilterController.clear();
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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดึงพิกัด GPS ปัจจุบันสำเร็จ'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 2500),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถดึงพิกัดปัจจุบันได้ กรุณาอนุญาตสิทธิ์เข้าตำแหน่งหรือระบุพิกัดด้วยตัวเอง'),
            backgroundColor: Colors.orange,
            duration: Duration(milliseconds: 2500),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการดึงตำแหน่ง: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ดึงพิกัดจากลิงก์ Google Maps สำเร็จ!'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 2500),
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถโทรออกได้'),
          duration: Duration(seconds: 3),
        ),
      );
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถเปิดแผนที่ได้'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickOrViewImage(CustomerRecord record) async {
    if (record.imageUrl != null) {
      // Show existing image
      if (!mounted) return;
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
                  'รูปบ้าน: ${record.name}',
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
                        ? Image.network(record.imageUrl!, fit: BoxFit.contain)
                        : Image.file(
                            io.File(record.imageUrl!),
                            fit: BoxFit.contain,
                            cacheWidth: 800,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final updated = CustomerRecord(
                        phone: record.phone,
                        name: record.name,
                        address: record.address,
                        createdAt: record.createdAt,
                        imageUrl: null,
                        latitude: record.latitude,
                        longitude: record.longitude,
                      );
                      await appDatabase.insertCustomer(updated);
                    },
                    child: const Text(
                      'ลบรูปภาพ',
                      style: TextStyle(color: Colors.red),
                    ),
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

  Future<void> _pickImageForForm() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูปบ้าน (กล้อง)'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลเลอรี (อัลบั้ม)'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImagePath = pickedFile.path;
      });
    }
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
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF00897B),
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: const Color(0xFF00897B),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: kanitTextStyle(fontWeight: FontWeight.normal, fontSize: 15),
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
                setState(() {
                  _selectedImagePath = null;
                });
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
                  'ค้นหาลูกค้า',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: TextField(
                  key: const Key('customerPhoneFilterField'),
                  controller: _phoneFilterController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'ค้นหาชื่อหรือเบอร์โทร',
                    hintText: 'พิมพ์ชื่อหรือเบอร์โทรศัพท์',
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
                    title: 'ไม่พบข้อมูลลูกค้าที่ค้นหา',
                    message: 'ลองค้นหาด้วยชื่อหรือเบอร์โทรอื่น',
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
                selectedImagePath: _selectedImagePath,
                onPickImage: _pickImageForForm,
                onRemoveImage: () => setState(() => _selectedImagePath = null),
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
    this.selectedImagePath,
    required this.onPickImage,
    required this.onRemoveImage,
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
  final String? selectedImagePath;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSave;
  final VoidCallback onGetLocation;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String latText = latitudeController.text.trim();
    final String lngText = longitudeController.text.trim();
    final bool hasCoords = latText.isNotEmpty && lngText.isNotEmpty;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'เพิ่ม/แก้ไข ข้อมูลลูกค้า',
            style: kanitTextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00897B),
            ),
          ),
          const SizedBox(height: 16),
          // Section 1: ข้อมูลลูกค้า (Customer Info Card)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F2F1),
                width: 1,
              ),
            ),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: Color(0xFF00897B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ข้อมูลลูกค้า',
                        style: kanitTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00897B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customerPhoneField'),
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: kanitTextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'เบอร์โทร',
                      hintText: 'เช่น 0812345678',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                      ),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customerNameField'),
                    controller: nameController,
                    enabled: canFillDetails,
                    style: kanitTextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ชื่อลูกค้า',
                      hintText: 'กรอกชื่อ',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                      ),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customerAddressField'),
                    controller: addressController,
                    enabled: canFillDetails,
                    minLines: 2,
                    maxLines: 4,
                    style: kanitTextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ที่อยู่',
                      hintText: 'บ้านเลขที่ / ซอย / ถนน / จุดสังเกต',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                      ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: ตำแหน่ง (Location Card)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F2F1),
                width: 1,
              ),
            ),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, color: Color(0xFF00897B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ตำแหน่ง',
                        style: kanitTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00897B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customerMapLinkField'),
                    controller: mapLinkController,
                    enabled: canFillDetails,
                    style: kanitTextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ลิงก์แผนที่ Google Maps',
                      hintText: 'วางลิงก์จาก Google Maps เพื่อดึงพิกัดอัตโนมัติ',
                      prefixIcon: const Icon(Icons.link_outlined),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('customerLatitudeField'),
                          controller: latitudeController,
                          enabled: canFillDetails,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          style: kanitTextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            hintText: 'เช่น 13.7563',
                            prefixIcon: const Icon(Icons.pin_drop_outlined),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('customerLongitudeField'),
                          controller: longitudeController,
                          enabled: canFillDetails,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          style: kanitTextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            hintText: 'เช่น 100.5018',
                            prefixIcon: const Icon(Icons.pin_drop_outlined),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF00897B), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasCoords
                              ? '📍 พิกัดบ้านลูกค้า: $latText, $lngText'
                              : '📍 ยังไม่มีพิกัดบ้านลูกค้า',
                          style: kanitTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasCoords
                                ? const Color(0xFF00897B)
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: onGetLocation,
                      icon: const Icon(Icons.my_location, size: 20),
                      label: Text(
                        '📍 ใช้ตำแหน่งปัจจุบัน',
                        style: kanitTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: รูปภาพบ้านลูกค้า (Customer House Image Card)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F2F1),
                width: 1,
              ),
            ),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_camera_outlined, color: Color(0xFF00897B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'รูปภาพบ้านลูกค้า',
                        style: kanitTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00897B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (selectedImagePath != null && selectedImagePath!.isNotEmpty)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                            child: kIsWeb
                                ? Image.network(selectedImagePath!, fit: BoxFit.cover)
                                : Image.file(
                                    io.File(selectedImagePath!),
                                    fit: BoxFit.cover,
                                    cacheWidth: 800,
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                                  onPressed: onPickImage,
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                  onPressed: onRemoveImage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: onPickImage,
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: const Color(0xFF00897B).withOpacity(0.5),
                          strokeWidth: 2,
                          dashPattern: [6, 4],
                          borderRadius: 16,
                        ),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B).withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo_outlined,
                                size: 36,
                                color: Color(0xFF00897B),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'เพิ่มรูปภาพบ้าน',
                                style: kanitTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00897B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Main Action Save Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF26C6DA)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00897B).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('saveCustomerButton'),
                onTap: onSave,
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '💾 บันทึกข้อมูลลูกค้า',
                        style: kanitTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashPattern,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final List<double> dashPattern;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    var distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final length = dashPattern[0];
        final space = dashPattern[1];
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += length + space;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    return Dismissible(
      key: Key(record.phone),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: Colors.amber.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'แก้ไขข้อมูล',
              style: kanitTextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF00897B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'โทรออก',
              style: kanitTextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.phone, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onUse();
        } else if (direction == DismissDirection.endToStart) {
          onCall();
        }
        return false;
      },
      child: GestureDetector(
        onTap: onUse,
        onLongPress: onDelete,
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F2F1),
              width: 1,
            ),
          ),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 0,
                    width: 0,
                    child: Text('${record.phone}\n${record.address}'),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leadingWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.name,
                                  style: kanitTextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (record.latitude == null || record.longitude == null)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
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
                          const SizedBox(height: 2),
                          Text(
                            record.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompact)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'โทรออก',
                            onPressed: onCall,
                            icon: const Icon(Icons.call_outlined, color: Color(0xFF00897B)),
                          ),
                          IconButton(
                            tooltip: 'แผนที่',
                            onPressed: onMap,
                            icon: const Icon(Icons.map_outlined, color: Color(0xFF00897B)),
                          ),
                          IconButton(
                            tooltip: 'รูปภาพ',
                            onPressed: onImage,
                            icon: const Icon(Icons.image_outlined, color: Color(0xFF00897B)),
                          ),
                          IconButton(
                            tooltip: 'แก้ไขข้อมูล',
                            onPressed: onUse,
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF00897B)),
                          ),
                          IconButton(
                            tooltip: 'ลบข้อมูลลูกค้า',
                            onPressed: onDelete,
                            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                      )
                    else
                      PopupMenuButton<_CustomerAction>(
                        tooltip: 'เมนูลูกค้า',
                        onSelected: (action) {
                          switch (action) {
                            case _CustomerAction.edit:
                              onUse();
                              break;
                            case _CustomerAction.delete:
                              onDelete();
                              break;
                            case _CustomerAction.image:
                              onImage();
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
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.address,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          if (record.latitude != null && record.longitude != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF00897B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'พิกัด: ${record.latitude}, ${record.longitude}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.tealAccent : const Color(0xFF00897B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (record.imageUrl != null && record.imageUrl!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: onImage,
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: kIsWeb
                                ? Image.network(record.imageUrl!, fit: BoxFit.cover)
                                : Image.file(
                                    io.File(record.imageUrl!),
                                    fit: BoxFit.cover,
                                    cacheWidth: 240,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isCompact) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                        label: const Text('โทร'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00897B),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: kanitTextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: onMap,
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('นำทาง'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: kanitTextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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
