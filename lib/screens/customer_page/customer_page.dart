import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/customer_record.dart';
import '../../database/hive_database.dart';
import '../../providers/app_state_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../core/theme_extensions.dart';
import '../map_page/map_page.dart';

import 'models/customer_sort_method.dart';
import 'widgets/customer_form.dart';
import 'widgets/customer_record_tile.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
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

      final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final atMatch = atRegex.firstMatch(decodedUrl);
      if (atMatch != null) {
        final lat = double.tryParse(atMatch.group(1) ?? '');
        final lng = double.tryParse(atMatch.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      final placeRegex = RegExp(r'(?:place|search|maps)\/(-?\d+\.\d+),(-?\d+\.\d+)');
      final placeMatch = placeRegex.firstMatch(decodedUrl);
      if (placeMatch != null) {
        final lat = double.tryParse(placeMatch.group(1) ?? '');
        final lng = double.tryParse(placeMatch.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

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
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${record.latitude},${record.longitude}'
        '&travelmode=driving',
      );
    } else {
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

    final updated = CustomerRecord(
      phone: record.phone,
      name: record.name,
      address: record.address,
      createdAt: record.createdAt,
      imageUrl: pickedFile.path,
      latitude: record.latitude,
      longitude: record.longitude,
    );

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
                  labelColor: const Color(0xFF33BCB4),
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: const Color(0xFF33BCB4),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: kanitTextStyle(fontWeight: FontWeight.normal, fontSize: 15),
                  tabs: [
                    Tab(
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.search, size: 28),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.01,
                                child: Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: const Text('รายชื่อลูกค้า'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.person_add, size: 28),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.01,
                                child: Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: const Text('เพิ่ม/แก้ไขลูกค้า'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                    return CustomerRecordTile(
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
              CustomerForm(
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
