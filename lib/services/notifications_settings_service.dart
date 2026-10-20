import 'dart:convert';

import 'base_services/base_storage_service.dart';

/// Настройки оповещений: что и когда показывать.
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.lessonReminder = true,
    this.minutesBefore = 5,
    this.scheduleChanges = true,
    this.helpRequests = true,
  });

  /// Главный выключатель: полностью отключает оповещения.
  final bool enabled;

  /// Напоминать о начале пары.
  final bool lessonReminder;

  /// За сколько минут до пары напоминать.
  final int minutesBefore;

  /// Сообщать, что расписание изменилось.
  final bool scheduleChanges;

  /// Сообщать о новых запросах помощи.
  final bool helpRequests;

  NotificationSettings copyWith({
    bool? enabled,
    bool? lessonReminder,
    int? minutesBefore,
    bool? scheduleChanges,
    bool? helpRequests,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      lessonReminder: lessonReminder ?? this.lessonReminder,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      scheduleChanges: scheduleChanges ?? this.scheduleChanges,
      helpRequests: helpRequests ?? this.helpRequests,
    );
  }
}

/// Хранилище настроек оповещений, отпечатков расписания и просмотренных
/// запросов помощи.
class NotificationsSettingsService extends BaseStorageService {
  static const String _enabledKey = 'notif_enabled';
  static const String _lessonsKey = 'notif_lessons';
  static const String _minutesKey = 'notif_minutes';
  static const String _scheduleKey = 'notif_schedule';
  static const String _helpKey = 'notif_help';
  static const String _seenHelpKey = 'notif_seen_help';
  static const String _askedKey = 'notif_permission_asked';

  static const String _signaturePrefix = 'notif_sig_v1:';

  @override
  Set<String> getAllowedKeys() => <String>{
        _enabledKey,
        _lessonsKey,
        _minutesKey,
        _scheduleKey,
        _helpKey,
        _seenHelpKey,
        _askedKey,
      };

  Future<NotificationSettings> load() async {
    return NotificationSettings(
      enabled: await getBool(_enabledKey) ?? true,
      lessonReminder: await getBool(_lessonsKey) ?? true,
      minutesBefore: (await getInt(_minutesKey) ?? 5).clamp(1, 60),
      scheduleChanges: await getBool(_scheduleKey) ?? true,
      helpRequests: await getBool(_helpKey) ?? true,
    );
  }

  Future<void> save(NotificationSettings settings) async {
    await setBool(_enabledKey, settings.enabled);
    await setBool(_lessonsKey, settings.lessonReminder);
    await setInt(_minutesKey, settings.minutesBefore);
    await setBool(_scheduleKey, settings.scheduleChanges);
    await setBool(_helpKey, settings.helpRequests);
  }

  /// Спрашивали ли разрешение на уведомления (Android 13+).
  Future<bool> isPermissionAsked() async =>
      await getBool(_askedKey) ?? false;

  Future<void> markPermissionAsked() => setBool(_askedKey, true);

  /// Отпечаток расписания конкретной группы и недели.
  Future<String?> loadSignature(String key) =>
      getString('$_signaturePrefix$key');

  Future<void> saveSignature(String key, String signature) =>
      setString('$_signaturePrefix$key', signature);

  /// id запросов помощи, о которых уже знаем (чтобы не повторяться).
  Future<Set<String>> loadSeenHelpIds() async {
    final raw = await getString(_seenHelpKey);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((item) => '$item').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveSeenHelpIds(Set<String> ids) =>
      setString(_seenHelpKey, jsonEncode(ids.toList()));
}
