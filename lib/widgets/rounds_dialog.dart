import 'package:flutter/material.dart';

class RoundsDialog extends StatefulWidget {
  const RoundsDialog({super.key, this.initialRounds});

  final int? initialRounds;

  @override
  State<RoundsDialog> createState() => _RoundsDialogState();
}

class _RoundsDialogState extends State<RoundsDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  late int _rounds;

  @override
  void initState() {
    super.initState();
    _rounds = widget.initialRounds ?? 1;
    _controller = TextEditingController(
      text: _rounds.toString(),
    );
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final val = int.tryParse(_controller.text.trim());
    if (val != null && val > 0) {
      setState(() {
        _rounds = val;
        _errorText = null;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
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
      scrollable: true,
      title: const Text('ระบุจำนวนรอบ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                color: Theme.of(context).colorScheme.primary,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _rounds > 1
                    ? () {
                        setState(() {
                          _rounds--;
                          _controller.text = _rounds.toString();
                        });
                      }
                    : null,
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: const OutlineInputBorder(),
                    errorText: _errorText != null ? '' : null,
                  ),
                ),
              ),
              IconButton(
                iconSize: 36,
                color: Theme.of(context).colorScheme.primary,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(() {
                    _rounds++;
                    _controller.text = _rounds.toString();
                  });
                },
              ),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'เลือกจำนวนรอบด่วน',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [1, 2, 3, 5, 10].map((val) {
              final isSelected = _rounds == val;
              return ChoiceChip(
                label: Text('$val รอบ'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _rounds = val;
                      _controller.text = val.toString();
                      _errorText = null;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
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
