const String baseCurrencyCode = 'YER';
const List<String> supportedCurrencyCodes = ['YER', 'SAR', 'USD'];

String currencyLabel(String code) {
  switch (code) {
    case 'SAR':
      return 'ر.س';
    case 'USD':
      return 'دولار';
    default:
      return 'ر.ي';
  }
}

bool hasFractionalMoneyValue(double value) =>
    (value - value.roundToDouble()).abs() > 0.0001;

int normalizeMoneyAmount(double value) {
  if (hasFractionalMoneyValue(value)) {
    throw const FormatException('المبالغ يجب أن تكون صحيحة بدون فواصل عشرية');
  }
  return value.round();
}

double toBaseCurrency(double amount, String currency, double exchangeRate) {
  if (currency == baseCurrencyCode) return amount;
  return amount * exchangeRate;
}

double toYemeniEquivalent(double receivedAmount, String currency, double exchangeRate) =>
    toBaseCurrency(receivedAmount, currency, exchangeRate);

double fromBaseCurrency(double baseAmount, String currency, double exchangeRate) {
  if (currency == baseCurrencyCode || exchangeRate <= 0) return baseAmount;
  return baseAmount / exchangeRate;
}

double fromYemeniEquivalent(double yemeniAmount, String currency, double exchangeRate) =>
    fromBaseCurrency(yemeniAmount, currency, exchangeRate);

class MoneyValue {
  final int minorUnits;
  final String currency;
  final double exchangeRate;

  const MoneyValue({
    required this.minorUnits,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  });

  double get majorUnits => minorUnits.toDouble();
  double get baseAmount => toBaseCurrency(majorUnits, currency, exchangeRate);

  static MoneyValue fromDouble(
    double value, {
    String currency = baseCurrencyCode,
    double exchangeRate = 1.0,
  }) {
    if (hasFractionalMoneyValue(value)) {
      throw const FormatException('المبالغ يجب أن تكون صحيحة بدون فواصل عشرية');
    }
    return MoneyValue(
      minorUnits: value.round(),
      currency: currency,
      exchangeRate: exchangeRate,
    );
  }

  static MoneyValue parseInput(
    String raw, {
    String currency = baseCurrencyCode,
    double exchangeRate = 1.0,
  }) {
    final sanitized = raw.replaceAll(',', '').trim();
    if (sanitized.isEmpty) {
      throw const FormatException('أدخل قيمة نقدية');
    }
    final parsed = double.tryParse(sanitized);
    if (parsed == null) {
      throw const FormatException('قيمة نقدية غير صحيحة');
    }
    return MoneyValue.fromDouble(parsed,
        currency: currency, exchangeRate: exchangeRate);
  }

  static double? tryParse(String raw) {
    try {
      return MoneyValue.parseInput(raw).majorUnits;
    } on FormatException {
      return null;
    }
  }

  static String formatDisplay(double value) {
    if (hasFractionalMoneyValue(value)) {
      return value.toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return value.round().toString();
  }
}

class ExpenseAllocation {
  String incomeId;
  String? paymentId; // الدفعة المستلمة من الإيراد التي يُخصم منها هذا المبلغ
  String? debtSettlementId; // الدفعة المستلمة من الدين الشخصي
  String? debtId; // معرف الدين الشخصي
  double amount;
  String currency;

  ExpenseAllocation({
    required this.incomeId,
    this.paymentId,
    this.debtSettlementId,
    this.debtId,
    required this.amount,
    this.currency = baseCurrencyCode,
  });

  Map<String, dynamic> toJson() => {
        'incomeId': incomeId,
        'paymentId': paymentId,
        'debtSettlementId': debtSettlementId,
        'debtId': debtId,
        'amount': amount,
        'currency': currency,
      };

  factory ExpenseAllocation.fromJson(Map<String, dynamic> json) =>
      ExpenseAllocation(
        incomeId: json['incomeId'] ?? '',
        paymentId: json['paymentId'],
        debtSettlementId: json['debtSettlementId'],
        debtId: json['debtId'],
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? baseCurrencyCode,
      );
}


class Expense {
  final String id;
  String title;
  double amount;
  DateTime date;
  String category;
  String? note;
  String? eventId; // الحدث المرتبط بمصروف (أجور عمالة، مواد، إلخ)
  String? workerId; // العامل المرتبط بصرف الأجر (إن وجد)
  double? wageDays; // عدد أيام العمل في صرف الأجر (يسمح بقيم عشرية)
  double? wageRate; // الأجر اليومي
  List<ExpenseAllocation> allocations;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.note,
    this.eventId,
    this.workerId,
    this.wageDays,
    this.wageRate,
    this.personId,
    this.paymentMethod,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
    List<ExpenseAllocation>? allocations,
  }) : allocations = allocations ?? [];

  String? personId; // الدائن / الشخص في حال الشراء بالآجل
  String? paymentMethod; // 'cash' | 'debt'
  String currency;
  double exchangeRate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'note': note,
        'eventId': eventId,
        'workerId': workerId,
        'wageDays': wageDays,
        'wageRate': wageRate,
        'personId': personId,
        'paymentMethod': paymentMethod,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'allocations': allocations.map((a) => a.toJson()).toList(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        category: json['category'],
        note: json['note'],
        eventId: json['eventId'],
        workerId: json['workerId'],
        wageDays: (json['wageDays'] as num?)?.toDouble(),
        wageRate: (json['wageRate'] as num?)?.toDouble(),
        personId: json['personId'],
        paymentMethod: json['paymentMethod'],
        currency: json['currency'] as String? ?? baseCurrencyCode,
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
        allocations: (json['allocations'] as List<dynamic>?)
                ?.map((a) =>
                    ExpenseAllocation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

const landPlotCategories = ['owned', 'partnered', 'client'];
String landPlotCategoryLabel(String category) {
  switch (category) {
    case 'owned': return 'تحت اليد';
    case 'partnered': return 'مشروك';
    case 'client': return 'عميل مياه';
    default: return category;
  }
}

class LandPlot {
  final String id;
  String name;
  double area;
  int numPlots;
  String category; // 'owned' = تحت اليد (يخرج الزكاة), 'partnered' = مشروك (بدون زكاة)
  String? warehouseId; // المخزن المرتبط بالموضع (اختياري)

  bool get hasZakat => category == 'owned';

  LandPlot({
    required this.id,
    required this.name,
    required this.area,
    required this.numPlots,
    this.category = 'partnered',
    this.warehouseId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'area': area,
        'numPlots': numPlots,
        'category': category,
        'hasZakat': hasZakat,
        'warehouseId': warehouseId,
      };

  factory LandPlot.fromJson(Map<String, dynamic> json) {
    String category;
    if (json['category'] != null) {
      category = json['category'] as String;
    } else {
      category = (json['hasZakat'] as bool? ?? false) ? 'owned' : 'partnered';
    }
    return LandPlot(
      id: json['id'],
      name: json['name'],
      area: (json['area'] as num).toDouble(),
      numPlots: json['numPlots'] as int? ?? 1,
      category: category,
      warehouseId: json['warehouseId'] as String?,
    );
  }
}

class Partnership {
  final String id;
  String landPlotId;
  String partnerId;
  String role; // 'water' or 'worker'
  double sharePercentage; // نسبة الشريك من المبلغ بعد الزكاة (%)
  DateTime startDate;
  DateTime? endDate; // null = still active

  Partnership({
    required this.id,
    required this.landPlotId,
    required this.partnerId,
    required this.role,
    required this.sharePercentage,
    required this.startDate,
    this.endDate,
  });

  bool isActiveAt(DateTime date) {
    if (date.isBefore(startDate)) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'landPlotId': landPlotId,
        'partnerId': partnerId,
        'role': role,
        'sharePercentage': sharePercentage,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };

  factory Partnership.fromJson(Map<String, dynamic> json) => Partnership(
        id: json['id'],
        landPlotId: json['landPlotId'],
        partnerId: json['partnerId'],
        role: json['role'] ?? 'worker',
        sharePercentage: (json['sharePercentage'] as num?)?.toDouble() ?? 25.0,
        startDate: DateTime.parse(json['startDate']),
        endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      );
}

class ZahraType {
  final String id;
  String name;
  String? notes;

  ZahraType({required this.id, required this.name, this.notes});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
      };

  factory ZahraType.fromJson(Map<String, dynamic> json) => ZahraType(
        id: json['id'],
        name: json['name'],
        notes: json['notes'],
      );
}

class Zahra {
  final String id;
  String name;
  String typeId;
  String? description;

  Zahra({required this.id, required this.name, required this.typeId, this.description});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'typeId': typeId,
        'description': description,
      };

  factory Zahra.fromJson(Map<String, dynamic> json) => Zahra(
        id: json['id'],
        name: json['name'],
        typeId: json['typeId'],
        description: json['description'],
      );
}

class Income {
  final String id;
  String title;
  double amount;
  DateTime date;
  String source;
  String? note;
  String? landPlotId;
  String? zahraId;
  String? walletId; // المحفظة المرتبطة بهذا الإيراد
  String status; // 'pending' or 'confirmed'
  String currency;
  double exchangeRate;
  List<Expense> _linkedExpenses = [];
  double _cachedTotalExpenses = 0;
  List<IncomePayment> _payments = [];

  Income({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.source,
    this.note,
    this.landPlotId,
    this.zahraId,
    this.walletId,
    this.status = 'pending',
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  });

  List<Expense> get linkedExpenses => List.unmodifiable(_linkedExpenses);
  void setLinkedExpenses(List<Expense> expenses) =>
      _linkedExpenses = List.from(expenses);
  void clearLinkedExpenses() => _linkedExpenses.clear();
  void addLinkedExpense(Expense e) => _linkedExpenses.add(e);
  void removeLinkedExpense(String expenseId) =>
      _linkedExpenses.removeWhere((e) => e.id == expenseId);
  void updateLinkedExpense(Expense updated) {
    final idx = _linkedExpenses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) _linkedExpenses[idx] = updated;
  }

  void setTotalExpenses(double v) => _cachedTotalExpenses = v;
  double get totalExpenses => _cachedTotalExpenses;
  double get netAmount => amount - _cachedTotalExpenses;
  double get expenseRatio =>
      amount > 0 ? (_cachedTotalExpenses / amount) * 100 : 0;

  List<IncomePayment> get payments => List.unmodifiable(_payments);
  void setPayments(List<IncomePayment> payments) => _payments = List.from(payments);
  void addPayment(IncomePayment p) => _payments.add(p);
  void removePayment(String id) => _payments.removeWhere((p) => p.id == id);
  double get receivedAmount => _payments.fold(0.0, (s, p) => s + p.amount);
  double get remainingAmount => amount - receivedAmount;
  bool get isFullyPaid => remainingAmount <= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'source': source,
        'note': note,
        'landPlotId': landPlotId,
        'zahraId': zahraId,
        'walletId': walletId,
        'status': status,
        'currency': currency,
        'exchangeRate': exchangeRate,
      };

  factory Income.fromJson(Map<String, dynamic> json) => Income(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        source: json['source'],
        note: json['note'],
        landPlotId: json['landPlotId'],
        zahraId: json['zahraId'],
        walletId: json['walletId'],
        status: json['status'] as String? ?? 'confirmed',
        currency: json['currency'] as String? ?? baseCurrencyCode,
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      );
}

class IncomePayment {
  final String id;
  String incomeId;
  double amount;
  DateTime date;
  String? notes;
  String? walletId;
  String currency;
  double exchangeRate;

  IncomePayment({
    required this.id,
    required this.incomeId,
    required this.amount,
    required this.date,
    this.notes,
    this.walletId,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'incomeId': incomeId,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'walletId': walletId,
        'currency': currency,
        'exchangeRate': exchangeRate,
      };

  factory IncomePayment.fromJson(Map<String, dynamic> json) => IncomePayment(
        id: json['id'],
        incomeId: json['incomeId'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        notes: json['notes'],
        walletId: json['walletId'],
        currency: json['currency'] as String? ?? baseCurrencyCode,
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      );
}

class ExpensePayment {
  final String id;
  String expenseId;
  double amount;
  DateTime date;
  String? walletId; // المحفظة التي خرجت منها الأموال
  String? notes;
  List<ExpenseAllocation> funding; // دفعات الاستلام من الإيرادات التي غطت هذا الصرف
  String currency;
  double exchangeRate;

  ExpensePayment({
    required this.id,
    required this.expenseId,
    required this.amount,
    required this.date,
    this.walletId,
    this.notes,
    List<ExpenseAllocation>? funding,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  }) : funding = funding ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'amount': amount,
        'date': date.toIso8601String(),
        'walletId': walletId,
        'notes': notes,
        'funding': funding.map((a) => a.toJson()).toList(),
        'currency': currency,
        'exchangeRate': exchangeRate,
      };

  factory ExpensePayment.fromJson(Map<String, dynamic> json) => ExpensePayment(
        id: json['id'],
        expenseId: json['expenseId'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        walletId: json['walletId'],
        notes: json['notes'],
        funding: (json['funding'] as List<dynamic>?)
                ?.map((a) =>
                    ExpenseAllocation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
              currency: json['currency'] as String? ?? baseCurrencyCode,
              exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      );
}

// حركة تصريف/سحب من محفظة (خروج مالي خارجي)
class MoneyMovement {
  final String id;
  String walletId;
  double amount;
  DateTime date;
  String? incomeId;
  String? paymentId;
  String? distributionId;
  String? purchaseId;
  String? zakatPaymentId;
  String? note;
  // تسديد تراكمي من ظهر الحساب: نوع الدائن 'w' عامل أو 's' مورد + معرّفه،
  // بدون ربط الحركة بأي عملية بعينها.
  String? creditorType; // 'w' | 's'
  String? creditorId;
  String? debtId; // معرّف دين شخصي مرتبط بهذه الحركة
  String? debtSettlementId; // معرّف تسوية الدين التي أنشأت الحركة
  List<ExpenseAllocation> funding; // دفعات الاستلام من الإيرادات التي غطت هذا الصرف
  String currency;
  double exchangeRate;

  MoneyMovement({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.date,
    this.incomeId,
    this.paymentId,
    this.distributionId,
    this.purchaseId,
    this.zakatPaymentId,
    this.note,
    this.creditorType,
    this.creditorId,
    this.debtId,
    this.debtSettlementId,
    List<ExpenseAllocation>? funding,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  }) : funding = funding ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'walletId': walletId,
        'amount': amount,
        'date': date.toIso8601String(),
        'incomeId': incomeId,
        'paymentId': paymentId,
        'distributionId': distributionId,
        'purchaseId': purchaseId,
        'zakatPaymentId': zakatPaymentId,
        'note': note,
        'creditorType': creditorType,
        'creditorId': creditorId,
        'debtId': debtId,
        'debtSettlementId': debtSettlementId,
        'funding': funding.map((a) => a.toJson()).toList(),
        'currency': currency,
        'exchangeRate': exchangeRate,
      };

  factory MoneyMovement.fromJson(Map<String, dynamic> json) => MoneyMovement(
        id: json['id'],
        walletId: json['walletId'] ?? json['boxId'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        incomeId: json['incomeId'],
        paymentId: json['paymentId'],
        distributionId: json['distributionId'],
        purchaseId: json['purchaseId'],
        zakatPaymentId: json['zakatPaymentId'],
        note: json['note'],
        creditorType: json['creditorType'],
        creditorId: json['creditorId'],
        debtId: json['debtId'],
        debtSettlementId: json['debtSettlementId'],
        funding: (json['funding'] as List<dynamic>?)
                ?.map((a) =>
                    ExpenseAllocation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
              currency: json['currency'] as String? ?? baseCurrencyCode,
              exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      );
}

class Wallet {
  final String id;
  String name;
  String? notes;

  Wallet({
    required this.id,
    required this.name,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
      };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        id: json['id'],
        name: json['name'],
        notes: json['notes'],
      );
}

const List<String> personRoles = [
  'client', 'supplier', 'worker', 'water',
];

String personRoleLabel(String role, {List<PartnershipType>? partnershipTypes}) {
  switch (role) {
    case 'client': return 'عميل';
    case 'supplier': return 'مورد';
    case 'worker': return 'عامل';
    case 'water': return 'شريك ماء';
    default:
      if (partnershipTypes != null) {
        final match = partnershipTypes.where((t) => t.id == role);
        if (match.isNotEmpty) return match.first.name;
      }
      return role;
  }
}

String personRolesLabel(List<String> roles, {List<PartnershipType>? partnershipTypes}) {
  return roles.map((r) => personRoleLabel(r, partnershipTypes: partnershipTypes)).join('، ');
}

const List<String> defaultExpenseCategories = [
  'تسويق', 'صيانة', 'نقل', 'ضرائب', 'أخرى',
];

const List<String> expenseCategories = defaultExpenseCategories;

class ExpenseCategory {
  final String id;
  String name;

  ExpenseCategory({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) => ExpenseCategory(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

const List<String> incomeSources = [
  'مبيعات', 'خدمات', 'استثمار', 'عقود', 'أخرى',
];

class LandEvent {
  final String id;
  String landPlotId;
  String eventType;
  DateTime date;
  String? notes;

  LandEvent({
    required this.id,
    required this.landPlotId,
    required this.eventType,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'landPlotId': landPlotId,
        'eventType': eventType,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory LandEvent.fromJson(Map<String, dynamic> json) => LandEvent(
        id: json['id'],
        landPlotId: json['landPlotId'],
        eventType: json['eventType'],
        date: DateTime.parse(json['date']),
        notes: json['notes'],
      );
}

class WorkRecord {
  final String id;
  String? partnerId;
  String landPlotId;
  DateTime startTime;
  DateTime endTime;
  String? note;
  double? hourlyRate;
  String? incomeId;

  WorkRecord({
    required this.id,
    this.partnerId,
    required this.landPlotId,
    required this.startTime,
    required this.endTime,
    this.note,
    this.hourlyRate,
    this.incomeId,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;
  double get durationHours => durationMinutes / 60.0;
  double get totalAmount => (hourlyRate ?? 0.0) * durationHours;

  Map<String, dynamic> toJson() => {
        'id': id,
        'partnerId': partnerId,
        'landPlotId': landPlotId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'note': note,
        'hourlyRate': hourlyRate,
        'incomeId': incomeId,
      };

  factory WorkRecord.fromJson(Map<String, dynamic> json) => WorkRecord(
        id: json['id'],
        partnerId: json['partnerId'],
        landPlotId: (json['landPlotId'] as String?) ?? '',
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        note: json['note'],
        hourlyRate: json['hourlyRate'] != null ? (json['hourlyRate'] as num).toDouble() : null,
        incomeId: json['incomeId'],
      );
}

class Warehouse {
  final String id;
  String name;
  String? notes;

  Warehouse({required this.id, required this.name, this.notes});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
      };

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
        id: json['id'],
        name: json['name'],
        notes: json['notes'],
      );
}

class StorageItem {
  final String id;
  String warehouseId;
  String name;
  String unit;
  double quantity; // عدد العلب/الأكياس للمعبأ، عدد الوحدات لغير المعبأ
  double? minQuantity;
  String? notes;
  String category; // 'fertilizer', 'pesticide', 'general'
  String? pesticideType; // 'fungicide', 'insecticide' (only for pesticides)
  String? productId; // المنتج المرتبط (من توزيع فاتورة شراء)
  double? packageSize; // حجم العبوة الواحدة بوحدة الاستخدام
  String? usageUnit; // 'مل' / 'غرام' للمعبأ

  bool get isPackaged => packageSize != null && packageSize! > 0;

  StorageItem({
    required this.id,
    required this.warehouseId,
    required this.name,
    required this.unit,
    this.quantity = 0,
    this.minQuantity,
    this.notes,
    this.category = 'general',
    this.pesticideType,
    this.productId,
    this.packageSize,
    this.usageUnit,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'warehouseId': warehouseId,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'minQuantity': minQuantity,
        'notes': notes,
        'category': category,
        'pesticideType': pesticideType,
        'productId': productId,
        'packageSize': packageSize,
        'usageUnit': usageUnit,
      };

  factory StorageItem.fromJson(Map<String, dynamic> json) => StorageItem(
        id: json['id'],
        warehouseId: json['warehouseId'] ?? '',
        name: json['name'],
        unit: json['unit'],
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        minQuantity: (json['minQuantity'] as num?)?.toDouble(),
        notes: json['notes'],
        category: json['category'] as String? ?? 'general',
        pesticideType: json['pesticideType'] as String?,
        productId: json['productId'],
        packageSize: (json['packageSize'] as num?)?.toDouble(),
        usageUnit: json['usageUnit'] as String?,
      );
}

class InventoryTransaction {
  final String id;
  String itemId;
  String type; // 'in' or 'out'
  double quantity;
  DateTime date;
  String? notes;
  String? eventId;
  String? purchaseItemId;
  String? transferId;
  String? toWarehouseId;
  String? fromWarehouseId;

  InventoryTransaction({
    required this.id,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.date,
    this.notes,
    this.eventId,
    this.purchaseItemId,
    this.transferId,
    this.toWarehouseId,
    this.fromWarehouseId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'type': type,
        'quantity': quantity,
        'date': date.toIso8601String(),
        'notes': notes,
        'eventId': eventId,
        'purchaseItemId': purchaseItemId,
        'transferId': transferId,
        'toWarehouseId': toWarehouseId,
        'fromWarehouseId': fromWarehouseId,
      };

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) =>
      InventoryTransaction(
        id: json['id'],
        itemId: json['itemId'],
        type: json['type'],
        quantity: (json['quantity'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        notes: json['notes'],
        eventId: json['eventId'],
        purchaseItemId: json['purchaseItemId'],
        transferId: json['transferId'] as String?,
        toWarehouseId: json['toWarehouseId'] as String?,
        fromWarehouseId: json['fromWarehouseId'] as String?,
      );
}

const List<String> storageUnits = [
  'كجم', 'لتر', 'عبوة', 'شوال', 'صندوق', 'حزمة', 'أخرى',
];

const List<String> productCategories = [
  'general', 'fertilizer', 'pesticide',
];

const List<String> pesticideTypes = [
  'fungicide', 'insecticide',
];

String productCategoryLabel(String cat) {
  switch (cat) {
    case 'fertilizer': return 'سماد';
    case 'pesticide': return 'مبيد';
    default: return 'عام';
  }
}

String pesticideTypeLabel(String type) {
  switch (type) {
    case 'fungicide': return 'فطري';
    case 'insecticide': return 'حشري';
    default: return type;
  }
}

class Partner {
  final String id;
  String name;
  List<String> roles; // 'client', 'supplier', 'worker', 'water'
  String? phone;
  String? notes;

  Partner({
    required this.id,
    required this.name,
    required this.roles,
    this.phone,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roles': roles,
        'phone': phone,
        'notes': notes,
      };

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
        id: json['id'],
        name: json['name'],
        roles: json['roles'] != null
            ? List<String>.from(json['roles'])
            : json['role'] != null
                ? [json['role'] as String]
                : ['client'],
        phone: json['phone'],
        notes: json['notes'],
      );
}

class Worker {
  final String id;
  String name;
  String? phone;
  String? notes;

  Worker({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
      };

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        notes: json['notes'],
      );
}

class Distribution {
  final String id;
  String incomeId;
  String partnerId;
  String role; // 'water' or 'worker'
  double amount;
  bool isPaid;
  DateTime? paidDate;

  Distribution({
    required this.id,
    required this.incomeId,
    required this.partnerId,
    required this.role,
    required this.amount,
    this.isPaid = false,
    this.paidDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'incomeId': incomeId,
        'partnerId': partnerId,
        'role': role,
        'amount': amount,
        'isPaid': isPaid,
        'paidDate': paidDate?.toIso8601String(),
      };

  factory Distribution.fromJson(Map<String, dynamic> json) => Distribution(
        id: json['id'],
        incomeId: json['incomeId'],
        partnerId: json['partnerId'],
        role: json['role'] ?? 'worker',
        amount: (json['amount'] as num).toDouble(),
        isPaid: json['isPaid'] as bool? ?? false,
        paidDate: json['paidDate'] != null ? DateTime.parse(json['paidDate']) : null,
      );
}

/// استحقاق زكاة (دين/التزام مستحق في الذمة لله تعالى)
class ZakatEntry {
  final String id;
  String? incomeId;
  String? landPlotId;
  String title;
  DateTime date;
  double amount;
  String? notes;
  String type; // 'crops' (زكاة زروع وثمار 5%), 'trade' (عروض تجارة), 'money' (نقد/مال), 'other' (أخرى)

  ZakatEntry({
    required this.id,
    this.incomeId,
    this.landPlotId,
    required this.title,
    required this.date,
    required this.amount,
    this.notes,
    this.type = 'crops',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'incomeId': incomeId,
        'landPlotId': landPlotId,
        'title': title,
        'date': date.toIso8601String(),
        'amount': amount,
        'notes': notes,
        'type': type,
      };

  factory ZakatEntry.fromJson(Map<String, dynamic> json) => ZakatEntry(
        id: json['id'],
        incomeId: json['incomeId'],
        landPlotId: json['landPlotId'],
        title: json['title'] ?? 'استحقاق زكاة',
        date: DateTime.parse(json['date']),
        amount: (json['amount'] as num).toDouble(),
        notes: json['notes'],
        type: json['type'] ?? 'crops',
      );
}

/// دفعة/سند إخراج زكاة (صرف وسداد الالتزام)
class ZakatPayment {
  final String id;
  String? zakatEntryId;
  String? incomeId;
  double amount;
  DateTime date;
  String walletId;
  String? recipient; // اسم المستحق أو الجهة
  String? recipientCategory; // مصرف الزكاة: 'فقراء ومساكين'، 'غارمون'، 'في سبيل الله'، 'ابن السبيل'، 'جمعية خيرية'، 'أخرى'
  String? notes;
  List<ExpenseAllocation> funding;

  ZakatPayment({
    required this.id,
    this.zakatEntryId,
    this.incomeId,
    required this.amount,
    required this.date,
    required this.walletId,
    this.recipient,
    this.recipientCategory,
    this.notes,
    List<ExpenseAllocation>? funding,
  }) : funding = funding ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'zakatEntryId': zakatEntryId,
        'incomeId': incomeId,
        'amount': amount,
        'date': date.toIso8601String(),
        'walletId': walletId,
        'recipient': recipient,
        'recipientCategory': recipientCategory,
        'notes': notes,
        'funding': funding.map((a) => a.toJson()).toList(),
      };

  factory ZakatPayment.fromJson(Map<String, dynamic> json) => ZakatPayment(
        id: json['id'],
        zakatEntryId: json['zakatEntryId'],
        incomeId: json['incomeId'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        walletId: json['walletId'] ?? '',
        recipient: json['recipient'],
        recipientCategory: json['recipientCategory'],
        notes: json['notes'],
        funding: (json['funding'] as List<dynamic>?)
                ?.map((a) =>
                    ExpenseAllocation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

const List<String> zakatCategories = [
  'فقراء ومساكين',
  'غارمون',
  'في سبيل الله',
  'ابن السبيل',
  'جمعية خيرية',
  'أخرى',
];

class IncomeBreakdown {
  final double gross;
  final double zakat;
  final double afterZakat;
  final double partnerShares;
  final double ownerNet;

  IncomeBreakdown({
    required this.gross,
    required this.zakat,
    required this.afterZakat,
    required this.partnerShares,
    required this.ownerNet,
  });
}

IncomeBreakdown computeIncomeBreakdown(double amount, bool hasZakat, List<Partnership> activePartnerships) {
  final zakat = hasZakat ? amount * 0.05 : 0.0;
  final afterZakat = amount - zakat;
  final partnerShares = activePartnerships.fold<double>(0, (s, p) => s + afterZakat * p.sharePercentage / 100);
  final ownerNet = afterZakat - partnerShares;
  return IncomeBreakdown(
    gross: amount,
    zakat: zakat,
    afterZakat: afterZakat,
    partnerShares: partnerShares,
    ownerNet: ownerNet,
  );
}

class ChemicalIngredient {
  final String id;
  String name;
  String type; // 'حشري' or 'فطري'
  String? notes;

  ChemicalIngredient({
    required this.id,
    required this.name,
    required this.type,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'notes': notes,
      };

  factory ChemicalIngredient.fromJson(Map<String, dynamic> json) =>
      ChemicalIngredient(
        id: json['id'],
        name: json['name'],
        type: json['type'] ?? 'حشري',
        notes: json['notes'],
      );
}

class Pest {
  final String id;
  String name;
  String type; // حشرية, فطرية, أكاروسية, حشائش, بكتيرية, فيروسية, أخرى
  String? symptoms;
  String? notes;

  Pest({
    required this.id,
    required this.name,
    required this.type,
    this.symptoms,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'symptoms': symptoms,
        'notes': notes,
      };

  factory Pest.fromJson(Map<String, dynamic> json) => Pest(
        id: json['id'],
        name: json['name'],
        type: json['type'] ?? 'حشرية',
        symptoms: json['symptoms'],
        notes: json['notes'],
      );
}

class PestIngredient {
  final String id;
  final String pestId;
  final String ingredientId;
  String? dosage;
  String? instructions;

  PestIngredient({
    required this.id,
    required this.pestId,
    required this.ingredientId,
    this.dosage,
    this.instructions,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pestId': pestId,
        'ingredientId': ingredientId,
        'dosage': dosage,
        'instructions': instructions,
      };

  factory PestIngredient.fromJson(Map<String, dynamic> json) => PestIngredient(
        id: json['id'],
        pestId: json['pestId'],
        ingredientId: json['ingredientId'],
        dosage: json['dosage'],
        instructions: json['instructions'],
      );
}

class Product {
  final String id;
  String name;
  String category;
  String unit;
  double purchasePrice; // أقل سعر شراء (لكل عبوة في المنتجات المعبأة)
  double maxPurchasePrice; // أكبر سعر شراء (0 = غير محدد)
  double salePrice;
  double currentStock; // عدد العلب/الأكياس للمعبأ، عدد الوحدات لغير المعبأ
  double minStock;
  String? packageType; // 'علبة' / 'كيس' / null = بكميات (بدون تعبئة)
  double packageSize; // حجم العبوة الواحدة بوحدة الاستخدام (0 = غير محدد)
  String? usageUnit; // وحدة القياس عند الاستخدام: 'مل' / 'غرام' (null للمنتجات العادية)

  bool get isPackaged => packageType != null && packageSize > 0;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.purchasePrice = 0,
    this.maxPurchasePrice = 0,
    this.salePrice = 0,
    this.currentStock = 0,
    this.minStock = 0,
    this.packageType,
    this.packageSize = 0,
    this.usageUnit,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'purchasePrice': purchasePrice,
        'maxPurchasePrice': maxPurchasePrice,
        'salePrice': salePrice,
        'currentStock': currentStock,
        'minStock': minStock,
        'packageType': packageType,
        'packageSize': packageSize,
        'usageUnit': usageUnit,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'],
        category: json['category'] ?? 'أخرى',
        unit: json['unit'] ?? 'كجم',
        purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
        maxPurchasePrice: (json['maxPurchasePrice'] as num?)?.toDouble() ?? 0,
        salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
        currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0,
        minStock: (json['minStock'] as num?)?.toDouble() ?? 0,
        packageType: json['packageType'] as String?,
        packageSize: (json['packageSize'] as num?)?.toDouble() ?? 0,
        usageUnit: json['usageUnit'] as String?,
      );
}

class ProductIngredient {
  final String id;
  final String productId;
  final String ingredientId;
  double? concentration;

  ProductIngredient({
    required this.id,
    required this.productId,
    required this.ingredientId,
    this.concentration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'ingredientId': ingredientId,
        'concentration': concentration,
      };

  factory ProductIngredient.fromJson(Map<String, dynamic> json) =>
      ProductIngredient(
        id: json['id'],
        productId: json['productId'],
        ingredientId: json['ingredientId'],
        concentration: (json['concentration'] as num?)?.toDouble(),
      );
}

class Purchase {
  final String id;
  final String supplierId; // Partner id بدور 'supplier'
  DateTime date;
  double totalAmount; // إجمالي قيمة الأصناف قبل الخصم
  double discount; // مبلغ الخصم الممنوح
  double paidAmount;
  String paymentType; // cash, debt, partial
  String? invoiceNumber; // رقم الفاتورة الورقية المستلمة من المورد
  String? notes;
  DateTime createdAt;

  double get netAmount => (totalAmount - discount).clamp(0.0, double.infinity);
  double get remainingAmount => (netAmount - paidAmount).toDouble();

  Purchase({
    required this.id,
    required this.supplierId,
    DateTime? date,
    required this.totalAmount,
    this.discount = 0.0,
    this.paidAmount = 0,
    this.paymentType = 'cash',
    this.invoiceNumber,
    this.notes,
    DateTime? createdAt,
  })  : date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'date': date.toIso8601String(),
        'totalAmount': totalAmount,
        'discount': discount,
        'paidAmount': paidAmount,
        'paymentType': paymentType,
        'invoiceNumber': invoiceNumber,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'],
        supplierId: json['supplierId'] ?? json['supplier_id'],
        date: DateTime.parse(json['date']),
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        paymentType: json['paymentType'] ?? 'cash',
        invoiceNumber: json['invoiceNumber'],
        notes: json['notes'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.parse(json['date']),
      );
}

class PurchaseItem {
  final String id;
  final String purchaseId;
  final String productId;
  double quantity;
  double unitPrice;
  double distributedQuantity;

  double get total => quantity * unitPrice;
  double get remainingToDistribute => quantity - distributedQuantity;

  PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.distributedQuantity = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'purchaseId': purchaseId,
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'distributedQuantity': distributedQuantity,
      };

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        id: json['id'],
        purchaseId: json['purchaseId'],
        productId: json['productId'],
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        distributedQuantity:
            (json['distributedQuantity'] as num?)?.toDouble() ?? 0,
      );
}

/// صف تقرير شهري: الإيرادات النقدية، الصادر النقدي، والصافي.
class MonthlyReportRow {
  final int year;
  final int month;
  double income = 0;
  double out = 0;

  double get net => income - out;

  MonthlyReportRow(this.year, this.month);
}

const List<String> chemicalIngredientTypes = ['حشري', 'فطري'];

const List<String> pestTypes = [
  'حشرية', 'فطرية', 'أكاروسية', 'حشائش', 'بكتيرية', 'فيروسية', 'أخرى',
];

const List<String> chemicalProductCategories = [
  'مبيدات', 'سماد', 'بذور', 'أدوات', 'أخرى',
];

const List<String> chemicalProductUnits = [
  'كجم', 'لتر', 'كيس', 'علبة', 'قطعة', 'صندوق',
];

const Map<String, String> purchasePaymentTypeLabels = {
  'cash': 'نقدي',
  'debt': 'دين',
  'partial': 'دفع جزئي',
};

class PartnershipType {
  final String id;
  String name;

  PartnershipType({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory PartnershipType.fromJson(Map<String, dynamic> json) =>
      PartnershipType(
        id: json['id'],
        name: json['name'],
      );
}

class EventType {
  final String id;
  String name;

  EventType({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory EventType.fromJson(Map<String, dynamic> json) => EventType(
        id: json['id'],
        name: json['name'],
      );
}

class PersonalDebt {
  final String id;
  String personId; // معرّف الشريك
  String direction; // 'receivable' (يدين لنا) | 'payable' (ندين له)
  double amount; // المبلغ الأصلي في العملة الأساسية (اليمني)
  DateTime date;
  String? note;
  String? eventId; // في حال كان الدين ناتجاً عن حدث
  String? expenseId; // في حال كان الدين ناتجاً عن مصروف حدث آجل
  String? walletId; // المحفظة المرتبطة بالصرف/القبض
  List<ExpenseAllocation> funding; // دفعات الاستلام من الإيرادات التي غطت هذا الصرف
  String currency;
  double exchangeRate;

  PersonalDebt({
    required this.id,
    required this.personId,
    required this.direction,
    required this.amount,
    required this.date,
    this.note,
    this.eventId,
    this.expenseId,
    this.walletId,
    List<ExpenseAllocation>? funding,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  }) : funding = funding ?? [];

  double get baseAmount => toBaseCurrency(amount, currency, exchangeRate);

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'direction': direction,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'eventId': eventId,
        'expenseId': expenseId,
        'walletId': walletId,
        'funding': funding.map((a) => a.toJson()).toList(),
        'currency': currency,
        'exchangeRate': exchangeRate,
      };

  factory PersonalDebt.fromJson(Map<String, dynamic> json) => PersonalDebt(
        id: json['id'],
        personId: json['personId'],
        direction: json['direction'] ?? 'receivable',
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        note: json['note'],
        eventId: json['eventId'],
        expenseId: json['expenseId'],
        walletId: json['walletId'],
        funding: (json['funding'] as List<dynamic>?)
                ?.map((a) =>
                    ExpenseAllocation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        currency: json['currency'] as String? ?? baseCurrencyCode,
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      );
}

class PersonalDebtSettlement {
  final String id;
  String debtId;
  double amount;
  DateTime date;
  String walletId;
  String? note;
  List<ExpenseAllocation> funding; // دفعات الاستلام من الإيرادات التي غطت هذا الصرف
  String currency;
  double exchangeRate;

  PersonalDebtSettlement({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    required this.walletId,
    this.note,
    List<ExpenseAllocation>? funding,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  }) : funding = funding ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'debtId': debtId,
        'amount': amount,
        'date': date.toIso8601String(),
        'walletId': walletId,
        'note': note,
        'funding': funding.map((a) => a.toJson()).toList(),
        'currency': currency,
        'exchangeRate': exchangeRate,
      };

  factory PersonalDebtSettlement.fromJson(Map<String, dynamic> json) =>
      PersonalDebtSettlement(
        id: json['id'],
        debtId: json['debtId'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        walletId: json['walletId'],
        note: json['note'],
        funding: (json['funding'] as List<dynamic>?)
                ?.map((a) =>
                    ExpenseAllocation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        currency: json['currency'] as String? ?? baseCurrencyCode,
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      );
}

class DebtFundingSource {
  final String id;
  final String debtId;
  final double amount;
  final DateTime date;
  final String walletId;
  final String? note;
  final bool isSettlement;
  final String currency;
  final double exchangeRate;

  const DebtFundingSource({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    required this.walletId,
    this.note,
    required this.isSettlement,
    this.currency = baseCurrencyCode,
    this.exchangeRate = 1.0,
  });
}
