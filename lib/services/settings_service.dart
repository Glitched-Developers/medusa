import 'base_services/base_storage_service.dart';

class SettingsService extends BaseStorageService {
  // Существующие ключи
  static const String _groupKey = 'selected_group';

  // Новые ключи для настроек темы
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _selectedFlexSchemeKey = 'selectedFlexScheme';
  static const String _firstLaunchKey = 'first_launch_completed';
  static const String _offlineRetentionKey = 'offline_retention_days';

  /// Сколько дней храним расписание на телефоне (по умолчанию — месяц).
  static const int defaultOfflineRetentionDays = 30;

  @override
  Set<String> getAllowedKeys() {
    return <String>{
      _groupKey,
      _isDarkModeKey,
      _selectedFlexSchemeKey,
      _firstLaunchKey,
      _offlineRetentionKey
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
    return await getString(_selectedFlexSchemeKey) ?? 'belgu';
  }

  Future<bool> getFirstLaunchStatus() async {
    return await containsKey(_firstLaunchKey);
  }

  Future<void> setFirstLaunchCompleate() async {
    await setInt(_firstLaunchKey, 1);
  }

  /// Сколько дней расписание хранится на телефоне (1–365).
  Future<int> getOfflineRetentionDays() async {
    final value = await getInt(_offlineRetentionKey);
    if (value == null) return defaultOfflineRetentionDays;
    return value.clamp(1, 365);
  }

  Future<void> saveOfflineRetentionDays(int days) async {
    await setInt(_offlineRetentionKey, days.clamp(1, 365));
  }
}