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
import '../widgets/confirm_delete_dialog.dart';
import '../core/theme_extensions.dart';

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
  final TextEditingController _phoneFilterController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Timer? _filterDebounce;
  String _phoneInput = '';
  String _debouncedPhoneInput = '';
  String _debouncedPhoneFilter = '';

  bool get _canFillDetails => _phoneController.text.trim().isNotEmpty;

  String get _activePhoneFilter {
    final manualFilter = _debouncedPhoneFilter.trim();
    if (manualFilter.isNotEmpty) {
      return manualFilter;
    }
    return _debouncedPhoneInput.trim();
  }

  List<CustomerRecord> _getFilteredRecords(List<CustomerRecord> customers) {
    final query = _normalizePhone(_activePhoneFilter);
    if (query.isEmpty) {
      return customers;
    }

    return customers.where((record) {
      return _normalizePhone(record.phone).contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _phoneController.addListener(_onPhoneInputChanged);
    _phoneFilterController.addListener(_onPhoneFilterChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterDebounce?.cancel();
    _phoneController.dispose();
    _nameController.dispose();
    _addressController.dispose();
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
      final record = CustomerRecord(
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        createdAt: DateTime.now(),
      );

      debugPrint('Creating customer record: ${record.phone}, ${record.name}');
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
      _phoneFilterController.clear();
      _phoneInput = record.phone;
      _debouncedPhoneInput = record.phone;
      _debouncedPhoneFilter = '';
    });
    _tabController.animateTo(1);
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
    final query = Uri.encodeComponent(record.address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
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
              kIsWeb
                  ? Image.network(record.imageUrl!)
                  : Image.file(io.File(record.imageUrl!)),
              OverflowBar(
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

    final updated = CustomerRecord(
      phone: record.phone,
      name: record.name,
      address: record.address,
      createdAt: record.createdAt,
      imageUrl: pickedFile.path,
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

    return SafeArea(
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
                      ? Colors.amber.shade900.withValues(alpha: 0.2)
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
                canFillDetails: true,
                onSave: _saveCustomer,
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
    required this.canFillDetails,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final bool canFillDetails;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
            : FileImage(io.File(record.imageUrl!)) as ImageProvider,
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
          title: Text(
            record.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${record.phone}\n${record.address}',
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum _CustomerAction { call, map, image, edit, delete }
