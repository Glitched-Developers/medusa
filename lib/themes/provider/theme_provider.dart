import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  String _selectedFlexScheme = FlexScheme.material.name;
  final SettingsService _settingsService;

  bool get isDarkMode => _isDarkMode;
  String get selectedFlexScheme => _selectedFlexScheme;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider(this._settingsService) {
    _loadThemeFromSettings();
  }

  // Загрузка темы при запуске приложения
  Future<void> _loadThemeFromSettings() async {
    _isDarkMode = await _settingsService.getDarkModeState();
    _selectedFlexScheme = await _settingsService.getSelectedTheme();
    notifyListeners();
  }

  // Переключение темы
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _settingsService.saveDarkModeState(_isDarkMode);
    notifyListeners();
  }

  // Установка конкретной темы
  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      _settingsService.saveDarkModeState(_isDarkMode);
      notifyListeners();
    }
  }

  // Использование системной темы
  Future<void> useSystemTheme() async {
    final window = WidgetsBinding.instance.window;
    _isDarkMode = window.platformBrightness == Brightness.dark;
    _settingsService.saveDarkModeState(_isDarkMode);
    notifyListeners();
  }

  // Установка темы из flex_color_scheme
  void setFlexSchemeTheme(String schemeName) {
    if (_selectedFlexScheme != schemeName) {
      _selectedFlexScheme = schemeName;
      _settingsService.saveSelectedTheme(_selectedFlexScheme);
      notifyListeners();
    }
  }

  // Получение текущей темы FlexColorScheme
  ThemeData get currentTheme {
    final scheme = FlexScheme.values.firstWhere(
          (scheme) => scheme.name == _selectedFlexScheme,
      orElse: () => FlexScheme.material,
    );

    if (_isDarkMode) {
      return FlexColorScheme.dark(scheme: scheme).toTheme;
    } else {
      return FlexColorScheme.light(scheme: scheme).toTheme;
    }
  }
}