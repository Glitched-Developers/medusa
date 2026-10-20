import 'package:flex_color_scheme/flex_color_scheme.dart';

import '../../themes/provider/theme_provider.dart';
import '../../utils/theme_mapper.dart';


class SettingsScreenController {
  final ThemeProvider themeProvider;

  SettingsScreenController(this.themeProvider);

  // Список имён схем: первая — фирменная тема БелГУ, дальше flex-схемы
  List<String> getAvailableThemes() {
    return [
      ThemeMapper.belguScheme,
      ...FlexScheme.values.map((scheme) => scheme.name),
    ];
  }

  // Установка выбранной темы
  void setTheme(String schemeName) {
    themeProvider.setFlexSchemeTheme(schemeName);
  }

  // Получение текущей темы (с локализованными названиями)
  String getCurrentTheme() {
    return ThemeMapper.getDisplayNameFor(themeProvider.selectedFlexScheme);
  }

  // Переключение на темный/светлый режим
  void setDarkMode(bool isDark) {
    themeProvider.setDarkMode(isDark);
  }

  // Получение текущего состояния темного режима
  bool isDarkMode() {
    return themeProvider.isDarkMode;
  }

  // Использование системной темы
  void useSystemTheme() {
    themeProvider.useSystemTheme();
  }
}