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
    await Future.delayed(const Duration(milliseconds: 200));
    return provider;
  }

  // محفظة + إيراد بمبلغ [amount] + دفعة مستلمة بمبلغ [received].
  Future<({FinanceProvider provider, Wallet wallet, Income income, IncomePayment payment})>
      setupIncome({double amount = 1000, double received = 600}) async {
    final provider = await newProvider();
    final wallet = Wallet(id: 'w-1', name: 'الخزينة');
    provider.addWallet(wallet);
    final income = Income(
      id: 'inc-1',
      title: 'إيراد',
      amount: amount,
      date: DateTime.now(),
      source: 'مبيعات',
      walletId: wallet.id,
    );
    provider.addIncome(income);
    final payment = IncomePayment(
      id: 'pay-1',
      incomeId: income.id,
      amount: received,
      date: DateTime.now(),
      walletId: wallet.id,
    );
    provider.addIncomePayment(payment);
    return (provider: provider, wallet: wallet, income: income, payment: payment);
  }

  group('تعديل الإيراد', () {
    test('يُرفض خفض المبلغ تحت المستلم', () async {
      final s = await setupIncome(amount: 1000, received: 600);
      s.income.amount = 500;
      expect(() => s.provider.updateIncome(s.income), throwsException);
    });

    test('رفع مبلغ إيراد مكتمل يعيده معلّقاً مع متبقٍ للتحصيل', () async {
      final s = await setupIncome(amount: 1000, received: 1000);
      expect(s.income.status, 'confirmed');

      s.income.amount = 1200;
      s.provider.updateIncome(s.income);

      expect(s.income.status, 'pending');
      expect(s.income.remainingAmount, 200);
    });

    test('خفض المبلغ إلى المستلم بالضبط يجعل الإيراد مكتملاً', () async {
      final s = await setupIncome(amount: 1000, received: 600);
      expect(s.income.status, 'pending');

      s.income.amount = 600;
      s.provider.updateIncome(s.income);

      expect(s.income.status, 'confirmed');
    });
  });

  group('تعديل المصروف', () {
    test('يُرفض خفض مصروف مدفوع تحت المدفوع', () async {
      final s = await setupIncome(amount: 500, received: 500);
      final expense = Expense(
        id: 'e-1',
        title: 'صيانة',
        amount: 100,
        date: DateTime.now(),
        category: 'صيانة',
        paymentMethod: 'cash',
      );
      s.provider.addExpense(expense);
      s.provider.addExpensePayment(ExpensePayment(
        id: 'ep-1',
        expenseId: expense.id,
        amount: 80,
        date: DateTime.now(),
        walletId: s.wallet.id,
        funding: [
          ExpenseAllocation(
            incomeId: s.income.id,
            paymentId: s.payment.id,
            amount: 80,
          ),
        ],
      ));

      expense.amount = 50;
      expect(() => s.provider.updateExpense(expense), throwsException);

      expense.amount = 80;
      expect(() => s.provider.updateExpense(expense), returnsNormally);
    });

    // مصروف آجل على مورد 150، سُدِّد منه 50 عبر تسوية دين.
    Future<({FinanceProvider provider, Expense expense})> setupSettledDebtExpense() async {
      final s = await setupIncome(amount: 500, received: 500);
      final supplier = Partner(id: 'sup-1', name: 'مورد', roles: ['supplier']);
      s.provider.addPartner(supplier);
      final expense = Expense(
        id: 'e-debt',
        title: 'ديزل',
        amount: 150,
        date: DateTime.now(),
        category: 'وقود',
        personId: supplier.id,
        paymentMethod: 'debt',
      );
      s.provider.addExpense(expense);
      final debt = s.provider.personalDebts
          .firstWhere((d) => d.expenseId == expense.id);
      final ok = s.provider.addPersonalDebtSettlement(PersonalDebtSettlement(
        id: 'set-1',
        debtId: debt.id,
        amount: 50,
        date: DateTime.now(),
        walletId: s.wallet.id,
        funding: s.provider.allocateFromSpecificIncomePayment(s.payment.id, 50),
      ));
      expect(ok, isTrue);
      return (provider: s.provider, expense: expense);
    }

    test('يُرفض خفض مصروف آجل تحت ما سُدِّد من دينه', () async {
      final s = await setupSettledDebtExpense();
      s.expense.amount = 40;
      expect(() => s.provider.updateExpense(s.expense), throwsException);
    });

    test('يُرفض تحويل مصروف آجل سُدِّد منه شيء إلى نقدي', () async {
      final s = await setupSettledDebtExpense();
      s.expense
        ..paymentMethod = 'cash'
        ..personId = null;
      expect(() => s.provider.updateExpense(s.expense), throwsException);
    });

    test('تعديل مصروف آجل مسدَّد جزئياً دون تغيير الأساس يمر', () async {
      final s = await setupSettledDebtExpense();
      s.expense.title = 'ديزل - تعديل';
      expect(() => s.provider.updateExpense(s.expense), returnsNormally);
    });
  });

  group('C2: دين واحد لكل مصروف آجل', () {
    test('addExpense ينشئ دينًا واحدًا يحمل معرّف الحدث', () async {
      final provider = await newProvider();
      final expense = Expense(
        id: 'e-1',
        title: 'ديزل',
        amount: 40,
        date: DateTime.now(),
        category: 'وقود',
        eventId: 'ev-1',
        personId: 'sup-1',
        paymentMethod: 'debt',
      );
      provider.addExpense(expense);

      final debts =
          provider.personalDebts.where((d) => d.expenseId == expense.id).toList();
      expect(debts.length, 1);
      expect(debts.first.eventId, 'ev-1');
      expect(debts.first.amount, 40);
    });

    test('addPersonalDebt يرفض دينًا ثانيًا لنفس المصروف', () async {
      final provider = await newProvider();
      final expense = Expense(
        id: 'e-1',
        title: 'ديزل',
        amount: 40,
        date: DateTime.now(),
        category: 'وقود',
        personId: 'sup-1',
        paymentMethod: 'debt',
      );
      provider.addExpense(expense);

      final added = provider.addPersonalDebt(PersonalDebt(
        id: 'd-dup',
        personId: 'sup-1',
        direction: 'payable',
        amount: 40,
        date: DateTime.now(),
        expenseId: expense.id,
      ));

      expect(added, isFalse);
      expect(
        provider.personalDebts.where((d) => d.expenseId == expense.id).length,
        1,
      );
    });

    test('دمج الديون المكررة الموجودة يُبقي دينًا واحدًا', () async {
      final expense = Expense(
        id: 'exp-dup',
        title: 'ديزل',
        amount: 40,
        date: DateTime(2026, 1, 1),
        category: 'وقود',
        eventId: 'ev-1',
        personId: 'sup-1',
        paymentMethod: 'debt',
      );
      final auto = PersonalDebt(
        id: 'd-auto',
        personId: 'sup-1',
        direction: 'payable',
        amount: 40,
        date: DateTime(2026, 1, 1),
        expenseId: 'exp-dup',
      );
      final fromScreen = PersonalDebt(
        id: 'd-screen',
        personId: 'sup-1',
        direction: 'payable',
        amount: 40,
        date: DateTime(2026, 1, 1),
        eventId: 'ev-1',
        expenseId: 'exp-dup',
      );
      SharedPreferences.setMockInitialValues({
        'expenses': json.encode([expense.toJson()]),
        'personalDebts': json.encode([auto.toJson(), fromScreen.toJson()]),
      });
      final provider = await newProvider();

      expect(provider.duplicateExpenseDebtGroups().length, 1);
      expect(provider.mergeDuplicateExpenseDebts(), 1);

      final left =
          provider.personalDebts.where((d) => d.expenseId == 'exp-dup').toList();
      expect(left.length, 1);
      expect(left.first.eventId, 'ev-1');
      expect(provider.duplicateExpenseDebtGroups(), isEmpty);
    });
  });
}
