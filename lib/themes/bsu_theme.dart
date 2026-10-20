import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Фирменные цвета НИУ БелГУ (bsuedu.ru): белый + зелёный.
class BsuColors {
  /// Основной зелёный БелГУ (логотип, шапка сайта).
  static const Color green = Color(0xFF27844A);
  static const Color greenDark = Color(0xFF1B5E32);
  static const Color greenLight = Color(0xFFE8F3EC);
}

/// Тема «БелГУ» — белый фон, зелёные акценты.
class BsuTheme {
  static ThemeData light() => FlexColorScheme.light(
        scheme: FlexScheme.custom,
        colors: const FlexSchemeColor(
          primary: BsuColors.green,
          primaryContainer: BsuColors.greenLight,
          secondary: BsuColors.greenDark,
          appBarColor: BsuColors.greenLight,
        ),
        subThemesData: const FlexSubThemesData(
          appBarBackgroundSchemeColor: SchemeColor.primaryContainer,
          navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
          cardRadius: 14.0,
        ),
        visualDensity: VisualDensity.standard,
        useMaterial3: true,
      ).toTheme;

  static ThemeData dark() => FlexColorScheme.dark(
        scheme: FlexScheme.custom,
        colors: const FlexSchemeColor(
          primary: Color(0xFF6FBF8E),
          primaryContainer: Color(0xFF1B3D28),
          secondary: Color(0xFF9BD4AF),
          appBarColor: Color(0xFF14291B),
        ),
        subThemesData: const FlexSubThemesData(
          appBarBackgroundSchemeColor: SchemeColor.surface,
          cardRadius: 14.0,
        ),
        visualDensity: VisualDensity.standard,
        useMaterial3: true,
      ).toTheme;

  /// Имя темы по умолчанию.
  static const String schemeName = 'belgu';
}
