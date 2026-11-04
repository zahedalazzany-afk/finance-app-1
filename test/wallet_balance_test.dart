import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/providers/finance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // محفظتان: الخزينة (محفظة الإيراد) والبنك (دخلت إليه الدفعة، 1000).
  Future<FinanceProvider> setup() async {
    final provider = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 200));
    provider.addWallet(Wallet(id: 'cash', name: 'الخزينة'));
    provider.addWallet(Wallet(id: 'bank', name: 'البنك'));
    provider.addIncome(Income(
      id: 'inc-1',
      title: 'إيراد',
      amount: 1000,
      date: DateTime(2026, 1, 5),
      source: 'مبيعات',
      walletId: 'cash',
    ));
    provider.addIncomePayment(IncomePayment(
      id: 'pay-1',
      incomeId: 'inc-1',
      amount: 1000,
      date: DateTime(2026, 1, 10),
      walletId: 'bank',
    ));
    return provider;
  }

  test('C3: المصروف المستقطع من دفعة يخفض رصيد محفظة الدفعة', () async {
    final provider = await setup();
    provider.addExpense(Expense(
      id: 'e-1',
      title: 'صيانة',
      amount: 100,
      date: DateTime(2026, 1, 15),
      category: 'صيانة',
      paymentMethod: 'cash',
      allocations: [
        ExpenseAllocation(incomeId: 'inc-1', paymentId: 'pay-1', amount: 100),
      ],
    ));

    expect(provider.walletBalance('bank'), 900);
    expect(provider.walletBalance('cash'), 0);
    // كشف المحفظة يعرض المصروف نفسه، فيطابق الرصيد.
    expect(provider.getExpensesForWallet('bank').length, 1);
  });

  test('C3: المصروف المدفوع بدفعة مصروف لا يُخصم مرتين', () async {
    final provider = await setup();
    provider.addExpense(Expense(
      id: 'e-2',
      title: 'أجر',
      amount: 100,
      date: DateTime(2026, 1, 15),
      category: 'عمالة',
      paymentMethod: 'cash',
    ));
    provider.addExpensePayment(ExpensePayment(
      id: 'ep-2',
      expenseId: 'e-2',
      amount: 100,
      date: DateTime(2026, 1, 15),
      walletId: 'bank',
      funding: provider.allocateFromSpecificIncomePayment('pay-1', 100),
    ));

    expect(provider.walletBalance('bank'), 900);
  });

  test('C3: التقرير الشهري يحسب المصروف المستقطع خروجاً', () async {
    final provider = await setup();
    provider.addExpense(Expense(
      id: 'e-1',
      title: 'صيانة',
      amount: 100,
      date: DateTime(2026, 1, 15),
      category: 'صيانة',
      paymentMethod: 'cash',
      allocations: [
        ExpenseAllocation(incomeId: 'inc-1', paymentId: 'pay-1', amount: 100),
      ],
    ));

    final row = provider
        .monthlyReport()
        .firstWhere((r) => r.year == 2026 && r.month == 1);
    expect(row.income, 1000);
    expect(row.out, 100);
  });

  test('C3: مصروف بلا تخصيصات لا يغيّر رصيد أي محفظة', () async {
    final provider = await setup();
    provider.addExpense(Expense(
      id: 'e-3',
      title: 'أجر آجل',
      amount: 100,
      date: DateTime(2026, 1, 15),
      category: 'عمالة',
      paymentMethod: 'debt',
    ));

    expect(provider.walletBalance('bank'), 1000);
    expect(provider.walletBalance('cash'), 0);
  });
}
