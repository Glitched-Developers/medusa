import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _groupKey = 'selected_group';

  // Сохранение выбранной группы (число)
  Future<void> saveSelectedGroup(int group) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_groupKey, group);
  }

  // Получение выбранной группы
  Future<int?> getSelectedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_groupKey);
  }

  // Проверка, была ли выбрана группа
  Future<bool> hasSelectedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_groupKey);
  }

  // Очистка сохраненной группы (если потребуется)
  Future<void> clearSelectedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_groupKey);
  }
}