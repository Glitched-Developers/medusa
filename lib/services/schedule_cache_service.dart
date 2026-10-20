import 'dart:convert';
import 'base_services/base_storage_service.dart';
import '../models/schedule_response.dart';

class ScheduleCacheService extends BaseStorageService {
  // Keys for storing different types of data.
  // _scheduleKey содержит версию схемы (v2): данные, сохранённые до
  // появления teacherId, игнорируются и перезагружаются с сайта.
  static const String _scheduleKey = 'cached_schedule_v2_';
  static const String _actualScheduleKey = 'cached_actual_schedule_v2_';
  static const String _weekKey = 'cached_current_week';
  static const String _timestampPrefix = 'timestamp_';

  // Cache TTL in minutes
  static const int _scheduleTtlMinutes = 60; // 1 hour
  static const int _actualScheduleTtlMinutes = 15; // 15 minutes
  static const int _weekTtlMinutes = 240; // 4 hours

  /// Сколько дней храним расписание на телефоне. Меняется из настроек:
  /// пока интернета нет, приложение живёт на этом снимке.
  int retentionDays = 30;

  @override
  Set<String> getAllowedKeys() {
    // Return empty set to disable filtering - allows all keys
    return {};
  }

  // Generate cache key for schedule of a specific group and week
  String _getScheduleKey(int groupId, int? week) {
    return '$_scheduleKey${groupId}_${week ?? 0}';
  }

  // Generate cache key for actual schedule of a group
  String _getActualScheduleKey(int groupId) {
    return '$_actualScheduleKey$groupId';
  }

  // Generate key for timestamp
  String _getTimestampKey(String key) {
    return '$_timestampPrefix$key';
  }

  // Fixed save methods with error handling
  Future<void> saveSchedule(int groupId, int? week, ScheduleResponse schedule) async {
    try {
      final key = _getScheduleKey(groupId, week);
      // Fixed: Use Map directly without conversion
      final scheduleData = schedule.toJson();
      final scheduleString = jsonEncode(scheduleData);
      await setString(key, scheduleString);
      await setInt(_getTimestampKey(key), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving schedule: $e');
      // Handle the error appropriately
    }
  }

  Future<void> saveActualSchedule(int groupId, ScheduleResponse schedule) async {
    try {
      final key = _getActualScheduleKey(groupId);
      // Fixed: Use Map directly without conversion
      final scheduleData = schedule.toJson();
      final scheduleString = jsonEncode(scheduleData);
      await setString(key, scheduleString);
      await setInt(_getTimestampKey(key), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving actual schedule: $e');
      // Handle the error appropriately
    }
  }

  Future<void> saveCurrentWeek(int week) async {
    try {
      await setInt(_weekKey, week);
      await setInt(_getTimestampKey(_weekKey), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving current week: $e');
      // Handle the error appropriately
    }
  }

  // Fixed get methods with error handling
  Future<ScheduleResponse?> getSchedule(int groupId, int? week) async {
    try {
      final key = _getScheduleKey(groupId, week);
      if (!await isValid(key, _scheduleTtlMinutes)) {
        return null;
      }
      final dataString = await getString(key);
      if (dataString == null) return null;
      final data = jsonDecode(dataString) as Map<String, dynamic>;
      return ScheduleResponse.fromJson(data);
    } catch (e) {
      print('Error getting schedule: $e');
      return null;
    }
  }

  Future<ScheduleResponse?> getActualSchedule(int groupId) async {
    try {
      final key = _getActualScheduleKey(groupId);
      if (!await isValid(key, _actualScheduleTtlMinutes)) {
        return null;
      }
      final dataString = await getString(key);
      if (dataString == null) return null;
      final data = jsonDecode(dataString) as Map<String, dynamic>;
      return ScheduleResponse.fromJson(data);
    } catch (e) {
      print('Error getting actual schedule: $e');
      return null;
    }
  }

  /// Сохранённое расписание без проверки «свежести» — для офлайна.
  ///
  /// Отдаём снимок, пока он не старше [retentionDays]: даже через неделю
  /// без интернета студент увидит своё расписание, а не пустой экран.
  Future<ScheduleResponse?> getStaleSchedule(int groupId, int? week) async {
    try {
      final key = _getScheduleKey(groupId, week);
      if (!await _isWithinRetention(key)) return null;
      final dataString = await getString(key);
      if (dataString == null) return null;
      final data = jsonDecode(dataString) as Map<String, dynamic>;
      return ScheduleResponse.fromJson(data);
    } catch (e) {
      print('Error getting stale schedule: $e');
      return null;
    }
  }

  /// Когда расписание было сохранено (для подписи «данные от …»).
  Future<DateTime?> getCachedAt(int groupId, int? week) async {
    final key = _getScheduleKey(groupId, week);
    final timestamp = await getInt(_getTimestampKey(key));
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Снимок ещё не старше срока хранения из настроек.
  Future<bool> _isWithinRetention(String key) async {
    if (!await containsKey(key)) return false;
    final timestamp = await getInt(_getTimestampKey(key));
    if (timestamp == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age <= Duration(days: retentionDays).inMilliseconds;
  }

  /// Удаляет снимки, которые вышли за срок хранения из настроек.
  Future<void> pruneExpired() async {
    try {
      final prefs = await getPrefs();
      final limit = Duration(days: retentionDays).inMilliseconds;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final key in prefs.getKeys().toList()) {
        final isSchedule = key.startsWith(_scheduleKey) ||
            key.startsWith(_actualScheduleKey);
        if (!isSchedule) continue;
        final timestamp = prefs.getInt(_getTimestampKey(key));
        if (timestamp == null || now - timestamp > limit) {
          await prefs.remove(key);
          await prefs.remove(_getTimestampKey(key));
        }
      }
    } catch (e) {
      print('Error pruning cache: $e');
    }
  }

  Future<int?> getCurrentWeek() async {
    try {
      if (!await isValid(_weekKey, _weekTtlMinutes)) {
        return null;
      }
      return await getInt(_weekKey);
    } catch (e) {
      print('Error getting current week: $e');
      return null;
    }
  }

  /// Номер недели без проверки срока: нужен, когда сети нет.
  Future<int?> getCachedWeek() async {
    try {
      if (!await containsKey(_weekKey)) return null;
      return await getInt(_weekKey);
    } catch (e) {
      return null;
    }
  }

  Future<bool> isValid(String key, int ttlMinutes) async {
    try {
      final timestampKey = _getTimestampKey(key);
      if (!await containsKey(timestampKey) || !await containsKey(key)) {
        return false;
      }
      final timestamp = await getInt(timestampKey);
      if (timestamp == null) {
        return false;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedMinutes = (now - timestamp) / (1000 * 60);
      return elapsedMinutes < ttlMinutes;
    } catch (e) {
      print('Error checking validity: $e');
      return false;
    }
  }

  // Fixed clearCache to clear all related cache data
  Future<void> clearCache() async {
    try {
      // Очистка информации о текущей неделе
      await remove(_weekKey);
      await remove(_getTimestampKey(_weekKey));

      // Если у вас есть список групп, для которых может быть сохранен кеш,
      // можно использовать этот подход для очистки кеша для каждой группы:
      //
      // final List<int> cachedGroupIds = await getCachedGroupIds();
      // for (final groupId in cachedGroupIds) {
      //   await clearCacheForGroup(groupId);
      // }

      // Альтернатива: если вы знаете текущую группу, очистите только для нее
      // await clearCacheForGroup(currentGroupId);

    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

// Метод для очистки кеша для конкретной группы
  Future<void> clearCacheForGroup(int groupId) async {
    try {
      // Очистка актуального расписания для группы
      final actualKey = _getActualScheduleKey(groupId);
      await remove(actualKey);
      await remove(_getTimestampKey(actualKey));

      // Очистка регулярного расписания для группы (для всех недель)
      // Можно очистить для текущей недели и несколько недель вперед/назад
      for (int weekOffset = -2; weekOffset <= 2; weekOffset++) {
        final int weekNum = (await getCurrentWeek() ?? 1) + weekOffset;
        if (weekNum > 0) {
          final scheduleKey = _getScheduleKey(groupId, weekNum);
          await remove(scheduleKey);
          await remove(_getTimestampKey(scheduleKey));
        }
      }
    } catch (e) {
      print('Error clearing cache for group $groupId: $e');
    }
  }

}