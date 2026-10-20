import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/help_request.dart';
import '../models/lesson.dart';
import '../utils/lesson_time.dart';

/// Системные оповещения: напоминания о парах, изменения расписания и новые
/// запросы помощи.
///
/// Сервис ничего не решает — только показывает уведомления и планирует
/// напоминания. Что и когда показывать, решает NotificationsController.
class NotificationService {
  static const String _lessonsChannel = 'lessons';
  static const String _scheduleChannel = 'schedule_changes';
  static const String _helpChannel = 'help_requests';

  static const String _lessonPayload = 'lesson';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  bool get isReady => _ready;

  /// Инициализация плагина и часового пояса.
  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // Без пояса планировать нельзя — работаем в UTC, но не падаем.
      debugPrint('Не удалось определить часовой пояс: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Каналы создаём заранее, чтобы у них были понятные названия
    // в настройках телефона.
    final androidPlugin = _android;
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _lessonsChannel,
        'Пары',
        description: 'Напоминания о начале пары',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _scheduleChannel,
        'Расписание',
        description: 'Изменения в расписании',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _helpChannel,
        'Помощь',
        description: 'Новые запросы помощи от преподавателей',
        importance: Importance.high,
      ),
    );

    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Разрешение на уведомления (Android 13+) и точные будильники.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final allowed = await _android?.requestNotificationsPermission();
      return allowed ?? true;
    } catch (e) {
      debugPrint('Разрешение на уведомления: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    if (!_ready) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Перепланировать напоминания о парах: старые убираем, новые ставим.
  ///
  /// [schedule] — расписание в формате приложения, [minutesBefore] —
  /// за сколько минут до начала пары напомнить.
  Future<void> scheduleLessonReminders(
    Map<String, List<Lesson>> schedule,
    int minutesBefore,
  ) async {
    if (!_ready) return;
    await cancelLessonReminders();

    final now = DateTime.now();
    final exact = await _canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    var id = 41000;
    for (final entry in schedule.entries) {
      final day = scheduleDayDate(entry.key);
      if (day == null) continue;
      for (final lesson in entry.value) {
        final start = lessonStart(day, lesson.time);
        if (start == null) continue;
        final when = start.subtract(Duration(minutes: minutesBefore));
        if (!when.isAfter(now)) continue;
        // Дальше двух недель не планируем: расписание всё равно обновится.
        if (start.difference(now) > const Duration(days: 14)) continue;

        await _plugin.zonedSchedule(
          id++,
          'Пара через $minutesBefore мин',
          _lessonBody(lesson, start),
          tz.TZDateTime.from(when, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _lessonsChannel,
              'Пары',
              channelDescription: 'Напоминания о начале пары',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: mode,
          payload: _lessonPayload,
        );
      }
    }
  }

  /// Убрать все запланированные напоминания о парах.
  Future<void> cancelLessonReminders() async {
    if (!_ready) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload == _lessonPayload) {
          await _plugin.cancel(request.id);
        }
      }
    } catch (e) {
      debugPrint('Отмена напоминаний: $e');
    }
  }

  /// Сообщить, что расписание изменилось.
  Future<void> showScheduleChanged({
    required String groupName,
    String? detail,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      50001,
      'Расписание изменилось',
      detail?.isNotEmpty == true
          ? detail!
          : 'Группа $groupName: откройте приложение, чтобы увидеть новое '
              'расписание.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _scheduleChannel,
          'Расписание',
          channelDescription: 'Изменения в расписании',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'schedule',
    );
  }

  /// Сообщить о новом запросе помощи от преподавателя.
  Future<void> showNewHelpRequest(HelpRequest request, {int index = 0}) async {
    if (!_ready) return;
    final body = <String>[
      if (request.authorName.isNotEmpty) request.authorName,
      if (request.place.isNotEmpty) request.place,
      if (request.timeText.isNotEmpty) request.timeText,
    ].join(' · ');
    await _plugin.show(
      50100 + index,
      'Новый запрос помощи',
      body.isEmpty ? request.title : '${request.title}\n$body',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _helpChannel,
          'Помощь',
          channelDescription: 'Новые запросы помощи от преподавателей',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'help',
    );
  }

  /// Для отладки/тестов: показать проверочное уведомление.
  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      50999,
      'Оповещения включены',
      'Медузка будет напоминать о парах и сообщать об изменениях.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _lessonsChannel,
          'Пары',
          channelDescription: 'Напоминания о начале пары',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'test',
    );
  }

  Future<bool> _canScheduleExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  String _lessonBody(Lesson lesson, DateTime start) {
    final hh = start.hour.toString().padLeft(2, '0');
    final mm = start.minute.toString().padLeft(2, '0');
    final parts = <String>[
      '$hh:$mm',
      lesson.name,
      if (lesson.auditory.isNotEmpty) lesson.auditory,
    ];
    return parts.join(' · ');
  }
}
