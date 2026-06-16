import 'dart:io' as io;
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
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
            padding: isSmallScreen ? DesignTokens.paddingS : DesignTokens.paddingM,
            child: ListView(
              children: [
                Text(
                  'การตั้งค่า',
                  style: context.textStyles.headingPrimary.copyWith(
                    fontWeight: DesignTokens.fontWeightBold,
                    fontSize: isSmallScreen ? 24 : null,
                  ),
                ),
                SizedBox(height: isSmallScreen ? DesignTokens.spacingM : DesignTokens.spacingL),
                Text(
                  'การแสดงผล',
                  style: context.textStyles.cardTitle.copyWith(
                    fontWeight: DesignTokens.fontWeightBold,
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
                SizedBox(height: isSmallScreen ? DesignTokens.spacingXs2 : DesignTokens.spacingM),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.borderRadiusMd,
                    side: BorderSide(
                      color: context.colors.borderColor,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: isSmallScreen ? DesignTokens.paddingS : DesignTokens.paddingM,
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          color: context.colors.primary,
                          size: isSmallScreen ? DesignTokens.iconSizeMd : DesignTokens.iconSizeLg,
                        ),
                        SizedBox(width: isSmallScreen ? DesignTokens.spacingS : DesignTokens.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ธีมแอปพลิเคชัน',
                                style: context.textStyles.titleMedium?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: DesignTokens.fontWeightBold,
                                  fontSize: isSmallScreen ? 14 : null,
                                ),
                              ),
                              const SizedBox(height: DesignTokens.spacingXs),
                              Text(
                                'เลือกโหมดการแสดงผลของแอป',
                                style: context.textStyles.bodySmallText.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  fontSize: isSmallScreen ? 11 : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? DesignTokens.spacingS : DesignTokens.spacingM),
                        DropdownButton<ThemeMode>(
                          key: const Key('theme_mode_dropdown'),
                          value: currentTheme,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down),
                          borderRadius: DesignTokens.borderRadiusMd,
                          style: context.textStyles.bodyStandard.copyWith(
                            color: context.colors.onSurface,
                            fontWeight: DesignTokens.fontWeightSemibold,
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
                SizedBox(height: isSmallScreen ? DesignTokens.spacingL : DesignTokens.spacingXl),
                Text(
                  'การสำรองข้อมูล',
                  style: context.textStyles.cardTitle.copyWith(
                    fontWeight: DesignTokens.fontWeightBold,
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
                SizedBox(height: isSmallScreen ? DesignTokens.spacingXs2 : DesignTokens.spacingM),
                _BackupCard(
                  title: 'ส่งออกข้อมูล',
                  description:
                      'บันทึกสำรองข้อมูลทั้งหมดเป็นไฟล์ JSON ที่สามารถนำเข้าได้ภายหลัง',
                  icon: Icons.download,
                  onPressed: _isProcessing ? null : _exportBackup,
                ),
                const SizedBox(height: DesignTokens.spacingS),
                _BackupCard(
                  title: 'นำเข้าข้อมูล',
                  description:
                      'แทนที่ข้อมูลปัจจุบันด้วยข้อมูลสำรองที่บันทึกไว้',
                  icon: Icons.upload,
                  onPressed: _isProcessing ? null : _importBackup,
                  dangerous: true,
                ),
                const SizedBox(height: DesignTokens.spacingS),
                _BackupCard(
                  title: 'ผสานข้อมูล',
                  description:
                      'เพิ่มข้อมูลสำรองไปยังข้อมูลปัจจุบัน (ไม่ลบข้อมูลเดิม)',
                  icon: Icons.merge,
                  onPressed: _isProcessing ? null : _mergeBackup,
                ),
                SizedBox(height: isSmallScreen ? DesignTokens.spacingL : DesignTokens.spacingXl),
                Text(
                  'ข้อมูล',
                  style: context.textStyles.cardTitle.copyWith(
                    fontWeight: DesignTokens.fontWeightBold,
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
                SizedBox(height: isSmallScreen ? DesignTokens.spacingXs2 : DesignTokens.spacingM),
                _BackupCard(
                  title: 'ลบข้อมูลทั้งหมด',
                  description:
                      'ลบข้อมูลลูกค้าและรายการทั้งหมด (ไม่สามารถย้อนกลับได้)',
                  icon: Icons.delete_forever,
                  onPressed: _isProcessing ? null : _clearAllData,
                  dangerous: true,
                ),
                if (kIsWeb) ...[
                  SizedBox(height: isSmallScreen ? DesignTokens.spacingL : DesignTokens.spacingXl),
                  Text(
                    'แอปพลิเคชันมือถือ',
                    style: context.textStyles.cardTitle.copyWith(
                      fontWeight: DesignTokens.fontWeightBold,
                      fontSize: isSmallScreen ? 18 : null,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? DesignTokens.spacingXs2 : DesignTokens.spacingM),
                  _BackupCard(
                    title: 'ดาวน์โหลด Android APK',
                    description:
                        'ดาวน์โหลดและติดตั้งแอปเนทีฟบนอุปกรณ์ Android เพื่อความลื่นไหลสูงสุด',
                    icon: Icons.android_outlined,
                    onPressed: _downloadApk,
                  ),
                ],
                const SizedBox(height: DesignTokens.spacingL),
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
    final isSmallScreen = context.screenWidth < 380;
    final isDarkMode = context.isDarkMode;

    final backgroundColor = dangerous
        ? context.colors.errorContainer.withOpacity(isDarkMode ? 0.2 : 0.15)
        : null;
    final foregroundColor = dangerous
        ? context.colors.error
        : context.colors.primary;

    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: DesignTokens.borderRadiusMd,
        side: BorderSide(
          color: dangerous
              ? context.colors.error.withOpacity(0.4)
              : context.colors.borderColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: isSmallScreen ? DesignTokens.paddingS : DesignTokens.paddingM,
        child: Row(
          children: [
            Icon(
              icon,
              color: foregroundColor,
              size: isSmallScreen ? DesignTokens.iconSizeMd : DesignTokens.iconSizeLg,
            ),
            SizedBox(width: isSmallScreen ? DesignTokens.spacingS : DesignTokens.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.titleMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: DesignTokens.fontWeightBold,
                      fontSize: isSmallScreen ? 14 : null,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacingXs),
                  Text(
                    description,
                    style: context.textStyles.bodySmallText.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontSize: isSmallScreen ? 11 : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: isSmallScreen ? DesignTokens.spacingXs2 : DesignTokens.spacingS),
            isSmallScreen
                ? IconButton(
                    onPressed: onPressed,
                    icon: const Icon(Icons.arrow_forward),
                    style: IconButton.styleFrom(
                      backgroundColor: foregroundColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  )
                : ElevatedButton.icon(
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
