import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../bsu_theme.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  String _selectedFlexScheme = BsuTheme.schemeName;
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
    notifyListeners();
    _settingsService.saveDarkModeState(_isDarkMode).catchError((_) {});
  }

  // Установка конкретной темы
  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      notifyListeners();
      _settingsService.saveDarkModeState(_isDarkMode).catchError((_) {});
    }
  }

  // Использование системной темы
  Future<void> useSystemTheme() async {
    final window = WidgetsBinding.instance.window;
    _isDarkMode = window.platformBrightness == Brightness.dark;
    notifyListeners();
    _settingsService.saveDarkModeState(_isDarkMode).catchError((_) {});
  }

  // Установка темы из flex_color_scheme.
  // Сначала обновляем UI, потом сохраняем: сбой сохранения
  // не должен оставлять пользователя со «старой» темой.
  void setFlexSchemeTheme(String schemeName) {
    if (_selectedFlexScheme != schemeName) {
      _selectedFlexScheme = schemeName;
      notifyListeners();
      _settingsService.saveSelectedTheme(_selectedFlexScheme).catchError((_) {});
    }
  }

  // Получение текущей темы: фирменная «БелГУ» или одна из flex-схем
  ThemeData get currentTheme {
    if (_selectedFlexScheme == BsuTheme.schemeName) {
      return _isDarkMode ? BsuTheme.dark() : BsuTheme.light();
    }

    final scheme = FlexScheme.values.firstWhere(
          (scheme) => scheme.name == _selectedFlexScheme,
      orElse: () => FlexScheme.material,
    );

    try {
      if (_isDarkMode) {
        return FlexColorScheme.dark(scheme: scheme).toTheme;
      } else {
        return FlexColorScheme.light(scheme: scheme).toTheme;
      }
    } catch (_) {
      // Любая ошибка построения flex-схемы не должна ломать приложение
      return _isDarkMode ? BsuTheme.dark() : BsuTheme.light();
    }
  }
}