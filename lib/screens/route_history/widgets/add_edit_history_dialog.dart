import 'package:flutter/material.dart';
import '../../../core/design_tokens.dart';
import '../../../core/theme_extensions.dart';
import '../../../models/route_completion_record.dart';

class AddEditHistoryDialog extends StatefulWidget {
  final RouteCompletionRecord? record;

  const AddEditHistoryDialog({super.key, this.record});

  @override
  State<AddEditHistoryDialog> createState() => _AddEditHistoryDialogState();
}

class _AddEditHistoryDialogState extends State<AddEditHistoryDialog> {
  late final TextEditingController _pointsController;
  late final TextEditingController _distanceController;
  final _formKey = GlobalKey<FormState>();
  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController(
      text: _isEdit ? widget.record!.points.toString() : '',
    );
    _distanceController = TextEditingController(
      text: _isEdit ? widget.record!.distance.toString() : '',
    );
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'แก้ไขประวัติการนำทาง' : 'เพิ่มประวัติการนำทางเอง',
        style: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              style: kanitTextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'จำนวนจุดส่ง (จุด)',
                labelStyle: kanitTextStyle(fontSize: 14),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.pin_drop_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'กรุณาระบุจำนวนจุด';
                final parsed = int.tryParse(value);
                if (parsed == null || parsed < 0) return 'กรุณาระบุจำนวนที่ถูกต้อง';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: kanitTextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'ระยะทางนำทาง (กิโลเมตร)',
                labelStyle: kanitTextStyle(fontSize: 14),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.navigation_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'กรุณาระบุระยะทาง';
                final parsed = double.tryParse(value);
                if (parsed == null || parsed < 0) return 'กรุณาระบุระยะทางที่ถูกต้อง';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('ยกเลิก', style: kanitTextStyle(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final points = int.parse(_pointsController.text);
              final distance = double.parse(_distanceController.text);
              Navigator.pop(context, {
                'points': points,
                'distance': distance,
              });
            }
          },
          child: Text(_isEdit ? 'บันทึก' : 'เพิ่ม', style: kanitTextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
