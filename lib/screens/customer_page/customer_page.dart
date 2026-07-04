import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/customer_record.dart';
import '../../database/hive_database.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../core/theme_extensions.dart';
import '../map_page/map_page.dart';

import 'models/customer_sort_method.dart';
import 'widgets/customer_record_tile.dart';
import 'customer_form_page.dart';
import '../../widgets/voice_search_bottom_sheet.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _phoneFilterController = TextEditingController();

  Timer? _filterDebounce;
  String _debouncedPhoneFilter = '';
  CustomerSortMethod _sortMethod = CustomerSortMethod.name;

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
            final matchesAddress = record.address.toLowerCase().contains(query);
            return matchesName || matchesPhone || matchesAddress;
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
    _phoneFilterController.addListener(_onPhoneFilterChanged);
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _phoneFilterController.removeListener(_onPhoneFilterChanged);
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

  void _useRecord(CustomerRecord record) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerFormPage(record: record),
      ),
    );
    // Provider auto-updates via watchAllCustomers stream
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
                      // Provider auto-updates via watchAllCustomers stream
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
    // Provider auto-updates via watchAllCustomers stream
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
        child: _buildSearchTab(context, customers, filteredRecords, activePhoneFilter),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addCustomerFab'),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const CustomerFormPage(),
            ),
          );
          if (result == true && mounted) {
            // Provider auto-updates via watchAllCustomers stream
          }
        },
        child: const Icon(Icons.person_add),
      ),
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
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_phoneFilterController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'ล้างคำค้นหา',
                            onPressed: _clearPhoneFilter,
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'ค้นหาด้วยเสียง',
                          onPressed: () async {
                            final result = await showVoiceSearchBottomSheet(context);
                            if (result != null && result.isNotEmpty) {
                              _phoneFilterController.text = result;
                            }
                          },
                          icon: const Icon(Icons.mic, color: Color(0xFF33BCB4)),
                        ),
                      ],
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

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
