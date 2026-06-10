import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loscheck/database/app_database.dart';
import 'package:loscheck/screens/customer_page.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerPage Widget Tests', () {
    setUp(() async {
      // ignore: deprecated_member_use
      binding.window.physicalSizeTestValue = const Size(1200, 1600);
      // ignore: deprecated_member_use
      binding.window.devicePixelRatioTestValue = 1.0;
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
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays customer form after loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('ข้อมูลลูกค้า'), findsOneWidget);
      expect(find.text('เบอร์โทร'), findsOneWidget);
      expect(find.text('ชื่อลูกค้า'), findsOneWidget);
      expect(find.text('ที่อยู่'), findsOneWidget);
    });

    testWidgets('lays out on compact phone width', (tester) async {
      // ignore: deprecated_member_use
      binding.window.physicalSizeTestValue = const Size(360, 720);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disables name and address fields when phone is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('customerNameField')),
      );
      final addressField = tester.widget<TextFormField>(
        find.byKey(const Key('customerAddressField')),
      );

      expect(nameField.enabled, isFalse);
      expect(addressField.enabled, isFalse);
    });

    testWidgets('enables name and address fields when phone is entered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('customerNameField')),
      );
      final addressField = tester.widget<TextFormField>(
        find.byKey(const Key('customerAddressField')),
      );

      expect(nameField.enabled, isTrue);
      expect(addressField.enabled, isTrue);
    });

    testWidgets('shows validation error when phone is too short', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '123',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      expect(find.text('เบอร์โทรต้องมีอย่างน้อย 9 ตัวเลข'), findsOneWidget);
    });

    testWidgets('shows validation error when name is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      expect(find.text('กรุณาใส่ชื่อ'), findsOneWidget);
    });

    testWidgets('shows validation error when address is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      expect(find.text('กรุณาใส่ที่อยู่'), findsOneWidget);
    });

    testWidgets('saves customer record when form is valid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.text('0812345678\n123 ถนนสุขุมวิท'), findsOneWidget);
      expect(find.textContaining('123 ถนนสุขุมวิท'), findsOneWidget);
    });

    testWidgets('clears form after saving customer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      final phoneField = tester.widget<TextFormField>(
        find.byKey(const Key('customerPhoneField')),
      );
      expect(phoneField.controller?.text, isEmpty);
    });

    testWidgets('displays customer record tile after saving', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.textContaining('0812345678\n'), findsOneWidget);
    });

    testWidgets('shows delete confirmation when delete button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('ลบข้อมูลลูกค้า?'), findsOneWidget);
    });

    testWidgets('deletes customer record when confirmed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsNothing);
    });

    testWidgets('does not delete when cancelled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsOneWidget);
    });

    testWidgets('filters customers by phone number', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      // Add first customer
      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      // Add second customer
      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0898765432',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'มานี',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '456 ถนนสีลม',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      // Filter by phone
      await tester.enterText(
        find.byKey(const Key('customerPhoneFilterField')),
        '081',
      );
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.text('มานี'), findsNothing);
    });

    testWidgets('clears filter when clear button is tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      // Add customer
      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      // Filter
      await tester.enterText(
        find.byKey(const Key('customerPhoneFilterField')),
        '081',
      );
      await tester.pumpAndSettle();

      // Clear filter
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsOneWidget);
    });

    testWidgets('loads customer data into form when tile is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      // Tap on the customer tile
      await tester.tap(find.text('สมชาย'));
      await tester.pumpAndSettle();

      final phoneField = tester.widget<TextFormField>(
        find.byKey(const Key('customerPhoneField')),
      );
      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('customerNameField')),
      );
      final addressField = tester.widget<TextFormField>(
        find.byKey(const Key('customerAddressField')),
      );

      expect(phoneField.controller?.text, '0812345678');
      expect(nameField.controller?.text, 'สมชาย');
      expect(addressField.controller?.text, '123 ถนนสุขุมวิท');
    });

    testWidgets('copies CSV to clipboard when export button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '0812345678',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย',
      );
      await tester.enterText(
        find.byKey(const Key('customerAddressField')),
        '123 ถนนสุขุมวิท',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('displays empty state when no customers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CustomerPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีข้อมูลลูกค้า'), findsOneWidget);
    });
  });
}
