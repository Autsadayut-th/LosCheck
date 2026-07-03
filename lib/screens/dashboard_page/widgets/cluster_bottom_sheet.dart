import 'package:flutter/material.dart';
import '../../../models/customer_record.dart';

/// Bottom Sheet แสดงรายชื่อลูกค้าทั้งหมดในกลุ่มที่อยู่ใกล้กัน (Cluster)
class ClusterBottomSheet extends StatelessWidget {
  const ClusterBottomSheet({
    super.key,
    required this.items,
    required this.onSelectCustomer,
    required this.onCallCustomer,
    required this.onOpenInGoogleMaps,
  });

  final List<CustomerRecord> items;
  final ValueChanged<CustomerRecord> onSelectCustomer;
  final ValueChanged<String> onCallCustomer;
  final ValueChanged<CustomerRecord> onOpenInGoogleMaps;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.group_work_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ลูกค้าในกลุ่มนี้ (${items.length} ราย)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final c = items[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Theme.of(ctx).colorScheme.primaryContainer,
                            child: Text(
                              c.name.isNotEmpty
                                  ? c.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text('โทร: ${c.phone}',
                                    style: TextStyle(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withOpacity(0.8),
                                        fontSize: 12)),
                                Text(c.address,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor:
                                  Theme.of(ctx).colorScheme.primary,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              onSelectCustomer(c);
                            },
                            icon: const Icon(Icons.location_searching,
                                size: 16),
                            label: const Text('ระบุพิกัด',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor:
                                  Theme.of(ctx).colorScheme.secondary,
                            ),
                            onPressed: () => onCallCustomer(c.phone),
                            icon: const Icon(Icons.phone_outlined, size: 16),
                            label: const Text('โทร',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              elevation: 0,
                              backgroundColor: Theme.of(ctx)
                                  .colorScheme
                                  .primaryContainer,
                              foregroundColor: Theme.of(ctx)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                            onPressed: () => onOpenInGoogleMaps(c),
                            icon: const Icon(Icons.navigation_outlined,
                                size: 16),
                            label: const Text('นำทาง',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
