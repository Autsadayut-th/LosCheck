import 'package:flutter/material.dart';
import '../../../models/trip_record.dart';

/// รายการแถวแสดงประวัติแต่ละรายการของค่ารอบ มีความสามารถในการแก้ไขและลบรายการ
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final TripRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final totalText = '${record.totalBaht} บาท';

    final Color leadingColor = switch (record.rateBaht) {
      5 => Colors.blue.shade400,
      10 => Colors.green.shade400,
      15 => Colors.orange.shade400,
      25 => Colors.red.shade400,
      _ => Colors.grey.shade400,
    };

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: leadingColor,
              width: 6,
            ),
          ),
        ),
        child: ListTile(
          title: Text(record.distanceLabel),
          subtitle: Text(
            isCompact
                ? '${record.rounds} รอบ x ${record.rateBaht} บาทต่อบิล • ${_formatTime(record.createdAt)}\n$totalText'
                : '${record.rounds} รอบ x ${record.rateBaht} บาทต่อบิล • ${_formatTime(record.createdAt)}',
          ),
          trailing: isCompact
              ? PopupMenuButton<RecordAction>(
                  tooltip: 'เมนูรายการ',
                  onSelected: (action) {
                    switch (action) {
                      case RecordAction.edit:
                        onEdit();
                      case RecordAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: RecordAction.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('แก้ไข'),
                      ),
                    ),
                    PopupMenuItem(
                      value: RecordAction.delete,
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
                    Text(
                      totalText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'แก้ไขจำนวนรอบ',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'ลบรายการ',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute น.';
  }
}

enum RecordAction { edit, delete }
