import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/services/belgu_schedule_parser.dart';

void main() {
  // HTML сохранён с реального сайта: группа 12002301, неделя 12.10-18.10.2026
  final html = File('test/fixtures/schedule_12002301.html').readAsStringSync();

  group('BelguScheduleParser (реальный HTML с bsuedu.ru)', () {
    late Map<String, dynamic> parsed;

    setUpAll(() {
      parsed = BelguScheduleParser.parse(html);
    });

    test('разбирает все дни недели', () {
      final schedule = parsed['schedule'] as Map<String, dynamic>;
      // У этой группы занятия только по будням
      expect(schedule.keys.length, greaterThanOrEqualTo(5));

      final firstKey = schedule.keys.first;
      expect(firstKey, matches(RegExp(r'^\d{2}\.\d{2}\.\d{4} ')));
    });

    test('пары содержат все поля модели Lesson', () {
      final schedule = parsed['schedule'] as Map<String, dynamic>;
      final firstDay = schedule.values.first as List;
      expect(firstDay, isNotEmpty);

      final lesson = firstDay.first as Map<String, dynamic>;
      expect(lesson.keys, containsAll(['number', 'time', 'type', 'name',
        'teacher', 'auditory', 'online', 'key']));
      expect(lesson['number'], greaterThan(0));
      expect(lesson['time'], matches(RegExp(r'^\d{1,2}:\d{2} - \d{1,2}:\d{2}$')));
      expect(lesson['name'], isNotEmpty);
    });

    test('понедельник: первая пара — лабораторная по CASE-средствам', () {
      final schedule = parsed['schedule'] as Map<String, dynamic>;
      final mondayKey = schedule.keys.firstWhere((k) => k.contains('Понедельник'));
      final lessons = schedule[mondayKey] as List;
      final first = lessons.first as Map<String, dynamic>;

      expect(first['number'], 1);
      expect(first['time'], '8:30 - 10:05');
      expect(first['type'], 'лаб.');
      expect(first['name'], contains('CASE-средства'));
      expect(first['teacher'], contains('Золотарева'));
      expect(first['auditory'], contains('6-12'));
      expect(first['subgroup'], 1);
    });

    test('у пары разбирается ID преподавателя из ссылки', () {
      final schedule = parsed['schedule'] as Map<String, dynamic>;
      final mondayKey = schedule.keys.firstWhere((k) => k.contains('Понедельник'));
      final first = (schedule[mondayKey] as List).first as Map<String, dynamic>;

      expect(first['teacherId'], isA<int>());
      expect(first['teacherId'], greaterThan(0));
    });

    test('у пары сохраняется ссылка на курс Pegasus', () {
      final schedule = parsed['schedule'] as Map<String, dynamic>;
      final mondayKey = schedule.keys.firstWhere((k) => k.contains('Понедельник'));
      final first = (schedule[mondayKey] as List).first as Map<String, dynamic>;

      // На сайте название пары — ссылка на курс, её и открываем по тапу.
      expect(first['url'], isA<String>());
      expect(first['url'], startsWith('https://pegas.bsuedu.ru/course/view.php'));
    });

    test('пары отсортированы по номеру внутри дня', () {
      final schedule = parsed['schedule'] as Map<String, dynamic>;
      for (final day in schedule.values.cast<List>()) {
        final numbers = day
            .map((l) => (l as Map<String, dynamic>)['number'] as int)
            .toList();
        expect(numbers, List<int>.from(numbers)..sort());
      }
    });

    test('неделя содержит 5 пар в понедельник (по данным сайта)', () {
      final schedule = parsed['schedule'] as Map<String, dynamic>;
      final mondayKey = schedule.keys.firstWhere((k) => k.contains('Понедельник'));
      final lessons = schedule[mondayKey] as List;
      expect(lessons.length, 5);
    });

    test('metadata содержит timestamp', () {
      final metadata = parsed['metadata'] as Map<String, dynamic>;
      expect(metadata['timestamp'], isNotEmpty);
    });

    test('пустая строка -> FormatException', () {
      expect(() => BelguScheduleParser.parse(''),
          throwsA(isA<FormatException>()));
    });

    test('HTML без таблицы расписания -> FormatException', () {
      expect(
        () => BelguScheduleParser.parse('<html><body>404</body></html>'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
