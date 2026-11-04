import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/providers/finance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // محفظتان: الخزينة (محفظة الإيراد) والبنك (دخلت إليه الدفعات).
  Future<FinanceProvider> setupTwoWallets({
    double bankPayment = 1000,
    double cashPayment = 0,
  }) async {
    final provider = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 200));
    provider.addWallet(Wallet(id: 'cash', name: 'الخزينة'));
    provider.addWallet(Wallet(id: 'bank', name: 'البنك'));
    provider.addIncome(Income(
      id: 'inc-1',
      title: 'إيراد',
      amount: 1000,
      date: DateTime.now(),
      source: 'مبيعات',
      walletId: 'cash',
    ));
    provider.addIncomePayment(IncomePayment(
      id: 'pay-1',
      incomeId: 'inc-1',
      amount: bankPayment,
      date: DateTime.now(),
      walletId: 'bank',
    ));
    if (cashPayment > 0) {
      provider.addIncomePayment(IncomePayment(
        id: 'pay-2',
        incomeId: 'inc-1',
        amount: cashPayment,
        date: DateTime.now(),
        walletId: 'cash',
      ));
    }
    return provider;
  }

  test('H2: سداد حصة شريك يخرج من محفظة الدفعة لا من محفظة الإيراد', () async {
    final provider = await setupTwoWallets();
    provider.addDistribution(Distribution(
      id: 'd-1',
      incomeId: 'inc-1',
      partnerId: 'p-1',
      role: 'water',
      amount: 200,
    ));

    provider.markDistributionPaid(
      'd-1',
      DateTime.now(),
      provider.allocateFromSpecificIncomePayment('pay-1', 200),
    );

    final movement =
        provider.moneyMovements.firstWhere((m) => m.distributionId == 'd-1');
    expect(movement.walletId, 'bank');
    expect(provider.walletBalance('bank'), 800);
    expect(provider.walletBalance('cash'), 0);
  });

  test('H2: تمويل حصة من دفعات محافظ مختلفة مرفوض ولا يترك أثراً', () async {
    final provider = await setupTwoWallets(bankPayment: 600, cashPayment: 400);
    provider.addDistribution(Distribution(
      id: 'd-1',
      incomeId: 'inc-1',
      partnerId: 'p-1',
      role: 'water',
      amount: 200,
    ));

    final mixedFunding = [
      ExpenseAllocation(incomeId: 'inc-1', paymentId: 'pay-1', amount: 100),
      ExpenseAllocation(incomeId: 'inc-1', paymentId: 'pay-2', amount: 100),
    ];
    expect(
      () => provider.markDistributionPaid('d-1', DateTime.now(), mixedFunding),
      throwsException,
    );
    expect(provider.moneyMovements.any((m) => m.distributionId == 'd-1'),
        isFalse);
  });

  test('H2: سداد أجور مجمع يخرج من محفظة الدفعة الفعلية', () async {
    final provider = await setupTwoWallets();
    provider.addExpense(Expense(
      id: 'wage-1',
      title: 'أجر',
      amount: 100,
      date: DateTime.now(),
      category: 'عمالة',
      workerId: 'wk-1',
      paymentMethod: 'debt',
    ));

    provider.batchPayWorkerWages(
      workerPayouts: [(workerId: 'wk-1', amount: 60.0)],
      date: DateTime.now(),
      specificIncomePaymentId: 'pay-1',
    );

    final payment =
        provider.expensePayments.firstWhere((p) => p.expenseId == 'wage-1');
    expect(payment.walletId, 'bank');
    expect(provider.walletBalance('bank'), 940);
    expect(provider.walletBalance('cash'), 0);
  });
}
