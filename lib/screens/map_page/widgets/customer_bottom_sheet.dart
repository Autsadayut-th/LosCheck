import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/customer_record.dart';
import '../../route_planning/route_planning_page.dart';

class CustomerBottomSheet extends StatelessWidget {
  const CustomerBottomSheet({
    super.key,
    required this.customer,
    required this.onCallCustomer,
    required this.onOpenInGoogleMaps,
    required this.onClose,
  });

  final CustomerRecord customer;
  final ValueChanged<String> onCallCustomer;
  final ValueChanged<CustomerRecord> onOpenInGoogleMaps;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag indicator
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เบอร์โทร: ${customer.phone}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ที่อยู่: ${customer.address}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (customer.latitude != null && customer.longitude != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'พิกัด: ${customer.latitude}, ${customer.longitude}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'โทรหาลูกค้า',
                      icon: const Icon(Icons.phone, color: Color(0xFF33BCB4)),
                      onPressed: () => onCallCustomer(customer.phone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ],
            ),
            if (customer.imageUrl != null && customer.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppBar(
                            title: Text(
                              'รูปบ้าน: ${customer.name}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            automaticallyImplyLeading: false,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? Image.network(customer.imageUrl!, fit: BoxFit.contain)
                                    : Image.file(
                                        io.File(customer.imageUrl!),
                                        fit: BoxFit.contain,
                                        cacheWidth: 800,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    child: kIsWeb
                        ? Image.network(customer.imageUrl!, fit: BoxFit.cover)
                        : Image.file(
                            io.File(customer.imageUrl!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => onOpenInGoogleMaps(customer),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('นำทาง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF33BCB4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
