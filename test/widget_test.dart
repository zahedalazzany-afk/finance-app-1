import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/providers/finance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('FinanceProvider initial state and debt settlement funding', () async {
    final provider = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 200));

    // Ensure wallet and partner exist for testing
    final testWallet = Wallet(id: 'w1', name: 'الخزينة الرئيسية');
    provider.addWallet(testWallet);
    final testPartner = Partner(id: 'p1', name: 'محمد علي', roles: ['client']);
    provider.addPartner(testPartner);

    expect(provider.wallets, isNotEmpty);
    expect(provider.partners, isNotEmpty);

    // Verify getters exist and calculate properly
    final debtAvail = provider.totalDebtSettlementFundingAvailable();
    final incomeAvail = provider.totalFundingAvailable();
    expect(debtAvail >= 0, isTrue);
    expect(incomeAvail >= 0, isTrue);

    // Test personal debts calculations
    final pDebt = PersonalDebt(
      id: 'test-debt-1',
      personId: testPartner.id,
      amount: 1500,
      direction: 'receivable',
      date: DateTime.now(),
    );
    provider.addPersonalDebt(pDebt);
    expect(provider.personalDebtRemaining(pDebt.id), 1500);

    final settlement = PersonalDebtSettlement(
      id: 'test-settlement-1',
      debtId: pDebt.id,
      amount: 500,
      date: DateTime.now(),
      walletId: testWallet.id,
    );
    provider.addPersonalDebtSettlement(settlement);
    expect(provider.personalDebtPaid(pDebt.id), 500);
    expect(provider.personalDebtRemaining(pDebt.id), 1000);
  });

  test('MoneyValue enforces integer-only amounts', () {
    expect(MoneyValue.parseInput('1500').minorUnits, 1500);
    expect(() => MoneyValue.parseInput('1500.5'), throwsFormatException);
  });

  test('Proposal 1 & 3: Direct event expenses and partial wage payment', () async {
    final provider = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 100));

    final wallet = Wallet(id: 'w-test', name: 'محفظة الاختبار');
    provider.addWallet(wallet);

    final supplier = Partner(id: 'sup-1', name: 'مورد محروقات', roles: ['supplier']);
    provider.addPartner(supplier);

    final worker = Worker(id: 'wrk-1', name: 'أحمد سعيد');
    provider.addWorker(worker);

    final event = LandEvent(
      id: 'ev-test',
      landPlotId: 'plot-1',
      eventType: 'قلب التربة',
      date: DateTime.now(),
    );
    provider.addLandEvent(event);

    // Proposal 1: Direct Expense as Debt (دين على مورد بدون فاتورة مشتريات)
    final directDebtExpense = Expense(
      id: 'exp-direct-debt',
      title: '20 لتر ديزل للحراثة',
      amount: 150,
      date: DateTime.now(),
      category: 'وقود',
      eventId: event.id,
      personId: supplier.id,
      paymentMethod: 'debt',
    );
    provider.addExpense(directDebtExpense);

    final debtRecord = PersonalDebt(
      id: 'debt-p1',
      personId: supplier.id,
      direction: 'payable',
      amount: 150,
      date: DateTime.now(),
      note: 'مصروف حدث: ${event.eventType}',
      eventId: event.id,
      expenseId: directDebtExpense.id,
    );
    provider.addPersonalDebt(debtRecord);

    expect(provider.expensesForEvent(event.id).length, 1);
    expect(provider.personalDebtRemaining(debtRecord.id), 150);

    // Proposal 3: Worker with partial payment (wage: 200, cash: 80, debt: 120)
    final income = Income(
      id: 'inc-1',
      title: 'دفعة إيراد للتمويل',
      amount: 500,
      date: DateTime.now(),
      source: 'مبيعات',
      walletId: wallet.id,
    );
    provider.addIncome(income);
    final incPayment = IncomePayment(
      id: 'pay-1',
      incomeId: 'inc-1',
      amount: 500,
      date: DateTime.now(),
    );
    provider.addIncomePayment(incPayment);

    final wageExpense = Expense(
      id: 'exp-wage-partial',
      title: 'أجر عامل يومية 1',
      amount: 200,
      date: DateTime.now(),
      category: 'عمالة',
      eventId: event.id,
      workerId: worker.id,
      paymentMethod: 'partial',
    );
    provider.addExpense(wageExpense);

    provider.addExpensePayment(ExpensePayment(
      id: 'pay-wage-partial',
      expenseId: wageExpense.id,
      amount: 80,
      date: DateTime.now(),
      walletId: wallet.id,
      funding: [
        ExpenseAllocation(
          incomeId: income.id,
          paymentId: income.payments.first.id,
          amount: 80,
        ),
      ],
    ));

    expect(provider.paidForExpense(wageExpense.id), 80);
    final remainingWage = wageExpense.amount - provider.paidForExpense(wageExpense.id);
    expect(remainingWage, 120);
  });

  test('Yemeni base accounting converts foreign receipts at exchange rate', () {
    final receivedAmount = 1000.0;
    final rate = 57.5;
    final yemeniEquivalent = toYemeniEquivalent(receivedAmount, 'SAR', rate);

    expect(yemeniEquivalent, 57500.0);

    final income = Income(
      id: 'income-sar-1',
      title: 'بيع بالريال السعودي',
      amount: yemeniEquivalent,
      date: DateTime.now(),
      source: 'مبيعات',
      currency: 'SAR',
      exchangeRate: rate,
    );

    expect(income.amount, 57500.0);
    expect(income.currency, 'SAR');
    expect(income.exchangeRate, 57.5);
  });

  test('Multi-currency validation and inheritance in FinanceProvider', () async {
    final provider = FinanceProvider();
    final wallet = Wallet(id: 'w-curr', name: 'محفظة عملات');
    provider.addWallet(wallet);

    // Add Income in SAR
    final incomeSar = Income(
      id: 'inc-sar',
      title: 'إيراد بالريال السعودي',
      amount: 1000,
      date: DateTime.now(),
      source: 'مبيعات',
      currency: 'SAR',
      exchangeRate: 140.0,
      walletId: wallet.id,
    );
    provider.addIncome(incomeSar);

    final paymentSar = IncomePayment(
      id: 'pay-sar-1',
      incomeId: incomeSar.id,
      amount: 1000,
      date: DateTime.now(),
      currency: 'SAR',
      exchangeRate: 140.0,
    );
    provider.addIncomePayment(paymentSar);

    // Auto allocate funding for SAR
    final allocs = provider.autoAllocateFunding(500, currency: 'SAR');
    expect(allocs.length, 1);
    expect(allocs.first.currency, 'SAR');
    expect(allocs.first.amount, 500);

    // Mismatched currency funding should throw Exception
    expect(() {
      provider.validateFunding([
        ExpenseAllocation(
          incomeId: incomeSar.id,
          paymentId: paymentSar.id,
          amount: 100,
          currency: 'YER', // Mismatched currency against payment's SAR
        ),
      ]);
    }, throwsException);

    // Matching currency funding should succeed
    expect(() {
      provider.validateFunding([
        ExpenseAllocation(
          incomeId: incomeSar.id,
          paymentId: paymentSar.id,
          amount: 100,
          currency: 'SAR',
        ),
      ]);
    }, returnsNormally);
  });
}
