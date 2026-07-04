import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/route_completion_record.dart';
import '../../providers/app_state_provider.dart';
import '../../database/hive_database.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../core/theme_extensions.dart';
import 'widgets/route_history_tile.dart';
import 'widgets/add_edit_history_dialog.dart';

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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddEditHistoryDialog(record: record),
    );

    if (result != null) {
      final points = result['points'] as int;
      final distance = result['distance'] as double;
      final isEdit = record != null;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ประวัติการนำทาง',
          style: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
        label: Text('เพิ่มประวัติเอง', style: kanitTextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                        const SizedBox(height: 16),
                        Text(
                          'ยังไม่มีประวัติการนำทาง',
                          style: kanitTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ประวัติจะบันทึกเมื่อจัดส่งคิวเสร็จในหน้าแผนที่',
                          style: kanitTextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: completions.length,
                    itemBuilder: (context, index) {
                      final record = completions[index];
                      return RouteHistoryTile(
                        record: record,
                        onEdit: () => _showAddOrEditDialog(record: record),
                        onDelete: () => _deleteCompletion(record),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
