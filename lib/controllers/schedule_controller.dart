// lib/controllers/schedule_controller.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../models/schedule_response.dart';
import '../repositories/interfaces/i_schedule_repository.dart';

class ScheduleController extends ChangeNotifier {
  final IScheduleRepository _repository;

  /// Вызывается после каждой успешной загрузки расписания.
  /// На этом построены оповещения: напоминания о парах и изменения.
  final void Function(int groupId, Map<String, List<Lesson>> schedule)?
      onScheduleLoaded;

  ScheduleController(this._repository, {this.onScheduleLoaded});

  ScheduleResponse? _scheduleResponse;
  int? _currentWeek;

  bool _isLoading = false;
  String? _error;

  /// Смещение недели от текущей: 0 — эта, -1 — прошлая, +1 — следующая.
  int _weekOffset = 0;

  /// Направление последнего переключения недели:
  /// +1 — вперёд (следующая), -1 — назад (прошлая). Нужно для анимации.
  int weekDirection = 0;

  int? _groupId;

  ScheduleResponse? get scheduleResponse => _scheduleResponse;
  Map<String, List<Lesson>>? get schedule => _scheduleResponse?.schedule;
  int? get currentWeek => _currentWeek;
  int get weekOffset => _weekOffset;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Расписание показано из сохранённого снимка: сайт недоступен.
  bool get isOffline => _repository.isOffline;

  /// Когда был сделан снимок, который видит пользователь.
  DateTime? get offlineSnapshotAt => _repository.offlineSnapshotAt;

  Future<void> loadSchedule(int groupId, {int? week}) async {
    _groupId = groupId;
    if (week != null) _weekOffset = week;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currentWeek = await _repository.getCurrentWeek();
      _scheduleResponse =
          await _repository.getSchedule(groupId, week: _weekOffset);
      _error = null;

      // Загрузка «сама» (выбрали группу или открыли экран): если на этой
      // неделе впереди уже ничего нет, показываем следующую.
      if (week == null) await _skipFinishedWeek(groupId, forced: false);
      _notifyLoaded(groupId);
    } catch (e) {
      print(e.toString());
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Переключение на соседнюю неделю (+1 / -1) с загрузкой расписания.
  Future<void> changeWeek(int delta) async {
    final groupId = _groupId;
    if (groupId == null || _isLoading) return;
    weekDirection = delta >= 0 ? 1 : -1;
    await loadSchedule(groupId, week: _weekOffset + delta);
  }

  /// Возврат к текущей неделе.
  Future<void> goToCurrentWeek() async {
    if (_weekOffset == 0 || _isLoading) return;
    final groupId = _groupId;
    if (groupId == null) return;
    weekDirection = _weekOffset > 0 ? -1 : 1;
    await loadSchedule(groupId, week: 0);
  }

  /// Принудительная перезагрузка с сайта (минуя кеш) для текущей недели.
  Future<void> refreshSchedule() async {
    final groupId = _groupId;
    if (groupId == null || _isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _scheduleResponse =
          await _repository.forceRefreshSchedule(groupId, week: _weekOffset);
      await _skipFinishedWeek(groupId, forced: true);
      _notifyLoaded(groupId);
    } catch (e) {
      print(e.toString());
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Отдать загруженное расписание системе оповещений.
  void _notifyLoaded(int groupId) {
    final callback = onScheduleLoaded;
    final schedule = _scheduleResponse?.schedule;
    if (callback == null || schedule == null || schedule.isEmpty) return;
    // Не ждём: планирование уведомлений не должно тормозить экран.
    unawaited(Future<void>(() => callback(groupId, schedule)));
  }

  /// Прошедшую неделю не показываем.
  ///
  /// Если сегодня пятница после последней пары, суббота без занятий или
  /// воскресенье — пары впереди только на следующей неделе, и смотреть на
  /// закончившуюся смысла нет. Перескакиваем один раз: дальше листает
  /// пользователь, и выбранную вручную неделю мы не трогаем.
  Future<void> _skipFinishedWeek(int groupId, {required bool forced}) async {
    if (_weekOffset != 0) return;
    final loaded = _scheduleResponse?.schedule;
    if (loaded == null || _hasLessonsAhead(loaded)) return;

    weekDirection = 1;
    _weekOffset = 1;
    _scheduleResponse = forced
        ? await _repository.forceRefreshSchedule(groupId, week: 1)
        : await _repository.getSchedule(groupId, week: 1);
  }

  /// Остались ли на неделе пары — сегодня или в следующие дни.
  bool _hasLessonsAhead(Map<String, List<Lesson>> schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final entry in schedule.entries) {
      if (entry.value.isEmpty) continue;
      final date = _parseDayKey(entry.key);
      if (date == null || date.isBefore(today)) continue;
      return true;
    }
    return false;
  }

  /// Ключ дня из расписания («19.10.2026 Понедельник») → 19.10.2026.
  DateTime? _parseDayKey(String key) {
    final parts = key.split(' ').first.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  Future<void> loadActualSchedule(int groupId, {int? week}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentWeek = await _repository.getCurrentWeek();
      _scheduleResponse = await _repository.getActualSchedule(groupId, week: week);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


}