import 'package:flutter/material.dart';
import '../../../models/customer_record.dart';

/// Bottom Sheet แสดงรายละเอียดของลูกค้าเดี่ยว เช่น ชื่อ ที่อยู่ เบอร์โทรศัพท์ ปุ่มโทรออก และปุ่มนำทาง
class CustomerBottomSheet extends StatelessWidget {
  const CustomerBottomSheet({
    super.key,
    required this.customer,
    required this.onCallCustomer,
    required this.onOpenInGoogleMaps,
    required this.onClose,
    required this.onNavigateToRoutePlanning,
  });

  final CustomerRecord customer;
  final ValueChanged<String> onCallCustomer;
  final ValueChanged<CustomerRecord> onOpenInGoogleMaps;
  final VoidCallback onClose;
  final VoidCallback onNavigateToRoutePlanning;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'เบอร์โทร: ${customer.phone}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ที่อยู่: ${customer.address}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.latitude != null &&
                          customer.longitude != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'พิกัด: ${customer.latitude}, ${customer.longitude}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: Colors.green),
                  onPressed: () => onCallCustomer(customer.phone),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                    onClose();
                  },
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onNavigateToRoutePlanning();
              },
              icon: const Icon(Icons.route),
              label: const Text('วางแผนเส้นทางส่งของ'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
