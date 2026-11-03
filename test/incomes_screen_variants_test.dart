import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finance_tracker/providers/finance_provider.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/screens/incomes_screen_v1.dart';
import 'package:finance_tracker/screens/incomes_screen_v2.dart';

void main() {
  testWidgets('IncomesScreenV1 renders executive dashboard header and items', (WidgetTester tester) async {
    final provider = FinanceProvider();
    final wallet = Wallet(id: 'w-1', name: 'الخزينة');
    provider.addWallet(wallet);

    final income = Income(
      id: 'inc-test-1',
      title: 'بيع رمان بلدي',
      amount: 100000,
      date: DateTime.now(),
      source: 'مبيعات',
      walletId: wallet.id,
    );
    provider.addIncome(income);

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
    expect(find.text('بيع رمان بلدي'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
  });

  testWidgets('IncomesScreenV2 renders timeline & plot grouping view and items', (WidgetTester tester) async {
    final provider = FinanceProvider();
    final wallet = Wallet(id: 'w-1', name: 'الخزينة');
    provider.addWallet(wallet);

    final income = Income(
      id: 'inc-test-2',
      title: 'بيع محصول الذرة',
      amount: 50000,
      date: DateTime.now(),
      source: 'مبيعات',
      walletId: wallet.id,
    );
    provider.addIncome(income);

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
    expect(find.text('بيع محصول الذرة'), findsOneWidget);
    expect(find.text('تسجيل سداد'), findsOneWidget);
  });
}
