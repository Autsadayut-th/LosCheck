import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme_extensions.dart';

class CustomerForm extends StatefulWidget {
  const CustomerForm({
    super.key,
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
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  @override
  void initState() {
    super.initState();
    widget.phoneController.addListener(_updateState);
    widget.nameController.addListener(_updateState);
    widget.addressController.addListener(_updateState);
    widget.latitudeController.addListener(_updateState);
    widget.longitudeController.addListener(_updateState);
    widget.mapLinkController.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.phoneController.removeListener(_updateState);
    widget.nameController.removeListener(_updateState);
    widget.addressController.removeListener(_updateState);
    widget.latitudeController.removeListener(_updateState);
    widget.longitudeController.removeListener(_updateState);
    widget.mapLinkController.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  double _calculateProgress() {
    double progress = 0.0;
    
    final phone = widget.phoneController.text.trim();
    if (phone.isNotEmpty && phone.replaceAll(RegExp(r'[^0-9]'), '').length >= 9) {
      progress += 0.25;
    }
    
    final name = widget.nameController.text.trim();
    if (name.isNotEmpty) {
      progress += 0.25;
    }
    
    final address = widget.addressController.text.trim();
    if (address.isNotEmpty) {
      progress += 0.25;
    }
    
    final lat = widget.latitudeController.text.trim();
    final lng = widget.longitudeController.text.trim();
    final hasCoords = lat.isNotEmpty && lng.isNotEmpty;
    final mapLink = widget.mapLinkController.text.trim();
    if (hasCoords || mapLink.isNotEmpty) {
      progress += 0.15;
    }
    
    if (widget.selectedImagePath != null && widget.selectedImagePath!.isNotEmpty) {
      progress += 0.10;
    }
    
    return progress;
  }

  Widget? _getPhoneSuffixIcon() {
    final text = widget.phoneController.text.trim();
    if (text.isNotEmpty && text.replaceAll(RegExp(r'[^0-9]'), '').length >= 9) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF33BCB4), size: 18);
    }
    return null;
  }

  Widget? _getNameSuffixIcon() {
    final text = widget.nameController.text.trim();
    if (text.isNotEmpty) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF33BCB4), size: 18);
    }
    return null;
  }

  Widget? _getAddressSuffixIcon() {
    final text = widget.addressController.text.trim();
    if (text.isNotEmpty) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF33BCB4), size: 18);
    }
    return null;
  }

  Widget? _getMapLinkSuffixIcon() {
    final text = widget.mapLinkController.text.trim();
    if (text.isNotEmpty) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF33BCB4), size: 18);
    }
    return null;
  }

  Widget? _getCoordsSuffixIcon() {
    final lat = widget.latitudeController.text.trim();
    final lng = widget.longitudeController.text.trim();
    if (lat.isNotEmpty && lng.isNotEmpty && double.tryParse(lat) != null && double.tryParse(lng) != null) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF33BCB4), size: 18);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String latText = widget.latitudeController.text.trim();
    final String lngText = widget.longitudeController.text.trim();
    final bool hasCoords = latText.isNotEmpty && lngText.isNotEmpty;
    
    final progress = _calculateProgress();
    final progressPercentage = (progress * 100).toInt();

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'เพิ่ม/แก้ไข ข้อมูลลูกค้า',
                  style: kanitTextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF33BCB4),
                  ),
                ),
              ),
              Text(
                'ข้อมูลสมบูรณ์ $progressPercentage%',
                style: kanitTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: progress == 1.0 ? const Color(0xFF33BCB4) : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF33BCB4)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          
          // Section 1: ข้อมูลลูกค้า (Customer Info Card)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
                width: 1,
              ),
            ),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: Color(0xFF33BCB4), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'ข้อมูลลูกค้า',
                        style: kanitTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF33BCB4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('customerPhoneField'),
                    controller: widget.phoneController,
                    keyboardType: TextInputType.phone,
                    style: kanitTextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'เบอร์โทร',
                      hintText: 'เช่น 0812345678',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      suffixIcon: _getPhoneSuffixIcon(),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF33BCB4), width: 1.5),
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
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('customerNameField'),
                    controller: widget.nameController,
                    enabled: widget.canFillDetails,
                    style: kanitTextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ชื่อลูกค้า',
                      hintText: 'กรอกชื่อ',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      suffixIcon: _getNameSuffixIcon(),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF33BCB4), width: 1.5),
                      ),
                    ),
                    validator: (value) {
                      if (!widget.canFillDetails) {
                        return null;
                      }
                      if ((value ?? '').trim().isEmpty) {
                        return 'กรุณาใส่ชื่อ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('customerAddressField'),
                    controller: widget.addressController,
                    enabled: widget.canFillDetails,
                    minLines: 1,
                    maxLines: 3,
                    style: kanitTextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ที่อยู่',
                      hintText: 'บ้านเลขที่ / ซอย / ถนน',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      suffixIcon: _getAddressSuffixIcon(),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF33BCB4), width: 1.5),
                      ),
                    ),
                    validator: (value) {
                      if (!widget.canFillDetails) {
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
          const SizedBox(height: 10),

          // Section 2: ตำแหน่ง (Location Card - Compact layout)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
                width: 1,
              ),
            ),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, color: Color(0xFF33BCB4), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'ตำแหน่ง',
                        style: kanitTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF33BCB4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('customerMapLinkField'),
                    controller: widget.mapLinkController,
                    enabled: widget.canFillDetails,
                    style: kanitTextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ลิงก์แผนที่ Google Maps',
                      hintText: 'วางลิงก์เพื่อดึงพิกัดอัตโนมัติ',
                      prefixIcon: const Icon(Icons.link_outlined, size: 20),
                      suffixIcon: _getMapLinkSuffixIcon(),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF33BCB4), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('customerLatitudeField'),
                          controller: widget.latitudeController,
                          enabled: widget.canFillDetails,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          style: kanitTextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            hintText: 'เช่น 13.7563',
                            prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
                            suffixIcon: _getCoordsSuffixIcon(),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF33BCB4), width: 1.5),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: const Key('customerLongitudeField'),
                          controller: widget.longitudeController,
                          enabled: widget.canFillDetails,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          style: kanitTextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            hintText: 'เช่น 100.5018',
                            prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
                            suffixIcon: _getCoordsSuffixIcon(),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF33BCB4), width: 1.5),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF33BCB4), size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hasCoords
                              ? '📍 พิกัด: $latText, $lngText'
                              : '📍 ยังไม่มีพิกัด',
                          style: kanitTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasCoords
                                ? const Color(0xFF33BCB4)
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: widget.onGetLocation,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: Text(
                        'ใช้ตำแหน่งปัจจุบัน',
                        style: kanitTextStyle(
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
          ),
          const SizedBox(height: 10),

          // Section 3: รูปภาพบ้านลูกค้า (Customer House Image Card)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
                width: 1,
              ),
            ),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_camera_outlined, color: Color(0xFF33BCB4), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'รูปภาพบ้านลูกค้า',
                        style: kanitTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF33BCB4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.selectedImagePath != null && widget.selectedImagePath!.isNotEmpty)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                            child: kIsWeb
                                ? Image.network(widget.selectedImagePath!, fit: BoxFit.cover)
                                : Image.file(
                                    io.File(widget.selectedImagePath!),
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
                                  onPressed: widget.onPickImage,
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                  onPressed: widget.onRemoveImage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: widget.onPickImage,
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: const Color(0xFF33BCB4).withOpacity(0.5),
                          strokeWidth: 2,
                          dashPattern: [6, 4],
                          borderRadius: 12,
                        ),
                        child: Container(
                          height: 70,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF33BCB4).withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo_outlined,
                                size: 24,
                                color: Color(0xFF33BCB4),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'เพิ่มรูปภาพบ้าน',
                                style: kanitTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF33BCB4),
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
          const SizedBox(height: 16),

          // Main Action Save Button (Clean, Simple, standard style as requested)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('saveCustomerButton'),
              onPressed: widget.onSave,
              icon: const Icon(Icons.save, size: 20),
              label: Text(
                'บันทึกข้อมูลลูกค้า',
                style: kanitTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF33BCB4),
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
