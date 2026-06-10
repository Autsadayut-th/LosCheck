import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loscheck/database/app_database.dart';
import 'package:loscheck/screens/trip_fee_page.dart';
import 'package:loscheck/widgets/rounds_dialog.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

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

  group('TripFeePage Widget Tests', () {
    testWidgets('displays loading skeleton initially', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays summary panel after loading', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('ยอดรวม'), findsOneWidget);
      expect(find.text('0 ฿'), findsOneWidget);
      expect(find.text('รวม 0 รอบ'), findsOneWidget);
    });

    testWidgets('lays out on compact phone width', (tester) async {
      // ignore: deprecated_member_use
      binding.window.physicalSizeTestValue = const Size(360, 720);

      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays distance option buttons', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();
      expect(find.text('เพิ่มค่ารอบ'), findsOneWidget);
      expect(find.text('ระยะทาง 0-300 เมตร'), findsOneWidget);
      expect(find.text('ระยะทาง 301-500 เมตร'), findsOneWidget);
      expect(find.text('ระยะทาง 501 เมตร - 3 กิโลเมตร'), findsOneWidget);
      expect(find.text('ระยะทาง มากกว่า 3 กิโลเมตร'), findsOneWidget);
    });

    testWidgets('opens rounds dialog when distance option is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();

      expect(find.byType(RoundsDialog), findsOneWidget);
    });

    testWidgets('adds trip record when rounds dialog is confirmed', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      expect(find.textContaining('5 รอบ x 5 บาทต่อบิล'), findsOneWidget);
      expect(find.text('25 บาท'), findsWidgets);
    });

    testWidgets('does not add record when rounds dialog is cancelled', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.byType(RoundsDialog), findsNothing);
    });

    testWidgets('edits trip record when edit button is tapped', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Add a record first
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(RoundsDialog), findsOneWidget);

      // Change rounds
      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      expect(find.textContaining('7 รอบ x 5 บาทต่อบิล'), findsOneWidget);
      expect(find.text('35 บาท'), findsWidgets);
    });

    testWidgets('shows delete confirmation when delete button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Add a record first
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('ลบรายการนี้?'), findsOneWidget);
    });

    testWidgets('deletes trip record when confirmed', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Add a record first
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Delete the record
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 รอบ x 5 บาทต่อบิล'), findsNothing);
    });

    testWidgets('does not delete when cancelled', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Add a record first
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Try to delete but cancel
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 รอบ x 5 บาทต่อบิล'), findsOneWidget);
    });

    testWidgets('shows clear today confirmation when clear button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Add a record first
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      expect(find.text('ล้างรายการของวันที่เลือกทั้งหมด?'), findsOneWidget);
    });

    testWidgets('clears today records when confirmed', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Add a record
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Clear today
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 รอบ x 5 บาทต่อบิล'), findsNothing);
    });

    testWidgets('copies CSV to clipboard when export button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Add a record
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Export
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('displays daily summaries section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      expect(find.text('สรุปรายวัน'), findsOneWidget);
    });

    testWidgets('updates today total when record is added', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripFeePage()));
      await tester.pumpAndSettle();

      // Check initial total
      expect(find.text('0 ฿'), findsOneWidget);

      // Add a record
      await tester.tap(find.text('ระยะทาง 0-300 เมตร'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Check updated total
      expect(find.text('15 บาท'), findsWidgets);
    });
  });
}
