import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finance_app/providers/finance_provider.dart';
import 'package:finance_app/screens/incomes_screen_v1.dart';
import 'package:finance_app/screens/incomes_screen_v2.dart';

void main() {
  testWidgets('IncomesScreenV1 renders executive dashboard header', (WidgetTester tester) async {
    final provider = FinanceProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: IncomesScreenV1(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('إيرادات 1 - اللوحة المتقدمة'), findsOneWidget);
    expect(find.text('تصميم إيرادات ١'), findsOneWidget);
    expect(find.text('التقرير التنفيذي الشامل'), findsOneWidget);
  });

  testWidgets('IncomesScreenV2 renders timeline & plot grouping view', (WidgetTester tester) async {
    final provider = FinanceProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: IncomesScreenV2(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('إيرادات 2 - الدفتر الزمني والأراضي'), findsOneWidget);
    expect(find.text('تصميم إيرادات ٢'), findsOneWidget);
    expect(find.text('الدفتر الزمني'), findsOneWidget);
    expect(find.text('حسب الأرض والموضِع'), findsOneWidget);
  });
}
