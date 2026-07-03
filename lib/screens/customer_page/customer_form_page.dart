import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/customer_record.dart';
import '../../database/hive_database.dart';
import '../../providers/app_state_provider.dart';
import '../../services/location_service.dart';
import '../../core/theme_extensions.dart';
import 'widgets/customer_form.dart';

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key, this.record});

  final CustomerRecord? record;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _mapLinkController = TextEditingController();
  final TextEditingController _importTextController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedImagePath;
  String? _lastPromptedPhone;
  bool _isPrompting = false;

  bool get isEditMode => widget.record != null;

  @override
  void initState() {
    super.initState();
    _mapLinkController.addListener(_onMapLinkChanged);
    _phoneController.addListener(_onPhoneChanged);
    if (widget.record != null) {
      _phoneController.text = widget.record!.phone;
      _nameController.text = widget.record!.name;
      _addressController.text = widget.record!.address;
      _latitudeController.text = widget.record!.latitude?.toString() ?? '';
      _longitudeController.text = widget.record!.longitude?.toString() ?? '';
      _selectedImagePath = widget.record!.imageUrl;
    }
  }

  @override
  void dispose() {
    _mapLinkController.removeListener(_onMapLinkChanged);
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapLinkController.dispose();
    _importTextController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    if (isEditMode) return;

    final rawPhone = _phoneController.text;
    final cleanedPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedPhone.length < 9 || cleanedPhone.length > 10) return;
    if (_lastPromptedPhone == cleanedPhone) return;

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final existingRecord = appState.customers.firstWhere(
        (c) => c.phone.replaceAll(RegExp(r'[^0-9]'), '') == cleanedPhone,
      );

      _lastPromptedPhone = cleanedPhone;

      if (_isPrompting) return;
      _isPrompting = true;

      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF33BCB4)),
              SizedBox(width: 8),
              Text('พบข้อมูลเดิม'),
            ],
          ),
          content: Text(
            'พบข้อมูลลูกค้าเบอร์นี้แล้วในฐานข้อมูล:\n'
            '• ชื่อ: ${existingRecord.name}\n'
            '• ที่อยู่: ${existingRecord.address}\n\n'
            'คุณต้องการโหลดข้อมูลลูกค้าเดิมนี้ขึ้นมาเพื่อแก้ไข/อัปเดตแทนหรือไม่?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF33BCB4),
              ),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      ).then((shouldLoad) {
        _isPrompting = false;
        if (shouldLoad == true && mounted) {
          setState(() {
            _nameController.text = existingRecord.name;
            _addressController.text = existingRecord.address;
            _latitudeController.text = existingRecord.latitude?.toString() ?? '';
            _longitudeController.text = existingRecord.longitude?.toString() ?? '';
            _selectedImagePath = existingRecord.imageUrl;
          });
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('โหลดข้อมูลเดิมเข้าแบบฟอร์มเรียบร้อยแล้ว'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (_) {
      // No matching customer found
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

  void _parseImportedText(String inputText) {
    String text = inputText.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาวางข้อความก่อนกดดึงข้อมูล'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    String? parsedPhone;
    String? parsedName;
    String? parsedAddress;
    String? parsedMapLink;

    // 1. Parse Google Maps Link
    final mapRegex = RegExp(r'(https?:\/\/(?:[a-zA-Z0-9-]+\.)*(?:google\.com|goo\.gl|maps\.app\.goo\.gl)\/\S+)');
    final mapMatch = mapRegex.firstMatch(text);
    if (mapMatch != null) {
      parsedMapLink = mapMatch.group(1);
      text = text.replaceAll(parsedMapLink!, '');
    }

    // 2. Parse Phone Number
    final phoneRegex = RegExp(r'(?:\+?66|0)[0-9\-\s]{8,15}');
    for (final match in phoneRegex.allMatches(text)) {
      final rawMatch = match.group(0)!;
      final cleaned = rawMatch.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.length == 9 || cleaned.length == 10) {
        parsedPhone = cleaned;
        if (parsedPhone.startsWith('66')) {
          parsedPhone = '0' + parsedPhone.substring(2);
        }
        text = text.replaceAll(rawMatch, '');
        break;
      }
    }

    // 3. Parse Name with labels
    final nameLabelRegex = RegExp(r'(?:ชื่อลูกค้า|ชื่อ|ลูกค้า|ผู้รับ|คุณ|Name|Customer|Contact)\s*[:：\- ]\s*([^\n]+)', caseSensitive: false);
    final nameMatch = nameLabelRegex.firstMatch(text);
    if (nameMatch != null) {
      parsedName = nameMatch.group(1)!.trim();
      text = text.replaceAll(nameMatch.group(0)!, '');
    } else {
      final titleRegex = RegExp(r'(?:คุณ|นาย|นาง|นางสาว|Mr\.|Mrs\.|Ms\.)\s*([^\s\n\-\:\,]+(?:\s+[^\s\n\-\:\,]+)?)');
      final titleMatch = titleRegex.firstMatch(text);
      if (titleMatch != null) {
        parsedName = titleMatch.group(0)!.trim();
        text = text.replaceAll(titleMatch.group(0)!, '');
      }
    }

    // 4. Parse Address with labels
    final addressLabelRegex = RegExp(r'(?:ที่อยู่จัดส่ง|ที่อยู่ลูกค้า|ที่อยู่|ส่งที่|Address|Addr)\s*[:：\- ]\s*([^\n]+(?:\n\s*[^\n]+)*)', caseSensitive: false);
    final addressMatch = addressLabelRegex.firstMatch(text);
    if (addressMatch != null) {
      parsedAddress = addressMatch.group(1)!.trim();
      text = text.replaceAll(addressMatch.group(0)!, '');
    }

    // 5. Fallback heuristics: Split remaining text into non-empty lines
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 1)
        .toList();

    if (parsedName == null && lines.isNotEmpty) {
      final firstLine = lines.first;
      final addressKeywords = ['ม.', 'หมู่', 'ต.', 'อ.', 'จ.', 'แขวง', 'เขต', 'ถนน', 'ซอย', 'บ้านเลขที่', 'เลขที่', 'ตำบล', 'อำเภอ', 'จังหวัด', 'ถ.'];
      final hasAddressKeywords = addressKeywords.any((keyword) => firstLine.contains(keyword));
      
      if (firstLine.length < 35 && !hasAddressKeywords) {
        parsedName = firstLine;
        lines.removeAt(0);
      }
    }

    if (parsedAddress == null && lines.isNotEmpty) {
      parsedAddress = lines.join(' ');
    }

    if (parsedName != null) {
      parsedName = parsedName
          .replaceAll(RegExp(r'^(?:ชื่อลูกค้า|ชื่อ|ลูกค้า|ผู้รับ|Name|คุณ|นาย|นาง|นางสาว)\s*[:：\- ]\s*', caseSensitive: false), '')
          .trim();
    }
    
    if (parsedAddress != null) {
      parsedAddress = parsedAddress
          .replaceAll(RegExp(r'^(?:ที่อยู่จัดส่ง|ที่อยู่ลูกค้า|ที่อยู่|ส่งที่|Address|โทร|เบอร์โทร|เบอร์|แผนที่|พิกัด|Google Maps)\s*[:：\- ]\s*', caseSensitive: false), '')
          .trim();
    }

    setState(() {
      if (parsedPhone != null && parsedPhone.isNotEmpty) {
        _phoneController.text = parsedPhone;
      }
      if (parsedName != null && parsedName.isNotEmpty) {
        _nameController.text = parsedName;
      }
      if (parsedAddress != null && parsedAddress.isNotEmpty) {
        _addressController.text = parsedAddress;
      }
      if (parsedMapLink != null && parsedMapLink.isNotEmpty) {
        _mapLinkController.text = parsedMapLink;
      }
    });

    final List<String> parsedItems = [];
    if (parsedName != null && parsedName.isNotEmpty) parsedItems.add('ชื่อ');
    if (parsedPhone != null && parsedPhone.isNotEmpty) parsedItems.add('เบอร์โทร');
    if (parsedAddress != null && parsedAddress.isNotEmpty) parsedItems.add('ที่อยู่');
    if (parsedMapLink != null && parsedMapLink.isNotEmpty) parsedItems.add('พิกัดแผนที่');

    ScaffoldMessenger.of(context).clearSnackBars();
    if (parsedItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ดึงข้อมูลสำเร็จ: ${parsedItems.join(', ')}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      _importTextController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถตรวจจับข้อมูลลูกค้าได้จากข้อความนี้ กรุณาตรวจสอบข้อมูล'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
        createdAt: widget.record?.createdAt ?? DateTime.now(),
        imageUrl: _selectedImagePath,
        latitude: latitude,
        longitude: longitude,
      );

      debugPrint('Creating customer record: ${record.phone}, ${record.name}, lat: ${record.latitude}, lng: ${record.longitude}');
      debugPrint('Database initialized: ${appDatabase.isInitialized}');

      await appDatabase.insertCustomer(record);
      debugPrint('Customer inserted successfully');
      
      if (!mounted) return;
      // Database watch streams automatically update the UI state provider.

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode ? 'แก้ไขข้อมูลลูกค้าสำเร็จ' : 'บันทึกข้อมูลลูกค้าสำเร็จ'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 2500),
        ),
      );
      debugPrint('=== Save Customer Completed Successfully ===');
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('=== Save Customer Failed ===');
      debugPrint('Error: $e');
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditMode ? 'แก้ไขข้อมูลลูกค้า' : 'เพิ่มลูกค้าใหม่',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
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
                      color: isDark 
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
                                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ข้อมูลจะไม่ถูกบันทึกลงเครื่องถาวร กรุณาอย่าปิดบราวเซอร์',
                                style: TextStyle(
                                  color: isDark ? Colors.amber.shade100 : Colors.amber.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
                      width: 1.5,
                    ),
                  ),
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: ExpansionTile(
                    key: const Key('smartPasteExpansionTile'),
                    leading: const Icon(Icons.auto_awesome, color: Color(0xFF33BCB4)),
                    title: Text(
                      'วางข้อความด่วน (ช่วยกรอกข้อมูลอัตโนมัติ)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.all(12),
                    expandedAlignment: Alignment.topLeft,
                    children: [
                      Text(
                        'คัดลอกข้อความยาว ๆ ทั้งหมดจากแอปแชทมาวางที่นี่ ระบบจะดึงชื่อ เบอร์โทร ที่อยู่ และลิงก์แผนที่ให้อัตโนมัติ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('smartPasteInputField'),
                        controller: _importTextController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'วางข้อความแชท เช่น:\nคุณสมชาย รักดี\nโทร 081-234-5678\nที่อยู่ 99/9 ม.2 ต.บางรัก...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white30 : Colors.grey.shade400,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: FilledButton.icon(
                          key: const Key('smartPasteSubmitButton'),
                          onPressed: () {
                            _parseImportedText(_importTextController.text);
                          },
                          icon: const Icon(Icons.bolt, size: 16),
                          label: const Text(
                            'แยกแยะและกรอกข้อมูลอัตโนมัติ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF33BCB4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
      ),
    );
  }
}
