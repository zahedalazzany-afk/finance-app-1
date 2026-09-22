import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

class FinanceProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  List<Income> _incomes = [];
  List<Expense> _expenses = [];
  List<LandPlot> _landPlots = [];
  List<ZahraType> _zahraTypes = [];
  List<Zahra> _zahras = [];
  List<LandEvent> _landEvents = [];
  List<Warehouse> _warehouses = [];
  List<StorageItem> _storageItems = [];
  List<InventoryTransaction> _inventoryTransactions = [];
  List<Partner> _partners = [];
  List<Partnership> _partnerships = [];
  List<Distribution> _distributions = [];
  List<IncomePayment> _incomePayments = [];
  List<ExpensePayment> _expensePayments = [];
  List<WorkRecord> _workRecords = [];
  List<Worker> _workers = [];
  List<Wallet> _wallets = [];
  List<MoneyMovement> _moneyMovements = [];
  List<ChemicalIngredient> _chemicalIngredients = [];
  List<Pest> _pests = [];
  List<PestIngredient> _pestIngredients = [];
  List<Product> _products = [];
  List<ProductIngredient> _productIngredients = [];
  List<Purchase> _purchases = [];
  List<PurchaseItem> _purchaseItems = [];
  List<PersonalDebt> _personalDebts = [];
  List<PersonalDebtSettlement> _personalDebtSettlements = [];
  List<ExpenseCategory> _expenseCategories = [];
  List<PartnershipType> _partnershipTypes = [];
  List<EventType> _eventTypes = [];
  List<ZakatEntry> _zakatEntries = [];
  List<ZakatPayment> _zakatPayments = [];
  bool _isLoading = false;
  final Map<String, Future<void>> _syncQueue = {};
  int _loadGeneration = 0;

  List<Income> get incomes => List.unmodifiable(_incomes);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<LandPlot> get landPlots => List.unmodifiable(_landPlots);
  List<ZahraType> get zahraTypes => List.unmodifiable(_zahraTypes);
  List<Zahra> get zahras => List.unmodifiable(_zahras);
  List<LandEvent> get landEvents => List.unmodifiable(_landEvents);
  List<Warehouse> get warehouses => List.unmodifiable(_warehouses);
  List<StorageItem> get storageItems => List.unmodifiable(_storageItems);
  List<InventoryTransaction> get inventoryTransactions =>
      List.unmodifiable(_inventoryTransactions);
  List<Partner> get partners => List.unmodifiable(_partners);
  List<Partnership> get partnerships => List.unmodifiable(_partnerships);
  List<Distribution> get distributions => List.unmodifiable(_distributions);
  List<IncomePayment> get incomePayments => List.unmodifiable(_incomePayments);
  List<ExpensePayment> get expensePayments => List.unmodifiable(_expensePayments);
  List<WorkRecord> get workRecords => List.unmodifiable(_workRecords);
  List<Worker> get workers => List.unmodifiable(_workers);
  List<Wallet> get wallets => List.unmodifiable(_wallets);
  List<MoneyMovement> get moneyMovements =>
      List.unmodifiable(_moneyMovements);
  List<ChemicalIngredient> get chemicalIngredients =>
      List.unmodifiable(_chemicalIngredients);
  List<Pest> get pests => List.unmodifiable(_pests);
  List<PestIngredient> get pestIngredients =>
      List.unmodifiable(_pestIngredients);
  List<Product> get products => List.unmodifiable(_products);
  List<ProductIngredient> get productIngredients =>
      List.unmodifiable(_productIngredients);
  List<Purchase> get purchases => List.unmodifiable(_purchases);
  List<PurchaseItem> get purchaseItems =>
      List.unmodifiable(_purchaseItems);
  List<PersonalDebt> get personalDebts => List.unmodifiable(_personalDebts);
  List<PersonalDebtSettlement> get personalDebtSettlements =>
      List.unmodifiable(_personalDebtSettlements);
  List<ExpenseCategory> get expenseCategories =>
      List.unmodifiable(_expenseCategories);
  List<PartnershipType> get partnershipTypes =>
      List.unmodifiable(_partnershipTypes);
  List<EventType> get eventTypesList => List.unmodifiable(_eventTypes);
  List<ZakatEntry> get zakatEntries => List.unmodifiable(_zakatEntries);
  List<ZakatPayment> get zakatPayments => List.unmodifiable(_zakatPayments);
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    AppTheme.isDarkMode = _themeMode == ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    AppTheme.isDarkMode = mode == ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  double get totalIncome => _incomes
      .where((i) => i.status == 'confirmed')
      .fold(0, (sum, i) => sum + i.amount);
  double get totalExpenses => _expenses.fold(0, (sum, e) => sum + e.amount);
  double get netBalance => totalIncome - totalExpenses;
  double get overallExpenseRatio =>
      totalIncome > 0 ? (totalExpenses / totalIncome) * 100 : 0;

  FinanceProvider() {
    _loadData();
  }

  void _rebuildLinkedExpenses() {
    for (final income in _incomes) {
      income.clearLinkedExpenses();
      final paymentIds = income.payments.map((p) => p.id).toSet();
      double total = 0;
      for (final expense in _expenses) {
        final alloc = expense.allocations
            .where((a) =>
                a.incomeId == income.id ||
                (a.paymentId != null && paymentIds.contains(a.paymentId)))
            .toList();
        if (alloc.isNotEmpty) {
          for (final a in alloc) {
            if (a.incomeId.isEmpty || a.incomeId != income.id) {
              a.incomeId = income.id;
            }
          }
          income.addLinkedExpense(expense);
          total += alloc.fold(0.0, (s, a) => s + a.amount);
        }
      }
      income.setTotalExpenses(total);
      // اعتماد الحالة تلقائياً بناءً على مجموع المبالغ المستلمة
      income.status =
          (income.amount > 0 && income.remainingAmount <= 0)
              ? 'confirmed'
              : 'pending';
    }
  }

  void _rebuildIncomePayments() {
    for (final income in _incomes) {
      income.setPayments(
        _incomePayments.where((p) => p.incomeId == income.id).toList(),
      );
    }
  }

  void _cleanupSeededStorageItems() {
    const seeded = [
      'يوريا (سماد آزوتي)',
      'سوبر فوسفات',
      'سماد عضوي',
      'مبيد حشري عام',
      'مبيد فطري نحاسي',
      'مبيد أعشاب',
    ];
    final before = _storageItems.length;
    _storageItems.removeWhere((s) =>
        seeded.contains(s.name.trim()) &&
        !_inventoryTransactions.any((t) => t.itemId == s.id));
    if (_storageItems.length != before) {
      _saveRefData();
    }
  }

  /// يضمن تطابق كميات المخازن والفواتير مع سجل الحركات الفعلي 100%
  void _reconcileInventoryAndPurchases() {
    // 1. حساب كميات التوزيع لكل بند شراء من واقع حركات الإدخال
    final distributedByPurchaseItemId = <String, double>{};
    for (final tx in _inventoryTransactions) {
      if (tx.type == 'in' &&
          tx.purchaseItemId != null &&
          tx.purchaseItemId!.isNotEmpty) {
        distributedByPurchaseItemId[tx.purchaseItemId!] =
            (distributedByPurchaseItemId[tx.purchaseItemId!] ?? 0.0) +
                tx.quantity;
      }
    }

    for (final pi in _purchaseItems) {
      final actualDistributed = distributedByPurchaseItemId[pi.id] ?? 0.0;
      pi.distributedQuantity = actualDistributed;
    }

    // 2. حساب رصيد كل صنف في المخزن من واقع حركات الإدخال والصرف
    final netByItemId = <String, double>{};
    for (final tx in _inventoryTransactions) {
      if (tx.type == 'in') {
        netByItemId[tx.itemId] = (netByItemId[tx.itemId] ?? 0.0) + tx.quantity;
      } else if (tx.type == 'out') {
        netByItemId[tx.itemId] = (netByItemId[tx.itemId] ?? 0.0) - tx.quantity;
      }
    }

    for (final si in _storageItems) {
      if (netByItemId.containsKey(si.id)) {
        si.quantity = (netByItemId[si.id] ?? 0.0).clamp(0.0, double.infinity);
      }
    }

    // 3. تحديث الرصيد الإجمالي للمنتجات
    for (var i = 0; i < _products.length; i++) {
      final p = _products[i];
      final totStock = totalStockForProduct(p.id);
      if (p.currentStock != totStock) {
        _products[i] = Product(
          id: p.id,
          name: p.name,
          category: p.category,
          unit: p.unit,
          purchasePrice: p.purchasePrice,
          salePrice: p.salePrice,
          currentStock: totStock,
          minStock: p.minStock,
          packageType: p.packageType,
          packageSize: p.packageSize,
          usageUnit: p.usageUnit,
          maxPurchasePrice: p.maxPurchasePrice,
        );
      }
    }
  }

  /// يضمن تطابق حالة سداد حصص الشركاء مع سجل الحركات النقدية للصندوق 100%
  /// بحيث يكون سجل الحركات النقدية (MoneyMovement) هو المصدر الأساسي للحقيقة المالية.
  void _reconcileDistributionsAndMovements() {
    var changed = false;

    // 1. مزامنة الحركات النقدية القائمة لتأكيد حالة الحصص المرتبطة بها
    for (final m in _moneyMovements) {
      if (m.distributionId != null) {
        final dIdx = _distributions.indexWhere((d) => d.id == m.distributionId);
        if (dIdx != -1) {
          if (!_distributions[dIdx].isPaid) {
            _distributions[dIdx].isPaid = true;
            changed = true;
          }
          if (_distributions[dIdx].paidDate == null) {
            _distributions[dIdx].paidDate = m.date;
            changed = true;
          }
        }
      }
    }

    // 2. مزامنة الحصص المسددة تاريخياً التي تفتقر لسند حركة نقدية في الصندوق
    for (final d in _distributions) {
      if (d.isPaid) {
        final hasMovement = _moneyMovements.any((m) => m.distributionId == d.id);
        if (!hasMovement) {
          final inc = _incomes.firstWhereOrNull((i) => i.id == d.incomeId);
          final effectiveWalletId = inc?.walletId ??
              defaultWallet()?.id ??
              (_wallets.isNotEmpty ? _wallets.first.id : '');
          _moneyMovements.add(MoneyMovement(
            id: const Uuid().v4(),
            walletId: effectiveWalletId,
            amount: d.amount,
            date: d.paidDate ?? inc?.date ?? DateTime.now(),
            distributionId: d.id,
            incomeId: inc?.id,
            note: 'تسديد حصة شريك (تسوية نظام)',
          ));
          changed = true;
        }
      }
    }

    if (changed) {
      _saveRefData();
    }
  }

  Future<void> reloadData({bool syncFromCloud = true}) async {
    await _loadData(syncFromCloud: syncFromCloud);
  }

  Future<void> _loadData({bool syncFromCloud = true}) async {
    final loadGeneration = ++_loadGeneration;
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();

    // إعادة التحميل يجب أن تبدأ من حالة فارغة حتى لا تتضاعف السجلات عند
    // استدعاء reloadData() أو عند إعادة محاولة التحميل بعد انقطاع الشبكة.
    _incomes.clear();
    _expenses.clear();
    _landPlots.clear();
    _zahraTypes.clear();
    _zahras.clear();
    _landEvents.clear();
    _warehouses.clear();
    _storageItems.clear();
    _inventoryTransactions.clear();
    _partners.clear();
    _partnerships.clear();
    _distributions.clear();
    _incomePayments.clear();
    _expensePayments.clear();
    _workRecords.clear();
    _workers.clear();
    _wallets.clear();
    _moneyMovements.clear();
    _chemicalIngredients.clear();
    _pests.clear();
    _pestIngredients.clear();
    _products.clear();
    _productIngredients.clear();
    _purchases.clear();
    _purchaseItems.clear();
    _personalDebts.clear();
    _personalDebtSettlements.clear();
    _expenseCategories.clear();
    _partnershipTypes.clear();
    _eventTypes.clear();
    _zakatEntries.clear();
    _zakatPayments.clear();

    final oldPlotsStr = prefs.getString('landPlots');
    _loadDecodeList<LandPlot>(prefs, 'landPlots', LandPlot.fromJson);
    _loadDecodeList<ZahraType>(prefs, 'zahraTypes', ZahraType.fromJson);
    _loadDecodeList<Zahra>(prefs, 'zahras', Zahra.fromJson);
    _loadDecodeList<LandEvent>(prefs, 'landEvents', LandEvent.fromJson);
    _loadDecodeList<Warehouse>(prefs, 'warehouses', Warehouse.fromJson);
    _loadDecodeList<StorageItem>(prefs, 'storageItems', StorageItem.fromJson);
    _loadDecodeList<Partner>(prefs, 'partners', Partner.fromJson);
    _loadDecodeList<Partnership>(prefs, 'partnerships', Partnership.fromJson);
    _loadDecodeList<WorkRecord>(prefs, 'workRecords', WorkRecord.fromJson);
    _loadDecodeList<Worker>(prefs, 'workers', Worker.fromJson);
    _loadDecodeList<Wallet>(prefs, 'wallets', Wallet.fromJson);
    _loadDecodeList<MoneyMovement>(
        prefs, 'moneyMovements', MoneyMovement.fromJson);
    _loadDecodeList<ChemicalIngredient>(
        prefs, 'chemicalIngredients', ChemicalIngredient.fromJson);
    _loadDecodeList<Pest>(prefs, 'pests', Pest.fromJson);
    _loadDecodeList<PestIngredient>(
        prefs, 'pestIngredients', PestIngredient.fromJson);
    _loadDecodeList<Product>(prefs, 'products', Product.fromJson);
    _loadDecodeList<ProductIngredient>(
        prefs, 'productIngredients', ProductIngredient.fromJson);
    _loadDecodeList<Purchase>(prefs, 'purchases', Purchase.fromJson);
    _loadDecodeList<PurchaseItem>(
        prefs, 'purchaseItems', PurchaseItem.fromJson);
    _loadDecodeList<PersonalDebt>(
        prefs, 'personalDebts', PersonalDebt.fromJson);
    _loadDecodeList<PersonalDebtSettlement>(
        prefs, 'personalDebtSettlements', PersonalDebtSettlement.fromJson);
    _loadDecodeList<ExpenseCategory>(
        prefs, 'expenseCategories', ExpenseCategory.fromJson);
    _loadDecodeList<PartnershipType>(
        prefs, 'partnershipTypes', PartnershipType.fromJson);
    _loadDecodeList<EventType>(
        prefs, 'eventTypes', EventType.fromJson);
    _loadDecodeList<ZakatEntry>(
        prefs, 'zakatEntries', ZakatEntry.fromJson);
    _loadDecodeList<ZakatPayment>(
        prefs, 'zakatPayments', ZakatPayment.fromJson);

    if (_partnershipTypes.isEmpty) {
      _partnershipTypes.addAll([
        PartnershipType(id: 'water', name: 'شريك ماء'),
        PartnershipType(id: 'worker', name: 'شريك عامل'),
      ]);
    }

    if (_expenseCategories.isEmpty) {
      _expenseCategories.addAll(defaultExpenseCategories
          .map((name) => ExpenseCategory(id: name, name: name)));
    }

    if (_eventTypes.isEmpty) {
      _eventTypes.addAll([
        EventType(id: 'soil_turning', name: 'قلب التربة'),
        EventType(id: 'irrigation', name: 'سقي المزروعات'),
        EventType(id: 'pruning', name: 'قصة الأشجار'),
        EventType(id: 'pesticide', name: 'رش المبيدات'),
        EventType(id: 'other', name: 'أخرى'),
      ]);
    }
    _deduplicateReferenceData();

    if (_wallets.isEmpty) {
      final oldStr = prefs.getString('cashBoxes');
      if (oldStr != null) {
        final List<dynamic> oldList = json.decode(oldStr);
        _wallets = oldList
            .map((e) => Wallet.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    final distStr = prefs.getString('distributions');
    if (distStr != null) {
      final List<dynamic> distList = json.decode(distStr);
      _distributions = distList
          .map((e) => Distribution.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final payStr = prefs.getString('incomePayments');
    if (payStr != null) {
      final List<dynamic> payList = json.decode(payStr);
      _incomePayments = payList
          .map((e) => IncomePayment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final expPayStr = prefs.getString('expensePayments');
    if (expPayStr != null) {
      final List<dynamic> expPayList = json.decode(expPayStr);
      _expensePayments = expPayList
          .map((e) => ExpensePayment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final txStr = prefs.getString('inventoryTransactions');
    if (txStr != null) {
      final List<dynamic> txList = json.decode(txStr);
      _inventoryTransactions = txList
          .map((e) => InventoryTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
      _inventoryTransactions.sort((a, b) => b.date.compareTo(a.date));
    }

    final expensesStr = prefs.getString('expenses');
    if (expensesStr != null) {
      final List<dynamic> expensesList = json.decode(expensesStr);
      _expenses = expensesList
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final jsonStr = prefs.getString('incomes');
    if (jsonStr != null) {
      final List<dynamic> jsonList = json.decode(jsonStr);
      _incomes = jsonList
          .map((e) => Income.fromJson(e as Map<String, dynamic>))
          .toList();
      _incomes.sort((a, b) => b.date.compareTo(a.date));

      if (expensesStr == null) {
        _migrateOldFormat(jsonList);
      }
    }

    _migrateOldPartnerships(oldPlotsStr);
    _rebuildIncomePayments();
    _migrateDebtReceiptFunding();
    _rebuildLinkedExpenses();
    _cleanupSeededStorageItems();
    _reconcileInventoryAndPurchases();
    _reconcileDistributionsAndMovements();

    final savedTheme = prefs.getString('app_theme_mode');
    if (savedTheme != null) {
      _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
      AppTheme.isDarkMode = _themeMode == ThemeMode.dark;
    }

    if (syncFromCloud && loadGeneration == _loadGeneration) {
      await _loadFromFirestore(prefs);
    }
    if (loadGeneration == _loadGeneration) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// يسحب البيانات من المنصة (إن وُجدت) لتصبح المنصة مصدر الحقيقة
  /// بينما تبقى SharedPreferences كذاكرة تخزين مؤقتة للعمل دون اتصال.
  Future<void> _loadFromFirestore(SharedPreferences prefs) async {
    try {
      await Future.wait([
        _hydrate('incomes', _incomes, Income.fromJson,
            insert: true, sortDesc: true),
        _hydrate('expenses', _expenses, Expense.fromJson, insert: true),
        _hydrate('landPlots', _landPlots, LandPlot.fromJson),
        _hydrate('zahraTypes', _zahraTypes, ZahraType.fromJson),
        _hydrate('zahras', _zahras, Zahra.fromJson),
        _hydrate('landEvents', _landEvents, LandEvent.fromJson,
            insert: true),
        _hydrate('warehouses', _warehouses, Warehouse.fromJson),
        _hydrate('storageItems', _storageItems, StorageItem.fromJson),
        _hydrate('inventoryTransactions', _inventoryTransactions,
            InventoryTransaction.fromJson,
            insert: true, sortDesc: true),
        _hydrate('partners', _partners, Partner.fromJson),
        _hydrate('partnerships', _partnerships, Partnership.fromJson),
        _hydrate('distributions', _distributions, Distribution.fromJson),
        _hydrate(
            'incomePayments', _incomePayments, IncomePayment.fromJson),
        _hydrate(
            'expensePayments', _expensePayments, ExpensePayment.fromJson),
        _hydrate('workRecords', _workRecords, WorkRecord.fromJson,
            insert: true),
        _hydrate('workers', _workers, Worker.fromJson),
        _hydrate('wallets', _wallets, Wallet.fromJson),
        _hydrate(
            'moneyMovements', _moneyMovements, MoneyMovement.fromJson),
        _hydrate('chemicalIngredients', _chemicalIngredients,
            ChemicalIngredient.fromJson),
        _hydrate('pests', _pests, Pest.fromJson),
        _hydrate(
            'pestIngredients', _pestIngredients, PestIngredient.fromJson),
        _hydrate('products', _products, Product.fromJson),
        _hydrate('productIngredients', _productIngredients,
            ProductIngredient.fromJson),
        _hydrate('purchases', _purchases, Purchase.fromJson,
            insert: true),
        _hydrate('purchaseItems', _purchaseItems, PurchaseItem.fromJson),
        _hydrate('personalDebts', _personalDebts, PersonalDebt.fromJson),
        _hydrate('personalDebtSettlements', _personalDebtSettlements,
            PersonalDebtSettlement.fromJson),
        _hydrate('expenseCategories', _expenseCategories,
            ExpenseCategory.fromJson),
        _hydrate(
            'partnershipTypes', _partnershipTypes, PartnershipType.fromJson),
        _hydrate('eventTypes', _eventTypes, EventType.fromJson),
        _hydrate('zakatEntries', _zakatEntries, ZakatEntry.fromJson),
        _hydrate('zakatPayments', _zakatPayments, ZakatPayment.fromJson),
      ]);
      _deduplicateReferenceData();
      _rebuildIncomePayments();
      _migrateDebtReceiptFunding();
      _rebuildLinkedExpenses();
      _reconcileInventoryAndPurchases();
      _reconcileDistributionsAndMovements();
      if (prefs.getBool('cloudBootstrapped') != true) {
        await _bootstrapCloud();
        await prefs.setBool('cloudBootstrapped', true);
      }
    } catch (_) {
      // دون اتصال: نكتفي بالذاكرة المؤقتة.
    }
  }

  /// رفع أولي لبيانات هذا الجهاز إلى المنصة بعد الترحيل.
  /// لا يحذف أي سجل موجود على المنصة؛ فالتهيئة قد تحدث على جهاز ثانٍ
  /// يحتوي على مجموعة محلية مختلفة، ولا ينبغي أن تعتبر هذه المجموعة
  /// المحلية نسخة كاملة من بيانات الحساب السحابية.
  Future<void> _bootstrapCloud() async {
    final tasks = <Future<void>>[];
    void push<T>(String name, List<T> items,
        Map<String, dynamic> Function(T) toJson) {
      if (items.isNotEmpty) {
        tasks.add(FirestoreService.mergeCollection(name, items, toJson));
      }
    }

    push('incomes', _incomes, (i) => i.toJson());
    push('expenses', _expenses, (e) => e.toJson());
    push('landPlots', _landPlots, (e) => e.toJson());
    push('zahraTypes', _zahraTypes, (e) => e.toJson());
    push('zahras', _zahras, (e) => e.toJson());
    push('landEvents', _landEvents, (e) => e.toJson());
    push('warehouses', _warehouses, (e) => e.toJson());
    push('storageItems', _storageItems, (e) => e.toJson());
    push(
        'inventoryTransactions', _inventoryTransactions, (e) => e.toJson());
    push('partners', _partners, (e) => e.toJson());
    push('partnerships', _partnerships, (e) => e.toJson());
    push('distributions', _distributions, (e) => e.toJson());
    push('incomePayments', _incomePayments, (e) => e.toJson());
    push('expensePayments', _expensePayments, (e) => e.toJson());
    push('workRecords', _workRecords, (e) => e.toJson());
    push('workers', _workers, (e) => e.toJson());
    push('wallets', _wallets, (e) => e.toJson());
    push('moneyMovements', _moneyMovements, (e) => e.toJson());
    push('chemicalIngredients', _chemicalIngredients, (e) => e.toJson());
    push('pests', _pests, (e) => e.toJson());
    push('pestIngredients', _pestIngredients, (e) => e.toJson());
    push('products', _products, (e) => e.toJson());
    push('productIngredients', _productIngredients, (e) => e.toJson());
    push('purchases', _purchases, (e) => e.toJson());
    push('purchaseItems', _purchaseItems, (e) => e.toJson());
    push('personalDebts', _personalDebts, (e) => e.toJson());
    push('personalDebtSettlements', _personalDebtSettlements,
        (e) => e.toJson());
    push('expenseCategories', _expenseCategories, (e) => e.toJson());
    push('partnershipTypes', _partnershipTypes, (e) => e.toJson());
    push('eventTypes', _eventTypes, (e) => e.toJson());
    push('zakatEntries', _zakatEntries, (e) => e.toJson());
    push('zakatPayments', _zakatPayments, (e) => e.toJson());
    await Future.wait(tasks);
  }

  /// يدمج قائمة المنصة مع القائمة المحلية حسب المعرّف:
  /// سجل المنصة يحل محل المحلي، ولا تُفقد السجلات المحلية غير المتزامنة،
  /// ولا تتكرر السجلات. عند عدم وجود بيانات على المنصة تُترك المحلية كما هي.
  Future<void> _hydrate<T>(
    String collection,
    List<T> target,
    T Function(Map<String, dynamic>) fromJson, {
    bool insert = false,
    bool sortDesc = false,
  }) async {
    final docs = await FirestoreService.loadCollection(collection);
    if (docs.isEmpty) return;
    final cloudItems = docs.map(fromJson);
    final byId = <String, T>{};
    for (final item in target) {
      byId[(item as dynamic).id as String] = item;
    }
    for (final item in cloudItems) {
      byId[(item as dynamic).id as String] = item;
    }
    var merged = byId.values.toList();
    if (sortDesc) {
      merged.sort(
          (a, b) => (b as dynamic).date.compareTo((a as dynamic).date));
    }
    target
      ..clear()
      ..addAll(merged);
  }

  void _loadDecodeList<T>(SharedPreferences prefs, String key, T Function(Map<String, dynamic>) fromJson) {
    final str = prefs.getString(key);
    if (str == null) return;
    try {
      final decoded = json.decode(str);
      if (decoded is! List) return;
      final list = decoded
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (T == LandPlot) {
        (_landPlots as List<LandPlot>).addAll(list.cast<LandPlot>());
      } else if (T == ZahraType) {
        (_zahraTypes as List<ZahraType>).addAll(list.cast<ZahraType>());
      } else if (T == Zahra) {
        (_zahras as List<Zahra>).addAll(list.cast<Zahra>());
      } else if (T == LandEvent) {
        (_landEvents as List<LandEvent>).addAll(list.cast<LandEvent>());
      } else if (T == Warehouse) {
        (_warehouses as List<Warehouse>).addAll(list.cast<Warehouse>());
      } else if (T == StorageItem) {
        (_storageItems as List<StorageItem>).addAll(list.cast<StorageItem>());
      } else if (T == Partner) {
        (_partners as List<Partner>).addAll(list.cast<Partner>());
      } else if (T == Partnership) {
        (_partnerships as List<Partnership>).addAll(list.cast<Partnership>());
      } else if (T == WorkRecord) {
        (_workRecords as List<WorkRecord>).addAll(list.cast<WorkRecord>());
      } else if (T == Worker) {
        (_workers as List<Worker>).addAll(list.cast<Worker>());
      } else if (T == Wallet) {
        (_wallets as List<Wallet>).addAll(list.cast<Wallet>());
      } else if (T == MoneyMovement) {
        (_moneyMovements as List<MoneyMovement>).addAll(list.cast<MoneyMovement>());
      } else if (T == ChemicalIngredient) {
        (_chemicalIngredients as List<ChemicalIngredient>).addAll(list.cast<ChemicalIngredient>());
      } else if (T == Pest) {
        (_pests as List<Pest>).addAll(list.cast<Pest>());
      } else if (T == PestIngredient) {
        (_pestIngredients as List<PestIngredient>).addAll(list.cast<PestIngredient>());
      } else if (T == Product) {
        (_products as List<Product>).addAll(list.cast<Product>());
      } else if (T == ProductIngredient) {
        (_productIngredients as List<ProductIngredient>).addAll(list.cast<ProductIngredient>());
      } else if (T == Purchase) {
        (_purchases as List<Purchase>).addAll(list.cast<Purchase>());
      } else if (T == PurchaseItem) {
        (_purchaseItems as List<PurchaseItem>).addAll(list.cast<PurchaseItem>());
      } else if (T == PersonalDebt) {
        (_personalDebts as List<PersonalDebt>).addAll(list.cast<PersonalDebt>());
      } else if (T == PersonalDebtSettlement) {
        (_personalDebtSettlements as List<PersonalDebtSettlement>).addAll(list.cast<PersonalDebtSettlement>());
      } else if (T == ExpenseCategory) {
        (_expenseCategories as List<ExpenseCategory>).addAll(list.cast<ExpenseCategory>());
      } else if (T == PartnershipType) {
        (_partnershipTypes as List<PartnershipType>).addAll(list.cast<PartnershipType>());
      } else if (T == EventType) {
        (_eventTypes as List<EventType>).addAll(list.cast<EventType>());
      } else if (T == ZakatEntry) {
        (_zakatEntries as List<ZakatEntry>).addAll(list.cast<ZakatEntry>());
      } else if (T == ZakatPayment) {
        (_zakatPayments as List<ZakatPayment>).addAll(list.cast<ZakatPayment>());
      }
    } catch (_) {
      // سجل تالف: نتجاهل هذا المفتاح فقط حتى لا يمنع بقية بيانات التطبيق من التحميل.
    }
  }

  void _migrateOldPartnerships(String? oldPlotsStr) {
    if (_partnerships.isNotEmpty || oldPlotsStr == null) return;
    final List<dynamic> oldList = json.decode(oldPlotsStr);
    bool migrated = false;
    for (final json in oldList) {
      final plotId = json['id'] as String;
      final waterId = json['waterPartnerId'] as String?;
      final workerId = json['workerPartnerId'] as String?;
      if (waterId != null) {
        _partnerships.add(Partnership(
          id: const Uuid().v4(),
          landPlotId: plotId,
          partnerId: waterId,
          role: 'water',
          sharePercentage: 25.0,
          startDate: DateTime(2000, 1, 1),
        ));
        migrated = true;
      }
      if (workerId != null) {
        _partnerships.add(Partnership(
          id: const Uuid().v4(),
          landPlotId: plotId,
          partnerId: workerId,
          role: 'worker',
          sharePercentage: 25.0,
          startDate: DateTime(2000, 1, 1),
        ));
        migrated = true;
      }
    }
    if (migrated) _saveRefData();
  }

  void _migrateOldFormat(List<dynamic> oldJsonList) {
    final oldExpenses = <Expense>[];
    for (final json in oldJsonList) {
      final incomeId = json['id'] as String;
      final linked = (json['linkedExpenses'] as List<dynamic>?) ?? [];
      for (final eJson in linked) {
        final expense = Expense.fromJson(eJson as Map<String, dynamic>);
        expense.allocations
            .add(ExpenseAllocation(incomeId: incomeId, amount: expense.amount));
        oldExpenses.add(expense);
      }
    }
    if (oldExpenses.isNotEmpty) {
      _expenses = oldExpenses;
      _saveExpenses();
      _saveIncomes();
    }
  }

  Future<void> _saveIncomes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'incomes', json.encode(_incomes.map((i) => i.toJson()).toList()));
    _syncCollection('incomes', _incomes, (i) => i.toJson());
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'expenses', json.encode(_expenses.map((e) => e.toJson()).toList()));
    _syncCollection('expenses', _expenses, (e) => e.toJson());
  }

  Future<void> _saveAll() async {
    await Future.wait([_saveIncomes(), _saveExpenses(), _saveRefData()]);
  }

  /// مزامنة صريحة لجميع البيانات المحلية بعد استيراد/استعادة نسخة احتياطية.
  /// تستخدم بعد نجاح الاستعادة حتى لا تبقى السحابة على بيانات أقدم من الجهاز.
  Future<void> syncAllToCloud() async {
    // _saveAll() يطلق عمليات المزامنة في الخلفية، لذلك لا يكفي انتظارها
    // مباشرة. ننتظر طوابير جميع المجموعات حتى تصبح الاستعادة/التصدير
    // متزامنة فعلياً قبل إبلاغ المستدعي بنجاح العملية.
    await _saveAll();
    await _waitForPendingSync();
  }

  Future<void> _waitForPendingSync() async {
    // قد تنضم عملية جديدة إلى الطوابير أثناء الانتظار؛ نكرر القراءة حتى
    // لا نغادر قبل اكتمال آخر دفعة بدأت من هذا الـ provider.
    while (_syncQueue.isNotEmpty) {
      final pending = List<Future<void>>.from(_syncQueue.values);
      if (pending.isEmpty) break;
      await Future.wait(pending);
    }
  }

  /// يرفع مجموعة إلى المنصة بشكل خلفي (fire-and-forget).
  /// أي فشل في الاتصال يُتجاهل بهدوء ليبقى التطبيق يعمل دون اتصال.
  void _syncCollection<T>(
    String name,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) {
    // تسلسل عمليات المزامنة لكل مجموعة يمنع سباق الحفظ عندما ينفذ
    // المستخدم عدة تعديلات متتابعة بسرعة. آخر نسخة محلية هي التي تُرفع.
    final previous = _syncQueue[name] ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        await FirestoreService.saveCollection(name, List<T>.from(items), toJson);
      } catch (_) {
        // التطبيق يعمل دون اتصال؛ ستُعاد محاولة المزامنة مع عملية حفظ لاحقة.
      }
    });
    late Future<void> queued;
    queued = next.whenComplete(() {
      if (identical(_syncQueue[name], queued)) {
        _syncQueue.remove(name);
      }
    });
    _syncQueue[name] = queued;
  }

  Future<void> _saveRefData() async {
    _deduplicateReferenceData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'landPlots', json.encode(_landPlots.map((e) => e.toJson()).toList()));
    await prefs.setString('zahraTypes',
        json.encode(_zahraTypes.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'zahras', json.encode(_zahras.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'landEvents', json.encode(_landEvents.map((e) => e.toJson()).toList()));
    await prefs.setString('warehouses',
        json.encode(_warehouses.map((e) => e.toJson()).toList()));
    await prefs.setString('storageItems',
        json.encode(_storageItems.map((e) => e.toJson()).toList()));
    await prefs.setString('inventoryTransactions',
        json.encode(_inventoryTransactions.map((e) => e.toJson()).toList()));
    await prefs.setString('partners',
        json.encode(_partners.map((e) => e.toJson()).toList()));
    await prefs.setString('partnerships',
        json.encode(_partnerships.map((e) => e.toJson()).toList()));
    await prefs.setString('distributions',
        json.encode(_distributions.map((e) => e.toJson()).toList()));
    await prefs.setString('incomePayments',
        json.encode(_incomePayments.map((e) => e.toJson()).toList()));
    await prefs.setString('expensePayments',
        json.encode(_expensePayments.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'workRecords', json.encode(_workRecords.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'workers', json.encode(_workers.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'wallets', json.encode(_wallets.map((e) => e.toJson()).toList()));
    await prefs.setString('moneyMovements',
        json.encode(_moneyMovements.map((e) => e.toJson()).toList()));
    await prefs.setString('chemicalIngredients',
        json.encode(_chemicalIngredients.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'pests', json.encode(_pests.map((e) => e.toJson()).toList()));
    await prefs.setString('pestIngredients',
        json.encode(_pestIngredients.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'products', json.encode(_products.map((e) => e.toJson()).toList()));
    await prefs.setString('productIngredients',
        json.encode(_productIngredients.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'purchases', json.encode(_purchases.map((e) => e.toJson()).toList()));
    await prefs.setString('purchaseItems',
        json.encode(_purchaseItems.map((e) => e.toJson()).toList()));
    await prefs.setString('personalDebts',
        json.encode(_personalDebts.map((e) => e.toJson()).toList()));
    await prefs.setString('personalDebtSettlements',
        json.encode(_personalDebtSettlements.map((e) => e.toJson()).toList()));
    await prefs.setString('expenseCategories',
        json.encode(_expenseCategories.map((e) => e.toJson()).toList()));
    await prefs.setString('partnershipTypes',
        json.encode(_partnershipTypes.map((e) => e.toJson()).toList()));
    await prefs.setString('eventTypes',
        json.encode(_eventTypes.map((e) => e.toJson()).toList()));
    await prefs.setString('zakatEntries',
        json.encode(_zakatEntries.map((e) => e.toJson()).toList()));
    await prefs.setString('zakatPayments',
        json.encode(_zakatPayments.map((e) => e.toJson()).toList()));

    _syncCollection('landPlots', _landPlots, (e) => e.toJson());
    _syncCollection('zahraTypes', _zahraTypes, (e) => e.toJson());
    _syncCollection('zahras', _zahras, (e) => e.toJson());
    _syncCollection('landEvents', _landEvents, (e) => e.toJson());
    _syncCollection('warehouses', _warehouses, (e) => e.toJson());
    _syncCollection('storageItems', _storageItems, (e) => e.toJson());
    _syncCollection('inventoryTransactions', _inventoryTransactions,
        (e) => e.toJson());
    _syncCollection('partners', _partners, (e) => e.toJson());
    _syncCollection('partnerships', _partnerships, (e) => e.toJson());
    _syncCollection('distributions', _distributions, (e) => e.toJson());
    _syncCollection(
        'incomePayments', _incomePayments, (e) => e.toJson());
    _syncCollection(
        'expensePayments', _expensePayments, (e) => e.toJson());
    _syncCollection('workRecords', _workRecords, (e) => e.toJson());
    _syncCollection('workers', _workers, (e) => e.toJson());
    _syncCollection('wallets', _wallets, (e) => e.toJson());
    _syncCollection('moneyMovements', _moneyMovements, (e) => e.toJson());
    _syncCollection(
        'chemicalIngredients', _chemicalIngredients, (e) => e.toJson());
    _syncCollection('pests', _pests, (e) => e.toJson());
    _syncCollection('pestIngredients', _pestIngredients, (e) => e.toJson());
    _syncCollection('products', _products, (e) => e.toJson());
    _syncCollection(
        'productIngredients', _productIngredients, (e) => e.toJson());
    _syncCollection('purchases', _purchases, (e) => e.toJson());
    _syncCollection('purchaseItems', _purchaseItems, (e) => e.toJson());
    _syncCollection('personalDebts', _personalDebts, (e) => e.toJson());
    _syncCollection('personalDebtSettlements', _personalDebtSettlements,
        (e) => e.toJson());
    _syncCollection('expenseCategories', _expenseCategories, (e) => e.toJson());
    _syncCollection(
        'partnershipTypes', _partnershipTypes, (e) => e.toJson());
    _syncCollection('eventTypes', _eventTypes, (e) => e.toJson());
    _syncCollection('zakatEntries', _zakatEntries, (e) => e.toJson());
    _syncCollection('zakatPayments', _zakatPayments, (e) => e.toJson());
  }

  // --- Income CRUD ---

  void addIncome(Income income) {
    _incomes.insert(0, income);
    _saveIncomes();
    ensureDistributionsForIncome(income.id);
    notifyListeners();
  }

  void updateIncome(Income updated) {
    final idx = _incomes.indexWhere((i) => i.id == updated.id);
    if (idx != -1) {
      _incomes[idx] = updated;
      _saveIncomes();
      _saveRefData();
      ensureDistributionsForIncome(updated.id);
      notifyListeners();
    }
  }

  void deleteIncome(String id) {
    // حذف الإيراد لا يعني حذف المصروف نفسه. المصروف سجل مستقل، وقد يكون
    // ممولاً من أكثر من إيراد. نحذف فقط تخصيصات هذا الإيراد/دفعاته.
    final removedPaymentIds = _incomePayments
        .where((p) => p.incomeId == id)
        .map((p) => p.id)
        .toSet();

    for (final expense in _expenses) {
      expense.allocations.removeWhere((a) =>
          a.incomeId == id ||
          (a.paymentId != null && removedPaymentIds.contains(a.paymentId)));
    }

    _incomes.removeWhere((i) => i.id == id);
    _incomePayments.removeWhere((p) => p.incomeId == id);

    // الحركات النقدية التي كانت تمثل قبض الإيراد أو مرتبطة بدفعاته تُزال،
    // بينما الحركات الأخرى تبقى كما هي.
    _moneyMovements.removeWhere((m) =>
        m.incomeId == id || removedPaymentIds.contains(m.paymentId));

    final removedDistributionIds = _distributions
        .where((d) => d.incomeId == id)
        .map((d) => d.id)
        .toSet();
    _distributions.removeWhere((d) => d.incomeId == id);
    _moneyMovements.removeWhere((m) =>
        m.distributionId != null &&
        removedDistributionIds.contains(m.distributionId));

    // تنظيف استحقاقات ومدفوعات الزكاة المرتبطة بهذا الإيراد.
    final removedZakatPaymentIds = _zakatPayments
        .where((p) => p.incomeId == id || p.zakatEntryId == 'inc_$id')
        .map((p) => p.id)
        .toSet();
    _zakatPayments.removeWhere(
        (p) => p.incomeId == id || p.zakatEntryId == 'inc_$id');
    _zakatEntries.removeWhere(
        (e) => e.incomeId == id || e.id == 'inc_$id');
    _moneyMovements.removeWhere((m) =>
        m.zakatPaymentId != null &&
        removedZakatPaymentIds.contains(m.zakatPaymentId));

    _rebuildLinkedExpenses();
    _saveAll();
    notifyListeners();
  }

  // --- Expense CRUD ---

  void _removePersonalDebtData(String debtId) {
    _personalDebts.removeWhere((d) => d.id == debtId);
    _personalDebtSettlements.removeWhere((s) => s.debtId == debtId);
    _moneyMovements.removeWhere((m) => m.debtId == debtId);
  }

  void _syncExpenseDebt(Expense expense) {
    final linkedDebt = _personalDebts.firstWhereOrNull(
      (debt) => debt.expenseId == expense.id,
    );

    if (expense.paymentMethod == 'debt' && expense.personId != null) {
      if (linkedDebt == null) {
        _personalDebts.add(PersonalDebt(
          id: const Uuid().v4(),
          personId: expense.personId!,
          direction: 'payable',
          amount: expense.amount,
          date: expense.date,
          note: expense.note ?? 'مصروف آجل: ${expense.title}',
          expenseId: expense.id,
        ));
      } else {
        linkedDebt
          ..personId = expense.personId!
          ..direction = 'payable'
          ..amount = expense.amount
          ..date = expense.date
          ..note = expense.note ?? 'مصروف آجل: ${expense.title}'
          ..expenseId = expense.id
          ..walletId = null
          ..funding = [];
      }
    } else if (linkedDebt != null) {
      _removePersonalDebtData(linkedDebt.id);
    }
  }

  void addExpense(Expense expense) {
    _validateExpenseAllocations(expense, null);
    _expenses.insert(0, expense);
    _syncExpenseDebt(expense);
    _rebuildLinkedExpenses();
    _saveAll();
    notifyListeners();
  }

  void updateExpense(Expense updated) {
    final idx = _expenses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _validateExpenseAllocations(updated, updated.id);
      _expenses[idx] = updated;
      _syncExpenseDebt(updated);
      _rebuildLinkedExpenses();
      _saveAll();
      notifyListeners();
    }
  }

  void deleteExpense(String id) {
    // دفعات المصروف قد يكون لكل منها حركة نقدية مرتبطة عبر paymentId.
    // يجب جمع معرفاتها قبل حذف الدفعات حتى لا تبقى حركة نقدية يتيمة
    // تستمر في التأثير على رصيد المحفظة بعد حذف المصروف.
    final removedPaymentIds = _expensePayments
        .where((p) => p.expenseId == id)
        .map((p) => p.id)
        .toSet();

    _expenses.removeWhere((e) => e.id == id);
    _expensePayments.removeWhere((p) => p.expenseId == id);
    _moneyMovements.removeWhere((m) =>
        m.paymentId != null && removedPaymentIds.contains(m.paymentId));

    final linkedDebtIds = _personalDebts
        .where((d) => d.expenseId == id)
        .map((d) => d.id)
        .toList();
    for (final debtId in linkedDebtIds) {
      _removePersonalDebtData(debtId);
    }
    _rebuildLinkedExpenses();
    _saveAll();
    notifyListeners();
  }

  // --- Legacy helpers for income_detail_screen ---

  void deleteExpenseFromIncome(String incomeId, String expenseId) {
    final expense = _expenses.firstWhereOrNull((e) => e.id == expenseId);
    if (expense != null) {
      // فك الارتباط فقط؛ لا نغيّر قيمة المصروف الأصلية ولا نحذف المصروف
      // إذا كانت له مصادر تمويل أخرى.
      expense.allocations.removeWhere((a) => a.incomeId == incomeId);
      _rebuildLinkedExpenses();
      _saveAll();
      notifyListeners();
    }
  }

  List<Expense> getExpensesForIncome(String incomeId) {
    final income = _incomes.firstWhereOrNull((i) => i.id == incomeId);
    final paymentIds = (income?.payments.map((p) => p.id) ?? const <String>[]).toSet();
    return _expenses
        .where((e) => e.allocations.any((a) =>
            a.incomeId == incomeId ||
            (a.paymentId != null && paymentIds.contains(a.paymentId))))
        .toList();
  }

  double totalExpensesForIncome(String incomeId) {
    final income = _incomes.firstWhereOrNull((i) => i.id == incomeId);
    final paymentIds = (income?.payments.map((p) => p.id) ?? const <String>[]).toSet();
    return _expenses
        .where((e) => e.allocations.any((a) =>
            a.incomeId == incomeId ||
            (a.paymentId != null && paymentIds.contains(a.paymentId))))
        .fold(0.0, (sum, e) {
      final allocs = e.allocations.where((a) =>
          a.incomeId == incomeId ||
          (a.paymentId != null && paymentIds.contains(a.paymentId)));
      return sum + allocs.fold(0.0, (s, a) => s + a.amount);
    });
  }

  /// مجموع المصروفات المرتبطة بدفعة استلام محددة.
  double totalExpensesForPayment(String paymentId) {
    return _expenses.fold(0.0, (sum, e) =>
        sum +
        e.allocations
            .where((a) => a.paymentId == paymentId)
            .fold(0.0, (s, a) => s + a.amount));
  }

  /// مجموع المبالغ المرتبطة بدفعة استلام محددة عبر:
  /// استقطاعات المصروفات + تمويل دفعات المصروف + تمويل حركات الصرف + تصريفاتها القديمة.
  double fundedForPayment(String paymentId) {
    double sum = 0;
    for (final ep in _expensePayments) {
      for (final a in ep.funding) {
        if (a.paymentId == paymentId) sum += a.amount;
      }
    }
    for (final m in _moneyMovements) {
      for (final a in m.funding) {
        if (a.paymentId == paymentId) sum += a.amount;
      }
    }
    return sum;
  }

  /// المبلغ المتاح من دفعة استلام (متبقي الدفعة − مصروفاتها − تصريفاتها − تمويلها).
  /// عند تعديل مصروف، نستثني حصته القديمة عبر [excludeExpenseId].
  double paymentAvailable(String paymentId, {String? excludeExpenseId}) {
    final payment = _incomePayments.firstWhereOrNull((p) => p.id == paymentId);
    if (payment == null) return 0;
    final expenses = _expenses.fold<double>(0, (sum, e) {
      if (e.id == excludeExpenseId) return sum;
      return sum +
          e.allocations
              .where((a) => a.paymentId == paymentId)
              .fold(0.0, (s, a) => s + a.amount);
    });
    return (payment.amount -
            expenses -
            disbursedForPayment(paymentId) -
            fundedForPayment(paymentId))
        .clamp(0.0, double.infinity);
  }

  /// يتحقق من صلاحية تمويل عملية صرف من دفعات الاستلام.
  /// يرمي استثناءً إذا تجاوز أي مبلغ المتاح من الدفعة.
  void validateFunding(List<ExpenseAllocation> funding) {
    final usedByPayment = <String, double>{};
    final usedByDebtSettlement = <String, double>{};
    for (final a in funding) {
      final paymentId = a.paymentId;
      if (paymentId != null) {
        final payment = _incomePayments.firstWhereOrNull((p) => p.id == paymentId);
        if (payment != null && a.currency != payment.currency) {
          throw Exception('لا يمكن تمويل العملية بعملة مختلفة عن عملة الدفعة');
        }
        final used = (usedByPayment[paymentId] ?? 0) + a.amount;
        usedByPayment[paymentId] = used;
        final available = paymentAvailable(paymentId);
        if (used > available + 0.001) {
          throw Exception(
              'المبلغ يتجاوز المتاح في الدفعة ($available ${available.toStringAsFixed(2)} ر.ي)');
        }
      }
      final settlementId = a.debtSettlementId;
      if (settlementId != null) {
        final source = debtFundingSources.firstWhereOrNull((s) => s.id == settlementId);
        if (source != null && a.currency != source.currency) {
          throw Exception('لا يمكن تمويل العملية بعملة مختلفة عن عملة الدفعة');
        }
        final used = (usedByDebtSettlement[settlementId] ?? 0) + a.amount;
        usedByDebtSettlement[settlementId] = used;
        final available = debtFundingAvailable(settlementId);
        if (used > available + 0.001) {
          throw Exception(
              'المبلغ يتجاوز المتاح من دفعة الدين (${available.toStringAsFixed(2)} ر.ي)');
        }
      }
    }
  }

  void _validateExpenseAllocations(Expense expense, String? excludeExpenseId) {
    for (final alloc in expense.allocations) {
      final paymentId = alloc.paymentId;
      if (paymentId != null) {
        final available = paymentAvailable(paymentId,
            excludeExpenseId: excludeExpenseId);
        final consumed = expense.allocations
            .where((a) => a.paymentId == paymentId)
            .fold(0.0, (s, a) => s + a.amount);
        if (consumed > available + 0.001) {
          throw Exception('المصروف يتجاوز المتاح في الدفعة المختارة');
        }
      }
      final debtSourceId = alloc.debtSettlementId;
      if (debtSourceId != null) {
        final available = debtFundingAvailable(
          debtSourceId,
          excludeExpenseId: excludeExpenseId,
        );
        final consumed = expense.allocations
            .where((a) => a.debtSettlementId == debtSourceId)
            .fold(0.0, (s, a) => s + a.amount);
        if (consumed > available + 0.001) {
          throw Exception('المصروف يتجاوز المتاح من دفعة الدين');
        }
      }
    }
  }

  double remainingForIncome(String incomeId) {
    final income = _incomes.firstWhereOrNull((i) => i.id == incomeId);
    if (income == null) return 0;
    final available = income.status == 'confirmed' ? income.amount : income.receivedAmount;
    return (available - totalExpensesForIncome(incomeId) - disbursedForIncome(incomeId))
        .clamp(0.0, double.infinity);
  }

  // --- LandPlot CRUD ---

  void addLandPlot(LandPlot plot) {
    _landPlots.add(plot);
    _saveRefData();
    notifyListeners();
  }

  void updateLandPlot(LandPlot updated) {
    final idx = _landPlots.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _landPlots[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deleteLandPlot(String id) {
    final used = _incomes.any((e) => e.landPlotId == id) ||
        _expenses.any((e) => e.landPlotId == id) ||
        _zahras.any((e) => e.landPlotId == id) ||
        _landEvents.any((e) => e.landPlotId == id) ||
        _partnerships.any((e) => e.landPlotId == id);
    if (used) return false;
    _landPlots.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  // --- ZahraType CRUD ---

  void addZahraType(ZahraType type) {
    _zahraTypes.add(type);
    _saveRefData();
    notifyListeners();
  }

  void updateZahraType(ZahraType updated) {
    final idx = _zahraTypes.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _zahraTypes[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deleteZahraType(String id) {
    if (_zahras.any((z) => z.typeId == id)) return false;
    _zahraTypes.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  // --- Zahra CRUD ---

  void addZahra(Zahra zahra) {
    _zahras.add(zahra);
    _saveRefData();
    notifyListeners();
  }

  void updateZahra(Zahra updated) {
    final idx = _zahras.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _zahras[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deleteZahra(String id) {
    final used = _incomes.any((e) => e.zahraId == id) ||
        _expenses.any((e) => e.zahraId == id) ||
        _landEvents.any((e) => e.zahraId == id);
    if (used) return false;
    _zahras.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  // --- LandEvent CRUD ---

  void addLandEvent(LandEvent event) {
    _landEvents.insert(0, event);
    _saveRefData();
    notifyListeners();
  }

  void updateLandEvent(LandEvent updated) {
    final idx = _landEvents.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _landEvents[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  void deleteLandEvent(String id) {
    final txs =
        _inventoryTransactions.where((t) => t.eventId == id).toList();
    for (final tx in txs) {
      final itemIdx = _storageItems.indexWhere((i) => i.id == tx.itemId);
      if (itemIdx != -1) {
        if (tx.type == 'in') {
          _storageItems[itemIdx].quantity =
              _storageItems[itemIdx].quantity - tx.quantity;
        } else {
          _storageItems[itemIdx].quantity += tx.quantity;
        }
      }
      final item = _storageItems.firstWhereOrNull((i) => i.id == tx.itemId);
      final product = _productForStorageItem(item);
      if (product != null) {
        final idx = _products.indexWhere((e) => e.id == product.id);
        if (idx != -1) {
          final delta = tx.type == 'in' ? -tx.quantity : tx.quantity;
          _products[idx] = Product(
            id: product.id,
            name: product.name,
            category: product.category,
            unit: product.unit,
            purchasePrice: product.purchasePrice,
            salePrice: product.salePrice,
            currentStock: (product.currentStock + delta).toDouble(),
            minStock: product.minStock,
            maxPurchasePrice: product.maxPurchasePrice,
          );
        }
      }
      _inventoryTransactions.removeWhere((t) => t.id == tx.id);
    }
    final eventExpenses =
        _expenses.where((e) => e.eventId == id).toList();
    for (final e in eventExpenses) {
      _expensePayments.removeWhere((p) => p.expenseId == e.id);
      _expenses.removeWhere((ex) => ex.id == e.id);
    }
    _personalDebts.removeWhere((d) => d.eventId == id);
    _landEvents.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
  }
  // --- Warehouse CRUD ---

  void addWarehouse(Warehouse w) {
    _warehouses.add(w);
    _saveRefData();
    notifyListeners();
  }

  void updateWarehouse(Warehouse updated) {
    final idx = _warehouses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _warehouses[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deleteWarehouse(String id) {
    final items = _storageItems.where((s) => s.warehouseId == id).toList();
    // لا نحذف مخزناً يحتوي على رصيد أو سجل حركة تاريخي.
    // حذف هذه السجلات سيكسر تاريخ المخزون ويجعل الأرصدة غير قابلة للمراجعة.
    if (items.any((s) => s.quantity.abs() > 0.000001)) return false;
    final itemIds = items.map((s) => s.id).toSet();
    if (_inventoryTransactions.any((t) => itemIds.contains(t.itemId))) return false;
    _warehouses.removeWhere((e) => e.id == id);
    _storageItems.removeWhere((s) => s.warehouseId == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  List<StorageItem> getItemsForWarehouse(String warehouseId) {
    return _storageItems.where((s) => s.warehouseId == warehouseId).toList();
  }

  // --- StorageItem CRUD ---

  void addStorageItem(StorageItem item) {
    _storageItems.add(item);
    _saveRefData();
    notifyListeners();
  }

  void updateStorageItem(StorageItem updated) {
    final idx = _storageItems.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;

    final current = _storageItems[idx];
    final hasTransactions =
        _inventoryTransactions.any((t) => t.itemId == current.id);

    // بعد وجود حركة تاريخية لا نسمح بتغيير هوية عنصر المخزون،
    // لأن ذلك يفصل الحركة عن المخزن/الصنف الذي حدثت عليه فعليًا.
    if (hasTransactions &&
        (updated.warehouseId != current.warehouseId ||
            updated.productId != current.productId)) {
      return;
    }

    // الكمية تُشتق من حركات المخزون بعد بدء التاريخ؛ تعديلها يدويًا
    // سيجعل الرصيد مختلفًا عن مجموع الحركات.
    final safeUpdated = hasTransactions
        ? StorageItem(
            id: updated.id,
            warehouseId: current.warehouseId,
            name: updated.name,
            unit: updated.unit,
            quantity: current.quantity,
            minQuantity: updated.minQuantity,
            notes: updated.notes,
            category: updated.category,
            pesticideType: updated.pesticideType,
            productId: current.productId,
            packageSize: updated.packageSize,
            usageUnit: updated.usageUnit,
          )
        : updated;

    _storageItems[idx] = safeUpdated;
    _reconcileInventoryAndPurchases();
    _saveRefData();
    notifyListeners();
  }

  bool deleteStorageItem(String id) {
    final item = _storageItems.firstWhereOrNull((s) => s.id == id);
    if (item == null) return false;

    // عنصر المخزون جزء من التاريخ. إذا كانت له حركة سابقة لا نحذفه،
    // لأن حذف الحركة نفسها قد يكون له أثر مالي/مخزني مستقل.
    final hasTransactions =
        _inventoryTransactions.any((t) => t.itemId == id);
    if (hasTransactions || item.quantity.abs() > 0.000001) {
      return false;
    }

    _storageItems.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  Product? _productForStorageItem(StorageItem? item) {
    if (item == null) return null;
    return _products.firstWhereOrNull((e) => e.id == item.productId) ??
        _products.firstWhereOrNull(
            (e) => e.name.trim() == item.name.trim());
  }

  // --- InventoryTransaction CRUD ---

  bool addInventoryTransaction(InventoryTransaction tx) {
    if (tx.quantity <= 0 || (tx.type != 'in' && tx.type != 'out')) {
      return false;
    }
    if (_inventoryTransactions.any((t) => t.id == tx.id)) return false;
    final itemIdx = _storageItems.indexWhere((i) => i.id == tx.itemId);
    if (itemIdx == -1) return false;

    final item = _storageItems[itemIdx];
    if (tx.type == 'out' && tx.quantity > item.quantity + 0.000001) {
      return false;
    }

    if (tx.type == 'in' && tx.purchaseItemId != null) {
      final purchaseItem = _purchaseItems
          .firstWhereOrNull((p) => p.id == tx.purchaseItemId);
      if (purchaseItem == null ||
          purchaseItem.productId != item.productId ||
          purchaseItem.remainingToDistribute + 0.000001 < tx.quantity) {
        return false;
      }
    }

    _inventoryTransactions.insert(0, tx);
    item.quantity += tx.type == 'in' ? tx.quantity : -tx.quantity;

    if (tx.type == 'in' && tx.purchaseItemId != null) {
      final idx = _purchaseItems.indexWhere((p) => p.id == tx.purchaseItemId);
      if (idx != -1) {
        final purchaseItem = _purchaseItems[idx];
        _purchaseItems[idx] = PurchaseItem(
          id: purchaseItem.id,
          purchaseId: purchaseItem.purchaseId,
          productId: purchaseItem.productId,
          quantity: purchaseItem.quantity,
          unitPrice: purchaseItem.unitPrice,
          distributedQuantity: purchaseItem.distributedQuantity + tx.quantity,
        );
      }
    }

    _reconcileInventoryAndPurchases();
    _saveRefData();
    notifyListeners();
    return true;
  }

  bool updateInventoryTransaction(InventoryTransaction updatedTx) {
    if (updatedTx.quantity <= 0 ||
        (updatedTx.type != 'in' && updatedTx.type != 'out')) {
      return false;
    }
    final oldTxIdx = _inventoryTransactions.indexWhere((t) => t.id == updatedTx.id);
    if (oldTxIdx == -1) return false;
    final oldTx = _inventoryTransactions[oldTxIdx];

    // الحركات المرتبطة بتحويل مخزني يجب تعديلها كتحويل كامل.
    if (oldTx.transferId != null || updatedTx.transferId != null) {
      return false;
    }

    final oldItem = _storageItems.firstWhereOrNull((i) => i.id == oldTx.itemId);
    final newItem = _storageItems.firstWhereOrNull((i) => i.id == updatedTx.itemId);
    if (newItem == null) return false;

    final simulated = <String, double>{};
    if (oldItem != null) {
      simulated[oldItem.id] = oldItem.quantity +
          (oldTx.type == 'in' ? -oldTx.quantity : oldTx.quantity);
    }
    simulated[newItem.id] = (simulated[newItem.id] ?? newItem.quantity) +
        (updatedTx.type == 'in' ? updatedTx.quantity : -updatedTx.quantity);
    if (simulated.values.any((q) => q < -0.000001)) return false;

    // نعيد حالة توزيع عنصر الشراء القديم ثم نتحقق من الحركة الجديدة.
    if (oldTx.type == 'in' && oldTx.purchaseItemId != null) {
      final oldPurchase = _purchaseItems
          .firstWhereOrNull((p) => p.id == oldTx.purchaseItemId);
      if (oldPurchase == null) return false;
    }
    if (updatedTx.type == 'in' && updatedTx.purchaseItemId != null) {
      final newPurchase = _purchaseItems
          .firstWhereOrNull((p) => p.id == updatedTx.purchaseItemId);
      if (newPurchase == null ||
          newPurchase.productId != newItem.productId) return false;
      final available = newPurchase.remainingToDistribute +
          (oldTx.type == 'in' && oldTx.purchaseItemId == updatedTx.purchaseItemId
              ? oldTx.quantity
              : 0);
      if (updatedTx.quantity > available + 0.000001) return false;
    }

    if (oldItem != null) {
      oldItem.quantity = simulated[oldItem.id]!;
    }
    if (newItem.id != oldItem?.id) {
      newItem.quantity = simulated[newItem.id]!;
    }

    if (oldTx.type == 'in' && oldTx.purchaseItemId != null) {
      final idx = _purchaseItems.indexWhere((p) => p.id == oldTx.purchaseItemId);
      if (idx != -1) {
        final p = _purchaseItems[idx];
        _purchaseItems[idx] = PurchaseItem(
          id: p.id, purchaseId: p.purchaseId, productId: p.productId,
          quantity: p.quantity, unitPrice: p.unitPrice,
          distributedQuantity: (p.distributedQuantity - oldTx.quantity)
              .clamp(0, p.quantity).toDouble(),
        );
      }
    }
    if (updatedTx.type == 'in' && updatedTx.purchaseItemId != null) {
      final idx = _purchaseItems.indexWhere((p) => p.id == updatedTx.purchaseItemId);
      if (idx != -1) {
        final p = _purchaseItems[idx];
        _purchaseItems[idx] = PurchaseItem(
          id: p.id, purchaseId: p.purchaseId, productId: p.productId,
          quantity: p.quantity, unitPrice: p.unitPrice,
          distributedQuantity: (p.distributedQuantity + updatedTx.quantity)
              .clamp(0, p.quantity).toDouble(),
        );
      }
    }

    _inventoryTransactions[oldTxIdx] = updatedTx;
    _reconcileInventoryAndPurchases();
    _saveRefData();
    notifyListeners();
    return true;
  }

  bool deleteInventoryTransaction(String id) {
    final tx = _inventoryTransactions.firstWhereOrNull((t) => t.id == id);
    if (tx == null) return false;
    if (tx.transferId != null) {
      deleteWarehouseTransfer(tx.transferId!);
      return true;
    }

    final item = _storageItems.firstWhereOrNull((i) => i.id == tx.itemId);
    if (item == null) return false;
    final newQuantity = item.quantity +
        (tx.type == 'in' ? -tx.quantity : tx.quantity);
    if (newQuantity < -0.000001) return false;

    if (tx.type == 'in' && tx.purchaseItemId != null) {
      final pIdx = _purchaseItems.indexWhere((p) => p.id == tx.purchaseItemId);
      if (pIdx == -1) return false;
      final p = _purchaseItems[pIdx];
      _purchaseItems[pIdx] = PurchaseItem(
        id: p.id, purchaseId: p.purchaseId, productId: p.productId,
        quantity: p.quantity, unitPrice: p.unitPrice,
        distributedQuantity: (p.distributedQuantity - tx.quantity)
            .clamp(0, p.quantity).toDouble(),
      );
    }

    item.quantity = newQuantity < 0 ? 0 : newQuantity;
    _inventoryTransactions.removeWhere((t) => t.id == id);
    _reconcileInventoryAndPurchases();
    _saveRefData();
    notifyListeners();
    return true;
  }

  /// تحويل كميات بين المخازن
  /// [fromWarehouseId]: المخزن المحول منه (المصدر)
  /// [toWarehouseId]: المخزن المحول إليه (الوجهة)
  /// [entries]: قائمة بالأصناف المحولة: {itemId, quantity}
  /// [date]: تاريخ التحويل
  /// [notes]: ملاحظات التحويل
  bool transferWarehouseItems({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<Map<String, dynamic>> entries,
    required DateTime date,
    String? notes,
  }) {
    if (fromWarehouseId == toWarehouseId || entries.isEmpty) return false;
    final fromW = _warehouses.firstWhereOrNull((w) => w.id == fromWarehouseId);
    final toW = _warehouses.firstWhereOrNull((w) => w.id == toWarehouseId);
    if (fromW == null || toW == null) return false;

    final planned = <String, double>{};
    for (final entry in entries) {
      final sourceItemId = entry['itemId'] as String?;
      final rawQuantity = entry['quantity'];
      if (sourceItemId == null || rawQuantity is! num) return false;
      final quantity = rawQuantity.toDouble();
      if (quantity <= 0) return false;
      planned[sourceItemId] = (planned[sourceItemId] ?? 0) + quantity;
    }

    for (final e in planned.entries) {
      final source = _storageItems.firstWhereOrNull(
          (s) => s.id == e.key && s.warehouseId == fromWarehouseId);
      if (source == null || e.value > source.quantity + 0.000001) return false;
    }

    final fromName = fromW.name;
    final toName = toW.name;
    final transferId = const Uuid().v4();

    for (final e in planned.entries) {
      final sourceItem = _storageItems.firstWhere((s) => s.id == e.key);
      final actualQty = e.value;
      var destItem = _storageItems.firstWhereOrNull((s) =>
          s.warehouseId == toWarehouseId &&
          (sourceItem.productId != null
              ? s.productId == sourceItem.productId
              : s.productId == null &&
                  s.name.trim().toLowerCase() ==
                      sourceItem.name.trim().toLowerCase()));

      if (destItem == null) {
        destItem = StorageItem(
          id: const Uuid().v4(), warehouseId: toWarehouseId,
          name: sourceItem.name, unit: sourceItem.unit, quantity: 0,
          minQuantity: sourceItem.minQuantity, notes: sourceItem.notes,
          category: sourceItem.category, pesticideType: sourceItem.pesticideType,
          productId: sourceItem.productId, packageSize: sourceItem.packageSize,
          usageUnit: sourceItem.usageUnit,
        );
        _storageItems.add(destItem);
      }

      sourceItem.quantity -= actualQty;
      destItem.quantity += actualQty;
      final extraNote = notes != null && notes.trim().isNotEmpty
          ? ' · ${notes.trim()}'
          : '';
      _inventoryTransactions.insert(0, InventoryTransaction(
        id: const Uuid().v4(), itemId: sourceItem.id, type: 'out',
        quantity: actualQty, date: date,
        notes: 'تحويل إلى مخزن $toName$extraNote', transferId: transferId,
        toWarehouseId: toWarehouseId, fromWarehouseId: fromWarehouseId,
      ));
      _inventoryTransactions.insert(0, InventoryTransaction(
        id: const Uuid().v4(), itemId: destItem.id, type: 'in',
        quantity: actualQty, date: date,
        notes: 'تحويل من مخزن $fromName$extraNote', transferId: transferId,
        toWarehouseId: toWarehouseId, fromWarehouseId: fromWarehouseId,
      ));
    }

    _reconcileInventoryAndPurchases();
    _saveRefData();
    notifyListeners();
    return true;
  }

  /// إلغاء/حذف عملية تحويل كاملة واسترجاع الكميات للمخازن
  bool deleteWarehouseTransfer(String transferId) {
    final relatedTxs = _inventoryTransactions
        .where((t) => t.transferId == transferId)
        .toList();
    if (relatedTxs.isEmpty) return false;

    // لا نعكس التحويل إذا كانت الكمية الموجودة في المخزن الوجهة
    // أقل من الكمية التي أدخلها هذا التحويل؛ منعًا لصناعة رصيد غير صحيح.
    final requiredFromDestination = <String, double>{};
    for (final tx in relatedTxs.where((t) => t.type == 'in')) {
      requiredFromDestination[tx.itemId] =
          (requiredFromDestination[tx.itemId] ?? 0) + tx.quantity;
    }
    for (final entry in requiredFromDestination.entries) {
      final item = _storageItems.firstWhereOrNull((s) => s.id == entry.key);
      if (item == null || item.quantity + 0.000001 < entry.value) {
        return false;
      }
    }

    for (final tx in relatedTxs) {
      final item = _storageItems.firstWhereOrNull((s) => s.id == tx.itemId);
      if (item == null) return false;
      if (tx.type == 'in') {
        item.quantity -= tx.quantity;
      } else if (tx.type == 'out') {
        item.quantity += tx.quantity;
      }
      _inventoryTransactions.removeWhere((t) => t.id == tx.id);
    }

    _reconcileInventoryAndPurchases();
    _saveRefData();
    notifyListeners();
    return true;
  }

  List<InventoryTransaction> getTransactionsForItem(String itemId) {
    return _inventoryTransactions
        .where((t) => t.itemId == itemId)
        .toList();
  }

  // --- Income Payment CRUD ---

  void addIncomePayment(IncomePayment payment) {
    if (payment.amount <= 0) {
      throw Exception('مبلغ دفعة الإيراد يجب أن يكون أكبر من صفر');
    }
    if (payment.walletId == null || payment.walletId!.trim().isEmpty) {
      throw Exception('يجب تحديد المحفظة عند تسجيل دفعة إيراد');
    }
    if (_incomePayments.any((p) => p.id == payment.id)) {
      throw Exception('دفعة الإيراد موجودة مسبقاً');
    }
    final income = _incomes.firstWhereOrNull((i) => i.id == payment.incomeId);
    final inheritedCurrency = payment.currency == baseCurrencyCode &&
        income != null && income.currency != baseCurrencyCode
      ? income.currency
      : payment.currency;
    final inheritedRate = inheritedCurrency == payment.currency
      ? payment.exchangeRate
      : income!.exchangeRate;
    if (income != null) {
      final remaining = income.remainingAmount;
      if (payment.amount > remaining + 0.001) {
        throw Exception('مبلغ دفعة الإيراد يتجاوز المبلغ المتبقي للإيراد');
      }
      final clamped = IncomePayment(
        id: payment.id,
        incomeId: payment.incomeId,
        amount: payment.amount,
        date: payment.date,
        notes: payment.notes,
        walletId: payment.walletId,
        currency: inheritedCurrency,
        exchangeRate: inheritedRate,
      );
      _incomePayments.add(clamped);
      income.addPayment(clamped);
      if (income.remainingAmount <= 0) {
        income.status = 'confirmed';
      }
    } else {
      _incomePayments.add(payment);
    }
    _rebuildLinkedExpenses();
    _saveAll();
    notifyListeners();
  }

  void deleteIncomePayment(String paymentId) {
    final payment = _incomePayments.firstWhereOrNull((p) => p.id == paymentId);
    if (payment != null) {
      _incomePayments.removeWhere((p) => p.id == paymentId);
      _moneyMovements.removeWhere((m) => m.paymentId == paymentId);
      final income = _incomes.firstWhereOrNull((i) => i.id == payment.incomeId);
      income?.removePayment(paymentId);

      // فك تمويل المصروف من الدفعة المحذوفة فقط. قيمة المصروف نفسها
      // لا تتغير لأنها تمثل قيمة الالتزام الأصلي، وليست مصدر تمويله.
      for (final e in _expenses) {
        e.allocations.removeWhere((a) => a.paymentId == paymentId);
      }

      // إذا كانت الدفعة قد استُخدمت في دفع نقدي آخر، فلا نحذف سجل الدفع
      // المرتبط بالمصروف تلقائياً؛ يبقى السجل المالي كما هو ولا نُنشئ
      // بيانات ناقصة أو أرصدة سالبة.

      _rebuildLinkedExpenses();
      // إعادة حساب الحالة: إذا بقي مبلغ غير مستلم يعود الإيراد معلقاً
      if (income != null && income.remainingAmount > 0) {
        income.status = 'pending';
      }
      _saveAll();
      notifyListeners();
    }
  }

  // --- Expense Payment CRUD ---

  void addExpensePayment(ExpensePayment payment,
      {List<ExpenseAllocation>? funding}) {
    final remaining = expenseRemainingAmount(payment.expenseId);
    if (payment.amount <= 0) {
      throw Exception('مبلغ دفعة المصروف يجب أن يكون أكبر من صفر');
    }
    if (payment.amount > remaining + 0.001) {
      throw Exception('مبلغ دفعة المصروف يتجاوز المبلغ المتبقي للمصروف');
    }
    final clamped = payment.amount;
    if (payment.walletId == null || payment.walletId!.trim().isEmpty) {
      throw Exception('يجب تحديد المحفظة عند تسجيل دفعة مصروف');
    }
    final exp = _expenses.firstWhereOrNull((e) => e.id == payment.expenseId);
    final inheritedCurrency = payment.currency == baseCurrencyCode &&
            exp != null &&
            exp.currency != baseCurrencyCode
        ? exp.currency
        : payment.currency;
    final inheritedRate = inheritedCurrency == payment.currency
        ? payment.exchangeRate
        : (exp?.exchangeRate ?? 1.0);
    final effectiveFunding = funding ?? payment.funding;
    final sumFunding =
        effectiveFunding.fold(0.0, (s, a) => s + a.amount);
    if ((sumFunding - clamped).abs() > 0.01) {
      throw Exception('مجموع التمويل يجب أن يساوي مبلغ الدفعة ($clamped ر.ي)');
    }
    validateFunding(effectiveFunding);
    _expensePayments.add(ExpensePayment(
      id: payment.id,
      expenseId: payment.expenseId,
      amount: clamped,
      date: payment.date,
      walletId: payment.walletId,
      notes: payment.notes,
      funding: effectiveFunding,
      currency: inheritedCurrency,
      exchangeRate: inheritedRate,
    ));
    _saveRefData();
    notifyListeners();
  }

  void deleteExpensePayment(String paymentId) {
    final existed = _expensePayments.any((p) => p.id == paymentId);
    if (!existed) return;

    // الحركة النقدية المرتبطة بهذه الدفعة يجب أن تُحذف معها؛
    // وإلا سيبقى سحب مالي بلا دفعة مصروف مقابلة.
    _moneyMovements.removeWhere((m) => m.paymentId == paymentId);
    _expensePayments.removeWhere((p) => p.id == paymentId);

    _saveAll();
    notifyListeners();
  }

  List<ExpensePayment> expensePaymentsFor(String expenseId) =>
      _expensePayments.where((p) => p.expenseId == expenseId).toList();

  List<ExpensePayment> getExpensePaymentsForWallet(String walletId) =>
      _expensePayments.where((p) => p.walletId == walletId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  double paidForExpense(String expenseId) => _expensePayments
      .where((p) => p.expenseId == expenseId)
      .fold(0.0, (s, p) => s + p.amount);

  double expenseRemainingAmount(String expenseId) {
    final e = _expenses.firstWhereOrNull((ex) => ex.id == expenseId);
    if (e == null) return 0;
    return (e.amount - paidForExpense(expenseId)).clamp(0, double.infinity);
  }

  void updateIncomePayment(IncomePayment updated) {
    final idx = _incomePayments.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    if (updated.amount <= 0) {
      throw Exception('مبلغ دفعة الإيراد يجب أن يكون أكبر من صفر');
    }
    if (updated.walletId == null || updated.walletId!.trim().isEmpty) {
      throw Exception('يجب تحديد المحفظة عند تعديل دفعة إيراد');
    }
    final old = _incomePayments[idx];
    final income = _incomes.firstWhereOrNull((i) => i.id == updated.incomeId);

    // لا يمكن تخفيض الدفعة عن المبلغ الملتزم به (تصريفات + مصروفات مرتبطة)
    final committed =
        totalExpensesForPayment(updated.id) +
        disbursedForPayment(updated.id) +
        fundedForPayment(updated.id);
    if (updated.amount < committed - 0.001) {
      throw Exception(
          'لا يمكن تخفيض الدفعة عن المبلغ الملتزم به (${committed.toStringAsFixed(2)} ر.ي)');
    }

    // لا يمكن زيادة الدفعة بحيث يتجاوز مجموع الدفعات مبلغ الإيراد
    final remaining = (income?.remainingAmount ?? 0) > 0
        ? income!.remainingAmount
        : 0;
    final maxAllowed = old.amount + remaining;
    if (updated.amount > maxAllowed + 0.001) {
      throw Exception(
          'لا يمكن أن يتجاوز مجموع الدفعات مبلغ الإيراد (${income!.amount.toStringAsFixed(2)} ر.ي)');
    }

    final inheritedCurrency = updated.currency == baseCurrencyCode &&
            income != null &&
            income.currency != baseCurrencyCode
        ? income.currency
        : updated.currency;
    final inheritedRate = inheritedCurrency == updated.currency
        ? updated.exchangeRate
        : (income?.exchangeRate ?? 1.0);

    final finalUpdated = IncomePayment(
      id: updated.id,
      incomeId: updated.incomeId,
      amount: updated.amount,
      date: updated.date,
      notes: updated.notes,
      walletId: updated.walletId,
      currency: inheritedCurrency,
      exchangeRate: inheritedRate,
    );

    _incomePayments[idx] = finalUpdated;
    if (income != null) {
      income.removePayment(old.id);
      income.addPayment(finalUpdated);
      // إعادة حساب الحالة بناءً على المبلغ المتبقي
      income.status = income.remainingAmount <= 0 ? 'confirmed' : 'pending';
    }
    _rebuildLinkedExpenses();
    _saveAll();
    notifyListeners();
  }

  void confirmIncome(String incomeId) {
    final idx = _incomes.indexWhere((i) => i.id == incomeId);
    if (idx != -1) {
      _incomes[idx].status = 'confirmed';
      _saveAll();
      notifyListeners();
    }
  }

  List<Partnership> getActivePartnershipsForLandPlot(String landPlotId, DateTime date) {
    return _partnerships.where((p) =>
        p.landPlotId == landPlotId && p.isActiveAt(date)).toList();
  }

  // --- Partnership CRUD ---

  void addPartnership(Partnership p) {
    if (p.id.trim().isEmpty) throw Exception('معرّف الشراكة غير صالح');
    if (_partnerships.any((e) => e.id == p.id)) {
      throw Exception('الشراكة موجودة مسبقاً');
    }
    if (p.landPlotId.trim().isEmpty ||
        !_landPlots.any((e) => e.id == p.landPlotId)) {
      throw Exception('يجب تحديد موضع صالح للشراكة');
    }
    if (p.partnerId.trim().isEmpty ||
        !_partners.any((e) => e.id == p.partnerId)) {
      throw Exception('يجب تحديد شريك صالح');
    }
    if (p.role != 'water' && p.role != 'worker') {
      throw Exception('نوع الشراكة غير صالح');
    }
    if (p.sharePercentage <= 0 || p.sharePercentage > 100) {
      throw Exception('نسبة الشراكة يجب أن تكون أكبر من صفر ولا تتجاوز 100%');
    }
    if (p.endDate != null && p.endDate!.isBefore(p.startDate)) {
      throw Exception('تاريخ نهاية الشراكة لا يمكن أن يسبق تاريخ بدايتها');
    }
    _partnerships.add(p);
    _syncDistributionsForPartnershipScope(p.landPlotId);
    _saveAll();
    notifyListeners();
  }

  void updatePartnership(Partnership updated) {
    final idx = _partnerships.indexWhere((e) => e.id == updated.id);
    if (updated.landPlotId.trim().isEmpty ||
        !_landPlots.any((e) => e.id == updated.landPlotId)) {
      throw Exception('يجب تحديد موضع صالح للشراكة');
    }
    if (updated.partnerId.trim().isEmpty ||
        !_partners.any((e) => e.id == updated.partnerId)) {
      throw Exception('يجب تحديد شريك صالح');
    }
    if (updated.role != 'water' && updated.role != 'worker') {
      throw Exception('نوع الشراكة غير صالح');
    }
    if (updated.sharePercentage <= 0 || updated.sharePercentage > 100) {
      throw Exception('نسبة الشراكة يجب أن تكون أكبر من صفر ولا تتجاوز 100%');
    }
    if (updated.endDate != null && updated.endDate!.isBefore(updated.startDate)) {
      throw Exception('تاريخ نهاية الشراكة لا يمكن أن يسبق تاريخ بدايتها');
    }
    if (idx != -1) {
      final oldPlotId = _partnerships[idx].landPlotId;
      _partnerships[idx] = updated;
      _syncDistributionsForPartnershipScope(updated.landPlotId);
      if (oldPlotId != updated.landPlotId) {
        _syncDistributionsForPartnershipScope(oldPlotId);
      }
      _saveAll();
      notifyListeners();
    }
  }

  void deletePartnership(String id) {
    final part = _partnerships.firstWhereOrNull((e) => e.id == id);
    if (part == null) return;
    final plotId = part.landPlotId;
    _partnerships.removeWhere((e) => e.id == id);
    // تنظيف التوزيعات غير المسددة المرتبطة بالموضع وإعادة مزامنتها مع العقود المتبقية
    _syncDistributionsForPartnershipScope(plotId);
    _saveAll();
    notifyListeners();
  }

  /// يتحقق مما إذا كانت للشراكة توزيعات أرباح مسددة بالفعل نقداً
  bool partnershipHasPaidDistributions(String partnershipId) {
    final part = _partnerships.firstWhereOrNull((p) => p.id == partnershipId);
    if (part == null) return false;
    for (final inc in _incomes.where((i) => i.landPlotId == part.landPlotId)) {
      if (part.isActiveAt(inc.date)) {
        final hasPaid = _distributions.any((d) =>
            d.incomeId == inc.id &&
            d.partnerId == part.partnerId &&
            d.role == part.role &&
            d.isPaid);
        if (hasPaid) return true;
      }
    }
    return false;
  }

  /// مزامنة دقيقة للتوزيعات لإيرادات موضع معين وفق عقود الشراكة الفعلية النشطة:
  /// - يحذف التوزيعات غير المسددة التي لم يعد لها عقد شراكة نشط
  /// - يحدّث مبالغ التوزيعات غير المسددة لتطابق النسب الحالية
  /// - يضيف التوزيعات المستحقة للعقود الجديدة دون المساس بأي توزيعات سُددت بالفعل
  void _syncDistributionsForPartnershipScope(String landPlotId) {
    final relevantIncomes =
        _incomes.where((i) => i.landPlotId == landPlotId).toList();
    for (final income in relevantIncomes) {
      _syncDistributionsForIncomeInternal(income);
    }
  }

  void _syncDistributionsForIncomeInternal(Income income) {
    if (income.landPlotId == null) return;
    LandPlot? plot;
    try {
      plot = _landPlots.firstWhere((p) => p.id == income.landPlotId);
    } catch (_) {}
    if (plot == null) return;

    final active =
        getActivePartnershipsForLandPlot(income.landPlotId!, income.date);

    if (active.isEmpty) {
      // لا توجد أي شراكة نشطة في هذا التاريخ: حذف أي توزيعات غير مسددة معلقة
      _distributions.removeWhere(
          (d) => d.incomeId == income.id && !d.isPaid);
      return;
    }

    final b = computeIncomeBreakdown(income.amount, plot.hasZakat, active);

    // 1. حذف التوزيعات غير المسددة التي لم يعد شريكها أو دورها نشطاً لهذا الإيراد
    _distributions.removeWhere((d) {
      if (d.incomeId != income.id || d.isPaid) return false;
      return !active.any((p) => p.partnerId == d.partnerId && p.role == d.role);
    });

    // 2. تحديث التوزيعات الحالية غير المسددة أو إضافة توزيعات الشركاء الجدد
    for (final p in active) {
      final share = b.afterZakat * p.sharePercentage / 100;
      if (share <= 0) continue;
      final existingIdx = _distributions.indexWhere((d) =>
          d.incomeId == income.id &&
          d.partnerId == p.partnerId &&
          d.role == p.role);
      if (existingIdx != -1) {
        // إذا لم تكن مسددة، حدّث المبلغ ليطابق النسبة المعدلة
        if (!_distributions[existingIdx].isPaid) {
          _distributions[existingIdx].amount = share;
        }
      } else {
        // شريك جديد: إضافة حصته المستحقة بدقة
        _distributions.add(Distribution(
          id: const Uuid().v4(),
          incomeId: income.id,
          partnerId: p.partnerId,
          role: p.role,
          amount: share,
        ));
      }
    }
  }

  // --- Partner CRUD ---

  void addPartner(Partner p) {
    if (p.id.trim().isEmpty) throw Exception('معرّف الشريك غير صالح');
    if (p.name.trim().isEmpty) throw Exception('اسم الشريك مطلوب');
    if (_partners.any((e) => e.id == p.id)) {
      throw Exception('الشريك موجود مسبقاً');
    }
    _partners.add(p);
    _saveRefData();
    notifyListeners();
  }

  void updatePartner(Partner updated) {
    final idx = _partners.indexWhere((e) => e.id == updated.id);
    if (updated.name.trim().isEmpty) throw Exception('اسم الشريك مطلوب');
    if (idx != -1) {
      _partners[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deletePartner(String id) {
    final hasHistory = _partnerships.any((p) => p.partnerId == id) ||
        _distributions.any((d) => d.partnerId == id);
    if (hasHistory) return false;
    _partners.removeWhere((e) => e.id == id);
    _saveAll();
    notifyListeners();
    return true;
  }

  // --- Distribution CRUD ---

  void addDistribution(Distribution d) {
    String? paidWalletId;
    if (d.isPaid && !_moneyMovements.any((m) => m.distributionId == d.id)) {
      final inc = _incomes.firstWhereOrNull((i) => i.id == d.incomeId);
      final effectiveWalletId = inc?.walletId ??
          defaultWallet()?.id ??
          (_wallets.isNotEmpty ? _wallets.first.id : '');
      if (effectiveWalletId.trim().isEmpty) {
        throw Exception('لا يمكن تسجيل حصة شريك مسددة دون تحديد محفظة');
      }
      paidWalletId = effectiveWalletId;
    }
    _distributions.add(d);
    if (d.isPaid && !_moneyMovements.any((m) => m.distributionId == d.id)) {
      final inc = _incomes.firstWhereOrNull((i) => i.id == d.incomeId);
      final effectiveWalletId = paidWalletId!;
      _moneyMovements.add(MoneyMovement(
        id: const Uuid().v4(),
        walletId: effectiveWalletId,
        amount: d.amount,
        date: d.paidDate ?? inc?.date ?? DateTime.now(),
        distributionId: d.id,
        incomeId: inc?.id,
        note: 'تسديد حصة شريك (تسوية استيراد)',
      ));
    }
    _saveRefData();
    notifyListeners();
  }

  /// يضمن وجود توزيعة لكل شراكة نشطة في تاريخ الإيراد، ويزيل أي توزيعة غير مسددة معلقة.
  void ensureDistributionsForIncome(String incomeId) {
    final income = _incomes.firstWhereOrNull((i) => i.id == incomeId);
    if (income == null) return;
    _syncDistributionsForIncomeInternal(income);
    _saveAll();
    notifyListeners();
  }

  /// يضمن تطابق التوزيعات لكل الإيرادات المرتبطة بمواضع مع عقود الشراكات الفعلية.
  void ensureAllDistributions() {
    for (final income in _incomes.toList()) {
      _syncDistributionsForIncomeInternal(income);
    }
    _saveAll();
    notifyListeners();
  }

  void markDistributionPaid(
      String id, DateTime date, List<ExpenseAllocation> funding, {String? walletId}) {
    final idx = _distributions.indexWhere((d) => d.id == id);
    if (idx != -1) {
      final d = _distributions[idx];
      if (d.amount <= 0.001) {
        throw Exception('مبلغ حصة الشريك يجب أن يكون أكبر من صفر');
      }
      if (d.isPaid || _moneyMovements.any((m) => m.distributionId == d.id)) return;
      if (funding.isEmpty) {
        throw Exception('غير مسموح بالاستقطاع المباشر من المحفظة دون تحديد دفعة إيراد نقدية');
      }
      final total = funding.fold(0.0, (s, a) => s + a.amount);
      if ((total - d.amount).abs() > 0.01) {
        throw Exception(
            'مجموع الاستقطاع يجب أن يساوي مبلغ الحصة (${d.amount.toStringAsFixed(2)} ر.ي)');
      }
      validateFunding(funding);
      final firstPayment = _incomePayments
          .firstWhereOrNull((p) => p.id == funding.first.paymentId);
      final income = firstPayment != null
          ? _incomes.firstWhereOrNull((i) => i.id == firstPayment.incomeId)
          : null;
      final effectiveWalletId = income?.walletId ??
          walletId ??
          defaultWallet()?.id ??
          (_wallets.isNotEmpty ? _wallets.first.id : '');
      if (effectiveWalletId.trim().isEmpty) {
        throw Exception('لا يمكن تسجيل حصة شريك مسددة دون تحديد محفظة');
      }
      _distributions[idx].isPaid = true;
      _distributions[idx].paidDate = date;
      _moneyMovements.add(MoneyMovement(
        id: const Uuid().v4(),
        walletId: effectiveWalletId,
        amount: d.amount,
        date: date,
        distributionId: d.id,
        incomeId: income?.id,
        note: 'تسديد حصة شريك',
        funding: funding,
      ));
      _saveAll();
      notifyListeners();
    }
  }

  static const String debtTemporaryIncomeId = '__debt_settlements__';

  /// يخصص استقطاعات تلقائية من دفعات الإيرادات المتاحة لتغطية مبلغ مطلوب
  List<ExpenseAllocation> autoAllocateFunding(double requiredAmount,
      {String? walletFilter, String currency = baseCurrencyCode}) {
    final allocations = <ExpenseAllocation>[];
    var needed = requiredAmount;
    final payments = _incomePayments.where((p) {
      if (p.currency != currency) return false;
      if (walletFilter != null) {
        if (incomePaymentWalletId(p.id) != walletFilter) return false;
      }
      return paymentAvailable(p.id) > 0.001;
    }).toList();

    for (final p in payments) {
      if (needed <= 0.001) break;
      final avail = paymentAvailable(p.id);
      final take = needed < avail ? needed : avail;
      if (take > 0.001) {
        final rounded = double.parse(take.toStringAsFixed(2));
        allocations.add(ExpenseAllocation(
          incomeId: p.incomeId,
          paymentId: p.id,
          amount: rounded,
          currency: p.currency,
        ));
        needed -= rounded;
      }
    }

    if (needed > 0.001) {
      final settlements = debtFundingSources.where((s) {
        if (s.currency != currency) return false;
        if (walletFilter != null && s.walletId != walletFilter) return false;
        return debtFundingAvailable(s.id) > 0.001;
      }).toList();

      for (final s in settlements) {
        if (needed <= 0.001) break;
        final avail = debtFundingAvailable(s.id);
        final take = needed < avail ? needed : avail;
        if (take > 0.001) {
          final rounded = double.parse(take.toStringAsFixed(2));
          allocations.add(ExpenseAllocation(
            incomeId: '',
            debtSettlementId: s.id,
            debtId: s.debtId,
            amount: rounded,
            currency: s.currency,
          ));
          needed -= rounded;
        }
      }
    }

    return allocations;
  }

  /// استقطاع من دفعة إيراد محددة
  List<ExpenseAllocation> allocateFromSpecificIncomePayment(
      String paymentId, double requiredAmount) {
    final avail = paymentAvailable(paymentId);
    final take = requiredAmount < avail ? requiredAmount : avail;
    if (take <= 0.001) return [];
    final payment = _incomePayments.firstWhereOrNull((p) => p.id == paymentId);
    if (payment == null) return [];
    final rounded = double.parse(take.toStringAsFixed(2));
    return [
      ExpenseAllocation(
        incomeId: payment.incomeId,
        paymentId: payment.id,
        amount: rounded,
        currency: payment.currency,
      )
    ];
  }

  /// إجمالي المبالغ المتاحة للاستقطاع عبر كل دفعات الإيرادات والديون المستلمة (تمويل مؤقت)
  double totalFundingAvailable({String? walletFilter}) {
    final incomeFunding = _incomePayments.where((p) {
      if (walletFilter != null) {
        if (incomePaymentWalletId(p.id) != walletFilter) return false;
      }
      return true;
    }).fold(0.0, (s, p) => s + (paymentAvailable(p.id).clamp(0.0, double.infinity)));

    final debtFunding = debtFundingSources.where((s) {
      if (walletFilter != null && s.walletId != walletFilter) return false;
      return true;
    }).fold(0.0, (sum, s) => sum + (debtFundingAvailable(s.id).clamp(0.0, double.infinity)));

    return incomeFunding + debtFunding;
  }

  /// دفعات استلام الديون الشخصية المستحقة لنا (التي دخلت كسيولة نقدية)
  List<PersonalDebtSettlement> get receivableDebtSettlements {
    final receivableDebtIds = _personalDebts
        .where((d) => d.direction == 'receivable')
        .map((d) => d.id)
        .toSet();
    return _personalDebtSettlements
        .where((s) => receivableDebtIds.contains(s.debtId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<DebtFundingSource> get debtFundingSources {
    final sources = <DebtFundingSource>[];
    for (final settlement in receivableDebtSettlements) {
      if (settlement.walletId.isEmpty) continue;
      sources.add(DebtFundingSource(
        id: settlement.id,
        debtId: settlement.debtId,
        amount: settlement.amount,
        date: settlement.date,
        walletId: settlement.walletId,
        note: settlement.note,
        isSettlement: true,
        currency: settlement.currency,
        exchangeRate: settlement.exchangeRate,
      ));
    }
    for (final debt in _personalDebts.where(
        (d) => d.direction == 'payable' && d.walletId?.isNotEmpty == true)) {
      sources.add(DebtFundingSource(
        id: 'debt_borrow_${debt.id}',
        debtId: debt.id,
        amount: debt.amount,
        date: debt.date,
        walletId: debt.walletId!,
        note: debt.note,
        isSettlement: false,
        currency: baseCurrencyCode,
        exchangeRate: 1.0,
      ));
    }
    return sources..sort((a, b) => b.date.compareTo(a.date));
  }

  double debtFundingAvailable(String sourceId, {String? excludeExpenseId}) {
    final source = debtFundingSources.firstWhereOrNull((s) => s.id == sourceId);
    if (source == null) return 0;
    var used = 0.0;
    for (final expense in _expenses) {
      if (expense.id == excludeExpenseId) continue;
      used += expense.allocations
          .where((a) => a.debtSettlementId == sourceId)
          .fold(0.0, (sum, a) => sum + a.amount);
    }
    for (final payment in _expensePayments) {
      used += payment.funding
          .where((a) => a.debtSettlementId == sourceId)
          .fold(0.0, (sum, a) => sum + a.amount);
    }
    for (final movement in _moneyMovements) {
      used += movement.funding
          .where((a) => a.debtSettlementId == sourceId)
          .fold(0.0, (sum, a) => sum + a.amount);
    }
    return (source.amount - used).clamp(0.0, double.infinity);
  }

  /// المبلغ المتاح للصرف من دفعة استلام دين شخصي محددة (بعد استبعاد ما تم استقطاعه منها)
  double debtSettlementAvailable(String settlementId, {String? excludeExpenseId}) {
    final settlement =
        _personalDebtSettlements.firstWhereOrNull((s) => s.id == settlementId);
    if (settlement == null) return 0;
    final debt =
        _personalDebts.firstWhereOrNull((d) => d.id == settlement.debtId);
    if (debt == null || debt.direction != 'receivable') return 0;

    double used = 0;
    for (final e in _expenses) {
      if (e.id == excludeExpenseId) continue;
      for (final a in e.allocations) {
        if (a.debtSettlementId == settlementId) used += a.amount;
      }
    }
    for (final ep in _expensePayments) {
      for (final a in ep.funding) {
        if (a.debtSettlementId == settlementId) used += a.amount;
      }
    }
    for (final m in _moneyMovements) {
      for (final a in m.funding) {
        if (a.debtSettlementId == settlementId) used += a.amount;
      }
    }
    return (settlement.amount - used).clamp(0.0, double.infinity);
  }

  /// إجمالي المبالغ المتاحة للاستقطاع عبر كل دفعات استلام الديون
  double totalDebtSettlementFundingAvailable({String? walletFilter}) {
    return debtFundingSources.where((s) {
      if (walletFilter != null && s.walletId != walletFilter) return false;
      return true;
    }).fold(0.0, (sum, s) => sum + debtFundingAvailable(s.id));
  }

  /// استقطاع من دفعة استلام دين محددة
  List<ExpenseAllocation> allocateFromSpecificDebtSettlement(
      String settlementId, double requiredAmount) {
    return allocateFromSpecificDebtFundingSource(settlementId, requiredAmount);
  }

  List<ExpenseAllocation> allocateFromSpecificDebtFundingSource(
      String sourceId, double requiredAmount) {
    final avail = debtFundingAvailable(sourceId);
    final take = requiredAmount < avail ? requiredAmount : avail;
    if (take <= 0.001) return [];
    final source = debtFundingSources.firstWhereOrNull((s) => s.id == sourceId);
    if (source == null) return [];
    final rounded = double.parse(take.toStringAsFixed(2));
    return [
      ExpenseAllocation(
        incomeId: '',
        debtSettlementId: source.id,
        debtId: source.debtId,
        amount: rounded,
        currency: source.currency,
      )
    ];
  }

  /// استقطاع تلقائي من دفعات استلام الديون المتاحة
  List<ExpenseAllocation> autoAllocateDebtSettlementFunding(
      double requiredAmount,
      {String? walletFilter, String currency = baseCurrencyCode}) {
    final allocations = <ExpenseAllocation>[];
    var needed = requiredAmount;
    final settlements = debtFundingSources.where((s) {
      if (s.currency != currency) return false;
      if (walletFilter != null && s.walletId != walletFilter) return false;
      return debtFundingAvailable(s.id) > 0.001;
    }).toList();

    for (final s in settlements) {
      if (needed <= 0.001) break;
      final avail = debtFundingAvailable(s.id);
      final take = needed < avail ? needed : avail;
      if (take > 0.001) {
        final rounded = double.parse(take.toStringAsFixed(2));
        allocations.add(ExpenseAllocation(
          incomeId: '',
          debtSettlementId: s.id,
          debtId: s.debtId,
          amount: rounded,
          currency: s.currency,
        ));
        needed -= rounded;
      }
    }
    return allocations;
  }

  /// سداد كافة الحصص المستحقة وغير المسددة لشريك في موضع محدد أو عموماً مع ربطها بدفعات الإيراد المحددة
  void payAllPartnerDistributions({
    required String partnerId,
    String? landPlotId,
    required DateTime date,
    required List<ExpenseAllocation> funding,
  }) {
    if (funding.isEmpty) {
      throw Exception('غير مسموح بالاستقطاع المباشر من المحفظة، يجب اختيار إيراد ودفعات نقدية متاحة');
    }

    final unpaid = _distributions.where((d) {
      if (d.partnerId != partnerId || isDistributionPaid(d)) return false;
      if (landPlotId != null) {
        final inc = _incomes.firstWhereOrNull((i) => i.id == d.incomeId);
        if (inc?.landPlotId != landPlotId) return false;
      }
      return true;
    }).toList();

    if (unpaid.isEmpty) return;

    final totalUnpaid = unpaid.fold(0.0, (s, d) => s + d.amount);
    final totalFunding = funding.fold(0.0, (s, a) => s + a.amount);
    if ((totalFunding - totalUnpaid).abs() > 0.01) {
      throw Exception(
          'مجموع التمويل (${totalFunding.toStringAsFixed(2)} ر.ي) يجب أن يغطي إجمالي المستحقات (${totalUnpaid.toStringAsFixed(2)} ر.ي)');
    }
    validateFunding(funding);

    // توزيع مخصصات التمويل المختارة على الحصص المستحقة بالتتابع
    var remainingAllocations = funding.map((a) => ExpenseAllocation(
      incomeId: a.incomeId,
      paymentId: a.paymentId,
      debtSettlementId: a.debtSettlementId,
      debtId: a.debtId,
      amount: a.amount,
      currency: a.currency,
    )).toList();

    for (final d in unpaid) {
      var needed = d.amount;
      final distFunding = <ExpenseAllocation>[];

      while (needed > 0.001 && remainingAllocations.isNotEmpty) {
        final currentAlloc = remainingAllocations.first;
        if (currentAlloc.amount <= needed + 0.001) {
          distFunding.add(currentAlloc);
          needed -= currentAlloc.amount;
          remainingAllocations.removeAt(0);
        } else {
          distFunding.add(ExpenseAllocation(
            incomeId: currentAlloc.incomeId,
            paymentId: currentAlloc.paymentId,
            debtSettlementId: currentAlloc.debtSettlementId,
            debtId: currentAlloc.debtId,
            amount: needed,
            currency: currentAlloc.currency,
          ));
          currentAlloc.amount -= needed;
          needed = 0;
        }
      }

      markDistributionPaid(d.id, date, distFunding);
    }
  }

  /// سداد مجمع لأجور عمال متعددين دفعة واحدة
  void batchPayWorkerWages({
    required List<({String workerId, double amount})> workerPayouts,
    required DateTime date,
    String? walletId,
    String fundingSource = 'income', // 'income' (دفعات الإيرادات) | 'debt_settlement' (استلام الديون الشخصية)
    String? specificIncomePaymentId,
    String? specificDebtSettlementId,
    String? note,
  }) {
    // Resolve wallet from the specific receipt payment if available
    String? paymentWalletId;
    if (fundingSource == 'income' && specificIncomePaymentId != null) {
      final p = _incomePayments.firstWhereOrNull((ip) => ip.id == specificIncomePaymentId);
      final inc = _incomes.firstWhereOrNull((i) => i.id == p?.incomeId);
      paymentWalletId = inc?.walletId;
    } else if (fundingSource == 'debt_settlement' && specificDebtSettlementId != null) {
      final s = debtFundingSources.firstWhereOrNull((ds) => ds.id == specificDebtSettlementId);
      paymentWalletId = s?.walletId;
    }

    final effectiveWalletId = paymentWalletId ??
        walletId ??
        defaultWallet()?.id ??
        (_wallets.isNotEmpty ? _wallets.first.id : '');

    final effectiveSource = fundingSource;

    for (final wp in workerPayouts) {
      if (wp.amount <= 0.001) continue;
      final worker = _workers.firstWhereOrNull((w) => w.id == wp.workerId);
      final workerName = worker?.name ?? 'عامل';
      final pNote = note ?? 'سداد مجمع لأجور العامل: $workerName';

      var remainingToPay = wp.amount;
      // نسدد المصروفات غير المسددة المرتبطة بهذا العامل أولاً
      final unpaidExpenses = _expenses
          .where((e) => e.workerId == wp.workerId)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      for (final exp in unpaidExpenses) {
        if (remainingToPay <= 0.001) break;
        final expRem = expenseRemainingAmount(exp.id);
        if (expRem > 0.001) {
          final toPay = remainingToPay < expRem ? remainingToPay : expRem;
          final rounded = double.parse(toPay.toStringAsFixed(2));
          List<ExpenseAllocation> funding = [];
          if (effectiveSource == 'income') {
            if (specificIncomePaymentId != null) {
              funding = allocateFromSpecificIncomePayment(
                  specificIncomePaymentId, rounded);
            } else {
              throw Exception('الاستقطاع التلقائي غير مسموح، يجب اختيار دفعة إيراد نقدية محددة');
            }
          } else if (effectiveSource == 'debt_settlement') {
            if (specificDebtSettlementId != null) {
              funding = allocateFromSpecificDebtFundingSource(
                  specificDebtSettlementId, rounded);
            } else {
              throw Exception('الاستقطاع التلقائي غير مسموح، يجب اختيار دفعة استلام محددة');
            }
          }
          _expensePayments.add(ExpensePayment(
            id: const Uuid().v4(),
            expenseId: exp.id,
            amount: rounded,
            date: date,
            walletId: effectiveWalletId,
            notes: pNote,
            funding: funding,
          ));
          remainingToPay -= rounded;
        }
      }

      // إذا بقي مبلغ إضافي لم يتطابق مع مصروفات محددة يُسجل كتسديد تراكمي (ظهر الحساب)
      if (remainingToPay > 0.001) {
        final rounded = double.parse(remainingToPay.toStringAsFixed(2));
        List<ExpenseAllocation> funding = [];
        if (effectiveSource == 'income') {
          if (specificIncomePaymentId != null) {
            funding = allocateFromSpecificIncomePayment(
                specificIncomePaymentId, rounded);
          } else {
            throw Exception('الاستقطاع التلقائي غير مسموح، يجب اختيار دفعة إيراد نقدية محددة');
          }
        } else if (effectiveSource == 'debt_settlement') {
          if (specificDebtSettlementId != null) {
            funding = allocateFromSpecificDebtFundingSource(
                specificDebtSettlementId, rounded);
          } else {
            throw Exception('الاستقطاع التلقائي غير مسموح، يجب اختيار دفعة استلام محددة');
          }
        }
        _moneyMovements.add(MoneyMovement(
          id: const Uuid().v4(),
          walletId: effectiveWalletId,
          amount: rounded,
          date: date,
          note: pNote,
          creditorType: 'w',
          creditorId: wp.workerId,
          funding: funding,
        ));
      }
    }

    _saveAll();
    _saveRefData();
    notifyListeners();
  }

  void deleteDistribution(String id) {
    _distributions.removeWhere((d) => d.id == id);
    _moneyMovements.removeWhere((m) => m.distributionId == id);
    _saveAll();
    notifyListeners();
  }

  List<Distribution> getDistributionsForIncome(String incomeId) {
    return _distributions.where((d) => d.incomeId == incomeId).toList();
  }

  List<Distribution> getDistributionsForPartner(String partnerId) {
    return _distributions.where((d) => d.partnerId == partnerId).toList();
  }

  /// التحقق الموحد من سداد الحصة بالاعتماد على سجل الحركات النقدية للصندوق كمصدر أصيل للحقيقة
  bool isDistributionPaid(Distribution d) {
    return _moneyMovements.any((m) => m.distributionId == d.id);
  }

  double get pendingPartnerTotal => _distributions
      .where((d) => !isDistributionPaid(d))
      .fold(0.0, (s, d) => s + d.amount);
  double get paidPartnerTotal => _distributions
      .where((d) => isDistributionPaid(d))
      .fold(0.0, (s, d) => s + d.amount);

  // --- Zakat Accounting & Ledger Methods ---

  /// جميع استحقاقات الزكاة الواجبة (المحسوبة تلقائياً من إيرادات المواضع ذات الزكاة + الاستحقاقات اليدوية)
  List<ZakatEntry> get allZakatEntries {
    final list = <ZakatEntry>[..._zakatEntries];
    for (final inc in _incomes) {
      if (inc.landPlotId == null) continue;
      LandPlot? plot;
      try {
        plot = _landPlots.firstWhere((p) => p.id == inc.landPlotId);
      } catch (_) {}
      if (plot != null && plot.hasZakat) {
        final activePartnerships =
            getActivePartnershipsForLandPlot(plot.id, inc.date);
        final b = computeIncomeBreakdown(inc.amount, true, activePartnerships);
        if (b.zakat > 0) {
          list.add(ZakatEntry(
            id: 'inc_${inc.id}',
            incomeId: inc.id,
            landPlotId: plot.id,
            title: 'زكاة زروع: ${inc.title}',
            date: inc.date,
            amount: b.zakat,
            type: 'crops',
            notes: 'محسوبة بنسبة 5% من إجمالي إيراد الزهرة (${inc.title})',
          ));
        }
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// إجمالي الزكاة الواجبة في الذمة (دائن)
  double get totalZakatDue =>
      allZakatEntries.fold(0.0, (s, e) => s + e.amount);

  /// إجمالي الزكاة المُخرَجة / المدفوعة (مدين)
  double get totalZakatPaid =>
      _zakatPayments.fold(0.0, (s, p) => s + p.amount);

  /// المتبقي من الزكاة الواجب إخراجها
  double get totalZakatRemaining =>
      (totalZakatDue - totalZakatPaid).clamp(0.0, double.infinity);

  /// مقدار الزكاة الواجبة لإيراد معين
  double zakatDueForIncome(String incomeId) {
    final inc = _incomes.firstWhereOrNull((i) => i.id == incomeId);
    if (inc == null || inc.landPlotId == null) return 0;
    LandPlot? plot;
    try {
      plot = _landPlots.firstWhere((p) => p.id == inc.landPlotId);
    } catch (_) {}
    if (plot == null || !plot.hasZakat) return 0;
    final active = getActivePartnershipsForLandPlot(plot.id, inc.date);
    return computeIncomeBreakdown(inc.amount, true, active).zakat;
  }

  /// مقدار الزكاة المدفوعة لإيراد معين
  double zakatPaidForIncome(String incomeId) {
    return _zakatPayments
        .where((p) => p.incomeId == incomeId || p.zakatEntryId == 'inc_$incomeId')
        .fold(0.0, (s, p) => s + p.amount);
  }

  /// المتبقي من زكاة إيراد معين
  double zakatRemainingForIncome(String incomeId) {
    final due = zakatDueForIncome(incomeId);
    final paid = zakatPaidForIncome(incomeId);
    return (due - paid).clamp(0.0, double.infinity);
  }

  /// مقدار المدفوع من استحقاق زكاة معين
  double zakatPaidForEntry(ZakatEntry entry) {
    if (entry.incomeId != null) {
      return zakatPaidForIncome(entry.incomeId!);
    }
    return _zakatPayments
        .where((p) => p.zakatEntryId == entry.id)
        .fold(0.0, (s, p) => s + p.amount);
  }

  /// المتبقي من استحقاق زكاة معين
  double zakatRemainingForEntry(ZakatEntry entry) {
    final paid = zakatPaidForEntry(entry);
    return (entry.amount - paid).clamp(0.0, double.infinity);
  }

  /// المدفوعات التابعة لاستحقاق معين
  List<ZakatPayment> getZakatPaymentsForEntry(ZakatEntry entry) {
    if (entry.incomeId != null) {
      return _zakatPayments
          .where((p) =>
              p.incomeId == entry.incomeId || p.zakatEntryId == entry.id)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    return _zakatPayments
        .where((p) => p.zakatEntryId == entry.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void addZakatPayment(ZakatPayment payment, {List<ExpenseAllocation>? funding}) {
    if (payment.amount <= 0) {
      throw Exception('مبلغ دفعة الزكاة يجب أن يكون أكبر من صفر');
    }
    if (payment.walletId.trim().isEmpty) {
      throw Exception('يجب تحديد المحفظة عند تسجيل دفعة الزكاة');
    }
    final effectiveFunding = funding ?? payment.funding;
    if (effectiveFunding.isNotEmpty) {
      final sumFunding = effectiveFunding.fold(0.0, (s, a) => s + a.amount);
      if ((sumFunding - payment.amount).abs() > 0.01) {
        throw Exception(
            'مجموع التمويل يجب أن يساوي مبلغ الدفعة (${payment.amount.toStringAsFixed(2)} ر.ي)');
      }
      validateFunding(effectiveFunding);
    }
    _zakatPayments.add(ZakatPayment(
      id: payment.id,
      zakatEntryId: payment.zakatEntryId,
      incomeId: payment.incomeId,
      amount: payment.amount,
      date: payment.date,
      walletId: payment.walletId,
      recipient: payment.recipient,
      recipientCategory: payment.recipientCategory,
      notes: payment.notes,
      funding: effectiveFunding,
    ));
    _moneyMovements.add(MoneyMovement(
      id: const Uuid().v4(),
      walletId: payment.walletId,
      amount: payment.amount,
      date: payment.date,
      zakatPaymentId: payment.id,
      incomeId: payment.incomeId,
      note: 'إخراج زكاة: ${payment.recipient?.isNotEmpty == true ? payment.recipient : (payment.recipientCategory ?? "مستحق")}',
      funding: effectiveFunding,
    ));
    _saveAll();
    notifyListeners();
  }

  void updateZakatPayment(ZakatPayment updated,
      {List<ExpenseAllocation>? funding}) {
    final idx = _zakatPayments.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    if (updated.amount <= 0) {
      throw Exception('مبلغ الزكاة يجب أن يكون أكبر من صفر');
    }
    if (updated.walletId.trim().isEmpty) {
      throw Exception('يجب تحديد المحفظة عند تعديل دفعة الزكاة');
    }
    final paidBeforeThis = _zakatPayments
        .where((p) => p.id != updated.id &&
            (p.incomeId == updated.incomeId ||
             p.zakatEntryId == updated.zakatEntryId))
        .fold(0.0, (s, p) => s + p.amount);
    final due = updated.incomeId != null
        ? zakatDueForIncome(updated.incomeId!)
        : (_zakatEntries.firstWhereOrNull((e) => e.id == updated.zakatEntryId)?.amount ?? double.infinity);
    if (due.isFinite && paidBeforeThis + updated.amount > due + 0.01) {
      throw Exception('لا يمكن أن يتجاوز مجموع مدفوعات الزكاة المستحق');
    }
    final effectiveFunding = funding ?? updated.funding;
    if (effectiveFunding.isNotEmpty) {
      final sumFunding = effectiveFunding.fold(0.0, (s, a) => s + a.amount);
      if ((sumFunding - updated.amount).abs() > 0.01) {
        throw Exception(
            'مجموع التمويل يجب أن يساوي مبلغ الدفعة (${updated.amount.toStringAsFixed(2)} ر.ي)');
      }
      validateFunding(effectiveFunding);
    }
    _zakatPayments[idx] = ZakatPayment(
      id: updated.id,
      zakatEntryId: updated.zakatEntryId,
      incomeId: updated.incomeId,
      amount: updated.amount,
      date: updated.date,
      walletId: updated.walletId,
      recipient: updated.recipient,
      recipientCategory: updated.recipientCategory,
      notes: updated.notes,
      funding: effectiveFunding,
    );
    final mIdx =
        _moneyMovements.indexWhere((m) => m.zakatPaymentId == updated.id);
    final noteStr =
        'إخراج زكاة: ${updated.recipient?.isNotEmpty == true ? updated.recipient : (updated.recipientCategory ?? "مستحق")}';
    if (mIdx != -1) {
      _moneyMovements[mIdx] = MoneyMovement(
        id: _moneyMovements[mIdx].id,
        walletId: updated.walletId,
        amount: updated.amount,
        date: updated.date,
        zakatPaymentId: updated.id,
        incomeId: updated.incomeId,
        note: noteStr,
        funding: effectiveFunding,
      );
    } else {
      _moneyMovements.add(MoneyMovement(
        id: const Uuid().v4(),
        walletId: updated.walletId,
        amount: updated.amount,
        date: updated.date,
        zakatPaymentId: updated.id,
        incomeId: updated.incomeId,
        note: noteStr,
        funding: effectiveFunding,
      ));
    }
    _saveAll();
    notifyListeners();
  }

  void deleteZakatPayment(String id) {
    _zakatPayments.removeWhere((p) => p.id == id);
    _moneyMovements.removeWhere((m) => m.zakatPaymentId == id);
    _saveAll();
    notifyListeners();
  }

  void addManualZakatEntry(ZakatEntry entry) {
    _zakatEntries.add(entry);
    _saveRefData();
    notifyListeners();
  }

  void updateManualZakatEntry(ZakatEntry updated) {
    final idx = _zakatEntries.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _zakatEntries[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  void deleteManualZakatEntry(String id) {
    _zakatEntries.removeWhere((e) => e.id == id);
    final removedPaymentIds = _zakatPayments
        .where((p) => p.zakatEntryId == id)
        .map((p) => p.id)
        .toSet();
    _zakatPayments.removeWhere((p) => p.zakatEntryId == id);
    _moneyMovements.removeWhere((m) =>
        m.zakatPaymentId != null &&
        removedPaymentIds.contains(m.zakatPaymentId));
    _saveAll();
    notifyListeners();
  }

  // --- WorkRecord CRUD ---

  void addWorkRecord(WorkRecord r) {
    _workRecords.insert(0, r);
    _saveRefData();
    notifyListeners();
  }

  void updateWorkRecord(WorkRecord updated) {
    final idx = _workRecords.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _workRecords[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  void deleteWorkRecord(String id) {
    final idx = _workRecords.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final rec = _workRecords[idx];
      if (rec.incomeId != null) {
        deleteIncome(rec.incomeId!);
      }
      _workRecords.removeAt(idx);
      _saveRefData();
      notifyListeners();
    }
  }

  bool workRecordOverlaps(WorkRecord r, {String? excludeId}) {
    return _workRecords.any((existing) {
      if (existing.id == excludeId) return false;
      return r.startTime.isBefore(existing.endTime) &&
          existing.startTime.isBefore(r.endTime);
    });
  }

  DateTime? lastWorkEndOn(DateTime date) {
    DateTime? last;
    for (final r in _workRecords) {
      final a = r.startTime;
      if (a.year == date.year && a.month == date.month && a.day == date.day) {
        if (last == null || r.endTime.isAfter(last)) last = r.endTime;
      }
    }
    return last;
  }

  // --- Worker CRUD ---

  void addWorker(Worker w) {
    if (w.id.trim().isEmpty) throw Exception('معرّف العامل غير صالح');
    if (w.name.trim().isEmpty) throw Exception('اسم العامل مطلوب');
    if (_workers.any((e) => e.id == w.id)) {
      throw Exception('العامل موجود مسبقاً');
    }
    _workers.insert(0, w);
    _saveRefData();
    notifyListeners();
  }

  void updateWorker(Worker updated) {
    final idx = _workers.indexWhere((e) => e.id == updated.id);
    if (updated.name.trim().isEmpty) throw Exception('اسم العامل مطلوب');
    if (idx != -1) {
      _workers[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deleteWorker(String id) {
    final used = _expenses.any((e) => e.workerId == id) ||
        _workRecords.any((r) => r.workerId == id);
    if (used) return false;
    _workers.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  List<Expense> expensesForEvent(String eventId) =>
      _expenses.where((e) => e.eventId == eventId).toList();

  List<Expense> wagesForWorker(String workerId) =>
      _expenses.where((e) => e.workerId == workerId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// مجموع تسديدات ظهر الحساب المسجلة على الدائن (عامل 'w' أو مورد 's').
  double creditorSettlementTotal(String creditorType, String creditorId) =>
      _moneyMovements
          .where((m) => m.creditorType == creditorType && m.creditorId == creditorId)
          .fold(0.0, (s, m) => s + m.amount);

  /// الرصيد المتبقي على العامل من الأجور غير المسددة (دين)
  /// مطروحاً منه تسديداته التراكمية من ظهر الحساب.
  double workerDebt(String workerId) {
    var debt = 0.0;
    for (final e in _expenses.where((e) => e.workerId == workerId)) {
      final rem = expenseRemainingButKeep(e.id);
      if (rem > 0) debt += rem;
    }
    debt -= creditorSettlementTotal('w', workerId);
    return debt > 0 ? debt : 0;
  }

  /// إجمالي دين المورد من فواتير الشراء غير المسددة،
  /// مطروحاً منه تسديداته التراكمية من ظهر الحساب.
  double supplierDebt(String partnerId) {
    var debt = 0.0;
    for (final p in _purchases.where((p) => p.supplierId == partnerId)) {
      final rem = p.remainingAmount.clamp(0.0, double.infinity).toDouble();
      if (rem > 0) debt += rem;
    }
    debt -= creditorSettlementTotal('s', partnerId);
    return debt > 0 ? debt : 0;
  }

  /// يشبه [expenseRemainingAmount] لكن بدون إعادة بناء القوائم.
  double expenseRemainingButKeep(String expenseId) {
    final paid = _expensePayments
        .where((p) => p.expenseId == expenseId)
        .fold(0.0, (s, p) => s + p.amount);
    final exp = _expenses.firstWhereOrNull((e) => e.id == expenseId);
    if (exp == null) return 0;
    return exp.amount - paid;
  }

  // --- Wallet CRUD ---

  void addWallet(Wallet wallet) {
    _wallets.add(wallet);
    _saveRefData();
    notifyListeners();
  }

  void updateWallet(Wallet updated) {
    final idx = _wallets.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _wallets[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deleteWallet(String id) {
    final hasReferences = _moneyMovements.any((m) => m.walletId == id) ||
        _personalDebtSettlements.any((s) => s.walletId == id) ||
        _personalDebts.any((d) => d.walletId == id) ||
        _incomes.any((i) => i.walletId == id) ||
        _expensePayments.any((p) => p.walletId == id) ||
        _incomePayments.any((p) => incomePaymentWalletId(p.id) == id);
    if (hasReferences) return false;
    _wallets.removeWhere((e) => e.id == id);
    _moneyMovements.removeWhere((m) => m.walletId == id);
    _personalDebtSettlements.removeWhere((s) => s.walletId == id);
    for (final p in _expensePayments) {
      if (p.walletId == id) p.walletId = null;
    }
    _saveRefData();
    notifyListeners();
    return true;
  }

  Wallet? defaultWallet() =>
      _wallets.isNotEmpty ? _wallets.first : null;

  double get totalWalletsBalance =>
      _wallets.fold(0.0, (s, w) => s + walletBalance(w.id));

  double walletBalance(String walletId) {
    // مصدر الحقيقة للنقد هو العمليات التي أثرت فعلياً على المحفظة:
    // قبض الإيرادات + المقبوضات الأخرى - المدفوعات - التصريفات.
    // لا نحسب التخصيصات مرة ثانية لأنها مجرد طريقة لشرح مصدر التمويل.
    final incomeReceived = _incomePayments
        .where((p) => incomePaymentWalletId(p.id) == walletId)
        .fold(0.0, (s, p) => s + p.amount);

    final expensePaid = _expensePayments
        .where((p) => p.walletId == walletId)
        .fold(0.0, (s, p) => s + p.amount);

    final movementsIn = _moneyMovements
        .where((m) => m.walletId == walletId && m.amount < 0)
        .fold(0.0, (s, m) => s + m.amount.abs());

    final movementsOut = _moneyMovements
        .where((m) => m.walletId == walletId && m.amount > 0)
        .fold(0.0, (s, m) => s + m.amount);

    return incomeReceived + movementsIn - expensePaid - movementsOut;
  }

  List<Expense> getExpensesForWallet(String walletId) {
    final walletPaymentIds = _incomePayments
      .where((p) => incomePaymentWalletId(p.id) == walletId)
        .map((p) => p.id)
        .toSet();
    final walletDebtSourceIds = debtFundingSources
      .where((s) => s.walletId == walletId)
      .map((s) => s.id)
      .toSet();

    return _expenses.where((e) =>
        e.allocations.any((a) =>
            (a.paymentId != null && walletPaymentIds.contains(a.paymentId)) ||
            (a.debtSettlementId != null && walletDebtSourceIds.contains(a.debtSettlementId)))
    ).toList();
  }

  List<MoneyMovement> getMovementsForWallet(String walletId) =>
      _moneyMovements.where((m) => m.walletId == walletId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// إجمالي قيمة المخزون الحالي = قيمة أصناف المخازن + المخزون العام غير الموزع.
  double get inventoryValue {
    // Product.currentStock هو الرصيد الإجمالي للصنف بعد المزامنة وإعادة
    // بناء المخزون (داخل المخازن + الكمية المشتراة غير الموزعة).
    // لا نضيف StorageItem مرة أخرى حتى لا تتضاعف قيمة المخزون.
    return _products.fold(
      0.0,
      (sum, product) => sum +
          (product.currentStock > 0 ? product.currentStock : 0) *
          product.purchasePrice,
    );
  }

  /// تقرير ربح/خسارة شهري (نقدي): إيرادات مقبوضة مقابل صادر مدفوع لكل شهر.
  List<MonthlyReportRow> monthlyReport() {
    final rows = <String, MonthlyReportRow>{};
    MonthlyReportRow rowFor(DateTime date) {
      final key = '${date.year}-${date.month}';
      return rows.putIfAbsent(
          key, () => MonthlyReportRow(date.year, date.month));
    }

    for (final p in _incomePayments) {
      rowFor(p.date).income += p.amount;
    }
    for (final p in _expensePayments) {
      rowFor(p.date).out += p.amount;
    }
    for (final m in _moneyMovements) {
      if (m.amount > 0) {
        rowFor(m.date).out += m.amount;
      } else if (m.amount < 0) {
        rowFor(m.date).income += m.amount.abs();
      }
    }
    final list = rows.values.toList()
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
    return list;
  }

  List<IncomePayment> getPaymentsForWallet(String walletId) {
    return _incomePayments
            .where((p) => incomePaymentWalletId(p.id) == walletId)
            .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  }

  // --- MoneyMovement (تصريف/سحب) CRUD ---

  void addMoneyMovement(MoneyMovement m) {
    if (m.walletId.trim().isEmpty) {
      throw Exception('يجب تحديد المحفظة للحركة المالية');
    }
    if (m.amount.abs() < 0.000001) {
      throw Exception('لا يمكن تسجيل حركة مالية بقيمة صفر');
    }
    _moneyMovements.add(m);
    _saveRefData();
    notifyListeners();
  }

  void updateMoneyMovement(MoneyMovement updated) {
    if (updated.walletId.trim().isEmpty) {
      throw Exception('يجب تحديد المحفظة للحركة المالية');
    }
    if (updated.amount.abs() < 0.000001) {
      throw Exception('لا يمكن تسجيل حركة مالية بقيمة صفر');
    }
    final idx = _moneyMovements.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _moneyMovements[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  bool deleteMoneyMovement(String id) {
    final m = _moneyMovements.firstWhereOrNull((e) => e.id == id);
    if (m == null) return false;

    // الحركات المنشأة تلقائياً يجب ألا تُحذف وحدها، وإلا انفصلت الحركة
    // النقدية عن العملية الأصلية وأصبح الرصيد مختلفاً عن السجل. نعكس
    // العملية الأصلية أولاً ثم نحذف الحركة المرتبطة بها.
    if (m.debtSettlementId != null) {
      return deletePersonalDebtSettlement(m.debtSettlementId!);
    }

    if (m.zakatPaymentId != null) {
      final paymentExists = _zakatPayments.any((p) => p.id == m.zakatPaymentId);
      if (!paymentExists) return false;
      _zakatPayments.removeWhere((p) => p.id == m.zakatPaymentId);
      _moneyMovements.removeWhere((e) => e.id == id);
      _saveAll();
      notifyListeners();
      return true;
    }

    if (m.purchaseId != null) {
      final pIdx = _purchases.indexWhere((p) => p.id == m.purchaseId);
      if (pIdx == -1) return false;
      final purchase = _purchases[pIdx];
      final restoredPaid = (purchase.paidAmount - m.amount).clamp(0.0, double.infinity);
      final net = (purchase.totalAmount - purchase.discount).clamp(0.0, double.infinity);
      _purchases[pIdx] = Purchase(
        id: purchase.id,
        supplierId: purchase.supplierId,
        date: purchase.date,
        totalAmount: purchase.totalAmount,
        discount: purchase.discount,
        paidAmount: restoredPaid,
        paymentType: restoredPaid >= net - 0.01
            ? 'cash'
            : (restoredPaid > 0 ? 'partial' : 'debt'),
        invoiceNumber: purchase.invoiceNumber,
        notes: purchase.notes,
        createdAt: purchase.createdAt,
      );
      _moneyMovements.removeWhere((e) => e.id == id);
      _saveAll();
      notifyListeners();
      return true;
    }

    // الحركة المرتبطة بتوزيعة شريك يمكن عكسها بأمان لأنها تحمل معرف
    // التوزيعة صراحة.
    if (m.distributionId != null) {
      final dIdx = _distributions.indexWhere((d) => d.id == m.distributionId);
      if (dIdx == -1) return false;
      _distributions[dIdx].isPaid = false;
      _distributions[dIdx].paidDate = null;
    }

    // الحركات القديمة المرتبطة بدين أصلي أو بدائن لا يمكن حذفها منفردة،
    // لأن ذلك يترك الدين موجوداً دون أثره النقدي.
    if (m.debtId != null || m.creditorId != null || m.creditorType != null) {
      return false;
    }

    _moneyMovements.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  double disbursedForPayment(String paymentId) => _moneyMovements
      .where((m) => m.paymentId == paymentId)
      .fold(0.0, (s, m) => s + m.amount);

  double disbursedForIncome(String incomeId) {
    final income = _incomes.firstWhereOrNull((i) => i.id == incomeId);
    final payIds = (income?.payments.map((p) => p.id) ?? const <String>[]).toSet();
    double total = 0.0;
    final countedMovementIds = <String>{};

    for (final m in _moneyMovements) {
      if (m.amount <= 0) continue;
      if (countedMovementIds.contains(m.id)) continue;

      if (m.funding.isNotEmpty) {
        final fundedShare = m.funding
            .where((a) =>
                a.incomeId == incomeId ||
                (a.paymentId != null && payIds.contains(a.paymentId)))
            .fold(0.0, (s, a) => s + a.amount);
        if (fundedShare > 0) {
          total += fundedShare;
          countedMovementIds.add(m.id);
        }
      } else if (m.incomeId == incomeId ||
          (m.paymentId != null && payIds.contains(m.paymentId))) {
        total += m.amount;
        countedMovementIds.add(m.id);
      }
    }

    for (final ep in _expensePayments) {
      final fundedShare = ep.funding
          .where((a) =>
              a.incomeId == incomeId ||
              (a.paymentId != null && payIds.contains(a.paymentId)))
          .fold(0.0, (s, a) => s + a.amount);
      if (fundedShare > 0) {
        total += fundedShare;
      }
    }

    for (final s in _personalDebtSettlements) {
      if (countedMovementIds.any((id) {
        final mov = _moneyMovements.firstWhereOrNull((m) => m.id == id);
        return mov?.debtId == s.debtId;
      })) {
        continue;
      }
      final fundedShare = s.funding
          .where((a) =>
              a.incomeId == incomeId ||
              (a.paymentId != null && payIds.contains(a.paymentId)))
          .fold(0.0, (sum, a) => sum + a.amount);
      if (fundedShare > 0) {
        total += fundedShare;
      }
    }

    return total;
  }

  double incomeDisbursable(String incomeId) {
    final income = _incomes.firstWhereOrNull((i) => i.id == incomeId);
    if (income == null) return 0;
    final available = income.receivedAmount -
        totalExpensesForIncome(incomeId) -
        disbursedForIncome(incomeId);
    return available > 0 ? available : 0;
  }

  /// أقصى مبلغ مسموح به عند تعديل حركة نقدية (تصريف).
  /// الحركات المرتبطة بفاتورة شراء أو حصة شريك يكون مبلغها ثابتاً.
  double movementMaxEditable(MoneyMovement m) {
    if (m.purchaseId != null || m.distributionId != null) return m.amount;
    var maxAllowed = double.infinity;
    if (m.incomeId != null) {
      maxAllowed = incomeDisbursable(m.incomeId!) + m.amount;
      if (m.paymentId != null) {
        final income = _incomes.firstWhereOrNull((i) => i.id == m.incomeId);
        if (income != null) {
          final payment =
              income.payments.firstWhereOrNull((p) => p.id == m.paymentId);
          if (payment != null) {
            final paymentMax =
                payment.amount -
                    totalExpensesForPayment(m.paymentId!) -
                    (disbursedForPayment(m.paymentId!) - m.amount);
            if (paymentMax < maxAllowed) maxAllowed = paymentMax;
          }
        }
      }
    }
    return maxAllowed;
  }

  // --- PersonalDebt (ديون شخصية) CRUD ---

  void _migrateDebtReceiptFunding() {
    final settlementById = {
      for (final settlement in _personalDebtSettlements)
        settlement.id: settlement,
    };
    var changed = false;

    void migrate(List<ExpenseAllocation> allocations) {
      for (final allocation in allocations) {
        final paymentId = allocation.paymentId;
        if (paymentId == null) continue;
        String? settlementId;
        if (paymentId.startsWith('debt_receipt_payment_')) {
          settlementId = paymentId.substring('debt_receipt_payment_'.length);
        } else if (paymentId.startsWith('debt_borrow_payment_')) {
          final debtId = paymentId.substring('debt_borrow_payment_'.length);
          allocation
            ..incomeId = ''
            ..paymentId = null
            ..debtSettlementId = 'debt_borrow_$debtId'
            ..debtId = debtId;
          changed = true;
          continue;
        }
        if (settlementId == null || !settlementById.containsKey(settlementId)) {
          continue;
        }
        allocation
          ..incomeId = ''
          ..paymentId = null
          ..debtSettlementId = settlementId
          ..debtId = settlementById[settlementId]!.debtId;
        changed = true;
      }
    }

    for (final expense in _expenses) {
      migrate(expense.allocations);
    }
    for (final payment in _expensePayments) {
      migrate(payment.funding);
    }
    for (final movement in _moneyMovements) {
      migrate(movement.funding);
    }

    final usedMovements = <MoneyMovement>{};
    for (final settlement in _personalDebtSettlements) {
      final debt = _personalDebts.firstWhereOrNull(
        (d) => d.id == settlement.debtId && d.direction == 'receivable',
      );
      if (debt == null || settlement.walletId.isEmpty) continue;
      final existingMovement = _moneyMovements.firstWhereOrNull((movement) =>
          !usedMovements.contains(movement) &&
          movement.debtId == settlement.debtId &&
          movement.walletId == settlement.walletId &&
          movement.amount < 0 &&
          (movement.amount.abs() - settlement.amount.abs()).abs() < 0.01);
      if (existingMovement != null) {
        usedMovements.add(existingMovement);
      } else {
        final person = _partners.firstWhereOrNull((p) => p.id == debt.personId);
        final personName = person?.name ?? '';
        final defaultNote = personName.isNotEmpty
            ? 'استلام ديون وأقساط من $personName'
            : 'استلام ديون وأقساط';
        final newMov = MoneyMovement(
          id: const Uuid().v4(),
          walletId: settlement.walletId,
          amount: -settlement.amount.abs(),
          date: settlement.date,
          debtId: settlement.debtId,
          debtSettlementId: settlement.id,
          funding: const [],
          note: (settlement.note != null && settlement.note!.trim().isNotEmpty)
              ? settlement.note
              : defaultNote,
        );
        _moneyMovements.add(newMov);
        usedMovements.add(newMov);
        changed = true;
      }
    }

    for (final debt in _personalDebts.where(
        (d) => d.direction == 'payable' && d.walletId?.isNotEmpty == true)) {
      final existingMovement = _moneyMovements.firstWhereOrNull((movement) =>
          !usedMovements.contains(movement) &&
          movement.debtId == debt.id &&
          movement.walletId == debt.walletId &&
          movement.amount < 0 &&
          (movement.amount.abs() - debt.amount.abs()).abs() < 0.01);
      if (existingMovement != null) {
        usedMovements.add(existingMovement);
      } else {
        final person = _partners.firstWhereOrNull((p) => p.id == debt.personId);
        final personName = person?.name ?? '';
        final defaultNote = personName.isNotEmpty
            ? 'استلام ديون وأقساط من $personName'
            : 'استلام ديون وأقساط';
        final newMov = MoneyMovement(
          id: const Uuid().v4(),
          walletId: debt.walletId!,
          amount: -debt.amount.abs(),
          date: debt.date,
          debtId: debt.id,
          funding: const [],
          note: (debt.note != null && debt.note!.trim().isNotEmpty)
              ? debt.note
              : defaultNote,
        );
        _moneyMovements.add(newMov);
        usedMovements.add(newMov);
        changed = true;
      }
    }

    _incomes.removeWhere((income) =>
      income.id == 'debt_receipts_income' ||
      income.id.startsWith('debt_receipt_income_'));
    _incomePayments.removeWhere((payment) =>
        payment.id.startsWith('debt_receipt_payment_') ||
        payment.id.startsWith('debt_borrow_payment_'));
    if (changed) _saveAll();
  }

  String? incomePaymentWalletId(String paymentId) {
    final payment = _incomePayments.firstWhereOrNull((p) => p.id == paymentId);
    if (payment == null) return null;
    return payment.walletId ??
        _incomes.firstWhereOrNull((i) => i.id == payment.incomeId)?.walletId;
  }

  bool addPersonalDebt(PersonalDebt debt) {
    if (debt.id.trim().isEmpty ||
        debt.personId.trim().isEmpty ||
        debt.amount <= 0 ||
        (debt.walletId != null && debt.walletId!.trim().isEmpty) ||
        _personalDebts.any((d) => d.id == debt.id)) {
      return false;
    }
    _personalDebts.add(debt);
    if (debt.walletId != null && debt.walletId!.isNotEmpty) {
      if (debt.direction == 'receivable') {
        // دفع/تسليف من المحفظة إلى الشخص (حركة صرف ممولة من دفعات الإيراد)
        _moneyMovements.add(MoneyMovement(
          id: const Uuid().v4(),
          walletId: debt.walletId!,
          amount: debt.amount,
          date: debt.date,
          debtId: debt.id,
          funding: debt.funding,
          note: debt.note ?? 'تسليف دين شخصي',
        ));
      } else {
        // استلام/اقتراض من الشخص إلى المحفظة (حركة إيداع في المحفظة)
        final person = partners.firstWhereOrNull((p) => p.id == debt.personId);
        final personName = person?.name ?? '';
        final defaultNote = personName.isNotEmpty
            ? 'استلام ديون وأقساط من $personName'
            : 'استلام ديون وأقساط';
        _moneyMovements.add(MoneyMovement(
          id: const Uuid().v4(),
          walletId: debt.walletId!,
          amount: -debt.amount,
          date: debt.date,
          debtId: debt.id,
          funding: const [],
          note: (debt.note != null && debt.note!.trim().isNotEmpty)
              ? debt.note
              : defaultNote,
        ));
      }
    }
    _saveRefData();
    notifyListeners();
    return true;
  }

  bool updatePersonalDebt(PersonalDebt updated) {
    final idx = _personalDebts.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return false;
    if (updated.amount <= 0 || updated.personId.trim().isEmpty) return false;
    if (updated.walletId != null && updated.walletId!.trim().isEmpty) return false;

    final current = _personalDebts[idx];
    final settlements = _personalDebtSettlements
        .where((s) => s.debtId == updated.id)
        .toList();
    final paid = settlements.fold<double>(0, (sum, s) => sum + s.amount);

    // بعد تسجيل تسويات لا نسمح بتغيير أصل الدين إلى قيمة أقل من المدفوع.
    if (updated.amount < paid) return false;

    // تغيير المحفظة/الاتجاه/المبلغ بعد إنشاء تسويات قد يكسر الربط التاريخي.
    // لذلك نسمح بتغيير بيانات الدين غير المالية فقط إذا كانت له تسويات.
    if (settlements.isNotEmpty &&
        (updated.direction != current.direction ||
            updated.walletId != current.walletId ||
            (updated.amount - current.amount).abs() > 0.000001 ||
            updated.date != current.date)) {
      return false;
    }

    // الدين بدون تسويات ما زال مرتبطًا بحركة الإنشاء؛ حدّث الحركة نفسها بدل
    // ترك حركة قديمة في المحفظة.
    if (settlements.isEmpty) {
      final movement = _moneyMovements.firstWhereOrNull((m) =>
          m.debtId == current.id && m.debtSettlementId == null);
      if (updated.walletId != null && updated.walletId!.isNotEmpty) {
        final expectedAmount = updated.direction == 'receivable'
            ? updated.amount.abs()
            : -updated.amount.abs();
        if (movement != null) {
          movement
            ..walletId = updated.walletId!
            ..amount = expectedAmount
            ..date = updated.date
            ..funding = updated.funding;
        } else {
          final person = partners.firstWhereOrNull((p) => p.id == updated.personId);
          final personName = person?.name ?? '';
          _moneyMovements.add(MoneyMovement(
            id: const Uuid().v4(),
            walletId: updated.walletId!,
            amount: expectedAmount,
            date: updated.date,
            debtId: updated.id,
            funding: updated.direction == 'receivable' ? updated.funding : const [],
            note: updated.note ??
                (updated.direction == 'receivable'
                    ? 'تسليف دين شخصي${personName.isNotEmpty ? ' إلى $personName' : ''}'
                    : 'استلام ديون وأقساط${personName.isNotEmpty ? ' من $personName' : ''}'),
          ));
        }
      } else if (movement != null) {
        _moneyMovements.removeWhere((m) => m.id == movement.id);
      }
    }

    _personalDebts[idx] = updated;
    _saveRefData();
    notifyListeners();
    return true;
  }

  bool deletePersonalDebt(String id) {
    final settlementIds = _personalDebtSettlements
        .where((s) => s.debtId == id)
        .map((s) => s.id);
    final hasFundingReferences =
      settlementIds.any(_debtFundingSourceIsUsed) ||
      _debtFundingSourceIsUsed('debt_borrow_$id') ||
        _expenses.any((e) => e.personId == id && e.paymentMethod == 'debt');
    if (hasFundingReferences) return false;
    _personalDebts.removeWhere((e) => e.id == id);
    _personalDebtSettlements.removeWhere((s) => s.debtId == id);
    _moneyMovements.removeWhere((m) => m.debtId == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  double personalDebtPaid(String debtId) => _personalDebtSettlements
      .where((s) => s.debtId == debtId)
      .fold(0.0, (s, p) => s + p.amount);

  double personalDebtRemaining(String debtId) {
    final debt = _personalDebts.firstWhereOrNull((d) => d.id == debtId);
    if (debt == null) return 0;
    return (debt.amount - personalDebtPaid(debtId))
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  List<PersonalDebtSettlement> settlementsForDebt(String debtId) =>
      _personalDebtSettlements.where((s) => s.debtId == debtId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  bool addPersonalDebtSettlement(PersonalDebtSettlement settlement) {
    final debt =
        _personalDebts.firstWhereOrNull((d) => d.id == settlement.debtId);
    if (debt == null || settlement.amount <= 0 || settlement.walletId.trim().isEmpty) {
      return false;
    }
    final remaining = personalDebtRemaining(debt.id);
    if (settlement.amount > remaining + 0.000001) return false;

    // لا تسمح بتكرار معرف التسوية لأن المعرف هو رابط الحركة النقدية.
    if (_personalDebtSettlements.any((s) => s.id == settlement.id)) return false;

    _personalDebtSettlements.add(settlement);
    if (settlement.walletId.isNotEmpty) {
      final person = partners.firstWhereOrNull((p) => p.id == debt.personId);
      final personName = person?.name ?? '';
      if (debt.direction == 'payable') {
        // نحن ندين له والآن نسدد له دفعة (دفع من المحفظة ممول من دفعات الإيراد)
        final defaultNote = personName.isNotEmpty
            ? 'دفع ديون وأقساط إلى $personName'
            : 'دفع ديون وأقساط';
        _moneyMovements.add(MoneyMovement(
          id: const Uuid().v4(),
          walletId: settlement.walletId,
          amount: settlement.amount,
          date: settlement.date,
          debtId: settlement.debtId,
          debtSettlementId: settlement.id,
          funding: settlement.funding,
          note: (settlement.note != null && settlement.note!.trim().isNotEmpty)
              ? settlement.note
              : defaultNote,
        ));
      } else {
        // هو يدين لنا: حركة إيداع نقدية، مع إبقاء التسوية مصدر تمويل مؤقت.
        final defaultNote = personName.isNotEmpty
            ? 'استلام ديون وأقساط من $personName'
            : 'استلام ديون وأقساط';
        _moneyMovements.add(MoneyMovement(
          id: const Uuid().v4(),
          walletId: settlement.walletId,
          amount: -settlement.amount.abs(),
          date: settlement.date,
          debtId: settlement.debtId,
          debtSettlementId: settlement.id,
          funding: const [],
          note: (settlement.note != null && settlement.note!.trim().isNotEmpty)
              ? settlement.note
              : defaultNote,
        ));
      }
    }
    _saveRefData();
    notifyListeners();
    return true;
  }

  bool _debtFundingSourceIsUsed(String sourceId, {Set<String>? ignoredMovementIds}) {
    if (_expenses.any((e) => e.allocations.any((a) => a.debtSettlementId == sourceId))) {
      return true;
    }
    if (_expensePayments.any((p) => p.funding.any((a) => a.debtSettlementId == sourceId))) {
      return true;
    }
    return _moneyMovements.any((m) =>
        !(ignoredMovementIds?.contains(m.id) ?? false) &&
        m.funding.any((a) => a.debtSettlementId == sourceId));
  }

  bool deletePersonalDebtSettlement(String id) {
    final settlement = _personalDebtSettlements
        .firstWhereOrNull((s) => s.id == id);
    if (settlement == null) return false;

    // الحركة النقدية المنشأة بواسطة هذه التسوية تحمل تمويل التسوية نفسها.
    // لا ينبغي اعتبار هذا الرابط الذاتي استخدامًا خارجيًا يمنع الحذف.
    final linked = _moneyMovements
        .where((m) => m.debtSettlementId == id)
        .toList();
    final linkedIds = linked.map((m) => m.id).toSet();
    if (_debtFundingSourceIsUsed(id, ignoredMovementIds: linkedIds)) return false;

    _personalDebtSettlements.removeWhere((s) => s.id == id);
    if (linked.isNotEmpty) {
      _moneyMovements.removeWhere((m) => linkedIds.contains(m.id));
    } else {
      // توافق مع البيانات القديمة التي لم يكن فيها رابط مباشر للتسوية.
      final legacy = _moneyMovements.firstWhereOrNull((m) =>
          m.debtId == settlement.debtId &&
          m.walletId == settlement.walletId &&
          m.date == settlement.date &&
          (m.amount.abs() - settlement.amount.abs()).abs() < 0.001);
      if (legacy != null) _moneyMovements.removeWhere((m) => m.id == legacy.id);
    }
    _saveRefData();
    notifyListeners();
    return true;
  }

  /// مجموع الديون الشخصية النشطة (المتبقية) للشخص
  double activeDebtForPerson(String personId) => _personalDebts
      .where((d) => d.personId == personId)
      .fold(0.0, (s, d) => s + personalDebtRemaining(d.id));

  // --- Helper to deduplicate reference data ---
  void _deduplicateReferenceData() {
    final seenExpNames = <String>{};
    final uniqueExp = <ExpenseCategory>[];
    for (final cat in _expenseCategories) {
      final name = cat.name.trim();
      if (name.isNotEmpty && seenExpNames.add(name.toLowerCase())) {
        uniqueExp.add(cat);
      }
    }
    _expenseCategories = uniqueExp;

    final seenPartNames = <String>{};
    final uniquePart = <PartnershipType>[];
    for (final pt in _partnershipTypes) {
      final name = pt.name.trim();
      if (name.isNotEmpty && seenPartNames.add(name.toLowerCase())) {
        uniquePart.add(pt);
      }
    }
    _partnershipTypes = uniquePart;

    final seenEventNames = <String>{};
    final uniqueEvents = <EventType>[];
    for (final et in _eventTypes) {
      final name = et.name.trim();
      if (name.isNotEmpty && seenEventNames.add(name.toLowerCase())) {
        uniqueEvents.add(et);
      }
    }
    _eventTypes = uniqueEvents;
  }

  // --- ExpenseCategory (تصنيفات المصروفات) CRUD ---

  void addExpenseCategory(ExpenseCategory category) {
    if (_expenseCategories.any((e) => e.name.trim().toLowerCase() == category.name.trim().toLowerCase())) {
      return;
    }
    _expenseCategories.add(category);
    _saveRefData();
    notifyListeners();
  }

  void updateExpenseCategory(ExpenseCategory updated) {
    final idx = _expenseCategories.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _expenseCategories[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  void deleteExpenseCategory(String id) {
    _expenseCategories.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
  }

  ExpenseCategory? expenseCategoryById(String id) =>
      _expenseCategories.firstWhereOrNull((c) => c.id == id);

  // --- PartnershipType (أنواع الشراكات) CRUD ---

  void addPartnershipType(PartnershipType type) {
    if (_partnershipTypes.any((p) => p.name.trim().toLowerCase() == type.name.trim().toLowerCase())) {
      return;
    }
    _partnershipTypes.add(type);
    _saveRefData();
    notifyListeners();
  }

  void updatePartnershipType(PartnershipType updated) {
    final idx = _partnershipTypes.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _partnershipTypes[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  void deletePartnershipType(String id) {
    _partnershipTypes.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
  }

  PartnershipType? partnershipTypeById(String id) =>
      _partnershipTypes.firstWhereOrNull((t) => t.id == id);

  // --- EventType (أنواع الأحداث) CRUD ---

  void addEventType(EventType type) {
    if (_eventTypes.any((e) => e.name.trim().toLowerCase() == type.name.trim().toLowerCase())) {
      return;
    }
    _eventTypes.add(type);
    _saveRefData();
    notifyListeners();
  }

  void updateEventType(EventType updated) {
    final idx = _eventTypes.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _eventTypes[idx] = updated;
      _saveRefData();
      notifyListeners();
    }
  }

  void deleteEventType(String id) {
    _eventTypes.removeWhere((e) => e.id == id);
    _saveRefData();
    notifyListeners();
  }

  EventType? eventTypeById(String id) =>
      _eventTypes.firstWhereOrNull((t) => t.id == id);

  // --- ChemicalIngredient (المواد الفعالة) CRUD ---

  void addChemicalIngredient(ChemicalIngredient item) {
    _chemicalIngredients.add(item);
    _chemicalIngredients.sort((a, b) => a.name.compareTo(b.name));
    _saveRefData();
    notifyListeners();
  }

  void updateChemicalIngredient(ChemicalIngredient updated) {
    final idx = _chemicalIngredients.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _chemicalIngredients[idx] = updated;
      _chemicalIngredients.sort((a, b) => a.name.compareTo(b.name));
      _saveRefData();
      notifyListeners();
    }
  }

  void deleteChemicalIngredient(String id) {
    _chemicalIngredients.removeWhere((e) => e.id == id);
    _pestIngredients.removeWhere((e) => e.ingredientId == id);
    _productIngredients.removeWhere((e) => e.ingredientId == id);
    _saveRefData();
    notifyListeners();
  }

  // --- Pest (الآفات الزراعية) CRUD ---

  void addPest(Pest pest) {
    _pests.add(pest);
    _pests.sort((a, b) => a.name.compareTo(b.name));
    _saveRefData();
    notifyListeners();
  }

  void updatePest(Pest updated) {
    final idx = _pests.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _pests[idx] = updated;
      _pests.sort((a, b) => a.name.compareTo(b.name));
      _saveRefData();
      notifyListeners();
    }
  }

  void deletePest(String id) {
    _pests.removeWhere((e) => e.id == id);
    _pestIngredients.removeWhere((e) => e.pestId == id);
    _saveRefData();
    notifyListeners();
  }

  List<PestIngredient> pestIngredientsFor(String pestId) => _pestIngredients
      .where((e) => e.pestId == pestId)
      .toList();

  void savePestIngredients(String pestId, List<Map<String, dynamic>> entries) {
    _pestIngredients.removeWhere((e) => e.pestId == pestId);
    for (final entry in entries) {
      _pestIngredients.add(PestIngredient(
        id: const Uuid().v4(),
        pestId: pestId,
        ingredientId: entry['ingredientId'] as String,
        dosage: entry['dosage'] as String?,
        instructions: entry['instructions'] as String?,
      ));
    }
    _saveRefData();
    notifyListeners();
  }

  // --- Product (المنتجات) CRUD ---

  void addProduct(Product product) {
    _products.add(product);
    _products.sort((a, b) => a.name.compareTo(b.name));
    _saveRefData();
    notifyListeners();
  }

  void updateProduct(Product updated) {
    final idx = _products.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;

    final current = _products[idx];
    final hasHistory = _storageItems.any((s) => s.productId == current.id) ||
        _purchaseItems.any((p) => p.productId == current.id) ||
        _productIngredients.any((e) => e.productId == current.id) ||
        _inventoryTransactions.any((t) => t.productId == current.id);

    // الرصيد الحالي لا يُعدّل يدويًا بعد بدء استخدام المنتج؛ فهو ناتج
    // عن حركات المخزون/المشتريات.
    final safeUpdated = hasHistory
        ? Product(
            id: updated.id,
            name: updated.name,
            category: updated.category,
            unit: updated.unit,
            purchasePrice: updated.purchasePrice,
            salePrice: updated.salePrice,
            currentStock: current.currentStock,
            minStock: updated.minStock,
            maxPurchasePrice: updated.maxPurchasePrice,
          )
        : updated;

    _products[idx] = safeUpdated;
    _reconcileInventoryAndPurchases();
    _products.sort((a, b) => a.name.compareTo(b.name));
    _saveRefData();
    notifyListeners();
  }

  bool deleteProduct(String id) {
    final used = _storageItems.any((s) => s.productId == id) ||
        _purchaseItems.any((p) => p.productId == id) ||
        _productIngredients.any((e) => e.productId == id) ||
        _inventoryTransactions.any((t) => t.productId == id);
    if (used) return false;
    _products.removeWhere((e) => e.id == id);
    _productIngredients.removeWhere((e) => e.productId == id);
    _saveRefData();
    notifyListeners();
    return true;
  }

  List<ProductIngredient> productIngredientsFor(String productId) =>
      _productIngredients.where((e) => e.productId == productId).toList();

  void saveProductIngredients(
      String productId, List<Map<String, dynamic>> entries) {
    _productIngredients.removeWhere((e) => e.productId == productId);
    for (final entry in entries) {
      _productIngredients.add(ProductIngredient(
        id: const Uuid().v4(),
        productId: productId,
        ingredientId: entry['ingredientId'] as String,
        concentration: entry['concentration'] as double?,
      ));
    }
    _saveRefData();
    notifyListeners();
  }

  /// إجمالي رصيد الصنف = مجموع رصيده في كافة المخازن + الكمية غير الموزعة من فواتير الشراء
  double totalStockForProduct(String productId) {
    final product = _products.firstWhereOrNull((p) => p.id == productId);
    if (product == null) return 0.0;
    final inWarehouses = _storageItems
        .where((s) =>
            s.productId == productId ||
            s.name.trim().toLowerCase() == product.name.trim().toLowerCase())
        .fold(0.0, (sum, s) => sum + s.quantity);
    final undistributed = undistributedStockForProduct(productId);
    return (inWarehouses + undistributed).clamp(0.0, double.infinity);
  }

  /// رصيد الصنف الفعلي الموجود داخل المخازن
  double warehouseStockForProduct(String productId) {
    final product = _products.firstWhereOrNull((p) => p.id == productId);
    if (product == null) return 0.0;
    return _storageItems
        .where((s) =>
            s.productId == productId ||
            s.name.trim().toLowerCase() == product.name.trim().toLowerCase())
        .fold(0.0, (sum, s) => sum + s.quantity);
  }

  /// الكمية المشتراة وغير الموزعة بعد إلى المخازن
  double undistributedStockForProduct(String productId) {
    return _purchaseItems
        .where((pi) => pi.productId == productId)
        .fold(0.0, (sum, pi) => sum + pi.remainingToDistribute);
  }

  // --- Purchases (المشتريات) CRUD ---

  void _validatePurchaseInput(Purchase purchase, List<Map<String, dynamic>> entries) {
    if (purchase.id.trim().isEmpty) {
      throw Exception('معرّف فاتورة الشراء غير صالح');
    }
    if (purchase.supplierId.trim().isEmpty) {
      throw Exception('يجب تحديد المورد في فاتورة الشراء');
    }
    if (!purchase.totalAmount.isFinite || purchase.totalAmount <= 0) {
      throw Exception('إجمالي فاتورة الشراء يجب أن يكون أكبر من صفر');
    }
    if (!purchase.discount.isFinite || purchase.discount < 0 ||
        purchase.discount > purchase.totalAmount + 0.01) {
      throw Exception('قيمة خصم فاتورة الشراء غير صحيحة');
    }
    if (!purchase.paidAmount.isFinite || purchase.paidAmount < 0 ||
        purchase.paidAmount > purchase.netAmount + 0.01) {
      throw Exception('قيمة الدفعة في فاتورة الشراء تتجاوز صافي الفاتورة');
    }
    if (entries.isEmpty) {
      throw Exception('يجب أن تحتوي فاتورة الشراء على صنف واحد على الأقل');
    }

    double entriesTotal = 0;
    for (final entry in entries) {
      final productId = entry['productId'];
      final rawQuantity = entry['quantity'];
      final rawUnitPrice = entry['unitPrice'];
      if (productId is! String || productId.trim().isEmpty ||
          rawQuantity is! num || rawUnitPrice is! num) {
        throw Exception('بيانات أحد أصناف فاتورة الشراء غير صحيحة');
      }
      final quantity = rawQuantity.toDouble();
      final unitPrice = rawUnitPrice.toDouble();
      if (!quantity.isFinite || quantity <= 0 ||
          !unitPrice.isFinite || unitPrice < 0) {
        throw Exception('كمية أو سعر أحد أصناف فاتورة الشراء غير صحيح');
      }
      if (!_products.any((p) => p.id == productId)) {
        throw Exception('يوجد صنف غير موجود في فاتورة الشراء');
      }
      entriesTotal += quantity * unitPrice;
    }

    if ((entriesTotal - purchase.totalAmount).abs() > 0.01) {
      throw Exception('إجمالي أصناف الفاتورة لا يساوي إجمالي الفاتورة');
    }
  }

  List<PurchaseItem> purchaseItemsFor(String purchaseId) =>
      _purchaseItems.where((e) => e.purchaseId == purchaseId).toList();

  void addPurchase(Purchase purchase, List<Map<String, dynamic>> entries,
      {String? paymentWalletId, List<ExpenseAllocation>? funding}) {
    _validatePurchaseInput(purchase, entries);
    if (purchase.paidAmount < 0 || purchase.paidAmount > purchase.totalAmount + 0.01) {
      throw Exception('قيمة الدفعة في فاتورة الشراء غير صحيحة');
    }
    if (purchase.paidAmount > 0 && (paymentWalletId == null || paymentWalletId.isEmpty)) {
      throw Exception('يجب تحديد المحفظة عند تسجيل فاتورة مدفوعة');
    }
    final effectiveFunding = funding ?? const <ExpenseAllocation>[];
    if (purchase.paidAmount > 0) {
      final sumFunding = effectiveFunding.fold(0.0, (s, a) => s + a.amount);
      if ((sumFunding - purchase.paidAmount).abs() > 0.01) {
        throw Exception('مجموع التمويل يجب أن يساوي مبلغ الدفعة المدفوعة');
      }
      validateFunding(effectiveFunding);
    }
    _purchases.insert(0, purchase);
    for (final entry in entries) {
      final productId = entry['productId'] as String;
      final quantity = (entry['quantity'] as num).toDouble();
      final unitPrice = (entry['unitPrice'] as num).toDouble();
      _purchaseItems.add(PurchaseItem(
        id: const Uuid().v4(),
        purchaseId: purchase.id,
        productId: productId,
        quantity: quantity,
        unitPrice: unitPrice,
      ));
      final idx = _products.indexWhere((e) => e.id == productId);
      if (idx != -1) {
        final p = _products[idx];
        _products[idx] = Product(
          id: p.id,
          name: p.name,
          category: p.category,
          unit: p.unit,
          purchasePrice: p.purchasePrice,
          salePrice: p.salePrice,
          currentStock: p.currentStock + quantity,
          minStock: p.minStock,
            maxPurchasePrice: p.maxPurchasePrice,
        );
      }
    }
    if (purchase.paidAmount > 0) {
      _moneyMovements.add(MoneyMovement(
        id: const Uuid().v4(),
        walletId: paymentWalletId,
        amount: purchase.paidAmount,
        date: purchase.date,
        purchaseId: purchase.id,
        note: 'دفعة فاتورة شراء',
        funding: effectiveFunding,
      ));
    }
    _products.sort((a, b) => a.name.compareTo(b.name));
    _purchases.sort((a, b) => b.date.compareTo(a.date));
    _saveAll();
    notifyListeners();
  }

  /// تسجيل دفعة نقدية إضافية على فاتورة شراء من محفظة محددة مع إمكانية تطبيق خصم تسوية.
  void recordPurchasePayment(String purchaseId, double amount, DateTime date,
      String? walletId,
      {double discount = 0.0,
      List<ExpenseAllocation>? funding,
      String? note}) {
    final idx = _purchases.indexWhere((e) => e.id == purchaseId);
    if (idx == -1) return;
    final purchase = _purchases[idx];
    final remaining = purchase.remainingAmount;
    if (remaining <= 0 && discount <= 0) return;

    if (amount < 0) {
      throw Exception('مبلغ دفعة الشراء لا يمكن أن يكون سالباً');
    }
    if (discount < 0) {
      throw Exception('قيمة الخصم لا يمكن أن تكون سالبة');
    }
    if (discount > remaining + 0.001) {
      throw Exception('قيمة الخصم تتجاوز المبلغ المتبقي من الفاتورة');
    }
    final actualDiscount = discount;
    final remainingAfterDiscount = remaining - actualDiscount;
    if (amount > remainingAfterDiscount + 0.001) {
      throw Exception('مبلغ دفعة الشراء يتجاوز المبلغ المتبقي بعد الخصم');
    }
    final paid = amount;

    if (paid > 0 && (walletId == null || walletId.trim().isEmpty)) {
      throw Exception('يجب تحديد المحفظة عند تسجيل دفعة شراء');
    }
    if (paid <= 0 && funding != null && funding.isNotEmpty) {
      throw Exception('لا يمكن تسجيل تمويل بدون دفعة شراء');
    }
    if (paid > 0 && walletId != null) {
      final effectiveFunding = funding ?? const <ExpenseAllocation>[];
      final sumFunding = effectiveFunding.fold(0.0, (s, a) => s + a.amount);
      if ((sumFunding - paid).abs() > 0.01) {
        throw Exception('مجموع التمويل يجب أن يساوي مبلغ الدفعة ($paid ر.ي)');
      }
      validateFunding(effectiveFunding);
      _moneyMovements.add(MoneyMovement(
        id: const Uuid().v4(),
        walletId: walletId,
        amount: paid,
        date: date,
        purchaseId: purchase.id,
        note: note ?? (actualDiscount > 0 ? 'دفعة فاتورة شراء (مع خصم $actualDiscount ر.ي)' : 'دفعة فاتورة شراء'),
        funding: effectiveFunding,
      ));
    }

    final newDiscount = purchase.discount + actualDiscount;
    final newPaid = purchase.paidAmount + paid;
    final newNet = (purchase.totalAmount - newDiscount).clamp(0.0, double.infinity);
    final isFullyPaid = newPaid >= newNet - 0.01;

    _purchases[idx] = Purchase(
      id: purchase.id,
      supplierId: purchase.supplierId,
      date: purchase.date,
      totalAmount: purchase.totalAmount,
      discount: newDiscount,
      paidAmount: newPaid,
      paymentType: isFullyPaid
          ? 'cash'
          : (newPaid > 0 ? 'partial' : 'debt'),
      invoiceNumber: purchase.invoiceNumber,
      notes: purchase.notes,
      createdAt: purchase.createdAt,
    );
    _saveAll();
    notifyListeners();
  }

  bool deletePurchase(String id) {
    final removedItems =
        _purchaseItems.where((e) => e.purchaseId == id).toList();
    final itemIds = removedItems.map((e) => e.id).toSet();
    if (_inventoryTransactions.any((t) =>
        t.purchaseItemId != null && itemIds.contains(t.purchaseItemId))) {
      return false;
    }
    _purchases.removeWhere((e) => e.id == id);
    _purchaseItems.removeWhere((e) => e.purchaseId == id);
    _moneyMovements.removeWhere((m) => m.purchaseId == id);
    for (final item in removedItems) {
      final idx = _products.indexWhere((e) => e.id == item.productId);
      if (idx != -1) {
        final p = _products[idx];
        _products[idx] = Product(
          id: p.id,
          name: p.name,
          category: p.category,
          unit: p.unit,
          purchasePrice: p.purchasePrice,
          salePrice: p.salePrice,
          currentStock: (p.currentStock - item.quantity).toDouble(),
          minStock: p.minStock,
            maxPurchasePrice: p.maxPurchasePrice,
        );
      }
    }
    _products.sort((a, b) => a.name.compareTo(b.name));
    _saveAll();
    notifyListeners();
    return true;
  }

  void updatePurchase(Purchase purchase, List<Map<String, dynamic>> entries,
      {String? paymentWalletId, List<ExpenseAllocation>? funding}) {
    final oldId = purchase.id;
    _validatePurchaseInput(purchase, entries);
    if (purchase.paidAmount < 0 || purchase.paidAmount > purchase.totalAmount + 0.01) {
      throw Exception('قيمة الدفعة في فاتورة الشراء غير صحيحة');
    }
    if (purchase.paidAmount > 0 && (paymentWalletId == null || paymentWalletId.isEmpty)) {
      throw Exception('يجب تحديد المحفظة عند تسجيل فاتورة مدفوعة');
    }
    final removedItems =
        _purchaseItems.where((e) => e.purchaseId == oldId).toList();
    final removedItemIds = removedItems.map((e) => e.id).toSet();
    if (_inventoryTransactions.any((tx) => tx.purchaseItemId != null && removedItemIds.contains(tx.purchaseItemId))) {
      throw Exception('لا يمكن تعديل فاتورة تم توزيع أصنافها على المخازن. قم بعكس التوزيع أولاً.');
    }
    final effectiveFunding = funding ?? const <ExpenseAllocation>[];
    if (purchase.paidAmount > 0) {
      final sumFunding = effectiveFunding.fold(0.0, (s, a) => s + a.amount);
      if ((sumFunding - purchase.paidAmount).abs() > 0.01) {
        throw Exception('مجموع التمويل يجب أن يساوي مبلغ الدفعة المدفوعة');
      }
      validateFunding(effectiveFunding);
    }
    _purchaseItems.removeWhere((e) => e.purchaseId == oldId);
    _moneyMovements.removeWhere((m) => m.purchaseId == oldId);
    for (final item in removedItems) {
      final idx = _products.indexWhere((e) => e.id == item.productId);
      if (idx != -1) {
        final p = _products[idx];
        _products[idx] = Product(
          id: p.id,
          name: p.name,
          category: p.category,
          unit: p.unit,
          purchasePrice: p.purchasePrice,
          salePrice: p.salePrice,
          currentStock: (p.currentStock - item.quantity).toDouble(),
          minStock: p.minStock,
            maxPurchasePrice: p.maxPurchasePrice,
        );
      }
    }

    final pIdx = _purchases.indexWhere((e) => e.id == purchase.id);
    if (pIdx != -1) {
      _purchases[pIdx] = purchase;
    } else {
      _purchases.insert(0, purchase);
    }

    for (final entry in entries) {
      final productId = entry['productId'] as String;
      final quantity = (entry['quantity'] as num).toDouble();
      final unitPrice = (entry['unitPrice'] as num).toDouble();
      _purchaseItems.add(PurchaseItem(
        id: const Uuid().v4(),
        purchaseId: purchase.id,
        productId: productId,
        quantity: quantity,
        unitPrice: unitPrice,
      ));
      final idx = _products.indexWhere((e) => e.id == productId);
      if (idx != -1) {
        final p = _products[idx];
        _products[idx] = Product(
          id: p.id,
          name: p.name,
          category: p.category,
          unit: p.unit,
          purchasePrice: p.purchasePrice,
          salePrice: p.salePrice,
          currentStock: p.currentStock + quantity,
          minStock: p.minStock,
            maxPurchasePrice: p.maxPurchasePrice,
        );
      }
    }

    if (purchase.paidAmount > 0) {
      _moneyMovements.add(MoneyMovement(
        id: const Uuid().v4(),
        walletId: paymentWalletId,
        amount: purchase.paidAmount,
        date: purchase.date,
        purchaseId: purchase.id,
        note: 'دفعة فاتورة شراء (تعديل)',
        funding: effectiveFunding,
      ));
    }

    _products.sort((a, b) => a.name.compareTo(b.name));
    _purchases.sort((a, b) => b.date.compareTo(a.date));
    _saveAll();
    notifyListeners();
  }

  /// توزيع أصناف فاتورة شراء إلى المخازن.
  /// يتحقق من جميع البنود أولاً ثم ينفذ العملية دفعة واحدة؛
  /// لذلك لا يمكن أن يبقى التوزيع في حالة جزئية إذا كان أحد البنود غير صالح.
  bool distributePurchase(
      String purchaseId, List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return false;
    if (!_purchases.any((p) => p.id == purchaseId)) return false;

    final planned = <String, Map<String, dynamic>>{};
    for (final entry in entries) {
      final purchaseItemId = entry['purchaseItemId'] as String?;
      final warehouseId = entry['warehouseId'] as String?;
      final rawQuantity = entry['quantity'];
      if (purchaseItemId == null || warehouseId == null || rawQuantity is! num) {
        return false;
      }
      final quantity = rawQuantity.toDouble();
      if (quantity <= 0) return false;
      final key = '$purchaseItemId|$warehouseId';
      final existing = planned[key];
      if (existing == null) {
        planned[key] = {
          'purchaseItemId': purchaseItemId,
          'warehouseId': warehouseId,
          'quantity': quantity,
          'date': entry['date'] as DateTime? ?? DateTime.now(),
        };
      } else {
        existing['quantity'] = (existing['quantity'] as double) + quantity;
      }
    }

    // تحقق كامل قبل أي تعديل على المخزون أو الفاتورة.
    for (final e in planned.values) {
      final purchaseItemId = e['purchaseItemId'] as String;
      final warehouseId = e['warehouseId'] as String;
      final quantity = e['quantity'] as double;
      if (!_warehouses.any((w) => w.id == warehouseId)) return false;

      final item = _purchaseItems.firstWhereOrNull((p) => p.id == purchaseItemId);
      if (item == null || item.purchaseId != purchaseId) return false;
      if (quantity > item.remainingToDistribute + 0.000001) return false;
      if (!_products.any((p) => p.id == item.productId)) return false;
    }

    for (final e in planned.values) {
      final purchaseItemId = e['purchaseItemId'] as String;
      final warehouseId = e['warehouseId'] as String;
      final quantity = e['quantity'] as double;
      final date = e['date'] as DateTime;

      final itemIdx = _purchaseItems.indexWhere((x) => x.id == purchaseItemId);
      final item = _purchaseItems[itemIdx];
      _purchaseItems[itemIdx] = PurchaseItem(
        id: item.id,
        purchaseId: item.purchaseId,
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        distributedQuantity: item.distributedQuantity + quantity,
      );

      final product = _products.firstWhereOrNull((x) => x.id == item.productId);
      final category = switch (product?.category) {
        'مبيدات' => 'pesticide',
        'سماد' => 'fertilizer',
        _ => 'general',
      };

      var storageItem = _storageItems.firstWhereOrNull((s) =>
          s.warehouseId == warehouseId &&
          ((product?.id != null && s.productId == product!.id) ||
              s.name.trim() == (product?.name ?? '').trim()));

      if (storageItem == null) {
        storageItem = StorageItem(
          id: const Uuid().v4(),
          warehouseId: warehouseId,
          name: product?.name ?? 'منتج محذوف',
          unit: product?.unit ?? 'كجم',
          quantity: 0,
          category: category,
          productId: product?.id,
          packageSize: product?.isPackaged == true ? product!.packageSize : null,
          usageUnit: product?.isPackaged == true ? product!.usageUnit : null,
        );
        _storageItems.add(storageItem);
      }

      _inventoryTransactions.insert(0, InventoryTransaction(
        id: const Uuid().v4(),
        itemId: storageItem.id,
        type: 'in',
        quantity: quantity,
        date: date,
        notes: 'توزيع من فاتورة شراء',
        purchaseItemId: item.id,
      ));
    }

    _reconcileInventoryAndPurchases();
    _products.sort((a, b) => a.name.compareTo(b.name));
    _saveRefData();
    notifyListeners();
    return true;
  }

}

extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
