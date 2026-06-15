import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loscheck/database/hive_database.dart';
import 'package:loscheck/models/customer_record.dart';
import 'package:loscheck/screens/route_planning_page.dart';

import 'test_helpers.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutePlanningPage Widget Tests', () {
    setUp(() async {
      // Set test window size
      // ignore: deprecated_member_use
      binding.window.physicalSizeTestValue = const Size(1200, 1600);
      // ignore: deprecated_member_use
      binding.window.devicePixelRatioTestValue = 1.0;
      await configureTestPathProvider();
      await appDatabase.initialize();
      await appDatabase.deleteAllCustomers();
      await appDatabase.deleteAllTrips();
    });

    tearDown(() async {
      await appDatabase.deleteAllCustomers();
      await appDatabase.deleteAllTrips();
      // ignore: deprecated_member_use
      binding.window.clearPhysicalSizeTestValue();
      // ignore: deprecated_member_use
      binding.window.clearDevicePixelRatioTestValue();
    });

    testWidgets('displays loading skeleton initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutePlanningPage())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays setup screen after loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutePlanningPage())),
      );
      await pumpApp(tester);

      expect(find.text('วางแผนเส้นทางนำทาง'), findsOneWidget);
      expect(find.text('จุดเริ่มต้นเดินทาง (ตำแหน่งของคุณ)'), findsOneWidget);
      expect(find.text('เลือกลูกค้าจัดส่ง'), findsOneWidget);
      expect(find.text('เริ่มนำทาง (0 จุด)'), findsOneWidget);
    });

    testWidgets('displays customers list and allows selection and starting navigation', (tester) async {
      // Insert test customers
      final now = DateTime.now();
      await appDatabase.insertCustomer(CustomerRecord(
        phone: '0812345678',
        name: 'สมชาย',
        address: '123 สุขุมวิท',
        createdAt: now,
        latitude: 13.7563,
        longitude: 100.5018,
      ));
      await appDatabase.insertCustomer(CustomerRecord(
        phone: '0898765432',
        name: 'มานี',
        address: '456 สีลม',
        createdAt: now,
        latitude: 13.7263,
        longitude: 100.5218,
      ));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutePlanningPage())),
      );
      await pumpApp(tester);

      // Verify customers are rendered
      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.text('มานี'), findsOneWidget);

      // Select both customers (tap checkboxes)
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsNWidgets(2));
      
      await tester.tap(checkboxFinder.at(0));
      await tester.pumpAndSettle();
      await tester.tap(checkboxFinder.at(1));
      await tester.pumpAndSettle();

      // Verify "เริ่มนำทาง (2 จุด)" button is enabled
      expect(find.text('เริ่มนำทาง (2 จุด)'), findsOneWidget);

      // Start navigation
      await tester.tap(find.text('เริ่มนำทาง (2 จุด)'));
      await tester.pumpAndSettle();

      // Verify navigation screen is loaded
      expect(find.text('คิวเส้นทางจัดส่ง'), findsOneWidget);
      expect(find.text('จุดหมายที่ 0 / 2'), findsOneWidget);
      expect(find.text('จุดหมายปัจจุบัน (Active)'), findsOneWidget);
      expect(find.byKey(const Key('jobCompletedButton')), findsOneWidget);
      
      // Tap job completed for the first customer
      await tester.tap(find.byKey(const Key('jobCompletedButton')));
      await tester.pumpAndSettle();

      // Verify progress updated
      expect(find.text('จุดหมายที่ 1 / 2'), findsOneWidget);

      // Tap job completed for the second customer
      await tester.tap(find.byKey(const Key('jobCompletedButton')));
      await tester.pumpAndSettle();

      // Verify completion screen
      expect(find.text('ยินดีด้วย!'), findsOneWidget);
      expect(find.text('คุณเดินทางเสร็จสิ้นครบทุกจุดหมายเรียบร้อยแล้ว'), findsOneWidget);
      expect(find.text('กลับหน้าวางแผนใหม่'), findsOneWidget);

      // Reset
      await tester.tap(find.text('กลับหน้าวางแผนใหม่'));
      await tester.pumpAndSettle();

      // Should be back to setup screen
      expect(find.text('วางแผนเส้นทางนำทาง'), findsOneWidget);
    });

    testWidgets('respects search filter on setup screen', (tester) async {
      final now = DateTime.now();
      await appDatabase.insertCustomer(CustomerRecord(
        phone: '0812345678',
        name: 'สมชาย',
        address: '123 สุขุมวิท',
        createdAt: now,
        latitude: 13.7563,
        longitude: 100.5018,
      ));
      await appDatabase.insertCustomer(CustomerRecord(
        phone: '0898765432',
        name: 'มานี',
        address: '456 สีลม',
        createdAt: now,
        latitude: 13.7263,
        longitude: 100.5218,
      ));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoutePlanningPage())),
      );
      await pumpApp(tester);

      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.text('มานี'), findsOneWidget);

      // Search for 'มานี'
      await tester.enterText(find.byType(TextField).at(2), 'มานี');
      await tester.pump();

      expect(find.text('สมชาย'), findsNothing);
      expect(find.text('มานี'), findsNWidgets(2)); // One in search text field, one in the customer tile
    });
  });
}
