import 'base_services/base_storage_service.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class SettingsService extends BaseStorageService {
  // Существующие ключи
  static const String _groupKey = 'selected_group';

  // Новые ключи для настроек темы
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _selectedFlexSchemeKey = 'selectedFlexScheme';
  static const String _firstLaunchKey = 'first_launch_completed';

  @override
  Set<String> getAllowedKeys() {
    return <String>{
      _groupKey,
      _isDarkModeKey,
      _selectedFlexSchemeKey,
      _firstLaunchKey
    };
  }

  // Существующие методы для работы с группой
  Future<void> saveSelectedGroup(int group) async {
    await setInt(_groupKey, group);
  }

  Future<int?> getSelectedGroup() async {
    return await getInt(_groupKey);
  }

  Future<bool> hasSelectedGroup() async {
    return await containsKey(_groupKey);
  }

  Future<void> clearSelectedGroup() async {
    await remove(_groupKey);
  }

  // Сохранение состояния темного режима
  Future<void> saveDarkModeState(bool isDarkMode) async {
    await setBool(_isDarkModeKey, isDarkMode);
  }

  // Получение состояния темного режима
  Future<bool> getDarkModeState() async {
    return await getBool(_isDarkModeKey) ?? false;
  }

  // Сохранение выбранной темы
  Future<void> saveSelectedTheme(String themeName) async {
    await setString(_selectedFlexSchemeKey, themeName);
  }

  // Получение выбранной темы
  Future<String> getSelectedTheme() async {
    return await getString(_selectedFlexSchemeKey) ?? FlexScheme.material.name;
  }

  Future<bool> getFirstLaunchStatus() async {
    return await containsKey(_firstLaunchKey);
  }

  Future<void> setFirstLaunchCompleate() async {
    await setInt(_firstLaunchKey, 1);
  }
}