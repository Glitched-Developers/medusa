import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Разбор HTML-фрагмента расписания с сайта bsuedu.ru.
///
/// Сайт отдаёт таблицу вида:
///   <tr><td class="colspan">...<b>12.10.2026 Понедельник </b>...</td></tr>
///   <tr>
///     <td id='num'>1 пара</td>
///     <td id='time'>8:30 - 10:05</td>
///     <td id='lesson'><small>лаб.</small></td>
///     <td id='lesson'>(п/г 1 подгруппа) <a>Название пары</a></td>
///     <td id='teacher'><small>ст.пр.</small> <a>ФИО</a></td>
///     <td id='aud'><small>ауд.</small><a>6-12</a>, Учебный корпус №15</td>
///   </tr>
///
/// Строки с rowspan (подгруппы) не несут num/time — значения наследуются
/// от предыдущей строки.
class BelguScheduleParser {
  /// Возвращает расписание в формате, ожидаемом приложением:
  /// `{'schedule': {'12.10.2026 Понедельник': [lesson, ...], ...}}`,
  /// где lesson — карта с ключами модели Lesson.
  ///
  /// Бросает [FormatException], если в HTML нет таблицы расписания
  /// (например, группа не найдена).
  static Map<String, dynamic> parse(String html) {
    final document = html_parser.parse(html);
    final table = document.querySelector("table#shedule");
    if (table == null) {
      throw const FormatException('В ответе нет таблицы расписания');
    }

    final schedule = <String, List<Map<String, dynamic>>>{};
    String? currentDay;
    String lastNumber = '';
    String lastTime = '';

    for (final row in table.querySelectorAll('tr')) {
      // Заголовок дня: "12.10.2026 Понедельник"
      final dayHeader = _dayHeader(row);
      if (dayHeader != null) {
        currentDay = dayHeader;
        schedule[currentDay] = [];
        continue;
      }

      if (currentDay == null) continue;

      final numberCell = row.querySelector("td[id='num']");
      final timeCell = row.querySelector("td[id='time']");

      // Строки-продолжения (rowspan подгрупп) num/time не несут.
      if (numberCell != null) {
        final number = _firstDigits(numberCell.text);
        if (number.isNotEmpty) lastNumber = number;
      }
      if (timeCell != null) {
        final time = _normalize(timeCell.text);
        if (time.isNotEmpty) lastTime = time;
      }

      final lessonCells = row.querySelectorAll("td[id='lesson']");
      if (lessonCells.isEmpty) continue;
      if (lastNumber.isEmpty) continue; // мусорная строка

      // Тип пары — маленький <small> в первой ячейке (лек./лаб./практ.)
      final type = _normalize(
          lessonCells.first.querySelector('small')?.text ?? '');

      // Название — вторая ячейка: сначала <a>, иначе весь текст без подгруппы
      final nameCell = lessonCells.length > 1 ? lessonCells[1] : lessonCells.first;
      final name = _lessonName(nameCell);
      final subgroup = _subgroup(nameCell.text);
      // Название на сайте — ссылка на курс в Pegasus. Запоминаем её,
      // чтобы по тапу на пару открывался сам курс.
      final courseUrl = _courseUrl(nameCell);

      // Преподаватель и аудитория — ссылки; в ссылке на расписание
      // преподавателя есть его ID: teachers/index.php?teacher=107180
      final teacherCell = row.querySelector("td[id='teacher']");
      final teacher =
          _normalize(teacherCell?.querySelector('a')?.text ?? '');
      final teacherId = _teacherId(teacherCell);

      final audCell = row.querySelector("td[id='aud']");
      final auditory = _auditory(audCell);

      final rowText = row.text.toLowerCase();
      final online = rowText.contains('онлайн') || rowText.contains('дистанцион');

      final day = schedule[currentDay]!;
      final key = '${day.length}_${lastNumber}_${name}_$subgroup';
      if (day.any((lesson) => lesson['key'] == key)) continue; // дубли

      day.add({
        'number': int.tryParse(lastNumber) ?? 0,
        'time': lastTime,
        'type': type,
        'name': name,
        'teacher': teacher,
        if (teacherId != null) 'teacherId': teacherId,
        'auditory': auditory,
        'online': online,
        'key': key,
        if (subgroup != null) 'subgroup': subgroup,
        if (courseUrl != null) 'url': courseUrl,
      });
    }

    if (schedule.isEmpty) {
      throw const FormatException('Таблица расписания пуста');
    }

    return {
      'schedule': schedule,
      'metadata': {'timestamp': DateTime.now().toIso8601String()},
    };
  }

  /// "12.10.2026 Понедельник " -> "12.10.2026 Понедельник"
  static String? _dayHeader(Element row) {
    final header = row.querySelector('td.colspan span.h3');
    if (header == null) return null;
    final text = _normalize(header.text);
    return text.isEmpty ? null : text;
  }

  /// Название пары без префикса подгруппы "(п/г 1 подгруппа)".
  static String _lessonName(Element cell) {
    final link = cell.querySelector('a');
    if (link != null) {
      final linkText = _normalize(link.text);
      if (linkText.isNotEmpty) return linkText;
    }
    var text = _normalize(cell.text);
    // Убираем ведущую скобку-подгруппу: "(п/г 1 подгруппа) Название"
    final paren = text.indexOf(')');
    if (text.startsWith('(') && paren > 0 && paren < text.length - 1) {
      text = _normalize(text.substring(paren + 1));
    }
    return text;
  }

  /// "п/г 1 подгруппа" -> 1; иначе null.
  static int? _subgroup(String cellText) {
    final match =
        RegExp(r'(\d)\s*подгрупп').firstMatch(cellText.toLowerCase());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Ссылка на курс в Pegasus из названия пары (атрибут href у <a>).
  static String? _courseUrl(Element cell) {
    for (final link in cell.querySelectorAll('a')) {
      final href = (link.attributes['href'] ?? '').trim();
      if (href.startsWith('http')) return href;
    }
    return null;
  }

  /// ID преподавателя из ссылки вида ../teachers/index.php?teacher=107180
  static int? _teacherId(Element? cell) {
    final href = cell?.querySelector('a')?.attributes['href'] ?? '';
    final match = RegExp(r'teacher=(\d+)').firstMatch(href);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// "ауд. 6-12, Учебный корпус №15" -> "6-12 (Учебный корпус №15)"
  static String _auditory(Element? cell) {
    if (cell == null) return '';
    final link = _normalize(cell.querySelector('a')?.text ?? '');
    var full = _normalize(cell.text);
    // Отрезаем ведущий мусор "ауд."
    full = full.replaceFirst(RegExp(r'^ауд\.?\s*'), '');
    if (link.isEmpty) return full;
    // Ссылка обычно — номер аудитории, остаток — корпус
    final rest = _normalize(full.replaceFirst(link, ''));
    return rest.startsWith(',') || rest.startsWith('—') || rest.startsWith('-')
        ? '$link (${_normalize(rest.substring(1))})'
        : link;
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _firstDigits(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match?.group(0) ?? '';
  }
}
