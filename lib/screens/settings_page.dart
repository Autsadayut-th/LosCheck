import 'dart:io' as io;
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import '../core/design_tokens.dart';
import '../core/theme_extensions.dart';
import '../main.dart';
import '../services/backup_service.dart';
import '../services/file_share_service.dart';
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

      await FileShareService.shareOrDownloadText(
        filename: filename,
        content: jsonData,
        mimeType: 'application/json',
      );

      if (!mounted) return;
      showSuccessSnackbar(
        context,
        message: 'ส่งออกข้อมูลสำรองเรียบร้อยแล้ว ($filename)',
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, message: 'เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String?> _getBackupJsonString(String title) async {
    final selectedOption = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_open),
                title: const Text('เลือกไฟล์สำรอง (.json)'),
                onTap: () => Navigator.pop(context, 'file'),
              ),
              ListTile(
                leading: const Icon(Icons.paste),
                title: const Text('วางข้อความสำรอง (Paste JSON)'),
                onTap: () => Navigator.pop(context, 'paste'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedOption == null) return null;

    if (selectedOption == 'file') {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result == null) return null;

        if (result.files.single.bytes != null) {
          return utf8.decode(result.files.single.bytes!);
        } else if (result.files.single.path != null) {
          final file = io.File(result.files.single.path!);
          return await file.readAsString();
        }
      } catch (e) {
        if (!mounted) return null;
        showErrorSnackbar(context, message: 'ไม่สามารถอ่านไฟล์ได้: ${e.toString()}');
      }
    } else if (selectedOption == 'paste') {
      final controller = TextEditingController();
      if (!mounted) return null;
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'วางข้อมูล JSON ที่คัดลอก...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
    }
    return null;
  }

  Future<void> _importBackup() async {
    final result = await _getBackupJsonString('นำเข้าข้อมูลสำรอง');
    if (result == null || result.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await BackupService.importFromJson(result);
      if (!mounted) return;
      showSuccessSnackbar(context, message: 'นำเข้าข้อมูลสำรองสำเร็จแล้ว');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, message: 'เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _mergeBackup() async {
    final result = await _getBackupJsonString('ผสานข้อมูลสำรอง');
    if (result == null || result.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await BackupService.mergeFromJson(result);
      if (!mounted) return;
      showSuccessSnackbar(context, message: 'ผสานข้อมูลสำรองสำเร็จแล้ว');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, message: 'เกิดข้อผิดพลาด: ${e.toString()}');
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
      showSuccessSnackbar(context, message: 'ลบข้อมูลทั้งหมดแล้ว');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, message: 'เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadApk() async {
    final baseUri = Uri.base;
    final pathSegments = List<String>.from(baseUri.pathSegments);
    if (pathSegments.isNotEmpty && (pathSegments.last.contains('.') || pathSegments.last.isEmpty)) {
      pathSegments.removeLast();
    }
    pathSegments.add('app-release.apk');
    final apkUri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      pathSegments: pathSegments,
    );

    try {
      if (await canLaunchUrl(apkUri)) {
        await launchUrl(apkUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot launch';
      }
    } catch (_) {
      if (!mounted) return;
      showErrorSnackbar(context, message: 'ไม่สามารถดาวน์โหลดไฟล์ APK ได้');
    }
  }

  Widget _buildSettingTile({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback? onTap,
    required BuildContext context,
    bool dangerous = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = dangerous 
        ? context.colors.error 
        : context.colors.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: kanitTextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
                if (title == 'ส่งออกข้อมูล' || title == 'ลบข้อมูลทั้งหมด')
                  const Text(
                    'ไป',
                    style: TextStyle(
                      color: Colors.transparent,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = context.screenWidth < 380;
    final themeState = MyApp.of(context);
    final currentTheme = themeState?.themeMode ?? ThemeMode.system;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: DesignTokens.containerMaxWidth),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'การตั้งค่า',
                  style: kanitTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // SECTION 1: Appearance
                Text(
                  'การแสดงผล',
                  style: kanitTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: context.colors.borderColor,
                      width: 1,
                    ),
                  ),
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1E1E1E) 
                      : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          color: context.colors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ธีมแอปพลิเคชัน',
                                style: kanitTextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'เลือกโหมดการแสดงผลของแอป',
                                style: TextStyle(
                                  color: context.colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<ThemeMode>(
                          key: const Key('theme_mode_dropdown'),
                          value: currentTheme,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down),
                          borderRadius: BorderRadius.circular(16),
                          style: kanitTextStyle(
                            color: context.colors.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          onChanged: (ThemeMode? value) {
                            if (value != null) {
                              themeState?.setThemeMode(value);
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text('ตามระบบ'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text('สว่าง'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text('มืด'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // SECTION 2: Backup & Restore
                Text(
                  'การสำรองข้อมูล',
                  style: kanitTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: context.colors.borderColor,
                      width: 1,
                    ),
                  ),
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1E1E1E) 
                      : Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _buildSettingTile(
                        title: 'ส่งออกข้อมูล',
                        description: 'บันทึกสำรองข้อมูลทั้งหมดเป็นไฟล์ JSON',
                        icon: Icons.download_outlined,
                        onTap: _isProcessing ? null : _exportBackup,
                        context: context,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildSettingTile(
                        title: 'นำเข้าข้อมูล',
                        description: 'แทนที่ข้อมูลปัจจุบันด้วยข้อมูลสำรองจากไฟล์',
                        icon: Icons.upload_outlined,
                        onTap: _isProcessing ? null : _importBackup,
                        dangerous: true,
                        context: context,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildSettingTile(
                        title: 'ผสานข้อมูล',
                        description: 'เพิ่มข้อมูลสำรองไปยังข้อมูลปัจจุบัน',
                        icon: Icons.merge_type_outlined,
                        onTap: _isProcessing ? null : _mergeBackup,
                        context: context,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // SECTION 3: System & Info
                Text(
                  'ข้อมูลและระบบ',
                  style: kanitTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: context.colors.borderColor,
                      width: 1,
                    ),
                  ),
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1E1E1E) 
                      : Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _buildSettingTile(
                        title: 'ลบข้อมูลทั้งหมด',
                        description: 'ลบข้อมูลลูกค้าและรายการทั้งหมดถาวร',
                        icon: Icons.delete_forever_outlined,
                        onTap: _isProcessing ? null : _clearAllData,
                        dangerous: true,
                        context: context,
                      ),
                      if (kIsWeb) ...[
                        const Divider(height: 1, indent: 56),
                        _buildSettingTile(
                          title: 'ดาวน์โหลด Android APK',
                          description: 'ดาวน์โหลดและติดตั้งแอปเนทีฟบน Android',
                          icon: Icons.android_outlined,
                          onTap: _downloadApk,
                          context: context,
                        ),
                      ],
                    ],
                  ),
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
