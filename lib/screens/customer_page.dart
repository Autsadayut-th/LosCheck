import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../models/customer_record.dart';
import '../database/isar_database.dart';
import '../services/csv_export_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../core/theme_extensions.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneFilterController = TextEditingController();
  final List<CustomerRecord> _records = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Timer? _filterDebounce;
  String _phoneInput = '';
  String _debouncedPhoneInput = '';
  String _debouncedPhoneFilter = '';
  bool _isLoading = true;

  bool get _canFillDetails => _phoneController.text.trim().isNotEmpty;

  String get _activePhoneFilter {
    final manualFilter = _debouncedPhoneFilter.trim();
    if (manualFilter.isNotEmpty) {
      return manualFilter;
    }
    return _debouncedPhoneInput.trim();
  }

  List<CustomerRecord> get _filteredRecords {
    final query = _normalizePhone(_activePhoneFilter);
    if (query.isEmpty) {
      return _records;
    }

    return _records.where((record) {
      return _normalizePhone(record.phone).contains(query);
    }).toList();
  }

  StreamSubscription<List<CustomerRecord>>? _subscription;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneInputChanged);
    _phoneFilterController.addListener(_onPhoneFilterChanged);
    _subscription = appDatabase.watchAllCustomers().listen((customers) {
      if (!mounted) return;
      // Sort newest first
      final sortedCustomers = List<CustomerRecord>.from(customers)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
      setState(() {
        _records.clear();
        _records.addAll(sortedCustomers);
        _isLoading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
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

  Future<void> _exportCsv() async {
    if (_records.isEmpty) return;

    final csv = CsvExportService.exportCustomerRecords(_records);
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
              Image.network(record.imageUrl!),
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

    final index = _records.indexOf(record);
    if (index == -1) return;

    final updated = CustomerRecord(
      phone: record.phone,
      name: record.name,
      address: record.address,
      createdAt: record.createdAt,
      imageUrl: pickedFile.path,
    );

    setState(() {
      _records[index] = updated;
    });

    // Persist only the affected record.
    await appDatabase.insertCustomer(updated);
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _filteredRecords;
    final activePhoneFilter = _activePhoneFilter;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 380 ? 12 : 20,
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      if (appDatabase.isUsingInMemory)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'โหมดในหน่วยความจำ - ข้อมูลจะไม่ถูกบันทึกเมื่อปิดแอป',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                            if (_records.isNotEmpty)
                              IconButton(
                                tooltip: 'Export CSV',
                                onPressed: _exportCsv,
                                icon: const Icon(Icons.file_download_outlined),
                              ),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: _CustomerForm(
                          formKey: _formKey,
                          phoneController: _phoneController,
                          nameController: _nameController,
                          addressController: _addressController,
                          canFillDetails: _canFillDetails,
                          onSave: _saveCustomer,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
                      if (_records.isEmpty)
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
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'เพิ่ม/แก้ไข ข้อมูลลูกค้า',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('customerPhoneField'),
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
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
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 16),
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
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('saveCustomerButton'),
                onPressed: onSave,
                icon: const Icon(Icons.save, size: 28),
                label: const Text(
                  'บันทึกข้อมูลลูกค้า',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 20,
          vertical: 8,
        ),
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
            ? PopupMenuButton<_CustomerAction>(
                tooltip: 'เมนูลูกค้า',
                onSelected: (action) {
                  switch (action) {
                    case _CustomerAction.edit:
                      onUse();
                    case _CustomerAction.delete:
                      onDelete();
                    case _CustomerAction.call:
                      onCall();
                    case _CustomerAction.map:
                      onMap();
                    case _CustomerAction.image:
                      onImage();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _CustomerAction.call,
                    child: ListTile(
                      leading: Icon(Icons.call_outlined),
                      title: Text('โทรออก'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _CustomerAction.map,
                    child: ListTile(
                      leading: Icon(Icons.map_outlined),
                      title: Text('แผนที่'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _CustomerAction.image,
                    child: ListTile(
                      leading: Icon(Icons.image_outlined),
                      title: Text('รูปภาพ'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _CustomerAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('แก้ไข'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _CustomerAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('ลบ'),
                    ),
                  ),
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
                ],
              ),
      ),
    );
  }
}

enum _CustomerAction { call, map, image, edit, delete }
