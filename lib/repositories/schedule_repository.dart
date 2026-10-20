import '../models/schedule_response.dart';
import 'interfaces/i_schedule_repository.dart';
import '../services/bsu_api_service.dart';
import '../services/schedule_cache_service.dart';

class ScheduleRepository implements IScheduleRepository {
  final BsuApiService _apiService;
  final ScheduleCacheService _cacheService;

  ScheduleRepository(this._apiService, this._cacheService);

  bool _offline = false;
  DateTime? _offlineAt;

  /// Сайт не ответил, показали сохранённый снимок.
  @override
  bool get isOffline => _offline;

  @override
  DateTime? get offlineSnapshotAt => _offlineAt;

  void _markOnline() {
    _offline = false;
    _offlineAt = null;
  }

  @override
  Future<ScheduleResponse> getSchedule(int groupId, {int? week}) async {
    // Свежий кеш (до часа) — сразу отдаём, в сеть не идём.
    final cachedSchedule = await _cacheService.getSchedule(groupId, week);
    if (cachedSchedule != null) {
      _markOnline();
      return cachedSchedule;
    }

    try {
      final data = await _apiService.getSchedule(groupId, week: week);
      final schedule = ScheduleResponse.fromJson(data);
      await _cacheService.saveSchedule(groupId, week, schedule);
      _markOnline();
      return schedule;
    } catch (e) {
      // Сети нет — показываем последний сохранённый снимок, пока он
      // не вышел за срок хранения из настроек. Приложение остаётся
      // полезным: расписание можно открыть, выйти и зайти снова.
      final stale = await _cacheService.getStaleSchedule(groupId, week);
      if (stale == null) rethrow;
      _offline = true;
      _offlineAt = await _cacheService.getCachedAt(groupId, week);
      return stale;
    }
  }

  @override
  Future<ScheduleResponse> getActualSchedule(int groupId, {int? week}) async {
    // Пытаемся получить из кеша
    final cachedSchedule = await _cacheService.getActualSchedule(groupId);
    if (cachedSchedule != null) {
      _markOnline();
      return cachedSchedule;
    }

    try {
      final data = await _apiService.getTodaySchedule(groupId);
      final schedule = ScheduleResponse.fromJson(data);
      await _cacheService.saveActualSchedule(groupId, schedule);
      _markOnline();
      return schedule;
    } catch (e) {
      final stale = await _cacheService.getSchedule(groupId, week);
      if (stale == null) rethrow;
      _offline = true;
      _offlineAt = await _cacheService.getCachedAt(groupId, week);
      return stale;
    }
  }

  @override
  Future<int> getCurrentWeek() async {
    // Пытаемся получить из кеша
    final cachedWeek = await _cacheService.getCurrentWeek();
    if (cachedWeek != null) {
      return cachedWeek;
    }

    try {
      final week = await _apiService.getWeek(WeekActions.this_);
      await _cacheService.saveCurrentWeek(week);
      return week;
    } catch (e) {
      // Без сети номер недели берём из сохранённого: он нужен только
      // для подписи, а расписание покажем из кеша.
      final stored = await _cacheService.getCachedWeek();
      if (stored != null) return stored;
      rethrow;
    }
  }

  // Принудительное обновление данных (игнорируя кеш)
  @override
  Future<ScheduleResponse> forceRefreshSchedule(int groupId,
      {int? week}) async {
    try {
      final data = await _apiService.getSchedule(groupId, week: week);
      final schedule = ScheduleResponse.fromJson(data);

      // Обновляем кеш
      await _cacheService.saveSchedule(groupId, week, schedule);
      _markOnline();
      return schedule;
    } catch (e) {
      // Потянули вниз без интернета — оставляем то, что уже есть.
      final stale = await _cacheService.getStaleSchedule(groupId, week);
      if (stale == null) rethrow;
      _offline = true;
      _offlineAt = await _cacheService.getCachedAt(groupId, week);
      return stale;
    }
  }

  // Очистка кеша
  @override
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }
}
