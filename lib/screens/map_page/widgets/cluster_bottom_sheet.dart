import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/customer_record.dart';

class ClusterBottomSheet extends StatelessWidget {
  const ClusterBottomSheet({
    super.key,
    required this.clusterCustomers,
    required this.onSelectCustomer,
    required this.onCallCustomer,
    required this.onOpenInGoogleMaps,
  });

  final List<CustomerRecord> clusterCustomers;
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
          // Drag indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.group_work_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ลูกค้าในกลุ่มนี้ (${clusterCustomers.length} ราย)',
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
          // Customer List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: clusterCustomers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final customer = clusterCustomers[index];
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
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              customer.name.isNotEmpty
                                  ? customer.name.substring(0, 1).toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'โทร: ${customer.phone}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  customer.address,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (customer.imageUrl != null && customer.imageUrl!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: kIsWeb
                                    ? Image.network(customer.imageUrl!, fit: BoxFit.cover)
                                    : Image.file(
                                        io.File(customer.imageUrl!),
                                        fit: BoxFit.cover,
                                        cacheWidth: 150,
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Actions row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              onSelectCustomer(customer);
                            },
                            icon: const Icon(Icons.location_searching, size: 16),
                            label: const Text('ระบุพิกัด', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Theme.of(context).colorScheme.secondary,
                            ),
                            onPressed: () => onCallCustomer(customer.phone),
                            icon: const Icon(Icons.phone_outlined, size: 16),
                            label: const Text('โทร', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              elevation: 0,
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            onPressed: () => onOpenInGoogleMaps(customer),
                            icon: const Icon(Icons.navigation_outlined, size: 16),
                            label: const Text('นำทาง', style: TextStyle(fontSize: 12)),
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
