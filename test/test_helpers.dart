import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loscheck/database/hive_database.dart';
import 'package:google_fonts/google_fonts.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Future<void> configureTestPathProvider() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  HiveDatabase.isTesting = true;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        final directory = Directory.systemTemp.createTempSync('loscheck_test_');

        return switch (call.method) {
          'getApplicationDocumentsDirectory' => directory.path,
          'getApplicationSupportDirectory' => directory.path,
          'getTemporaryDirectory' => directory.path,
          _ => null,
        };
      });
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Unmounts the app and drains async timers left by Isar streams or debounce.
Future<void> disposeAppTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// Clears all active SnackBars to prevent them from obscuring buttons like FABs in tests.
Future<void> clearSnackBars(WidgetTester tester) async {
  try {
    final context = tester.element(find.byType(Navigator).first);
    ScaffoldMessenger.of(context).clearSnackBars();
    await tester.pumpAndSettle();
  } catch (_) {}
}
