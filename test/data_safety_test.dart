import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/providers/finance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<FinanceProvider> newProvider() async {
    final provider = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 300));
    return provider;
  }

  group('H5: ترحيل الديون بمعرّفات حتمية', () {
    test('دين مستلم بمحفظة ينشئ حركة واحدة بمعرّف حتمي ولا تتكرر عند إعادة التحميل',
        () async {
      final debt = PersonalDebt(
        id: 'd-b',
        personId: 'p-1',
        direction: 'payable',
        amount: 300,
        date: DateTime(2026, 1, 1),
        walletId: 'w-1',
      );
      SharedPreferences.setMockInitialValues({
        'wallets': json.encode([Wallet(id: 'w-1', name: 'الخزينة').toJson()]),
        'personalDebts': json.encode([debt.toJson()]),
      });
      final provider = await newProvider();

      var movements =
          provider.moneyMovements.where((m) => m.debtId == 'd-b').toList();
      expect(movements.length, 1);
      expect(movements.first.id, 'mov_borrow_d-b');
      expect(movements.first.amount, -300);

      await provider.reloadData(syncFromCloud: false);
      movements =
          provider.moneyMovements.where((m) => m.debtId == 'd-b').toList();
      expect(movements.length, 1);
    });
  });

  group('H7: التحميل الآمن', () {
    test('مفتاح تالف لا يوقف التحميل وتُحفظ نسخته الخام', () async {
      final income = Income(
        id: 'inc-1',
        title: 'إيراد',
        amount: 100,
        date: DateTime(2026, 1, 1),
        source: 'مبيعات',
      );
      const brokenExpenses = '{هذا ليس JSON صالحاً';
      SharedPreferences.setMockInitialValues({
        'expenses': brokenExpenses,
        'incomes': json.encode([income.toJson()]),
        'wallets': '{"a": 1}', // ليس قائمة
      });
      final provider = await newProvider();

      // التحميل استمر بعد المفتاح التالف.
      expect(provider.incomes.length, 1);
      expect(provider.loadErrors, containsAll(['expenses', 'wallets']));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('corrupt_backup_expenses'), brokenExpenses);
      expect(prefs.getString('corrupt_backup_wallets'), '{"a": 1}');
    });

    test('تحميل سليم لا يسجل أي خطأ', () async {
      final provider = await newProvider();
      expect(provider.loadErrors, isEmpty);
    });
  });

  group('H6: سقف دفعات الزكاة', () {
    Future<FinanceProvider> setupZakat() async {
      final provider = await newProvider();
      provider.addWallet(Wallet(id: 'w-1', name: 'الخزينة'));
      provider.addManualZakatEntry(ZakatEntry(
          id: 'z-1', title: 'زكاة 1', date: DateTime(2026, 1, 1), amount: 100));
      provider.addManualZakatEntry(ZakatEntry(
          id: 'z-2', title: 'زكاة 2', date: DateTime(2026, 1, 1), amount: 100));
      return provider;
    }

    ZakatPayment pay(String id, String entryId, double amount) => ZakatPayment(
          id: id,
          zakatEntryId: entryId,
          amount: amount,
          date: DateTime(2026, 1, 2),
          walletId: 'w-1',
        );

    test('الإضافة تُرفض إذا تجاوز المجموع المستحق', () async {
      final provider = await setupZakat();
      expect(() => provider.addZakatPayment(pay('zp-1', 'z-1', 150)),
          throwsException);
      expect(() => provider.addZakatPayment(pay('zp-2', 'z-1', 60)),
          returnsNormally);
      expect(() => provider.addZakatPayment(pay('zp-3', 'z-1', 50)),
          throwsException);
      expect(() => provider.addZakatPayment(pay('zp-4', 'z-1', 40)),
          returnsNormally);
    });

    test('دفعات استحقاق لا تُحتسب على استحقاق آخر', () async {
      final provider = await setupZakat();
      provider.addZakatPayment(pay('zp-1', 'z-1', 100));
      expect(() => provider.addZakatPayment(pay('zp-2', 'z-2', 100)),
          returnsNormally);
    });

    test('تعديل دفعة لا يحتسب دفعات استحقاق آخر', () async {
      final provider = await setupZakat();
      provider.addZakatPayment(pay('zp-1', 'z-1', 100));
      provider.addZakatPayment(pay('zp-2', 'z-2', 50));
      expect(() => provider.updateZakatPayment(pay('zp-2', 'z-2', 100)),
          returnsNormally);
      expect(() => provider.updateZakatPayment(pay('zp-2', 'z-2', 120)),
          throwsException);
    });
  });
}
