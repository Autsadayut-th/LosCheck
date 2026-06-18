import 'package:flutter/material.dart';

class EditTripRecordDialog extends StatefulWidget {
  const EditTripRecordDialog({
    super.key,
    required this.initialRounds,
    required this.initialRate,
    required this.distanceLabel,
  });

  final int initialRounds;
  final int initialRate;
  final String distanceLabel;

  @override
  State<EditTripRecordDialog> createState() => _EditTripRecordDialogState();
}

class _EditTripRecordDialogState extends State<EditTripRecordDialog> {
  late final TextEditingController _roundsController;
  
  String? _roundsError;
  late int _rounds;
  late int _rate;

  @override
  void initState() {
    super.initState();
    _rounds = widget.initialRounds;
    _rate = widget.initialRate;
    
    _roundsController = TextEditingController(text: _rounds.toString());
    _roundsController.addListener(_onRoundsChanged);
  }

  void _onRoundsChanged() {
    final val = int.tryParse(_roundsController.text.trim());
    if (val != null && val > 0) {
      setState(() {
        _rounds = val;
        _roundsError = null;
      });
    }
  }

  @override
  void dispose() {
    _roundsController.removeListener(_onRoundsChanged);
    _roundsController.dispose();
    super.dispose();
  }

  void _submit() {
    final rounds = int.tryParse(_roundsController.text.trim());

    if (rounds == null || rounds <= 0) {
      setState(() {
        _roundsError = 'กรุณากรอกจำนวนรอบมากกว่า 0';
      });
      return;
    }

    Navigator.of(context).pop((rounds: rounds, rateBaht: _rate));
  }

  @override
  Widget build(BuildContext context) {
    // Generate dropdown items, ensuring the current custom rate is included if not standard
    final List<int> rateOptions = [5, 10, 15, 25];
    if (!rateOptions.contains(_rate)) {
      rateOptions.add(_rate);
    }
    rateOptions.sort();

    return AlertDialog(
      scrollable: true,
      title: const Text('แก้ไขรายการเดินทาง'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.distanceLabel,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 20),
          
          // Section 1: ค่ารอบ (Dropdown)
          Text(
            'ค่ารอบ (บาท/รอบ)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _rate,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            items: rateOptions.map((rate) {
              return DropdownMenuItem<int>(
                value: rate,
                child: Text(
                  '$rate บาท',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _rate = val;
                });
              }
            },
          ),
          
          const SizedBox(height: 24),
          
          // Section 2: จำนวนรอบ
          Text(
            'จำนวนรอบ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
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
                          _roundsController.text = _rounds.toString();
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _roundsController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    errorText: _roundsError != null ? '' : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 36,
                color: Theme.of(context).colorScheme.primary,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(() {
                    _rounds++;
                    _roundsController.text = _rounds.toString();
                  });
                },
              ),
            ],
          ),
          if (_roundsError != null) ...[
            const SizedBox(height: 4),
            Text(
              _roundsError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [1, 2, 3, 5, 10].map((val) {
              final isSelected = _rounds == val;
              return ChoiceChip(
                label: Text('$val รอบ'),
                selected: isSelected,
                visualDensity: VisualDensity.compact,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _rounds = val;
                      _roundsController.text = val.toString();
                      _roundsError = null;
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
        FilledButton(
          onPressed: _submit,
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
