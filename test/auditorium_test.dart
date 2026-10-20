// Поиск по кабинету и переход в расписание аудитории:
// у сайта нет общего списка кабинетов, поэтому индекс собирается
// по корпусам (aud_json.php) и кешируется.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/services/auditorium_index_service.dart';
import 'package:medusa/services/bsu_api_service.dart';
import 'package:medusa/view/screens/auditorium_schedule_screen.dart';
import 'package:medusa/view/widgets/lesson_title.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _requests = 0;

BsuApiService _api() => BsuApiService.withClient(
      'http://localhost',
      MockClient((request) async {
        _requests++;
        final url = request.url.toString();

        // Страница аудиторий: корпуса.
        if (url.endsWith('/auditories/')) {
          return http.Response.bytes(
            utf8.encode(
              '<select id="build" onchange="loadAuds();">'
              '<option id="01">Корпус 1</option>'
              '<option id="06">Корпус 6</option>'
              '</select>',
            ),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }

        // Кабинеты корпуса.
        if (url.contains('aud_json.php')) {
          final build = request.url.queryParameters['build'];
          if (build == '06') {
            return http.Response.bytes(
              utf8.encode(
                '[["7236","6-12"],["7363","6-10, 6-12"],["9606","6-12-2"]]',
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (build == '01') {
            return http.Response.bytes(
              utf8.encode('[["9176","1-4 (Учебный корпус №3)"]]'),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('[]', 200);
        }

        // Токен недели.
        if (url.endsWith('/groups/')) {
          return http.Response(
            '<span id="week" name="1910202625102026"></span>',
            200,
          );
        }

        // Расписание аудитории.
        if (url.contains('show_schedule.php')) {
          return http.Response('<table id="shedule"></table>', 200);
        }

        return http.Response('', 404);
      }),
    );

Future<AuditoriumIndexService> _loaded(BsuApiService api) async {
  final service = AuditoriumIndexService(api);
  await service.load();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _requests = 0;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Индекс аудиторий', () {
    test('собирает кабинеты всех корпусов и сортирует по названию', () async {
      final service = await _loaded(_api());

      expect(service.isReady, isTrue);
      expect(service.items.map((a) => a.name), [
        '1-4 (Учебный корпус №3)',
        '6-10, 6-12',
        '6-12',
        '6-12-2',
      ]);
      expect(service.resolve('6-12')?.id, '7236');
    });

    test('второй запуск берёт кеш и не ходит в сеть', () async {
      final api = _api();
      await _loaded(api);
      final firstRunRequests = _requests;

      final again = await _loaded(api);
      expect(again.items.length, 4);
      expect(_requests, firstRunRequests,
          reason: 'свежий кеш не должен перекачиваться');
    });

    test('по «6-12» первым идёт сам кабинет, а не 6-12-2', () async {
      final service = await _loaded(_api());
      final found = service.suggest('6-12').map((a) => a.name).toList();

      expect(found.first, '6-12');
      expect(found, contains('6-12-2'));
      expect(service.suggest('6-1').length, greaterThanOrEqualTo(3));
      expect(service.suggest('x'), isEmpty);
    });

    test('resolve понимает кабинет с корпусом в скобках', () async {
      final service = await _loaded(_api());

      expect(service.resolve('6-12 (Учебный корпус №15)')?.id, '7236');
      expect(service.resolve('6-12 (Учебный корпус №15)')?.name, '6-12');
      expect(service.resolve('1-4')?.id, '9176');
      expect(service.resolve('ауд. 999'), isNull);
    });
  });

  group('Карточка пары', () {
    testWidgets('тап по кабинету открывает расписание аудитории',
        (tester) async {
      final api = _api();
      final index = await _loaded(api);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<BsuApiService>.value(value: api),
            ChangeNotifierProvider<AuditoriumIndexService>.value(value: index),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LessonTile(
                lesson: Lesson(
                  number: 1,
                  time: '8:30 - 10:05',
                  type: 'Лекция',
                  name: 'Математика',
                  teacher: '',
                  auditory: '6-12',
                  online: false,
                  key: '1_key',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('6-12'));
      await tester.pumpAndSettle();

      expect(find.byType(AuditoriumScheduleScreen), findsOneWidget,
          reason: 'тап по кабинету должен открывать расписание аудитории');
    });
  });
}
