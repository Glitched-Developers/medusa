// Регрессионные тесты:
// 1) teacherId переживает сохранение в кеш (toJson -> fromJson);
// 2) выбор темы в настройках реально меняет тему MaterialApp;
// 3) тап по ФИО преподавателя открывает его расписание;
// 4) подсветка сегодняшних пар и затухание прошедших;
// 5) поиск по фамилии преподавателя (подсказки + резолв ID через сайт).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medusa/controllers/badges_controller.dart';
import 'package:medusa/controllers/bug_reports_controller.dart';
import 'package:medusa/controllers/chat_controller.dart';
import 'package:medusa/controllers/favorites_controller.dart';
import 'package:medusa/controllers/help_controller.dart';
import 'package:medusa/controllers/news_controller.dart';
import 'package:medusa/controllers/notifications_controller.dart';
import 'package:medusa/controllers/profile_controller.dart';
import 'package:medusa/controllers/schedule_controller.dart';
import 'package:medusa/controllers/settings_controller.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/models/metadata.dart';
import 'package:medusa/models/schedule_response.dart';
import 'package:medusa/repositories/schedule_repository.dart';
import 'package:medusa/services/auditorium_index_service.dart';
import 'package:medusa/services/bsu_api_service.dart';
import 'package:medusa/services/badges_service.dart';
import 'package:medusa/services/bug_report_service.dart';
import 'package:medusa/services/chat_service.dart';
import 'package:medusa/services/favorites_service.dart';
import 'package:medusa/services/group_index_service.dart';
import 'package:medusa/services/help_service.dart';
import 'package:medusa/services/news_service.dart';
import 'package:medusa/services/news_storage_service.dart';
import 'package:medusa/services/notification_service.dart';
import 'package:medusa/services/notifications_settings_service.dart';
import 'package:medusa/services/profile_service.dart';
import 'package:medusa/services/schedule_cache_service.dart';
import 'package:medusa/services/settings_service.dart';
import 'package:medusa/themes/provider/theme_provider.dart';
import 'package:medusa/view/screens/Initial_setup_screen_view.dart';
import 'package:medusa/view/screens/settings_screen_view.dart';
import 'package:medusa/view/screens/splash_screen_view.dart';
import 'package:medusa/view/screens/teacher_schedule_screen.dart';
import 'package:medusa/view/widgets/border_beam.dart';
import 'package:medusa/view/widgets/lesson_title.dart';
import 'package:medusa/view/widgets/salute_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Lesson _lesson({int? teacherId, required String time, String teacher = 'Иванов И.И.'}) =>
    Lesson(
      number: 1,
      time: time,
      type: 'лекция',
      name: 'Тестовая пара',
      teacher: teacher,
      teacherId: teacherId,
      auditory: '1-1',
      online: false,
      key: '1_key',
    );

/// Экраны приложения берут контроллеры из `main.dart` — собираем их здесь,
/// иначе тест падает на отсутствующем Provider.
///
/// Сервисы те же, что и в приложении, только с пустым хранилищем; сеть
/// подменяется мок-клиентом [api].
Future<Widget> _appWithProviders(
  Widget home, {
  BsuApiService? api,
}) async {
  // Список групп уже «скачан»: стартовый экран не должен ходить в сеть
  // из теста, а поиск по неполному номеру работает и по кешу.
  SharedPreferences.setMockInitialValues(<String, Object>{
    'groups_index_v1': jsonEncode(<String>[
      '12002301',
      '90002411',
      '90002414',
      '90002493',
    ]),
    'groups_index_updated_v1': DateTime.now().millisecondsSinceEpoch,
  });
  final settingsService = SettingsService();
  final cacheService = ScheduleCacheService();
  final helpService = HelpService();
  final favoritesService = FavoritesService();
  final profileService = ProfileService();
  await settingsService.init();
  await cacheService.init();
  await helpService.init();
  await favoritesService.init();
  await profileService.init();

  final apiService = api ?? BsuApiService('http://localhost');
  final repository = ScheduleRepository(apiService, cacheService);

  final scheduleController = ScheduleController(repository);
  final settingsController = SettingsController(settingsService);
  final helpController = HelpController(helpService);
  final favoritesController = FavoritesController(favoritesService);
  final profileController = ProfileController(profileService);
  final badgesController = BadgesController(
    BadgesService(),
    help: helpController,
    favorites: favoritesController,
    profile: profileController,
    settings: settingsController,
  );

  return MultiProvider(
    providers: [
      Provider<BsuApiService>.value(value: apiService),
      Provider<GroupIndexService>.value(
        value: GroupIndexService(apiService),
      ),
      ChangeNotifierProvider<AuditoriumIndexService>.value(
        value: AuditoriumIndexService(apiService),
      ),
      Provider<ScheduleCacheService>.value(value: cacheService),
      Provider<HelpService>.value(value: helpService),
      Provider<FavoritesService>.value(value: favoritesService),
      Provider<ProfileService>.value(value: profileService),
      ChangeNotifierProvider<ScheduleController>.value(
        value: scheduleController,
      ),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController,
      ),
      ChangeNotifierProvider<HelpController>.value(
        value: helpController,
      ),
      ChangeNotifierProvider<FavoritesController>.value(
        value: favoritesController,
      ),
      ChangeNotifierProvider<ProfileController>.value(
        value: profileController,
      ),
      ChangeNotifierProvider<BadgesController>.value(
        value: badgesController,
      ),
      ChangeNotifierProvider<BugReportsController>.value(
        value: BugReportsController(BugReportService()),
      ),
      ChangeNotifierProvider<ChatController>.value(
        value: ChatController(ChatService()),
      ),
      ChangeNotifierProvider<NewsController>.value(
        value: NewsController(NewsService(), NewsStorageService()),
      ),
      ChangeNotifierProvider<NotificationsController>.value(
        value: NotificationsController(
          NotificationService(),
          NotificationsSettingsService(),
        ),
      ),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Кеш расписания', () {
    test('teacherId переживает toJson -> fromJson', () {
      final original = ScheduleResponse(
        metadata: Metadata(timestamp: '2026-10-12'),
        schedule: {
          '12.10.2026 Понедельник': [_lesson(teacherId: 107180, time: '8:30 - 10:05')],
        },
      );

      final round = ScheduleResponse.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      final lesson = round.schedule.values.first.first;
      expect(lesson.teacherId, 107180,
          reason: 'teacherId теряется при сохранении в кеш — '
              'после перезапуска тап по ФИО перестаёт работать');
    });
  });

  group('Тема', () {
    testWidgets('выбор темы в настройках меняет MaterialApp',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsService = SettingsService();
      await settingsService.init();
      final themeProvider = ThemeProvider(settingsService);
      await tester.pump();

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatController>.value(
          value: ChatController(ChatService()),
          child: ChangeNotifierProvider<NewsController>.value(
            value: NewsController(NewsService(), NewsStorageService()),
            child: ChangeNotifierProvider<ProfileController>.value(
              value: ProfileController(ProfileService()),
              child: ChangeNotifierProvider<NotificationsController>.value(
                value: NotificationsController(
                  NotificationService(),
                  NotificationsSettingsService(),
                ),
                child: ChangeNotifierProvider<SettingsController>.value(
                  value: SettingsController(settingsService),
                  child: ChangeNotifierProvider.value(
                    value: themeProvider,
                    child: Consumer<ThemeProvider>(
                      builder: (context, p, _) => MaterialApp(
                        theme: p.currentTheme,
                        darkTheme: p.currentTheme,
                        themeMode: p.themeMode,
                        home: const SettingsScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Color primary() =>
          tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!
              .colorScheme.primary;
      final before = primary();

      // Открываем диалог выбора темы
      await tester.tap(find.text('Выбрать тему'));
      await tester.pumpAndSettle();
      expect(find.text('БелГУ (фирменная)'), findsWidgets,
          reason: 'фирменная тема должна быть первой в списке');

      // Выбираем «Синяя»
      final blue = find.text('Синяя');
      expect(blue, findsWidgets);
      await tester.ensureVisible(blue.first);
      await tester.tap(blue.first);
      await tester.pumpAndSettle();

      expect(themeProvider.selectedFlexScheme, 'blue');
      expect(primary(), isNot(before),
          reason: 'тема MaterialApp должна смениться после выбора в диалоге');
    });
  });

  group('Карточка пары', () {
    testWidgets('тап по ФИО преподавателя открывает его расписание',
        (tester) async {
      final api = BsuApiService.withClient(
        'http://localhost',
        MockClient((request) async => http.Response('<table id="shedule"></table>', 200)),
      );

      await tester.pumpWidget(
        await _appWithProviders(
          Scaffold(
            body: LessonTile(
              lesson: _lesson(teacherId: 42, time: '8:30 - 10:05'),
            ),
          ),
          api: api,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Иванов И.И.'));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherScheduleScreen), findsOneWidget,
          reason: 'тап по ФИО должен открывать расписание преподавателя');
    });

    testWidgets('прошедшая пара затухает (Opacity 0.45)', (tester) async {
      final now = DateTime.now();
      final nowMin = now.hour * 60 + now.minute;
      if (nowMin <= 10) {
        return; // крайне редкий запуск в 00:00–00:10 — пропускаем
      }
      String hhmm(int m) =>
          '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LessonTile(
            lesson: _lesson(teacherId: 1, time: '00:00 - ${hhmm(nowMin - 5)}'),
            isToday: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      expect(opacities, contains(0.45),
          reason: 'пара, которая уже прошла сегодня, должна «тухнуть»');
    });

    testWidgets('сегодняшняя непрошедшая пара подсвечена фоном',
        (tester) async {
      final now = DateTime.now();
      final nowMin = now.hour * 60 + now.minute;
      String hhmm(int m) =>
          '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

      // Пара через час — гарантированно будущая (часы > 23 просто уйдут
      // в сравнение, главное — конец позже текущего момента)
      final future = '${hhmm(nowMin + 60)} - ${hhmm(nowMin + 120)}';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => LessonTile(
              lesson: _lesson(teacherId: 1, time: future),
              isToday: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byType(Card)));
      final card = tester.widget<Card>(find.byType(Card));
      expect(
        card.color,
        theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
        reason: 'сегодняшняя пара должна быть подсвечена',
      );
    });

    testWidgets('вчера/завтра пары без подсветки и без затухания',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LessonTile(
            lesson: _lesson(teacherId: 1, time: '8:30 - 10:05'),
            isToday: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byType(Card)));
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, theme.colorScheme.surfaceContainerLow);
      final hasFade = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .any((o) => o.opacity < 1.0);
      expect(hasFade, isFalse);
    });

    test('timeRange разбирает формат сайта', () {
      expect(LessonTile.timeRange('8:30 - 10:05'), (510, 605));
      expect(LessonTile.timeRange('12:00–13:30'), (720, 810));
      expect(LessonTile.timeRange('что-то'), isNull);
    });
  });

  group('Поиск преподавателей', () {
    /// Мок сайта: поиск отдаёт ФИО и группу, страница поиска — ссылку
    /// на преподавателя (teacher=<id>).
    MockClient mockApi() => MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('search_json.php')) {
            return http.Response.bytes(
              utf8.encode(
                  '[["0","Золотарева Яна Борисовна"],["0","12002301"]]'),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (url.contains('search/index.php')) {
            return http.Response.bytes(
              utf8.encode('<small>Пр.</small>'
                  '<a href="../teachers/index.php?teacher=107180">'
                  'Золотарева Яна Борисовна</a>'),
              200,
            );
          }
          if (url.endsWith('/groups/')) {
            return http.Response.bytes(
              utf8.encode("<span id='week' name='1210202618102026'></span>"),
              200,
            );
          }
          if (url.contains('show_schedule.php')) {
            return http.Response('<table id="shedule"></table>', 200);
          }
          return http.Response('not found', 404);
        });

    test('searchEntries разделяет группы и преподавателей', () async {
      final api = BsuApiService.withClient('http://localhost', mockApi());
      final entries = await api.searchEntries('Золотарева');

      expect(entries, hasLength(2));
      expect(entries[0].name, 'Золотарева Яна Борисовна');
      expect(entries[0].isGroup, isFalse,
          reason: 'ФИО должно распознаваться как преподаватель');
      expect(entries[1].name, '12002301');
      expect(entries[1].isGroup, isTrue,
          reason: 'номер группы должен распознаваться как группа');
    });

    test('resolveTeacherId находит ID по ссылке на странице поиска', () async {
      final api = BsuApiService.withClient('http://localhost', mockApi());
      final id = await api.resolveTeacherId('Золотарева Яна Борисовна');
      expect(id, 107180,
          reason: 'страница поиска содержит ссылку teachers/index.php?teacher=');
    });

    testWidgets('ввод фамилии -> подсказка -> расписание преподавателя',
        (tester) async {
      final api = BsuApiService.withClient('http://localhost', mockApi());

      await tester.pumpWidget(
        await _appWithProviders(
          const InitialSetupScreenView(),
          api: api,
        ),
      );
      // На рамке поля поиска бежит бесконечная анимация (BorderBeam),
      // поэтому pumpAndSettle здесь завис бы — прокручиваем кадры вручную.
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Золотарева');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Золотарева Яна Борисовна'), findsOneWidget,
          reason: 'подсказка преподавателя должна появиться после ввода '
              'фамилии (дебаунс 350мс)');

      await tester.tap(find.text('Золотарева Яна Борисовна'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TeacherScheduleScreen), findsOneWidget,
          reason: 'тап по преподавателю в подсказках открывает его расписание');
      expect(find.text('Золотарева Яна Борисовна'), findsWidgets);
    });
  });

  group('Луч на рамке поля поиска', () {
    /// Текущий painter луча, который лежит поверх содержимого.
    CustomPaint beamOf(WidgetTester tester) => tester.widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(BorderBeam),
                matching: find.byType(CustomPaint),
              )
              .first,
        );

    testWidgets('рисуется поверх рамки и при обычных анимациях движется',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: BorderBeam(
              child: SizedBox(width: 220, height: 56),
            ),
          ),
        ),
      );

      expect(beamOf(tester).foregroundPainter, isNotNull,
          reason: 'луч должен рисоваться поверх рамки');
      final first = beamOf(tester).foregroundPainter;

      // Контроллер тикает -> AnimatedBuilder перестраиваетpainter каждый кадр.
      await tester.pump(const Duration(milliseconds: 300));
      expect(beamOf(tester).foregroundPainter, isNot(same(first)),
          reason: 'при обычных анимациях луч должен двигаться');
    });

    testWidgets('при системном reduce-motion замирает', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(
              child: BorderBeam(
                child: SizedBox(width: 220, height: 56),
              ),
            ),
          ),
        ),
      );

      expect(beamOf(tester).foregroundPainter, isNotNull,
          reason: 'даже с reduce-motion рамка остаётся видимой');
      final before = beamOf(tester).foregroundPainter;

      // Контроллер не запущен -> перестроений нет, painter тот же самый.
      await tester.pump(const Duration(milliseconds: 300));
      expect(beamOf(tester).foregroundPainter, same(before),
          reason: 'при уменьшении анимации луч не должен двигаться');
    });

    testWidgets('поле поиска на стартовом экране обрамлено лучом',
        (tester) async {
      await tester.pumpWidget(
        await _appWithProviders(const InitialSetupScreenView()),
      );
      await tester.pump();

      expect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(BorderBeam),
        ),
        findsOneWidget,
        reason: 'вокруг поля ввода группы/преподавателя должен бежать луч',
      );
    });
  });

  group('Салют', () {
    testWidgets('показывается при «находке» и сам исчезает', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showSalute(context),
                  child: const Text('Найти'),
                ),
              ),
            ),
          ],
        ),
      ));

      await tester.tap(find.text('Найти'));
      await tester.pump();
      expect(find.byKey(const Key('salute')), findsOneWidget,
          reason: 'салют должен появляться при успешном поиске');

      // Ждём завершения анимации (1.3 с) — салют удаляется сам.
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('salute')), findsNothing,
          reason: 'салют должен исчезать после анимации, не мешая экрану');
    });
  });

  group('Заставка', () {
    testWidgets('показывает иконку Медузки и уводит на стартовый экран',
        (tester) async {
      await tester.pumpWidget(await _appWithProviders(const SplashScreenView()));

      expect(find.byIcon(Icons.spa_outlined), findsOneWidget,
          reason: 'на заставке должна быть иконка Медузки');
      // Заголовок собран по буквам (у каждой своя анимация) — проверяем
      // по буквам, а не целым словом.
      for (final letter in 'Медузка'.split('')) {
        expect(find.text(letter), findsWidgets,
            reason: 'на заставке должно быть написано «Медузка»');
      }

      // Анимация идёт — экран не уходит мгновенно.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(InitialSetupScreenView), findsNothing);

      // Дожидаемся конца заставки (2.6 с) и перехода. Стартовый экран
      // несёт бесконечную анимацию BorderBeam, поэтому без pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(InitialSetupScreenView), findsOneWidget,
          reason: 'после заставки приложение должно открыть стартовый экран');
    });

    testWidgets('при отключённых анимациях в системе уходит быстро',
        (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(await _appWithProviders(const SplashScreenView()));
      await tester.pump(const Duration(milliseconds: 400));
      // Стартовый экран несёт бесконечные анимации (луч, лучи), поэтому
      // вместо pumpAndSettle прокручиваем кадры перехода вручную.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(InitialSetupScreenView), findsOneWidget,
          reason: 'users с reduced motion не должны ждать полную заставку');
    });
  });
}
