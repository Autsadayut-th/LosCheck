import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/route_completion_record.dart';
import '../providers/app_state_provider.dart';
import '../database/hive_database.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../core/design_tokens.dart';
import '../core/theme_extensions.dart';

class RouteHistoryPage extends StatefulWidget {
  const RouteHistoryPage({super.key});

  @override
  State<RouteHistoryPage> createState() => _RouteHistoryPageState();
}

class _RouteHistoryPageState extends State<RouteHistoryPage> {
  Future<void> _deleteCompletion(RouteCompletionRecord record) async {
    final confirmed = await confirmDelete(
      context,
      'ลบรายการประวัตินี้?',
      'จุดส่ง: ${record.points} จุด • ระยะทาง: ${record.distance.toStringAsFixed(1)} กม.',
    );
    if (!confirmed) return;

    if (record.id != null) {
      try {
        await appDatabase.deleteRouteCompletion(record.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบประวัติการนำทางเรียบร้อยแล้ว'),
            duration: Duration(milliseconds: 2500),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showAddOrEditDialog({RouteCompletionRecord? record}) async {
    final isEdit = record != null;
    final pointsController = TextEditingController(text: isEdit ? record.points.toString() : '');
    final distanceController = TextEditingController(text: isEdit ? record.distance.toString() : '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEdit ? 'แก้ไขประวัติการนำทาง' : 'เพิ่มประวัติการนำทางเอง',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนจุดส่ง (จุด)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin_drop_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'กรุณาระบุจำนวนจุด';
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 0) return 'กรุณาระบุจำนวนที่ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: DesignTokens.spacingM),
                TextFormField(
                  controller: distanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ระยะทางนำทาง (กิโลเมตร)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.navigation_outlined),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final points = int.parse(pointsController.text);
      final distance = double.parse(distanceController.text);

      try {
        if (isEdit) {
          final updated = RouteCompletionRecord(
            id: record.id,
            points: points,
            distance: distance,
            createdAt: record.createdAt,
          );
          await appDatabase.updateRouteCompletion(updated);
        } else {
          final newRecord = RouteCompletionRecord(
            points: points,
            distance: distance,
            createdAt: DateTime.now(),
          );
          await appDatabase.insertRouteCompletion(newRecord);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final completions = appState.routeCompletions;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ประวัติการนำทาง',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (completions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'ล้างประวัติทั้งหมด',
              onPressed: () async {
                final confirmed = await confirmDelete(
                  context,
                  'ล้างประวัติการนำทางทั้งหมด?',
                  'การกระทำนี้จะลบรายการประวัติการนำทางทั้งหมดและไม่สามารถกู้คืนได้',
                );
                if (confirmed) {
                  await appDatabase.deleteAllRouteCompletions();
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มประวัติเอง'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: completions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: DesignTokens.spacingM),
                        Text(
                          'ยังไม่มีประวัติการนำทาง',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: DesignTokens.spacingXs2),
                        const Text(
                          'ประวัติจะบันทึกเมื่อจัดส่งคิวเสร็จในหน้าแผนที่',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: completions.length,
                    itemBuilder: (context, index) {
                      final record = completions[index];
                      final dateStr = _formatDate(record.createdAt);
                      final timeStr = _formatTime(record.createdAt);

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.route_outlined,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$dateStr • $timeStr',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.pin_drop,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${record.points} จุดส่ง',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.navigation_rounded,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${record.distance.toStringAsFixed(1)} กม.',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'แก้ไข',
                                onPressed: () => _showAddOrEditDialog(record: record),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'ลบ',
                                onPressed: () => _deleteCompletion(record),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'วันนี้';

    final yesterday = today.subtract(const Duration(days: 1));
    if (target == yesterday) return 'เมื่อวาน';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute น.';
  }
}
