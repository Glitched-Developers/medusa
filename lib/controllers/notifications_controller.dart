import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/help_request.dart';
import '../models/lesson.dart';
import '../services/notification_service.dart';
import '../services/notifications_settings_service.dart';
import '../utils/group_format.dart';

/// Логика системы оповещений.
///
/// Решает, что показать: напоминание о паре, изменение расписания или новый
/// запрос помощи. Сами уведомления показывает [NotificationService].
class NotificationsController extends ChangeNotifier {
  NotificationsController(this._service, this._settings) {
    _load();
  }

  final NotificationService _service;
  final NotificationsSettingsService _settings;

  NotificationSettings _current = const NotificationSettings();
  bool _ready = false;

  /// Последнее загруженное расписание — чтобы перепланировать напоминания,
  /// когда пользователь меняет настройки.
  Map<String, List<Lesson>>? _lastSchedule;

  NotificationSettings get settings => _current;
  bool get isReady => _ready;
  bool get enabled => _current.enabled;

  Future<void> _load() async {
    _current = await _settings.load();
    _ready = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _current = _current.copyWith(enabled: value);
    await _persist();
    if (value) {
      await _service.requestPermission();
      await _service.showTest();
      await _applyReminders();
    } else {
      await _service.cancelLessonReminders();
    }
  }

  Future<void> setLessonReminder(bool value) async {
    _current = _current.copyWith(lessonReminder: value);
    await _persist();
    await _applyReminders();
  }

  Future<void> setMinutesBefore(int minutes) async {
    _current = _current.copyWith(minutesBefore: minutes.clamp(1, 60));
    await _persist();
    await _applyReminders();
  }

  Future<void> setScheduleChanges(bool value) async {
    _current = _current.copyWith(scheduleChanges: value);
    await _persist();
  }

  Future<void> setHelpRequests(bool value) async {
    _current = _current.copyWith(helpRequests: value);
    await _persist();
  }

  /// Попросить разрешение на уведомления (кнопка на экране настроек).
  Future<bool> requestPermission() async {
    final granted = await _service.requestPermission();
    if (granted) await _applyReminders();
    return granted;
  }

  Future<bool> hasPermission() => _service.hasPermission();

  /// Показать проверочное уведомление.
  Future<void> sendTest() async {
    await _service.requestPermission();
    await _service.showTest();
  }

  /// Вызывается после каждой успешной загрузки расписания.
  ///
  /// Здесь же ловим изменения: сравниваем отпечаток с прошлым разом и,
  /// если пары поменялись, показываем уведомление.
  Future<void> onScheduleLoaded(
    int groupId,
    Map<String, List<Lesson>> schedule,
  ) async {
    if (schedule.isEmpty) return;

    _lastSchedule = schedule;

    final weekKey = schedule.keys.first.split(' ').first;
    final signatureKey = '${formatGroupNumber(groupId)}:$weekKey';
    final signature = _signatureOf(schedule);
    final previous = await _settings.loadSignature(signatureKey);
    await _settings.saveSignature(signatureKey, signature);

    if (previous != null &&
        previous != signature &&
        _current.enabled &&
        _current.scheduleChanges) {
      final days = _changedDays(previous, signature);
      await _service.showScheduleChanged(
        groupName: formatGroupNumber(groupId),
        detail: days.isEmpty
            ? null
            : 'Изменились пары: $days. Откройте приложение, чтобы увидеть '
                'новое расписание.',
      );
    }

    if (!_current.enabled) {
      await _service.cancelLessonReminders();
      return;
    }
    await _ensurePermission();
    if (_current.lessonReminder) {
      await _service.scheduleLessonReminders(schedule, _current.minutesBefore);
    }
  }

  /// Вызывается после загрузки списка запросов помощи.
  ///
  /// О новых запросах сообщаем один раз: id запоминаем. Свои запросы
  /// (и демо-примеры при первом запуске) не считаем новыми.
  Future<void> onHelpRequests(
    List<HelpRequest> requests, {
    required String myName,
  }) async {
    final seen = await _settings.loadSeenHelpIds();
    final firstRun = seen.isEmpty;
    final fresh = requests
        .where((request) =>
            !seen.contains(request.id) &&
            request.authorName.trim() != myName.trim())
        .toList();
    await _settings.saveSeenHelpIds(
      requests.map((request) => request.id).toSet(),
    );

    if (firstRun || fresh.isEmpty) return;
    if (!_current.enabled || !_current.helpRequests) return;

    var index = 0;
    for (final request in fresh.take(3)) {
      await _service.showNewHelpRequest(request, index: index++);
    }
  }

  Future<void> _persist() async {
    notifyListeners();
    await _settings.save(_current);
  }

  Future<void> _applyReminders() async {
    final schedule = _lastSchedule;
    if (schedule == null) return;
    if (!_current.enabled || !_current.lessonReminder) {
      await _service.cancelLessonReminders();
      return;
    }
    await _service.scheduleLessonReminders(schedule, _current.minutesBefore);
  }

  Future<void> _ensurePermission() async {
    if (await _settings.isPermissionAsked()) return;
    await _settings.markPermissionAsked();
    await _service.requestPermission();
  }

  /// Отпечаток расписания: день -> отсортированный список пар.
  String _signatureOf(Map<String, List<Lesson>> schedule) {
    final days = <String, List<String>>{};
    for (final entry in schedule.entries) {
      final lessons = entry.value
          .map((lesson) => '${lesson.number}|${lesson.time}|${lesson.name}|'
              '${lesson.auditory}|${lesson.teacher}|${lesson.type}')
          .toList()
        ..sort();
      days[entry.key] = lessons;
    }
    final sortedKeys = days.keys.toList()..sort();
    return jsonEncode(<String, dynamic>{
      for (final key in sortedKeys) key: days[key],
    });
  }

  /// Какие дни изменились: «понедельник, среда».
  String _changedDays(String before, String after) {
    try {
      final oldDays = jsonDecode(before) as Map<String, dynamic>;
      final newDays = jsonDecode(after) as Map<String, dynamic>;
      final changed = <String>[];
      for (final key in newDays.keys) {
        final oldValue = jsonEncode(oldDays[key]);
        final newValue = jsonEncode(newDays[key]);
        if (oldValue == newValue) continue;
        final parts = key.split(' ');
        changed.add(parts.length > 1 ? parts.sublist(1).join(' ') : key);
      }
      return changed.take(3).join(', ');
    } catch (_) {
      return '';
    }
  }
}
