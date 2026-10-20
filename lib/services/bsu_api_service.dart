import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/auditorium.dart';
import '../utils/group_format.dart';
import 'belgu_schedule_parser.dart';

enum WeekActions {
  this_("this"),
  next("next"),
  last("last");

  final String value;
  const WeekActions(this.value);

  @override
  String toString() => value;
}

/// Клиент реального сайта расписания НИУ БелГУ (bsuedu.ru).
///
/// Сайт не имеет официального JSON API, но само расписание загружается
/// через PHP-скрипты (см. schedule.js на странице расписания):
///   * GET  groups/                     — страница с текущим токеном недели
///   * POST groups/show_schedule.php    — HTML-фрагмент расписания группы
///
/// HTML разбирается [BelguScheduleParser] и приводится к формату,
/// который ожидают модели приложения (ScheduleResponse/Lesson).
class BsuApiService {
  /// Базовый адрес страницы расписания, например
  /// https://bsuedu.ru/bsu/education/schedule
  final String baseUrl;
  final http.Client _client;

  BsuApiService(this.baseUrl) : _client = http.Client();

  BsuApiService.withClient(this.baseUrl, this._client);

  void dispose() {
    _client.close();
  }

  /// Текущая учебная неделя (ISO week-numbering) по данным сайта.
  Future<int> getWeek(WeekActions action, {int? week}) async {
    final token = await _currentWeekToken();
    final start = _parseWeekToken(token)?.$1;
    if (start == null) {
      throw ApiException('Не удалось разобрать текущую неделю');
    }
    final actionOffset = switch (action) {
      WeekActions.this_ => 0,
      WeekActions.next => 7,
      WeekActions.last => -7,
    };
    return _isoWeek(start.add(Duration(days: actionOffset)));
  }

  /// Полное расписание группы.
  ///
  /// [group] — номер группы (например, 12002301).
  /// [week] — смещение недели от текущей: 0 — эта неделя,
  /// -1 — прошлая, +1 — следующая и т.д.
  Future<Map<String, dynamic>> getSchedule(int group, {int? week}) async {
    final token = await _weekTokenFor(week ?? 0);
    return _fetchSchedule(group, token);
  }

  /// Актуальное (на сегодня) расписание. Пока что сайт отдаёт неделю целиком,
  /// отличие от [getSchedule] — только в срое кеширования.
  Future<Map<String, dynamic>> getTodaySchedule(int group) async {
    final token = await _currentWeekToken();
    return _fetchSchedule(group, token);
  }

  /// Расписание преподавателя на текущую неделю (все его пары по всем группам).
  ///
  /// [teacherId] — ID с сайта (из ссылки расписания: teachers/index.php?teacher=...).
  Future<Map<String, dynamic>> getTeacherSchedule(int teacherId) async {
    final token = await _currentWeekToken();
    final url = Uri.parse('$baseUrl/teachers/show_schedule.php');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: 'group=&week=$token&aud=&teach=$teacherId',
      );

      if (response.statusCode != 200) {
        throw ApiException(
            'Расписание преподавателя: HTTP ${response.statusCode}',
            response);
      }

      final html = utf8.decode(response.bodyBytes);
      return BelguScheduleParser.parse(html);
    } catch (e) {
      if (e is ApiException || e is FormatException) rethrow;
      throw ApiException('Ошибка загрузки расписания преподавателя: $e');
    }
  }

  /// Расписание аудитории на неделю: все пары, которые идут в кабинете.
  ///
  /// [audId] — id аудитории с сайта (aud_json.php), не её название.
  Future<Map<String, dynamic>> getAuditoriumSchedule(
    String audId, {
    int? week,
  }) async {
    final token = await _weekTokenFor(week ?? 0);
    final url = Uri.parse('$baseUrl/auditories/show_schedule.php');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: 'group=&week=$token&aud=$audId&teach=',
      );

      if (response.statusCode != 200) {
        throw ApiException(
            'Расписание аудитории: HTTP ${response.statusCode}', response);
      }

      final html = utf8.decode(response.bodyBytes);
      return BelguScheduleParser.parse(html);
    } catch (e) {
      if (e is ApiException || e is FormatException) rethrow;
      throw ApiException('Ошибка загрузки расписания аудитории: $e');
    }
  }

  /// Все аудитории вуза: обходим корпуса и собираем кабинеты.
  ///
  /// Отдельного «все аудитории одним запросом» у сайта нет: страница
  /// аудиторий отдаёт список корпусов, а `aud_json.php?build=` — кабинеты
  /// одного корпуса. Запросы идут пачками, чтобы не ждать минуту.
  Future<List<Auditorium>> fetchAllAuditoriums() async {
    final pageUrl = Uri.parse('$baseUrl/auditories/');
    final page = await _client.get(pageUrl);
    if (page.statusCode != 200) {
      throw ApiException('Страница аудиторий: HTTP ${page.statusCode}', page);
    }
    final html = utf8.decode(page.bodyBytes);
    final builds = _optionIds(html, 'build');
    if (builds.isEmpty) {
      throw ApiException('На странице аудиторий не найдены корпуса');
    }

    final found = <String, String>{};
    final emptyBuilds = <String>[];
    const batchSize = 6;
    for (var i = 0; i < builds.length; i += batchSize) {
      final batch = builds.skip(i).take(batchSize).toList();
      final results = await Future.wait(batch.map(_auditoriumsForBuild));
      for (var j = 0; j < batch.length; j++) {
        final chunk = results[j];
        if (chunk.isEmpty) {
          emptyBuilds.add(batch[j]);
        } else {
          found.addAll(chunk);
        }
      }
    }

    // Корпус мог не ответить с первого раза — пробуем ещё раз, уже
    // по одному: из-за пропущенного корпуса терялись целые кабинеты.
    for (final build in emptyBuilds) {
      found.addAll(await _auditoriumsForBuild(build));
    }

    if (found.isEmpty) {
      throw ApiException('Сайт не отдал список аудиторий');
    }
    final list = found.entries
        .map((entry) => Auditorium(id: entry.key, name: entry.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Кабинеты одного корпуса: `{[id]: название}`. Ошибки не пробрасываем —
  /// один неотдавшийся корпус не должен ломать весь список.
  Future<Map<String, String>> _auditoriumsForBuild(String build) async {
    final result = <String, String>{};
    try {
      final url = Uri.parse('$baseUrl/auditories/aud_json.php?build=$build');
      final response = await _client.get(url);
      if (response.statusCode != 200) return result;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return result;
      for (final item in data) {
        if (item is List && item.length > 1) {
          final id = '${item[0]}'.trim();
          final name = '${item[1]}'.trim();
          if (id.isNotEmpty && name.isNotEmpty) result[id] = name;
        }
      }
    } catch (_) {
      // Корпус не отдался — остальные всё равно соберём.
    }
    return result;
  }

  /// Поиск групп по номеру/названию: возвращает пары [id, название].
  /// Используется для автоподсказок при вводе группы.
  Future<List<List<String>>> search(String query) async {
    final url = Uri.parse('$baseUrl/search/search_json.php?query=${Uri.encodeQueryComponent(query)}');
    try {
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw ApiException('Поиск групп: HTTP ${response.statusCode}', response);
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return data
          .whereType<List>()
          .map((item) => item.map((e) => '$e').toList())
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка поиска: $e');
    }
  }

  /// Полный список групп вуза (все факультеты и формы обучения).
  ///
  /// Автоподсказки сайта отдают не больше десяти групп, поэтому по «9000»
  /// половина групп не находилась. Здесь сайт обходится по факультетам,
  /// а group_json.php отдаёт полный список без ограничения.
  Future<List<String>> fetchAllGroups() async {
    final pageUrl = Uri.parse('$baseUrl/groups/');
    final page = await _client.get(pageUrl);
    if (page.statusCode != 200) {
      throw ApiException('Страница групп: HTTP ${page.statusCode}', page);
    }
    final html = utf8.decode(page.bodyBytes);
    final faculties = _optionIds(html, 'faculty');
    final forms = _optionIds(html, 'eduform');
    if (faculties.isEmpty || forms.isEmpty) {
      throw ApiException('На странице групп не найдены факультеты');
    }

    final groups = <String>{};
    for (final faculty in faculties) {
      for (final form in forms) {
        final url = Uri.parse(
          '$baseUrl/groups/group_json.php?fak=$faculty&frm=$form',
        );
        try {
          final response = await _client.get(url);
          if (response.statusCode != 200) continue;
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is! List) continue;
          for (final item in data) {
            if (item is List && item.isNotEmpty) {
              final name = '${item.first}'.trim();
              if (name.isNotEmpty) groups.add(name);
            }
          }
        } catch (_) {
          // Один факультет не отдался — остальные всё равно соберём.
        }
      }
    }

    if (groups.isEmpty) {
      throw ApiException('Сайт не отдал список групп');
    }
    final list = groups.toList()..sort();
    return list;
  }

  /// id опций внутри `<select id='faculty'>` / `<select id='eduform'>`.
  List<String> _optionIds(String html, String selectId) {
    final select = RegExp(
      "<select[^>]*id=['\"]$selectId['\"][^>]*>(.*?)</select>",
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (select == null) return const <String>[];
    return RegExp(r'''<option[^>]*\bid=["'](\d+)["']''')
        .allMatches(select.group(1)!)
        .map((m) => m.group(1)!)
        .toList(growable: false);
  }

  /// Поиск «группы и преподаватели» одним запросом.
  ///
  /// Сайт отдаёт смешанный список [id, название]: группы — только цифры,
  /// преподаватели — ФИО кириллицей.
  Future<List<ScheduleSearchEntry>> searchEntries(String query) async {
    final raw = await search(query);
    return raw.map((item) {
      final name = item.length > 1 ? item[1] : item.first;
      return ScheduleSearchEntry(
        name,
        RegExp(r'^\d+$').hasMatch(name),
      );
    }).toList();
  }

  /// ID преподавателя по его ФИО.
  ///
  /// Страница поиска сайта (`search/index.php?query=ФИО`) в списке
  /// результатов содержит ссылку `teachers/index.php?teacher=<id>`.
  /// Прямого JSON для этого у сайта нет — резолвим по HTML-ссылке.
  Future<int> resolveTeacherId(String fullName) async {
    final url = Uri.parse('$baseUrl/search/index.php'
        '?query=${Uri.encodeQueryComponent(fullName)}');
    try {
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw ApiException('Преподаватель не найден: $fullName', response);
      }
      final html = utf8.decode(response.bodyBytes);
      final pattern = RegExp(
        r'teachers/index\.php\?teacher=(\d+)[^>]*>([^<]*)</a>',
        caseSensitive: false,
      );
      String? firstId;
      for (final m in pattern.allMatches(html)) {
        final id = m.group(1)!;
        firstId ??= id;
        final text = m.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text == fullName) return int.parse(id);
      }
      if (firstId != null) return int.parse(firstId);
      throw ApiException('Преподаватель не найден: $fullName');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка поиска преподавателя: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchSchedule(int group, String weekToken) async {
    final url = Uri.parse('$baseUrl/groups/show_schedule.php');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: 'group=${formatGroupNumber(group)}&week=$weekToken&aud=&teach=',
      );

      if (response.statusCode != 200) {
        throw ApiException(
            'Расписание: HTTP ${response.statusCode}', response);
      }

      final html = utf8.decode(response.bodyBytes);
      return BelguScheduleParser.parse(html);
    } catch (e) {
      if (e is ApiException || e is FormatException) rethrow;
      throw ApiException('Ошибка загрузки расписания: $e');
    }
  }

  /// Токен недели, сдвинутый на [offset] недель от текущей.
  /// Сайт принимает произвольные токены — прошлые и будущие недели
  /// отдаются корректно (проверено).
  Future<String> _weekTokenFor(int offset) async {
    if (offset == 0) return _currentWeekToken();
    final token = await _currentWeekToken();
    final parsed = _parseWeekToken(token);
    if (parsed == null) {
      throw ApiException('Не удалось разобрать текущую неделю');
    }
    final start = parsed.$1.add(Duration(days: 7 * offset));
    return _formatWeekToken(start);
  }

  /// Понедельник [start] -> токен "ддММггггддММгггг" (пн–вс).
  String _formatWeekToken(DateTime start) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}'
        '${x.month.toString().padLeft(2, '0')}'
        '${x.year}';
    return '${d(start)}${d(start.add(const Duration(days: 6)))}';
  }

  /// Токен недели вида "1210202618102026" (ддММггггддММгггг)
  /// лежит на странице выбора групп: <span id='week' name='...'>.
  Future<String> _currentWeekToken() async {
    final url = Uri.parse('$baseUrl/groups/');
    try {
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw ApiException(
            'Страница групп: HTTP ${response.statusCode}', response);
      }
      final html = utf8.decode(response.bodyBytes);
      final match =
          RegExp(r"id='week'\s+name='(\d+)'").firstMatch(html) ??
              RegExp(r'name="(\d+)"\s+id="week"').firstMatch(html) ??
              RegExp(r"id='week'[^>]*name='(\d+)'").firstMatch(html);
      if (match == null) {
        throw ApiException('На сайте не найден токен текущей недели');
      }
      return match.group(1)!;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка доступа к сайту: $e');
    }
  }

  /// Токен "1210202618102026" -> (DateTime начала, DateTime конца).
  (DateTime, DateTime)? _parseWeekToken(String token) {
    if (token.length < 16) return null;
    DateTime parseAt(int offset) => DateTime(
          int.parse(token.substring(offset + 4, offset + 8)),
          int.parse(token.substring(offset + 2, offset + 4)),
          int.parse(token.substring(offset, offset + 2)),
        );
    return (parseAt(0), parseAt(8));
  }

  /// ISO-8601 номер недели (понедельник — первый день недели).
  int _isoWeek(DateTime date) {
    final day = date.weekday == DateTime.sunday ? 7 : date.weekday;
    final thursday = date.add(Duration(days: 4 - day));
    final jan1 = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(jan1).inDays) / 7).floor() + 1;
  }
}

class ApiException implements Exception {
  final String message;
  final http.Response? response;

  ApiException(this.message, [this.response]);

  @override
  String toString() => 'ApiException: $message';
}

/// Запись результатов поиска расписания: группа, преподаватель или аудитория.
class ScheduleSearchEntry {
  /// Название: номер группы, ФИО преподавателя или номер кабинета.
  final String name;

  /// true — группа (только цифры), false — преподаватель.
  final bool isGroup;

  /// id аудитории на сайте. Заполнен только для кабинетов — по нему
  /// открывается расписание аудитории.
  final String? roomId;

  const ScheduleSearchEntry(this.name, this.isGroup, {this.roomId});

  /// Кабинет («6-12», «316 Физика»).
  bool get isRoom => roomId != null;

  @override
  String toString() =>
      'ScheduleSearchEntry($name, isGroup: $isGroup, roomId: $roomId)';
}
