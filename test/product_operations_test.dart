import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/providers/finance_provider.dart';

Product _packagedProduct() => Product(
      id: 'p-pack',
      name: 'مبيد تجريبي',
      category: 'أخرى',
      unit: 'لتر',
      purchasePrice: 100,
      packageType: 'علبة',
      packageSize: 500,
      usageUnit: 'مل',
    );

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

  test('H12: updateProduct keeps packaging fields for a product with history',
      () async {
    final provider = await newProvider();
    provider.addProduct(_packagedProduct());
    // الربط بمادة فعالة يجعل المنتج «له تاريخ» من أول يوم.
    provider.saveProductIngredients('p-pack', [
      {'ingredientId': 'ing-1', 'concentration': 5.0},
    ]);

    provider.updateProduct(Product(
      id: 'p-pack',
      name: 'مبيد تجريبي',
      category: 'أخرى',
      unit: 'لتر',
      purchasePrice: 120,
      packageType: 'علبة',
      packageSize: 500,
      usageUnit: 'مل',
    ));

    final saved = provider.products.firstWhere((p) => p.id == 'p-pack');
    expect(saved.purchasePrice, 120);
    expect(saved.packageType, 'علبة');
    expect(saved.packageSize, 500);
    expect(saved.usageUnit, 'مل');
    expect(saved.isPackaged, isTrue);
  });

  test('H13: a product linked only to active ingredients can be deleted',
      () async {
    final provider = await newProvider();
    provider.addProduct(_packagedProduct());
    provider.saveProductIngredients('p-pack', [
      {'ingredientId': 'ing-1', 'concentration': 5.0},
    ]);

    expect(provider.productDeleteBlockReason('p-pack'), isNull);
    expect(provider.deleteProduct('p-pack'), isTrue);
    expect(provider.products.any((p) => p.id == 'p-pack'), isFalse);
    expect(
      provider.productIngredients.any((e) => e.productId == 'p-pack'),
      isFalse,
    );
  });

  test('H13: a product with a warehouse item cannot be deleted and says why',
      () async {
    final provider = await newProvider();
    provider.addProduct(_packagedProduct());
    provider.addWarehouse(Warehouse(id: 'wh-1', name: 'مخزن'));
    final added = provider.addStorageItem(StorageItem(
      id: 'si-1',
      warehouseId: 'wh-1',
      name: 'مبيد تجريبي',
      unit: 'علبة',
      productId: 'p-pack',
    ));
    expect(added, isTrue);

    expect(provider.productDeleteBlockReason('p-pack'), isNotNull);
    expect(provider.deleteProduct('p-pack'), isFalse);
    expect(provider.products.any((p) => p.id == 'p-pack'), isTrue);
  });

  test('H13: a legacy storage item linked only by name also blocks deletion',
      () async {
    final provider = await newProvider();
    provider.addProduct(_packagedProduct());
    provider.addWarehouse(Warehouse(id: 'wh-1', name: 'مخزن'));
    final added = provider.addStorageItem(StorageItem(
      id: 'si-legacy',
      warehouseId: 'wh-1',
      name: 'مبيد تجريبي',
      unit: 'علبة',
    ));
    expect(added, isTrue);

    expect(provider.productDeleteBlockReason('p-pack'), isNotNull);
    expect(provider.deleteProduct('p-pack'), isFalse);
  });

  test('H13: a product with no references can still be deleted', () async {
    final provider = await newProvider();
    provider.addProduct(_packagedProduct());

    expect(provider.productDeleteBlockReason('p-pack'), isNull);
    expect(provider.deleteProduct('p-pack'), isTrue);
  });
}
