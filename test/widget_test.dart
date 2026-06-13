import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loscheck/database/isar_database.dart';
import 'package:loscheck/main.dart';

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
  });

  tearDown(() async {
    await appDatabase.deleteAllCustomers();
    await appDatabase.deleteAllTrips();
  });

  testWidgets('adds multiple trip fees and shows today total', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await pumpApp(tester);

    await tester.tap(find.text('ค่ารอบ'));
    await pumpApp(tester);

    expect(find.textContaining('ยอดรวม'), findsOneWidget);
    expect(find.text('0 ฿'), findsOneWidget);

    await _addTrip(tester, 'ระยะทาง 501 เมตร - 3 กิโลเมตร', '4');
    await _addTrip(tester, 'ระยะทาง 0-300 เมตร', '2');

    expect(find.text('70 ฿'), findsOneWidget);
    expect(find.text('รวม 6 รอบ'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
    await pumpApp(tester);

    expect(find.text('สรุปรายวัน'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await pumpApp(tester);

    expect(find.textContaining('4 รอบ x 15 บาทต่อบิล'), findsOneWidget);
    expect(find.textContaining('2 รอบ x 5 บาทต่อบิล'), findsOneWidget);
  });

  testWidgets('loads saved trip records and groups them by day', (
    WidgetTester tester,
  ) async {
    // TODO: Implement Drift database loading test
    await tester.pumpWidget(const MyApp());
    await pumpApp(tester);
    await disposeAppTree(tester);
  });

  testWidgets('saves customer phone name and address', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await pumpApp(tester);

    await tester.tap(find.text('ลูกค้า'));
    await pumpApp(tester);

    expect(find.text('ข้อมูลลูกค้า'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('customerPhoneField')),
      '0812345678',
    );
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('customerNameField')), 'สมชาย');
    await tester.enterText(
      find.byKey(const Key('customerAddressField')),
      '123 ถนนสุขุมวิท กรุงเทพ',
    );
    await tester.tap(find.byKey(const Key('saveCustomerButton')));
    await pumpApp(tester);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await pumpApp(tester);

    expect(find.text('สมชาย'), findsOneWidget);
    expect(find.text('0812345678\n123 ถนนสุขุมวิท กรุงเทพ'), findsOneWidget);
  });

  testWidgets('loads saved customer records from local storage', (
    WidgetTester tester,
  ) async {
    // TODO: Implement Drift database loading test
    await tester.pumpWidget(const MyApp());
    await pumpApp(tester);
    await disposeAppTree(tester);
  });

  testWidgets('filters saved customer records by phone number', (
    WidgetTester tester,
  ) async {
    // TODO: Implement Drift database loading test
    await tester.pumpWidget(const MyApp());
    await pumpApp(tester);
    await disposeAppTree(tester);
  });

  testWidgets('shows validation when rounds are invalid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await pumpApp(tester);

    await tester.tap(find.text('ค่ารอบ'));
    await pumpApp(tester);

    await tester.tap(find.text('ระยะทาง 301-500 เมตร'));
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('ตกลง'));
    await pumpApp(tester);

    expect(find.text('กรุณาใส่จำนวนรอบเป็นตัวเลขมากกว่า 0'), findsOneWidget);
  });
}

Future<void> _addTrip(
  WidgetTester tester,
  String optionLabel,
  String rounds,
) async {
  await tester.tap(find.text(optionLabel));
  await pumpApp(tester);

  await tester.enterText(find.byType(TextField), rounds);
  await tester.tap(find.text('ตกลง'));
  await pumpApp(tester);
}
