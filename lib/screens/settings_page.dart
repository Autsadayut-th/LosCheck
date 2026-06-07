import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/backup_service.dart';
import '../widgets/confirm_delete_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isProcessing = false;

  Future<void> _exportBackup() async {
    setState(() => _isProcessing = true);
    try {
      final jsonData = await BackupService.exportToJson();
      final filename = BackupService.generateBackupFilename();

      await Clipboard.setData(ClipboardData(text: jsonData));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ข้อมูลสำรองแล้ว ($filename) - คัดลอกไปยังคลิปบอร์ดแล้ว',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();

    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('นำเข้าข้อมูลสำรอง'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 20,
            decoration: const InputDecoration(
              hintText: 'วางข้อมูล JSON ที่คัดลอก...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('นำเข้า'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await BackupService.importFromJson(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('นำเข้าข้อมูลสำรองสำเร็จแล้ว'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _mergeBackup() async {
    final controller = TextEditingController();

    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ผสานข้อมูลสำรอง'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 20,
            decoration: const InputDecoration(
              hintText: 'วางข้อมูล JSON ที่คัดลอก...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('ผสาน'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await BackupService.mergeFromJson(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ผสานข้อมูลสำรองสำเร็จแล้ว'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await confirmDelete(
      context,
      'ลบข้อมูลทั้งหมด?',
      'การกระทำนี้ไม่สามารถย้อนกลับได้',
    );
    if (!confirmed) return;

    setState(() => _isProcessing = true);
    try {
      await BackupService.clearAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบข้อมูลทั้งหมดแล้ว'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                Text(
                  'การตั้งค่า',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'การสำรองข้อมูล',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _BackupCard(
                  title: 'ส่งออกข้อมูล',
                  description:
                      'บันทึกสำรองข้อมูลทั้งหมดเป็นไฟล์ JSON ที่สามารถนำเข้าได้ภายหลัง',
                  icon: Icons.download,
                  onPressed: _isProcessing ? null : _exportBackup,
                ),
                const SizedBox(height: 12),
                _BackupCard(
                  title: 'นำเข้าข้อมูล',
                  description:
                      'แทนที่ข้อมูลปัจจุบันด้วยข้อมูลสำรองที่บันทึกไว้',
                  icon: Icons.upload,
                  onPressed: _isProcessing ? null : _importBackup,
                  dangerous: true,
                ),
                const SizedBox(height: 12),
                _BackupCard(
                  title: 'ผสานข้อมูล',
                  description:
                      'เพิ่มข้อมูลสำรองไปยังข้อมูลปัจจุบัน (ไม่ลบข้อมูลเดิม)',
                  icon: Icons.merge,
                  onPressed: _isProcessing ? null : _mergeBackup,
                ),
                const SizedBox(height: 32),
                Text(
                  'ข้อมูล',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _BackupCard(
                  title: 'ลบข้อมูลทั้งหมด',
                  description:
                      'ลบข้อมูลลูกค้าและรายการทั้งหมด (ไม่สามารถย้อนกลับได้)',
                  icon: Icons.delete_forever,
                  onPressed: _isProcessing ? null : _clearAllData,
                  dangerous: true,
                ),
                const SizedBox(height: 24),
                if (_isProcessing)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
    this.dangerous = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool dangerous;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = dangerous
        ? (isDarkMode ? Colors.red.shade900 : Colors.red.shade50)
        : null;
    final foregroundColor = dangerous
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dangerous ? Colors.red.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: foregroundColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('ไป'),
              style: ElevatedButton.styleFrom(
                backgroundColor: foregroundColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
