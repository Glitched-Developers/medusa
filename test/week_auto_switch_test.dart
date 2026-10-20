import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/controllers/schedule_controller.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/models/metadata.dart';
import 'package:medusa/models/schedule_response.dart';
import 'package:medusa/repositories/interfaces/i_schedule_repository.dart';

/// Репозиторий-заглушка: отдаёт заранее собранное расписание.
class _FakeRepository implements IScheduleRepository {
  _FakeRepository(this.responses);

  final Map<int, ScheduleResponse> responses;

  /// Какие недели просили: [0, 1] — значит, был автопереход.
  final List<int?> requestedWeeks = <int?>[];

  @override
  Future<ScheduleResponse> getSchedule(int groupId, {int? week}) async {
    requestedWeeks.add(week);
    return _responseFor(week);
  }

  @override
  Future<ScheduleResponse> forceRefreshSchedule(int groupId, {int? week}) async {
    requestedWeeks.add(week);
    return _responseFor(week);
  }

  @override
  Future<ScheduleResponse> getActualSchedule(int groupId, {int? week}) async =>
      _responseFor(week);

  @override
  Future<int> getCurrentWeek() async => 1;

  @override
  Future<void> clearCache() async {}

  @override
  bool get isOffline => false;

  @override
  DateTime? get offlineSnapshotAt => null;

  ScheduleResponse _responseFor(int? week) =>
      responses[week ?? 0] ??
      ScheduleResponse(metadata: Metadata(timestamp: ''), schedule: {});
}

const _weekdays = <String>[
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

String _dayKey(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year} ${_weekdays[date.weekday - 1]}';
}

Lesson _lesson() => Lesson(
      number: 1,
      time: '8:30-9:50',
      type: 'пр.',
      name: 'Пара',
      teacher: '',
      auditory: '',
      online: false,
      key: '1',
    );

ScheduleResponse _response(Map<String, List<Lesson>> schedule) =>
    ScheduleResponse(metadata: Metadata(timestamp: ''), schedule: schedule);

void main() {
  test('если впереди только прошедшее — открывается следующая неделя',
      () async {
    final today = DateTime.now();
    final repository = _FakeRepository(<int, ScheduleResponse>{
      0: _response(<String, List<Lesson>>{
        _dayKey(today.subtract(const Duration(days: 1))): <Lesson>[_lesson()],
      }),
      1: _response(<String, List<Lesson>>{
        _dayKey(today.add(const Duration(days: 1))): <Lesson>[_lesson()],
      }),
    });
    final controller = ScheduleController(repository);

    await controller.loadSchedule(90002493);

    expect(controller.weekOffset, 1);
    expect(repository.requestedWeeks, <int?>[0, 1]);
  });

  test('сегодня ещё есть пары — остаёмся на текущей неделе', () async {
    final today = DateTime.now();
    final repository = _FakeRepository(<int, ScheduleResponse>{
      0: _response(<String, List<Lesson>>{
        _dayKey(today): <Lesson>[_lesson()],
      }),
    });
    final controller = ScheduleController(repository);

    await controller.loadSchedule(90002493);

    expect(controller.weekOffset, 0);
    expect(repository.requestedWeeks, <int?>[0]);
  });

  test('пары впереди на этой неделе — остаёмся', () async {
    final today = DateTime.now();
    final repository = _FakeRepository(<int, ScheduleResponse>{
      0: _response(<String, List<Lesson>>{
        _dayKey(today.add(const Duration(days: 1))): <Lesson>[_lesson()],
      }),
    });
    final controller = ScheduleController(repository);

    await controller.loadSchedule(90002493);

    expect(controller.weekOffset, 0);
  });

  test('выбранную вручную неделю не перепрыгиваем', () async {
    final today = DateTime.now();
    final repository = _FakeRepository(<int, ScheduleResponse>{
      0: _response(<String, List<Lesson>>{
        _dayKey(today.subtract(const Duration(days: 1))): <Lesson>[_lesson()],
      }),
    });
    final controller = ScheduleController(repository);

    await controller.loadSchedule(90002493, week: 0);

    expect(controller.weekOffset, 0);
    expect(repository.requestedWeeks, <int?>[0]);
  });
}
