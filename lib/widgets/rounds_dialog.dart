import 'package:flutter/material.dart';

class RoundsDialog extends StatefulWidget {
  const RoundsDialog({super.key});

  @override
  State<RoundsDialog> createState() => _RoundsDialogState();
}

class _RoundsDialogState extends State<RoundsDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final rounds = int.tryParse(_controller.text.trim());

    if (rounds == null || rounds <= 0) {
      setState(() {
        _errorText = 'กรุณาใส่จำนวนรอบเป็นตัวเลขมากกว่า 0';
      });
      return;
    }

    Navigator.of(context).pop(rounds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('กรุณาใส่จำนวนรอบ'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'จำนวนรอบ',
          hintText: 'เช่น 3',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(onPressed: _submit, child: const Text('ตกลง')),
      ],
    );
  }
}
