import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../../themes/provider/theme_provider.dart';
import '../../utils/theme_mapper.dart';


class SettingsScreenController {
  final ThemeProvider themeProvider;

  SettingsScreenController(this.themeProvider);

  // Получение списка доступных тем
  List<FlexScheme> getAvailableThemes() {
    return FlexScheme.values;
  }

  // Установка выбранной темы
  void setTheme(FlexScheme scheme) {
    themeProvider.setFlexSchemeTheme(scheme.name);
  }

  // Получение текущей темы (теперь с использованием локализованных названий)
  String getCurrentTheme() {
    final schemeName = themeProvider.selectedFlexScheme;
    final scheme = FlexScheme.values.firstWhere(
          (scheme) => scheme.name == schemeName,
      orElse: () => FlexScheme.material,
    );
    return ThemeMapper.getDisplayName(scheme);
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