// Сквозная проверка клиента расписания БелГУ против реального сайта.
// Запуск: dart run tool/e2e_belgu_check.dart [номер_группы]
import 'package:medusa/services/bsu_api_service.dart';

Future<void> main(List<String> args) async {
  final group = int.tryParse(args.isNotEmpty ? args[0] : '12002301') ?? 12002301;
  final service = BsuApiService('https://bsuedu.ru/bsu/education/schedule');
  var failures = 0;

  void check(String name, bool ok, [Object? detail]) {
    print('${ok ? "OK  " : "FAIL"}  $name${ok ? "" : " — $detail"}');
    if (!ok) failures++;
  }

  final week = await service.getWeek(WeekActions.this_);
  check('текущая неделя (>0)', week > 0, week);

  final data = await service.getSchedule(group);
  final schedule = data['schedule'] as Map<String, dynamic>;
  check('дней в расписании >= 5', schedule.length >= 5, schedule.length);

  final firstDay = schedule.values.first as List;
  check('пар в первом дне > 0', firstDay.isNotEmpty);
  final lesson = firstDay.first as Map<String, dynamic>;
  check('у пары есть название', (lesson['name'] as String).isNotEmpty, lesson);
  check('у пары есть время', (lesson['time'] as String).isNotEmpty, lesson);
  print('\nПервая пара: ${lesson['time']} — ${lesson['name']} '
      '(${lesson['type']}, ${lesson['teacher']}, ${lesson['auditory']})');
  print('Дней: ${schedule.length}, ключи: ${schedule.keys.take(3).join(" | ")}...');

  final search = await service.search('120023');
  check('поиск группы возвращает результат', search.isNotEmpty, search.length);

  // Расписание преподавателя: возьмём ID из первой пары
  final teacherId = lesson['teacherId'] as int?;
  check('у пары есть teacherId', teacherId != null, lesson);
  if (teacherId != null) {
    final teacherData = await service.getTeacherSchedule(teacherId);
    final teacherDays = teacherData['schedule'] as Map<String, dynamic>;
    check('у преподавателя есть пары на неделю', teacherDays.isNotEmpty,
        teacherDays.length);
  }

  // Переключение недель: прошлая и следующая недели (даты считаем
  // от первой даты текущей недели, чтобы проверка не устаревала)
  DateTime parseRu(String s) {
    final p = s.split('.');
    return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
  }

  final thisMonday = parseRu(schedule.keys.first.split(' ').first);
  final expectedPrev = thisMonday.subtract(const Duration(days: 7));
  final expectedNext = thisMonday.add(const Duration(days: 7));
  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  final prev = await service.getSchedule(12002301, week: -1);
  final prevDays = prev['schedule'] as Map<String, dynamic>;
  check(
      'прошлая неделя начинается с ${fmt(expectedPrev)}',
      prevDays.keys.any((k) => k.startsWith(fmt(expectedPrev))),
      prevDays.keys.take(3).toList());

  final next = await service.getSchedule(12002301, week: 1);
  final nextDays = next['schedule'] as Map<String, dynamic>;
  check(
      'следующая неделя начинается с ${fmt(expectedNext)}',
      nextDays.keys.any((k) => k.startsWith(fmt(expectedNext))),
      nextDays.keys.take(3).toList());

  print(failures == 0 ? '\nВсе проверки пройдены' : '\nПровалов: $failures');
  if (failures > 0) throw Exception('$failures проверок провалено');
}
