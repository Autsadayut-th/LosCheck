import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loscheck/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adds multiple trip fees and shows today total', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('ยอดรวมวันนี้'), findsOneWidget);
    expect(find.text('0 บาท'), findsOneWidget);

    await _addTrip(tester, '15 บาทต่อบิล • ระยะทาง 501 เมตร - 3 กิโลเมตร', '4');
    await _addTrip(tester, '5 บาทต่อบิล • ระยะทาง 0-300 เมตร', '2');

    expect(find.text('70 บาท'), findsWidgets);
    expect(find.text('รวม 6 รอบ'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('สรุปรายวัน'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.textContaining('4 รอบ x 15 บาทต่อบิล'), findsOneWidget);
    expect(find.textContaining('2 รอบ x 5 บาทต่อบิล'), findsOneWidget);
  });

  testWidgets('loads saved trip records and groups them by day', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final savedRecords = [
      jsonEncode({
        'distanceLabel': 'ระยะทาง 301-500 เมตร',
        'rateBaht': 10,
        'rounds': 3,
        'createdAt': now.toIso8601String(),
      }),
      jsonEncode({
        'distanceLabel': 'ระยะทาง มากกว่า 3 กิโลเมตร',
        'rateBaht': 25,
        'rounds': 2,
        'createdAt': yesterday.toIso8601String(),
      }),
    ];
    SharedPreferences.setMockInitialValues({'trip_records_v1': savedRecords});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('30 บาท'), findsWidgets);
    expect(find.text('รวม 3 รอบ'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('สรุปรายวัน'), findsOneWidget);
    expect(find.text('50 บาท'), findsOneWidget);
    expect(find.text(_formatDateForTest(yesterday)), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('ระยะทาง 301-500 เมตร'), findsOneWidget);
    expect(find.textContaining('3 รอบ x 10 บาทต่อบิล'), findsOneWidget);
  });

  testWidgets('saves customer phone name and address', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ลูกค้า'));
    await tester.pumpAndSettle();

    expect(find.text('ข้อมูลลูกค้า'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('customerPhoneField')),
      '0812345678',
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('customerNameField')), 'สมชาย');
    await tester.enterText(
      find.byKey(const Key('customerAddressField')),
      '123 ถนนสุขุมวิท กรุงเทพ',
    );
    await tester.tap(find.byKey(const Key('saveCustomerButton')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('สมชาย'), findsOneWidget);
    expect(find.text('0812345678\n123 ถนนสุขุมวิท กรุงเทพ'), findsOneWidget);
  });

  testWidgets('loads saved customer records from local storage', (
    WidgetTester tester,
  ) async {
    final savedRecord = jsonEncode({
      'phone': '0899999999',
      'name': 'มานี',
      'address': '45 ถนนสีลม',
      'createdAt': DateTime.now().toIso8601String(),
    });
    SharedPreferences.setMockInitialValues({
      'customer_records_v1': [savedRecord],
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ลูกค้า'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('มานี'), findsOneWidget);
    expect(find.textContaining('0899999999'), findsOneWidget);
    expect(find.textContaining('45 ถนนสีลม'), findsOneWidget);
  });

  testWidgets('filters saved customer records by phone number', (
    WidgetTester tester,
  ) async {
    final savedRecords = [
      jsonEncode({
        'phone': '0812345678',
        'name': 'สมชาย',
        'address': '123 ถนนสุขุมวิท',
        'createdAt': DateTime.now().toIso8601String(),
      }),
      jsonEncode({
        'phone': '0899999999',
        'name': 'มานี',
        'address': '45 ถนนสีลม',
        'createdAt': DateTime.now().toIso8601String(),
      }),
    ];
    SharedPreferences.setMockInitialValues({
      'customer_records_v1': savedRecords,
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ลูกค้า'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customerPhoneFilterField')),
      '1234',
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();

    expect(find.text('สมชาย'), findsOneWidget);
    expect(find.text('มานี'), findsNothing);
  });

  testWidgets('shows validation when rounds are invalid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('10 บาทต่อบิล • ระยะทาง 301-500 เมตร'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณาใส่จำนวนรอบเป็นตัวเลขมากกว่า 0'), findsOneWidget);
  });
}

Future<void> _addTrip(
  WidgetTester tester,
  String optionLabel,
  String rounds,
) async {
  await tester.tap(find.text(optionLabel));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), rounds);
  await tester.tap(find.text('ตกลง'));
  await tester.pumpAndSettle();
}

String _formatDateForTest(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
