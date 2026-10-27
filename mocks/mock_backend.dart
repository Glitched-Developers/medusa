// Тестовый сервер расписания для Медузки (версия на Dart).
//
// Зачем, если уже есть mock_backend.py: на Windows путь к python часто
// занят заглушкой Microsoft Store (AppData\Local\Microsoft\WindowsApps),
// которая не является Python и при запуске открывает магазин.
// Dart же гарантированно есть там, где установлен Flutter.
//
// Запуск:
//     dart mock_backend.dart                 # порт 5000
//     dart mock_backend.dart --port 5050
//
// Сводка:  http://localhost:5000/
// Проверка: curl -X POST http://localhost:5000/schedule -d '{"group":1}'
//
// Без сторонних пакетов: только dart:io, поэтому pub get не нужен.
import 'dart:convert';
import 'dart:io';

const List<String> weekdays = <String>[
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
];

const Map<int, String> times = <int, String>{
  1: '9:00-10:35',
  2: '10:50-12:25',
  3: '12:40-14:15',
  4: '14:30-16:05',
  5: '16:20-17:55',
  6: '18:10-19:45',
};

Map<String, Object?> lesson(
  int number,
  String type,
  String name,
  String teacher,
  String auditory, {
  int? subgroup,
  bool online = false,
}) {
  return <String, Object?>{
    'number': number,
    'time': times[number],
    'type': type,
    'name': name,
    'teacher': teacher,
    'auditory': auditory,
    'online': online,
    'key': '${number}_$name',
    if (subgroup != null) 'subgroup': subgroup,
  };
}

// Две недели различаются — переключение должно быть заметно.
// Типы намеренно разные, чтобы проверить всю палитру цветов, включая
// серый чип для неизвестного типа («УМО»).
final Map<int, Map<String, List<Map<String, Object?>>>> weeks = {
  1: {
    'Понедельник': [
      lesson(1, 'ЛК', 'Математический анализ', 'Иванова Е. П.', 'ауд. 305'),
      lesson(2, 'ПЗ', 'Иностранный язык', 'Смирнова О. В.', 'ауд. 412', subgroup: 1),
      lesson(2, 'ПЗ', 'Иностранный язык', 'Смирнова О. В.', 'ауд. 414', subgroup: 2),
      lesson(3, 'ЛР', 'Информатика и программирование', 'Петров А. А.', 'Лаб. 12'),
      lesson(4, 'Физкультура', 'Физическая культура', 'Сидоров И. К.', 'Спортзал'),
    ],
    'Вторник': [
      lesson(1, 'ЛК', 'Физика', 'Орлов М. В.', 'ауд. 210'),
      lesson(2, 'Лаб. работа', 'Физика (лабораторный практикум)', 'Орлов М. В.', 'Лаб. 7', subgroup: 1),
      lesson(2, 'Лаб. работа', 'Физика (лабораторный практикум)', 'Орлов М. В.', 'Лаб. 7', subgroup: 2),
      lesson(3, 'ПЗ', 'Начертательная геометрия', 'Кузнецов Д. С.', 'ауд. 118'),
      lesson(4, 'Консультация', 'Высшая математика', 'Иванова Е. П.', 'ауд. 305'),
    ],
    'Среда': [
      lesson(1, 'ЛК', 'История Беларуси', 'Волкова Н. И.', 'ауд. 401'),
      lesson(2, 'ПЗ', 'Информационные технологии', 'Петров А. А.', 'Дистанционно', online: true),
      lesson(3, 'ЛР', 'Химия', 'Борисова Л. А.', 'Лаб. 3'),
      lesson(4, 'КП', 'Курсовой проект', 'Кузнецов Д. С.', 'ауд. 118'),
    ],
    'Четверг': [
      lesson(1, 'ЛК', 'Экономика и организация производства', 'Макеева Т. Р.', 'ауд. 502'),
      lesson(2, 'ПЗ', 'Физическое воспитание', 'Сидоров И. К.', 'Спортзал'),
      lesson(3, 'ЛР', 'Электротехника', 'Гаврилов С. Н.', 'Лаб. 21'),
      lesson(4, 'УМО', 'Учебно-методическое объединение', 'Зайцева А. В.', 'ауд. 305'),
    ],
    'Пятница': [
      lesson(1, 'ЛК', 'Философия', 'Лебедева К. Ю.', 'ауд. 417'),
      lesson(2, 'ПЗ', 'Английский язык', 'Смирнова О. В.', 'ауд. 412', subgroup: 1),
      lesson(2, 'ПЗ', 'Английский язык', 'Смирнова О. В.', 'ауд. 414', subgroup: 2),
      lesson(3, 'ЛР', 'Теоретическая механика', 'Гаврилов С. Н.', 'Лаб. 5'),
    ],
    'Суббота': [
      lesson(1, 'ЛК', 'Основы экологии', 'Борисова Л. А.', 'ауд. 220'),
      lesson(2, 'ПЗ', 'Математический анализ', 'Иванова Е. П.', 'Дистанционно', online: true),
    ],
  },
  2: {
    'Понедельник': [
      lesson(1, 'ЛК', 'Математический анализ', 'Иванова Е. П.', 'ауд. 305'),
      lesson(2, 'ЛР', 'Информатика и программирование', 'Петров А. А.', 'Лаб. 14'),
      lesson(3, 'ПЗ', 'Начертательная геометрия', 'Кузнецов Д. С.', 'ауд. 118'),
      lesson(4, 'Экзамен', 'Зачёт по физической культуре', 'Сидоров И. К.', 'Спортзал'),
    ],
    'Вторник': [
      lesson(1, 'ЛК', 'Физика', 'Орлов М. В.', 'ауд. 210'),
      lesson(2, 'ПЗ', 'Физика (решение задач)', 'Орлов М. В.', 'ауд. 210'),
      lesson(3, 'ЛР', 'Химия', 'Борисова Л. А.', 'Лаб. 3'),
    ],
    'Среда': [
      lesson(1, 'ЛК', 'История Беларуси', 'Волкова Н. И.', 'ауд. 401'),
      lesson(2, 'Лаб. работа', 'Информационные технологии', 'Петров А. А.', 'Лаб. 12', subgroup: 1),
      lesson(2, 'Лаб. работа', 'Информационные технологии', 'Петров А. А.', 'Лаб. 12', subgroup: 2),
      lesson(3, 'ПЗ', 'Теоретическая механика', 'Гаврилов С. Н.', 'ауд. 230'),
      lesson(4, 'КП', 'Курсовой проект', 'Кузнецов Д. С.', 'ауд. 118'),
      lesson(5, 'Консультация', 'Экономика', 'Макеева Т. Р.', 'ауд. 502'),
    ],
    'Четверг': [
      lesson(1, 'ЛК', 'Экономика и организация производства', 'Макеева Т. Р.', 'ауд. 502'),
      lesson(2, 'ЛР', 'Электротехника', 'Гаврилов С. Н.', 'Лаб. 21'),
      lesson(3, 'Физкультура', 'Физическая культура', 'Сидоров И. К.', 'Спортзал'),
    ],
    'Пятница': [
      lesson(1, 'ЛК', 'Философия', 'Лебедева К. Ю.', 'ауд. 417'),
      lesson(2, 'ПЗ', 'Английский язык', 'Смирнова О. В.', 'ауд. 412', subgroup: 1),
      lesson(2, 'ПЗ', 'Английский язык', 'Смирнова О. В.', 'ауд. 414', subgroup: 2),
    ],
    // Пустой день — проверяем, что приложение показывает «Пар нет».
    'Суббота': <Map<String, Object?>>[],
  },
};

DateTime currentMonday([DateTime? today]) {
  final now = today ?? DateTime.now();
  return now.subtract(Duration(days: now.weekday - 1));
}

int weekNumber([DateTime? today]) {
  final now = today ?? DateTime.now();
  // Простая чётность недели ISO, чтобы данные различались.
  final isoWeek =
      ((now.difference(DateTime(now.year, 1, 1)).inDays + now.weekday) / 7).ceil();
  return isoWeek.isOdd ? 1 : 2;
}

Map<String, List<Map<String, Object?>>> buildSchedule(int week, [DateTime? today]) {
  final monday = currentMonday(today);
  final template = weeks[week] ?? weeks[1]!;
  final result = <String, List<Map<String, Object?>>>{};

  for (var i = 0; i < weekdays.length; i++) {
    final day = monday.add(Duration(days: i));
    final dd = day.day.toString().padLeft(2, '0');
    final mm = day.month.toString().padLeft(2, '0');
    final key = '$dd.$mm.${day.year} ${weekdays[i]}';
    result[key] = (template[weekdays[i]] ?? const <Map<String, Object?>>[])
        .map((l) => Map<String, Object?>.from(l))
        .toList();
  }
  return result;
}

String timestamp() => DateTime.now().toIso8601String().substring(0, 19);

Future<void> main(List<String> args) async {
  var port = 5000;
  var delay = 0.3;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[i + 1]) ?? 5000;
    } else if (args[i] == '--delay' && i + 1 < args.length) {
      delay = double.tryParse(args[i + 1]) ?? 0.3;
    }
  }

  final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } catch (error) {
    stderr.writeln('Не удалось занять порт $port: $error');
    stderr.writeln('Возможно, порт уже занят настоящим бэкендом.');
    exit(1);
  }

  stdout.writeln('Тестовый сервер Медузки слушает http://localhost:$port');
  stdout.writeln('Сводка: http://localhost:$port/');
  stdout.writeln('Ctrl+C — остановить.');

  await for (final request in server) {
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: (delay * 1000).round()));
    _handle(request, port);
  }
}

void _handle(HttpRequest request, int port) {
  final path = request.uri.path;

  // CORS: без него Chrome не даст приложению прочитать ответ.
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  request.response.headers.add('Access-Control-Allow-Headers', '*');

  if (request.method == 'OPTIONS') {
    _finish(request, 204, null);
    return;
  }

  if (request.method == 'GET' && (path == '/' || path.isEmpty)) {
    _sendHtml(request, _indexPage(weekNumber(), buildSchedule(weekNumber()), port));
    return;
  }

  if (request.method == 'POST') {
    _readBody(request).then((body) {
      Map<String, dynamic> payload = const <String, dynamic>{};
      if (body.isNotEmpty) {
        try {
          final decoded = jsonDecode(utf8.decode(body));
          if (decoded is Map) payload = decoded as Map<String, dynamic>;
        } catch (_) {
          payload = const <String, dynamic>{};
        }
      }

      switch (path) {
        case '/week':
          final action = payload['action']?.toString() ?? 'this';
          var week = weekNumber();
          if (action == 'next' || action == 'last') week = week == 1 ? 2 : 1;
          final explicit = payload['week'];
          if (explicit is int) {
            week = explicit;
          } else if (explicit != null) {
            week = int.tryParse(explicit.toString()) ?? week;
          }
          _sendJson(request, <String, Object?>{'week': week});
          return;

        case '/schedule':
          final explicit = payload['week'];
          var week = weekNumber();
          if (explicit is int) {
            week = explicit;
          } else if (explicit != null) {
            week = int.tryParse(explicit.toString()) ?? week;
          }
          _sendJson(request, <String, Object?>{
            'metadata': <String, Object?>{'timestamp': timestamp()},
            'schedule': buildSchedule(week),
          });
          return;

        case '/actual':
          final now = DateTime.now();
          final dd = now.day.toString().padLeft(2, '0');
          final mm = now.month.toString().padLeft(2, '0');
          final key = '$dd.$mm.${now.year} ${weekdays[now.weekday - 1]}';
          final full = buildSchedule(weekNumber(), now);
          _sendJson(request, <String, Object?>{
            'metadata': <String, Object?>{'timestamp': timestamp()},
            'schedule': <String, Object?>{
              key: full[key] ?? <Map<String, Object?>>[],
            },
          });
          return;

        default:
          _sendJson(request, <String, Object?>{'error': 'Unknown path: $path'}, status: 404);
          return;
      }
    });
    return;
  }

  _sendJson(request, <String, Object?>{'error': 'Unknown path: $path'}, status: 404);
}

Future<List<int>> _readBody(HttpRequest request) async {
  try {
    return await request.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
  } catch (_) {
    return <int>[];
  }
}

void _sendJson(HttpRequest request, Map<String, Object?> payload, {int status = 200}) {
  final body = utf8.encode(jsonEncode(payload));
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType('application', 'json', charset: 'utf-8')
    ..headers.add('Content-Length', body.length.toString());
  _finish(request, status, body);
}

void _sendHtml(HttpRequest request, String html) {
  final body = utf8.encode(html);
  request.response
    ..statusCode = 200
    ..headers.contentType = ContentType('text', 'html', charset: 'utf-8')
    ..headers.add('Content-Length', body.length.toString());
  _finish(request, 200, body);
}

void _finish(HttpRequest request, int status, List<int>? body) {
  if (body != null) request.response.add(body);
  request.response.close().catchError((Object _) => null);
}

String _indexPage(int week, Map<String, List<Map<String, Object?>>> schedule, int port) {
  final rows = StringBuffer();
  schedule.forEach((day, lessons) {
    final types = lessons.map((l) => l['type'].toString()).toSet().toList()..sort();
    rows.writeln(
      '  <tr><td>$day</td><td>${lessons.length}</td><td>${types.isEmpty ? '&mdash;' : types.join(', ')}</td></tr>',
    );
  });

  return '''<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8">
<title>Medusa mock backend</title>
<style>
body{font-family:system-ui,Segoe UI,Roboto,sans-serif;margin:32px;color:#222;background:#fafafa}
h1{margin:0 0 4px} p{margin:0 0 18px;color:#666}
table{border-collapse:collapse;background:#fff}
td,th{border:1px solid #ddd;padding:6px 12px;text-align:left}
code{background:#eee;padding:2px 5px;border-radius:3px}
</style></head><body>
<h1>Тестовый сервер Медузки (Dart)</h1>
<p>Работает. Неделя №$week. Группу можно указать любую &mdash;
ответ не зависит от неё.</p>
<table>
  <tr><th>День</th><th>Пар</th><th>Типы</th></tr>
$rows
</table>
<p style="margin-top:18px">Проверить вручную:
<code>curl -X POST http://localhost:$port/schedule -d '{"group":90002493}'</code></p>
</body></html>''';
}
