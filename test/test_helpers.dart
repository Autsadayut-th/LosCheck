import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unmounts the app and drains async timers left by Drift streams or debounce.
Future<void> disposeAppTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}
