import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer_record.dart';
import '../services/supabase_sync_service.dart';
import '../widgets/confirm_delete_dialog.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  static const String _storageKey = 'customer_records_v1';

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneFilterController = TextEditingController();
  final List<CustomerRecord> _records = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;

  bool get _canFillDetails => _phoneController.text.trim().isNotEmpty;

  String get _activePhoneFilter {
    final manualFilter = _phoneFilterController.text.trim();
    if (manualFilter.isNotEmpty) {
      return manualFilter;
    }
    return _phoneController.text.trim();
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

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _phoneFilterController.addListener(() => setState(() {}));
    _loadRecords();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecords = prefs.getStringList(_storageKey) ?? [];
    final loadedRecords =
        rawRecords
            .map((rawRecord) => CustomerRecord.fromJson(jsonDecode(rawRecord)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _records
        ..clear()
        ..addAll(loadedRecords);
      _isLoading = false;
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecords = _records
        .map((record) => jsonEncode(record.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, rawRecords);
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final record = CustomerRecord(
      phone: _phoneController.text.trim(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() {
      _records.insert(0, record);
      _phoneController.clear();
      _nameController.clear();
      _addressController.clear();
      _phoneFilterController.clear();
    });

    await _saveRecords();
    await SupabaseSyncService.saveCustomerRecord(
      record,
      onError: _showSyncError,
    );
  }

  void _showSyncError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteRecord(CustomerRecord record) async {
    final confirmed = await confirmDelete(
      context,
      'ลบข้อมูลลูกค้า?',
      '${record.name} (${record.phone})',
    );
    if (!confirmed) return;

    setState(() {
      _records.remove(record);
    });
    await _saveRecords();
  }

  void _useRecord(CustomerRecord record) {
    setState(() {
      _phoneController.text = record.phone;
      _nameController.text = record.name;
      _addressController.text = record.address;
      _phoneFilterController.clear();
    });
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
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      Text(
                        'ข้อมูลลูกค้า',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _CustomerForm(
                        formKey: _formKey,
                        phoneController: _phoneController,
                        nameController: _nameController,
                        addressController: _addressController,
                        canFillDetails: _canFillDetails,
                        onSave: _saveCustomer,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'ค้นหาเบอร์โทร',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
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
                                  onPressed: _phoneFilterController.clear,
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
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
                              onPressed: () {
                                setState(() {
                                  _phoneFilterController.clear();
                                  _phoneController.clear();
                                });
                              },
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('ล้างตัวกรอง'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_records.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'ยังไม่มีข้อมูลลูกค้า',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (filteredRecords.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'ไม่พบเบอร์โทรที่ค้นหา',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        for (final record in filteredRecords)
                          _CustomerRecordTile(
                            record: record,
                            onUse: () => _useRecord(record),
                            onDelete: () => _deleteRecord(record),
                          ),
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('customerPhoneField'),
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทร',
                  hintText: 'เช่น 0812345678',
                  prefixIcon: Icon(Icons.phone_outlined),
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
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('customerNameField'),
                controller: nameController,
                enabled: canFillDetails,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ',
                  hintText: 'ชื่อลูกค้า',
                  prefixIcon: Icon(Icons.person_outline),
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
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('customerAddressField'),
                controller: addressController,
                enabled: canFillDetails,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่',
                  hintText: 'บ้านเลขที่ / ซอย / ถนน / จุดสังเกต',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
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
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('saveCustomerButton'),
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('บันทึกข้อมูลลูกค้า'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerRecordTile extends StatelessWidget {
  const _CustomerRecordTile({
    required this.record,
    required this.onUse,
    required this.onDelete,
  });

  final CustomerRecord record;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(record.name),
        subtitle: Text('${record.phone}\n${record.address}'),
        isThreeLine: true,
        onTap: onUse,
        trailing: IconButton(
          tooltip: 'ลบข้อมูลลูกค้า',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}
