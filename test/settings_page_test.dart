import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loscheck/database/hive_database.dart';
import 'package:loscheck/screens/settings_page.dart';
import 'package:loscheck/services/file_share_service.dart';

import 'test_helpers.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // ignore: deprecated_member_use
    binding.window.physicalSizeTestValue = const Size(1200, 1600);
    // ignore: deprecated_member_use
    binding.window.devicePixelRatioTestValue = 1.0;
    await configureTestPathProvider();
    await appDatabase.initialize();
    await appDatabase.deleteAllCustomers();
    await appDatabase.deleteAllTrips();

    // Mock clipboard
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });

    FileShareService.mockHandler = ({required filename, required content, required mimeType}) async {
      return;
    };
  });

  tearDown(() async {
    await appDatabase.deleteAllCustomers();
    await appDatabase.deleteAllTrips();
    FileShareService.mockHandler = null;
    // ignore: deprecated_member_use
    binding.window.clearPhysicalSizeTestValue();
    // ignore: deprecated_member_use
    binding.window.clearDevicePixelRatioTestValue();
  });

  testWidgets('renders SettingsPage with all options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsPage(),
        ),
      ),
    );

    // Verify Title
    expect(find.text('การตั้งค่า'), findsOneWidget);
    expect(find.text('การแสดงผล'), findsOneWidget);
    expect(find.text('ธีมแอปพลิเคชัน'), findsOneWidget);
    expect(find.byKey(const Key('theme_mode_dropdown')), findsOneWidget);
    expect(find.text('การสำรองข้อมูล'), findsOneWidget);

    // Verify Cards
    expect(find.text('ส่งออกข้อมูล'), findsOneWidget);
    expect(find.text('นำเข้าข้อมูล'), findsOneWidget);
    expect(find.text('ผสานข้อมูล'), findsOneWidget);
    expect(find.text('ลบข้อมูลทั้งหมด'), findsOneWidget);
  });

  testWidgets('export data shows success snackbar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsPage(),
        ),
      ),
    );

    // Tap Export Button
    final exportCard = find.ancestor(
      of: find.text('ส่งออกข้อมูล'),
      matching: find.byType(Card),
    );
    final goButton = find.descendant(
      of: exportCard,
      matching: find.text('ไป'),
    );

    await tester.tap(goButton);
    await pumpApp(tester);

    // Verify success snackbar appears
    expect(find.textContaining('ส่งออกข้อมูลสำรองเรียบร้อยแล้ว'), findsOneWidget);
  });

  testWidgets('clear all data opens confirmation dialog and completes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsPage(),
        ),
      ),
    );

    // Tap Delete Card button
    final deleteCard = find.ancestor(
      of: find.text('ลบข้อมูลทั้งหมด'),
      matching: find.byType(Card),
    );
    final goButton = find.descendant(
      of: deleteCard,
      matching: find.text('ไป'),
    );

    await tester.tap(goButton);
    await tester.pumpAndSettle();

    // Verify dialog shows
    expect(find.text('ลบข้อมูลทั้งหมด?'), findsOneWidget);
    expect(find.text('การกระทำนี้ไม่สามารถย้อนกลับได้'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    // Dialog should be gone
    expect(find.text('ลบข้อมูลทั้งหมด?'), findsNothing);

    // Tap Delete again
    await tester.tap(goButton);
    await tester.pumpAndSettle();

    // Tap Confirm delete
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    // Verify success snackbar appears
    expect(find.text('ลบข้อมูลทั้งหมดแล้ว'), findsOneWidget);
  });
}
