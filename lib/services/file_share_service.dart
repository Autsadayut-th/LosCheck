import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class FileShareService {
  FileShareService._();

  /// A mock handler hook for unit/widget tests to stub sharing without channel calls.
  @visibleForTesting
  static Future<void> Function({
    required String filename,
    required String content,
    required String mimeType,
  })? mockHandler;

  /// Share text content as a file on mobile, or download it on web.
  static Future<void> shareOrDownloadText({
    required String filename,
    required String content,
    required String mimeType,
  }) async {
    if (mockHandler != null) {
      await mockHandler!(
        filename: filename,
        content: content,
        mimeType: mimeType,
      );
      return;
    }
    if (kIsWeb) {
      // For web, use a data URI to prompt download
      final bytes = utf8.encode(content);
      final base64Data = base64Encode(bytes);
      final url = 'data:$mimeType;base64,$base64Data';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch download URL on Web');
      }
    } else {
      // For mobile / native, write to a temporary file and share
      final tempDir = await getTemporaryDirectory();
      final file = io.File('${tempDir.path}/$filename');
      await file.writeAsString(content, flush: true);

      final xFile = XFile(file.path, mimeType: mimeType, name: filename);
      await Share.shareXFiles([xFile], text: filename);
    }
  }
}
