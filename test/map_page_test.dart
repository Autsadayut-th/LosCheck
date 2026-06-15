import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:loscheck/database/hive_database.dart';
import 'package:loscheck/models/customer_record.dart';
import 'package:loscheck/screens/map_page.dart';
import 'package:loscheck/providers/app_state_provider.dart';

import 'test_helpers.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('MapPage Widget Tests', () {
    setUp(() async {
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

    testWidgets('displays map page layout and search bar', (tester) async {
      final now = DateTime.now();
      await appDatabase.insertCustomer(CustomerRecord(
        phone: '0812345678',
        name: 'สมชาย',
        address: '123 สุขุมวิท',
        createdAt: now,
        latitude: 13.7563,
        longitude: 100.5018,
      ));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(),
          child: const MaterialApp(home: Scaffold(body: MapPage())),
        ),
      );
      await pumpApp(tester);

      // Verify page components exist
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('ค้นหาชื่อลูกค้า...'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('searches for customer and centers map', (tester) async {
      final now = DateTime.now();
      await appDatabase.insertCustomer(CustomerRecord(
        phone: '0812345678',
        name: 'สมชาย',
        address: '123 สุขุมวิท',
        createdAt: now,
        latitude: 13.7563,
        longitude: 100.5018,
      ));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(),
          child: const MaterialApp(home: Scaffold(body: MapPage())),
        ),
      );
      await pumpApp(tester);

      // Search for 'สมชาย'
      await tester.enterText(find.byType(TextField), 'สมชาย');
      await tester.pump();

      // Verify dropdown option appears
      expect(find.text('สมชาย'), findsWidgets);

      // Tap on the result ListTile in the search dropdown
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Verify customer details are displayed (e.g. bottom sheet details)
      expect(find.text('เบอร์โทร: 0812345678'), findsOneWidget);
      expect(find.text('ที่อยู่: 123 สุขุมวิท'), findsOneWidget);
    });
  });
}
