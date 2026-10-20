// Офлайн-расписание: если сайт недоступен, приложение показывает
// сохранённый снимок, пока он не вышел за срок хранения из настроек.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/models/metadata.dart';
import 'package:medusa/models/schedule_response.dart';
import 'package:medusa/repositories/schedule_repository.dart';
import 'package:medusa/services/bsu_api_service.dart';
import 'package:medusa/services/schedule_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScheduleResponse _schedule() => ScheduleResponse(
      metadata: Metadata(timestamp: '2026-10-19'),
      schedule: {
        '19.10.2026 Понедельник': [
          Lesson(
            number: 1,
            time: '8:30 - 10:05',
            type: 'Лекция',
            name: 'Математика',
            teacher: 'Иванов И.И.',
            auditory: '6-12',
            online: false,
            key: '1_key',
          ),
        ],
      },
    );

/// Сайт недоступен — любая попытка запроса падает.
BsuApiService _offlineApi() => BsuApiService.withClient(
      'http://localhost',
      MockClient((request) async => throw const SocketExceptionLike()),
    );

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketException: нет сети';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Офлайн-расписание', () {
    test('без сети отдаётся сохранённый снимок и флаг offline', () async {
      final cache = ScheduleCacheService();
      await cache.init();
      await cache.saveSchedule(12002301, 0, _schedule());
      // Сохранённый час назад: обычный кеш уже «протух», но снимок жив.
      final prefs = await cache.getPrefs();
      final key = 'timestamp_cached_schedule_v2_12002301_0';
      await prefs.setInt(
        key,
        DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
      );

      final repository = ScheduleRepository(_offlineApi(), cache);
      final result = await repository.getSchedule(12002301);

      expect(result.schedule['19.10.2026 Понедельник'], hasLength(1),
          reason: 'без интернета расписание должно открываться из кеша');
      expect(repository.isOffline, isTrue);
      expect(repository.offlineSnapshotAt, isNotNull);
    });

    test('снимок старше срока хранения не показываем', () async {
      final cache = ScheduleCacheService();
      await cache.init();
      cache.retentionDays = 2;
      await cache.saveSchedule(12002301, 0, _schedule());
      final prefs = await cache.getPrefs();
      await prefs.setInt(
        'timestamp_cached_schedule_v2_12002301_0',
        DateTime.now().subtract(const Duration(days: 5)).millisecondsSinceEpoch,
      );

      final repository = ScheduleRepository(_offlineApi(), cache);
      await expectLater(
        repository.getSchedule(12002301),
        throwsA(isA<ApiException>()),
        reason: 'старый снимок уже не должен выдаваться',
      );
    });

    test('номер недели тоже берётся из кеша, когда сети нет', () async {
      final cache = ScheduleCacheService();
      await cache.init();
      await cache.saveCurrentWeek(8);
      final prefs = await cache.getPrefs();
      await prefs.setInt(
        'timestamp_cached_current_week',
        DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      );

      final repository = ScheduleRepository(_offlineApi(), cache);
      expect(await repository.getCurrentWeek(), 8);
    });

    test('просроченные снимки удаляются из хранилища', () async {
      final cache = ScheduleCacheService();
      await cache.init();
      await cache.saveSchedule(12002301, 0, _schedule());
      final prefs = await cache.getPrefs();
      await prefs.setInt(
        'timestamp_cached_schedule_v2_12002301_0',
        DateTime.now().subtract(const Duration(days: 40)).millisecondsSinceEpoch,
      );

      cache.retentionDays = 30;
      await cache.pruneExpired();

      expect(prefs.containsKey('cached_schedule_v2_12002301_0'), isFalse);
      expect(prefs.containsKey('timestamp_cached_schedule_v2_12002301_0'),
          isFalse);
    });

    test('свежий кеш отдаётся без запросов к сайту', () async {
      final cache = ScheduleCacheService();
      await cache.init();
      await cache.saveSchedule(12002301, 0, _schedule());

      var requests = 0;
      final api = BsuApiService.withClient(
        'http://localhost',
        MockClient((request) async {
          requests++;
          return http.Response('', 500);
        }),
      );

      final repository = ScheduleRepository(api, cache);
      final result = await repository.getSchedule(12002301);

      expect(requests, 0);
      expect(repository.isOffline, isFalse);
      expect(jsonEncode(result.toJson()), contains('Математика'));
    });
  });
}
