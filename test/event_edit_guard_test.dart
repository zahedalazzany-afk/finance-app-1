import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/providers/finance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final day = DateTime(2026, 1, 1);

  // محفظة + إيراد 1000 مستلم كاملاً في دفعة واحدة، وحدث فيه:
  // أجر نقدي مدفوع كاملاً (له سجل مالي) وأجر آجل بلا سجل مالي.
  Future<({FinanceProvider provider, Wallet wallet})> setupEvent() async {
    final provider = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 200));
    final wallet = Wallet(id: 'w-1', name: 'الخزينة');
    provider.addWallet(wallet);
    final income = Income(
      id: 'inc-1',
      title: 'إيراد',
      amount: 1000,
      date: day,
      source: 'مبيعات',
      walletId: wallet.id,
    );
    provider.addIncome(income);
    provider.addIncomePayment(IncomePayment(
      id: 'pay-1',
      incomeId: income.id,
      amount: 1000,
      date: day,
      walletId: wallet.id,
    ));

    final paid = Expense(
      id: 'w-paid',
      title: 'أجر',
      amount: 100,
      date: day,
      category: 'عمالة',
      eventId: 'ev-1',
      workerId: 'wk-1',
      paymentMethod: 'cash',
    );
    provider.addExpense(paid);
    provider.addExpensePayment(ExpensePayment(
      id: 'ep-1',
      expenseId: paid.id,
      amount: 100,
      date: day,
      walletId: wallet.id,
      funding: provider.allocateFromSpecificIncomePayment('pay-1', 100),
    ));

    provider.addExpense(Expense(
      id: 'w-unpaid',
      title: 'أجر آجل',
      amount: 50,
      date: day,
      category: 'عمالة',
      eventId: 'ev-1',
      workerId: 'wk-2',
      paymentMethod: 'debt',
    ));
    return (provider: provider, wallet: wallet);
  }

  EventLineSnapshot lockedLine({
    double amount = 100,
    String mode = 'cash',
    double paid = 100,
    String? workerId = 'wk-1',
    String dateKey = '2026-01-01',
  }) =>
      EventLineSnapshot(
        existingId: 'w-paid',
        isLabor: true,
        workerId: workerId,
        amount: amount,
        paymentMode: mode,
        paid: paid,
        dateKey: dateKey,
      );

  const unpaidLine = EventLineSnapshot(
    existingId: 'w-unpaid',
    isLabor: true,
    workerId: 'wk-2',
    amount: 50,
    paymentMode: 'debt',
    paid: 0,
    dateKey: '2026-01-01',
  );

  group('expenseHasFinancialHistory', () {
    test('المصروف المدفوع له سجل مالي والآجل بلا دفعات لا سجل له', () async {
      final s = await setupEvent();
      expect(s.provider.expenseHasFinancialHistory('w-paid'), isTrue);
      expect(s.provider.expenseHasFinancialHistory('w-unpaid'), isFalse);
    });

    test('المصروف الآجل الذي سُدِّد من دينه له سجل مالي', () async {
      final s = await setupEvent();
      s.provider.addExpense(Expense(
        id: 'e-debt',
        title: 'ديزل',
        amount: 80,
        date: day,
        category: 'وقود',
        eventId: 'ev-1',
        personId: 'sup-1',
        paymentMethod: 'debt',
      ));
      expect(s.provider.expenseHasFinancialHistory('e-debt'), isFalse);

      final debt =
          s.provider.personalDebts.firstWhere((d) => d.expenseId == 'e-debt');
      final ok = s.provider.addPersonalDebtSettlement(PersonalDebtSettlement(
        id: 'set-1',
        debtId: debt.id,
        amount: 20,
        date: day,
        walletId: s.wallet.id,
        funding: s.provider.allocateFromSpecificIncomePayment('pay-1', 20),
      ));
      expect(ok, isTrue);
      expect(s.provider.expenseHasFinancialHistory('e-debt'), isTrue);
    });
  });

  group('eventEditBlocker', () {
    test('حفظ دون تغيير السطر المحمي يمرّ', () async {
      final s = await setupEvent();
      expect(
        s.provider.eventEditBlocker('ev-1', [lockedLine(), unpaidLine]),
        isNull,
      );
    });

    test('تغيير مبلغ سطر محمي مرفوض', () async {
      final s = await setupEvent();
      expect(
        s.provider.eventEditBlocker('ev-1', [lockedLine(amount: 120), unpaidLine]),
        isNotNull,
      );
    });

    test('تغيير حالة الدفع لسطر محمي مرفوض', () async {
      final s = await setupEvent();
      expect(
        s.provider.eventEditBlocker(
            'ev-1', [lockedLine(mode: 'debt', paid: 0), unpaidLine]),
        isNotNull,
      );
    });

    test('تغيير العامل في سطر محمي مرفوض', () async {
      final s = await setupEvent();
      expect(
        s.provider.eventEditBlocker(
            'ev-1', [lockedLine(workerId: 'wk-9'), unpaidLine]),
        isNotNull,
      );
    });

    test('تغيير تاريخ اليوم لسطر محمي مرفوض', () async {
      final s = await setupEvent();
      expect(
        s.provider.eventEditBlocker(
            'ev-1', [lockedLine(dateKey: '2026-01-02'), unpaidLine]),
        isNotNull,
      );
    });

    test('حذف سطر محمي من النموذج مرفوض', () async {
      final s = await setupEvent();
      expect(s.provider.eventEditBlocker('ev-1', [unpaidLine]), isNotNull);
    });

    test('حذف سطر بلا سجل مالي مسموح', () async {
      final s = await setupEvent();
      expect(s.provider.eventEditBlocker('ev-1', [lockedLine()]), isNull);
    });

    test('سطر جديد مدفوع بلا تمويل مرفوض', () async {
      final s = await setupEvent();
      const newLine = EventLineSnapshot(
        isLabor: true,
        workerId: 'wk-3',
        amount: 30,
        paymentMode: 'cash',
        paid: 30,
        dateKey: '2026-01-01',
        walletId: 'w-1',
      );
      expect(
        s.provider.eventEditBlocker('ev-1', [lockedLine(), unpaidLine, newLine]),
        isNotNull,
      );
    });

    test('سطر جديد مدفوع بلا محفظة مرفوض', () async {
      final s = await setupEvent();
      final newLine = EventLineSnapshot(
        isLabor: true,
        workerId: 'wk-3',
        amount: 30,
        paymentMode: 'cash',
        paid: 30,
        dateKey: '2026-01-01',
        funding: s.provider.allocateFromSpecificIncomePayment('pay-1', 30),
      );
      expect(
        s.provider.eventEditBlocker('ev-1', [lockedLine(), unpaidLine, newLine]),
        isNotNull,
      );
    });

    test('سطر جديد مدفوع بتمويل صحيح يمرّ', () async {
      final s = await setupEvent();
      final newLine = EventLineSnapshot(
        isLabor: true,
        workerId: 'wk-3',
        amount: 30,
        paymentMode: 'cash',
        paid: 30,
        dateKey: '2026-01-01',
        walletId: 'w-1',
        funding: s.provider.allocateFromSpecificIncomePayment('pay-1', 30),
      );
      expect(
        s.provider.eventEditBlocker('ev-1', [lockedLine(), unpaidLine, newLine]),
        isNull,
      );
    });

    test('تمويل سطور جديدة يتجاوز المتاح مجتمعاً مرفوض', () async {
      final s = await setupEvent();
      // المتاح من الدفعة 900 بعد الأجر المدفوع، وكل سطر يطلب 500.
      EventLineSnapshot line(String worker) => EventLineSnapshot(
            isLabor: true,
            workerId: worker,
            amount: 500,
            paymentMode: 'cash',
            paid: 500,
            dateKey: '2026-01-01',
            walletId: 'w-1',
            funding: [
              ExpenseAllocation(
                  incomeId: 'inc-1', paymentId: 'pay-1', amount: 500),
            ],
          );
      expect(
        s.provider.eventEditBlocker(
            'ev-1', [lockedLine(), unpaidLine, line('wk-3'), line('wk-4')]),
        isNotNull,
      );
    });
  });

  group('eventExpenseDeletionBlocker', () {
    test('يمنع حذف مصروف له سجل مالي ويسمح بغيره', () async {
      final s = await setupEvent();
      expect(s.provider.eventExpenseDeletionBlocker(['w-unpaid']), isNull);
      expect(s.provider.eventExpenseDeletionBlocker(['w-paid']), isNotNull);
      expect(
        s.provider.eventExpenseDeletionBlocker(['w-unpaid', 'w-paid']),
        isNotNull,
      );
    });
  });
}
