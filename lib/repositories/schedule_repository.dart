import '../models/schedule_response.dart';
import 'interfaces/i_schedule_repository.dart';
import '../services/bsu_api_service.dart';
import '../services/schedule_cache_service.dart';

class ScheduleRepository implements IScheduleRepository {
  final BsuApiService _apiService;
  final ScheduleCacheService _cacheService;

  ScheduleRepository(this._apiService, this._cacheService);

  @override
  Future<ScheduleResponse> getSchedule(int groupId, {int? week}) async {
    // Пытаемся получить из кеша
    final cachedSchedule = await _cacheService.getSchedule(groupId, week);
    if (cachedSchedule != null) {
      return cachedSchedule;
    }

    // Если нет в кеше, получаем из API
    final data = await _apiService.getSchedule(groupId, week: week);
    final schedule = ScheduleResponse.fromJson(data);

    // Сохраняем в кеш для будущих запросов
    await _cacheService.saveSchedule(groupId, week, schedule);

    return schedule;
  }

  @override
  Future<ScheduleResponse> getActualSchedule(int groupId, {int? week}) async {
    // Пытаемся получить из кеша
    final cachedSchedule = await _cacheService.getActualSchedule(groupId);
    if (cachedSchedule != null) {
      return cachedSchedule;
    }

    // Если нет в кеше, получаем из API
    final data = await _apiService.getTodaySchedule(groupId);
    final schedule = ScheduleResponse.fromJson(data);

    // Сохраняем в кеш
    await _cacheService.saveActualSchedule(groupId, schedule);

    return schedule;
  }

  @override
  Future<int> getCurrentWeek() async {
    // Пытаемся получить из кеша
    final cachedWeek = await _cacheService.getCurrentWeek();
    if (cachedWeek != null) {
      return cachedWeek;
    }

    // Если нет в кеше, получаем из API
    final week = await _apiService.getWeek(WeekActions.this_);

    // Сохраняем в кеш
    await _cacheService.saveCurrentWeek(week);

    return week;
  }

  // Принудительное обновление данных (игнорируя кеш)
  Future<ScheduleResponse> forceRefreshSchedule(int groupId, {int? week}) async {
    final data = await _apiService.getSchedule(groupId, week: week);
    final schedule = ScheduleResponse.fromJson(data);

    // Обновляем кеш
    await _cacheService.saveSchedule(groupId, week, schedule);

    return schedule;
  }

  // Очистка кеша
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }
}