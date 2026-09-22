import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  static bool isDarkMode = true;

  // ألوان الوضع الليلي الأصلية
  static const Color darkBg = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1A1D27);
  static const Color darkCard = Color(0xFF222636);
  static const Color darkCardBorder = Color(0xFF2E3348);
  static const Color darkIncomeGreen = Color(0xFF00D395);
  static const Color darkIncomeGreenDim = Color(0xFF0A3D2A);
  static const Color darkExpenseRed = Color(0xFFFF5C5C);
  static const Color darkExpenseRedDim = Color(0xFF3D1212);
  static const Color darkAccentBlue = Color(0xFF5B8DEF);
  static const Color darkAccentBlueDim = Color(0xFF1A2A4A);
  static const Color darkTextPrimary = Color(0xFFEEF0F8);
  static const Color darkTextSecondary = Color(0xFF8B90A7);
  static const Color darkTextMuted = Color(0xFF555870);
  static const Color darkDivider = Color(0xFF252838);

  // ألوان الوضع النهاري المريح تحت الشمس
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E6EE);
  static const Color lightIncomeGreen = Color(0xFF0D9768);
  static const Color lightIncomeGreenDim = Color(0xFFE0F5EC);
  static const Color lightExpenseRed = Color(0xFFE53935);
  static const Color lightExpenseRedDim = Color(0xFFFFEBEE);
  static const Color lightAccentBlue = Color(0xFF2563EB);
  static const Color lightAccentBlueDim = Color(0xFFE6F0FD);
  static const Color lightTextPrimary = Color(0xFF19202E);
  static const Color lightTextSecondary = Color(0xFF545F76);
  static const Color lightTextMuted = Color(0xFF8591A5);
  static const Color lightDivider = Color(0xFFE6EAF2);

  // ألوان ديناميكية تستجيب تلقائياً للوضع الحالي (نهاري / ليلي)
  static Color get bg => isDarkMode ? darkBg : lightBg;
  static Color get surface => isDarkMode ? darkSurface : lightSurface;
  static Color get card => isDarkMode ? darkCard : lightCard;
  static Color get cardBorder => isDarkMode ? darkCardBorder : lightCardBorder;
  static Color get incomeGreen => isDarkMode ? darkIncomeGreen : lightIncomeGreen;
  static Color get incomeGreenDim => isDarkMode ? darkIncomeGreenDim : lightIncomeGreenDim;
  static Color get expenseRed => isDarkMode ? darkExpenseRed : lightExpenseRed;
  static Color get expenseRedDim => isDarkMode ? darkExpenseRedDim : lightExpenseRedDim;
  static Color get accentBlue => isDarkMode ? darkAccentBlue : lightAccentBlue;
  static Color get accentBlueDim => isDarkMode ? darkAccentBlueDim : lightAccentBlueDim;
  static Color get textPrimary => isDarkMode ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => isDarkMode ? darkTextSecondary : lightTextSecondary;
  static Color get textMuted => isDarkMode ? darkTextMuted : lightTextMuted;
  static Color get divider => isDarkMode ? darkDivider : lightDivider;

  static ThemeData get theme => darkTheme;

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          primary: darkIncomeGreen,
          secondary: darkAccentBlue,
          surface: darkSurface,
          error: darkExpenseRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            color: darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: darkTextSecondary),
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: darkCardBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkCardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkCardBorder),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: darkAccentBlue, width: 1.5),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: darkExpenseRed, width: 1.5),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: darkExpenseRed, width: 2),
          ),
          errorStyle: const TextStyle(fontFamily: 'Cairo', color: darkExpenseRed, fontSize: 12),
          labelStyle: const TextStyle(fontFamily: 'Cairo', color: darkTextSecondary),
          hintStyle: const TextStyle(fontFamily: 'Cairo', color: darkTextMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkIncomeGreen,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkAccentBlue,
            textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
          ),
        ),
        dividerTheme: const DividerThemeData(color: darkDivider, thickness: 1),
        dialogTheme: DialogThemeData(
          backgroundColor: darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: darkCardBorder),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: darkTextSecondary,
            fontSize: 14,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: darkCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: darkCardBorder),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: darkTextPrimary,
            fontSize: 13,
          ),
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: lightBg,
        colorScheme: const ColorScheme.light(
          primary: lightIncomeGreen,
          secondary: lightAccentBlue,
          surface: lightSurface,
          error: lightExpenseRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            color: lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: lightTextSecondary),
        ),
        cardTheme: CardThemeData(
          color: lightCard,
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.04),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: lightCardBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightCardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightCardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightAccentBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightExpenseRed, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightExpenseRed, width: 2),
          ),
          errorStyle: const TextStyle(fontFamily: 'Cairo', color: lightExpenseRed, fontSize: 12),
          labelStyle: const TextStyle(fontFamily: 'Cairo', color: lightTextSecondary),
          hintStyle: const TextStyle(fontFamily: 'Cairo', color: lightTextMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightIncomeGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: lightAccentBlue,
            textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
          ),
        ),
        dividerTheme: const DividerThemeData(color: lightDivider, thickness: 1),
        dialogTheme: DialogThemeData(
          backgroundColor: lightSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: lightCardBorder),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: lightTextSecondary,
            fontSize: 14,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: lightSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: lightCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: lightCardBorder),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: lightTextPrimary,
            fontSize: 13,
          ),
        ),
      );
}

extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get dynamicScaffoldBg => isDark ? AppTheme.bg : AppTheme.lightBg;
  Color get dynamicSurfaceBg => isDark ? AppTheme.surface : AppTheme.lightSurface;
  Color get dynamicCardBg => isDark ? AppTheme.card : AppTheme.lightCard;
  Color get dynamicCardBorder => isDark ? AppTheme.cardBorder : AppTheme.lightCardBorder;
  Color get dynamicTextPrimary => isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  Color get dynamicTextSecondary => isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
  Color get dynamicTextMuted => isDark ? AppTheme.textMuted : AppTheme.lightTextMuted;
  Color get dynamicIncomeGreen => isDark ? AppTheme.incomeGreen : AppTheme.lightIncomeGreen;
  Color get dynamicIncomeGreenDim => isDark ? AppTheme.incomeGreenDim : AppTheme.lightIncomeGreenDim;
  Color get dynamicExpenseRed => isDark ? AppTheme.expenseRed : AppTheme.lightExpenseRed;
  Color get dynamicExpenseRedDim => isDark ? AppTheme.expenseRedDim : AppTheme.lightExpenseRedDim;
  Color get dynamicAccentBlue => isDark ? AppTheme.accentBlue : AppTheme.lightAccentBlue;
  Color get dynamicAccentBlueDim => isDark ? AppTheme.accentBlueDim : AppTheme.lightAccentBlueDim;
  Color get dynamicDivider => isDark ? AppTheme.divider : AppTheme.lightDivider;
}

extension NumFormat on double {
  String get formatted {
    final nf = NumberFormat('#,##0.##', 'en_US');
    return nf.format(this);
  }
}

extension NumFormatFull on double {
  String get formattedFull {
    final nf = NumberFormat('#,##0.##', 'en_US');
    return nf.format(this);
  }
}

extension NumPlain on double {
  String get plain {
    if (this == roundToDouble()) return toInt().toString();
    return toString();
  }
}

const _digitMap = {
  '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
  '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
  '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
};

/// يحلل الأرقام مع دعم الأرقام العربية/الفارسية والفواصل العربية
double? tryParseFlexible(String? raw) {
  if (raw == null) return null;
  var t = raw.trim();
  if (t.isEmpty) return null;
  t = t.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) => _digitMap[m[0]]!);
  t = t.replaceAll('٫', '.').replaceAll('٬', '').replaceAll(',', '');
  return double.tryParse(t);
}
