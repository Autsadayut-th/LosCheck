import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Future<void> configureTestPathProvider() async {
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
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// Unmounts the app and drains async timers left by Drift streams or debounce.
Future<void> disposeAppTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}
