import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loscheck/main.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // ignore: deprecated_member_use
    binding.window.physicalSizeTestValue = const Size(1200, 1600);
    // ignore: deprecated_member_use
    binding.window.devicePixelRatioTestValue = 1.0;
  });

  group('Integration Tests', () {
    testWidgets('app boots and displays home shell', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('Los Check'), findsOneWidget);
      expect(find.text('ค่ารอบ'), findsOneWidget);
      expect(find.text('ลูกค้า'), findsOneWidget);
    });

    testWidgets('navigates between tabs', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Initially on DashboardPage
      expect(find.text('ภาพรวม'), findsOneWidget);

      // Navigate to CustomerPage
      await tester.tap(find.text('ลูกค้า'));
      await tester.pumpAndSettle();

      expect(find.text('ข้อมูลลูกค้า'), findsOneWidget);
      expect(find.text('เพิ่มค่ารอบ'), findsNothing);

      // Navigate back to TripFeePage
      await tester.tap(find.text('ค่ารอบ'));
      await tester.pumpAndSettle();

      expect(find.text('เพิ่มค่ารอบ'), findsOneWidget);
      expect(find.text('ข้อมูลลูกค้า'), findsNothing);
    });

    testWidgets('complete trip record flow: add, edit, delete', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ค่ารอบ'));
      await tester.pumpAndSettle();

      // Add a trip record
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      expect(find.textContaining('5 รอบ x 5 บาทต่อบิล'), findsOneWidget);
      expect(find.text('25 บาท'), findsWidgets);

      // Edit the record
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '10');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      expect(find.textContaining('10 รอบ x 5 บาทต่อบิล'), findsOneWidget);
      expect(find.text('50 บาท'), findsWidgets);

      // Delete the record
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('10 รอบ x 5 บาทต่อบิล'), findsNothing);
    });

    testWidgets('complete customer record flow: add, edit, delete', (
      tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Navigate to CustomerPage
      await tester.tap(find.text('ลูกค้า'));
      await tester.pumpAndSettle();

      // Add a customer
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

      // Edit by tapping the tile
      await tester.tap(find.text('สมชาย'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'สมชาย ใหม่',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCustomerButton')));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย ใหม่'), findsOneWidget);

      // Delete
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย ใหม่'), findsNothing);
    });

    testWidgets('data persists across tab navigation', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ค่ารอบ'));
      await tester.pumpAndSettle();

      // Add trip record
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      expect(find.text('15 บาท'), findsWidgets);

      // Navigate to CustomerPage
      await tester.tap(find.text('ลูกค้า'));
      await tester.pumpAndSettle();

      // Navigate back to TripFeePage
      await tester.tap(find.text('ค่ารอบ'));
      await tester.pumpAndSettle();

      // Data should still be there
      expect(find.text('15 บาท'), findsWidgets);
    });

    testWidgets('theme switching works', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap theme button
      await tester.tap(find.byIcon(Icons.brightness_auto));
      await tester.pumpAndSettle();

      // Icon should change
      expect(find.byIcon(Icons.light_mode), findsOneWidget);

      // Tap again
      await tester.tap(find.byIcon(Icons.light_mode));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('clear today flow removes all today records', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ค่ารอบ'));
      await tester.pumpAndSettle();

      // Add multiple records
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ระยะทาง 301-500 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 รอบ x 5 บาทต่อบิล'), findsOneWidget);
      expect(find.textContaining('3 รอบ x 10 บาทต่อบิล'), findsOneWidget);

      // Clear today
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีรายการในวันนี้'), findsOneWidget);
    });

    testWidgets('customer search flow', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Navigate to CustomerPage
      await tester.tap(find.text('ลูกค้า'));
      await tester.pumpAndSettle();

      // Add multiple customers
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

      // Search
      await tester.enterText(
        find.byKey(const Key('customerPhoneFilterField')),
        '081',
      );
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.text('มานี'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.filter_alt_off_outlined));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.text('มานี'), findsOneWidget);
    });

    testWidgets('app handles empty states gracefully', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ค่ารอบ'));
      await tester.pumpAndSettle();

      // TripFeePage empty state
      expect(find.text('ยังไม่มีรายการในวันนี้'), findsOneWidget);

      // Navigate to CustomerPage
      await tester.tap(find.text('ลูกค้า'));
      await tester.pumpAndSettle();

      // CustomerPage empty state
      expect(find.text('ยังไม่มีข้อมูลลูกค้า'), findsOneWidget);
    });
  });
}
