import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/customer_record.dart';
import '../../../core/theme_extensions.dart';

enum CustomerAction { image, edit, delete }

class CustomerRecordTile extends StatelessWidget {
  const CustomerRecordTile({
    super.key,
    required this.record,
    required this.onUse,
    required this.onDelete,
    required this.onCall,
    required this.onMap,
    required this.onImage,
    this.isCompact = false,
  });

  final CustomerRecord record;
  final VoidCallback onUse;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback onMap;
  final VoidCallback onImage;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget leadingWidget;
    if (record.imageUrl != null && record.imageUrl!.isNotEmpty) {
      leadingWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: kIsWeb
              ? Image.network(record.imageUrl!, fit: BoxFit.cover)
              : Image.file(
                  io.File(record.imageUrl!),
                  fit: BoxFit.cover,
                  cacheWidth: 120,
                ),
        ),
      );
    } else {
      leadingWidget = CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF33BCB4).withOpacity(0.1),
        child: const Icon(
          Icons.person,
          color: Color(0xFF33BCB4),
        ),
      );
    }

    return Center(
      child: GestureDetector(
        onTap: onUse,
        onLongPress: onDelete,
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0F5F4),
              width: 1,
            ),
          ),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 0,
                    width: 0,
                    child: Text('${record.phone}\n${record.address}'),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leadingWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.name,
                                  style: kanitTextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (record.latitude == null || record.longitude == null)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    border: Border.all(color: Colors.orange.shade300),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ไม่มีพิกัด',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            record.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompact)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'โทรออก',
                            onPressed: onCall,
                            icon: const Icon(Icons.call_outlined, color: Color(0xFF33BCB4)),
                          ),
                          IconButton(
                            tooltip: 'แผนที่',
                            onPressed: onMap,
                            icon: const Icon(Icons.map_outlined, color: Color(0xFF33BCB4)),
                          ),
                          IconButton(
                            tooltip: 'รูปภาพ',
                            onPressed: onImage,
                            icon: const Icon(Icons.image_outlined, color: Color(0xFF33BCB4)),
                          ),
                          IconButton(
                            tooltip: 'แก้ไขข้อมูล',
                            onPressed: onUse,
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF33BCB4)),
                          ),
                          IconButton(
                            tooltip: 'ลบข้อมูลลูกค้า',
                            onPressed: onDelete,
                            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                      )
                    else
                      PopupMenuButton<CustomerAction>(
                        tooltip: 'เมนูลูกค้า',
                        onSelected: (action) {
                          switch (action) {
                            case CustomerAction.edit:
                              onUse();
                              break;
                            case CustomerAction.delete:
                              onDelete();
                              break;
                            case CustomerAction.image:
                              onImage();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: CustomerAction.image,
                            child: ListTile(
                              leading: Icon(Icons.image_outlined),
                              title: Text('รูปภาพ'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: CustomerAction.edit,
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('แก้ไข'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: CustomerAction.delete,
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('ลบ', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.address,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          if (record.latitude != null && record.longitude != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF33BCB4)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'พิกัด: ${record.latitude}, ${record.longitude}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.tealAccent : const Color(0xFF33BCB4),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (record.imageUrl != null && record.imageUrl!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: onImage,
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: kIsWeb
                                ? Image.network(record.imageUrl!, fit: BoxFit.cover)
                                : Image.file(
                                    io.File(record.imageUrl!),
                                    fit: BoxFit.cover,
                                    cacheWidth: 240,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isCompact) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                        label: const Text('โทร'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF33BCB4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: kanitTextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: onMap,
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('นำทาง'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF33BCB4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: kanitTextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
