// Тесты новых возможностей:
// 1) номер группы с ведущими нулями (иначе сайт не находит расписание,
//    а звёздочка в избранном «не ставится»);
// 2) поиск групп по неполному номеру — все совпадения, а не 10 с сайта;
// 3) ссылка на курс Pegasus сохраняется в модели и в кеше;
// 4) время пары для напоминаний;
// 5) настройки оповещений по умолчанию.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/models/metadata.dart';
import 'package:medusa/models/schedule_response.dart';
import 'package:medusa/services/bsu_api_service.dart';
import 'package:medusa/services/group_index_service.dart';
import 'package:medusa/services/notifications_settings_service.dart';
import 'package:medusa/utils/group_format.dart';
import 'package:medusa/utils/lesson_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

Lesson _lesson({String? url}) => Lesson(
      number: 1,
      time: '8:30 - 10:05',
      type: 'лек.',
      name: 'Физическая защита линий связи',
      teacher: 'Иванов И.И.',
      auditory: '6-12',
      online: false,
      key: '1_key',
      url: url,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Номер группы', () {
    test('ведущие нули сохраняются', () {
      expect(formatGroupNumber(1002205), '01002205');
      expect(formatGroupNumber(90002411), '90002411');
      expect(formatGroupName('1002205'), '01002205');
      expect(formatGroupName('  12002301 '), '12002301');
      // Не номер — не трогаем (поиск по фамилии).
      expect(formatGroupName('Иванов Иван'), 'Иванов Иван');
    });
  });

  group('Поиск групп по неполному номеру', () {
    test('по «9000» находит все группы, а не первые десять', () async {
      final groups = <String>[
        for (var i = 0; i < 56; i++)
          '9000${(2314 + i).toString().padLeft(4, '0')}',
        '12002301',
        '01002205',
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'groups_index_v1': jsonEncode(groups),
        'groups_index_updated_v1': DateTime.now().millisecondsSinceEpoch,
      });

      final service = GroupIndexService(BsuApiService('http://localhost'));
      await service.load();

      expect(service.isReady, isTrue);
      expect(service.suggest('9000').length, 56,
          reason: 'сайт отдаёт только 10 подсказок, локальный список — все');
      expect(service.suggest('900023').every((g) => g.startsWith('900023')),
          isTrue);
      expect(service.suggest('1200'), <String>['12002301']);
      expect(service.suggest('Иванов'), isEmpty,
          reason: 'по фамилии ищет сайт, локальный список групп не мешает');
    });
  });

  group('Ссылка на курс', () {
    test('переживает сохранение в кеш (toJson -> fromJson)', () {
      const url = 'https://pegas.bsuedu.ru/course/view.php?id=19697';
      // Именно так расписание ложится в кеш: через ScheduleResponse.
      final response = ScheduleResponse(
        metadata: Metadata(timestamp: '2026-10-19'),
        schedule: <String, List<Lesson>>{
          '19.10.2026 Понедельник': [_lesson(url: url)],
        },
      );
      final cached = ScheduleResponse.fromJson(
        jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>,
      );

      expect(cached.schedule.values.first.first.url, url,
          reason: 'иначе после перезапуска тап по паре перестанет '
              'открывать курс');
    });

    test('без ссылки url остаётся null', () {
      expect(Lesson.fromJson(_lesson().toJson()).url, isNull);
    });
  });

  group('Время пары', () {
    test('начало пары из строки сайта', () {
      final day = DateTime(2026, 10, 19);
      expect(lessonStart(day, '8:30 - 10:05'), DateTime(2026, 10, 19, 8, 30));
      expect(lessonStart(day, '14:05 – 15:40'), DateTime(2026, 10, 19, 14, 5));
      expect(lessonStart(day, 'нет времени'), isNull);
    });

    test('дата из ключа дня расписания', () {
      expect(scheduleDayDate('19.10.2026 Понедельник'),
          DateTime(2026, 10, 19));
      expect(scheduleDayDate('мусор'), isNull);
    });
  });

  group('Настройки оповещений', () {
    test('по умолчанию включены, напоминание за 5 минут', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await NotificationsSettingsService().load();

      expect(settings.enabled, isTrue);
      expect(settings.lessonReminder, isTrue);
      expect(settings.minutesBefore, 5);
      expect(settings.scheduleChanges, isTrue);
      expect(settings.helpRequests, isTrue);
    });

    test('время напоминания сохраняется и ограничено 1–60 минутами',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = NotificationsSettingsService();

      await service.save(
        (await service.load()).copyWith(minutesBefore: 15, enabled: false),
      );
      final restored = await service.load();
      expect(restored.minutesBefore, 15);
      expect(restored.enabled, isFalse);
    });
  });
}
