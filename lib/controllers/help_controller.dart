import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/help_request.dart';
import '../services/help_service.dart';

/// Логика раздела «Помощь».
///
/// Преподаватель публикует запрос («помогите перетащить вещи»), студенты
/// берут задачу и указывают свой статус: «уже в пути», «приду через пять
/// минут» и т.д. Здесь же считаем, сколько студентов уже взялось.
class HelpController extends ChangeNotifier {
  HelpController(this._service, {this.onRequestsLoaded}) {
    _init();
  }

  final HelpService _service;

  /// Вызывается после загрузки/изменения списка запросов — на этом
  /// построены оповещения о новых запросах помощи.
  final void Function(List<HelpRequest> requests, String userName)?
      onRequestsLoaded;

  List<HelpRequest> _requests = <HelpRequest>[];
  String _userName = '';
  bool _isTeacher = false;
  bool _ready = false;

  /// Загрузились ли данные профиля и запросов.
  bool get isReady => _ready;

  List<HelpRequest> get requests => List<HelpRequest>.unmodifiable(_requests);

  List<HelpRequest> get openRequests =>
      _requests.where((r) => !r.closed).toList(growable: false);

  /// Сколько открытых запросов — для бейджа на иконке.
  int get openCount => _requests.where((r) => !r.closed).length;

  /// Имя пользователя: чем подписываются отклики и запросы.
  String get userName => _userName;

  /// Режим «преподаватель»: можно публиковать запросы.
  bool get isTeacher => _isTeacher;

  /// Роль строкой — так она и хранится в настройках.
  String get userRole => _isTeacher ? 'teacher' : 'student';

  bool get hasProfile => _userName.trim().isNotEmpty;

  /// Запросы, которые создал текущий пользователь.
  List<HelpRequest> get myRequests =>
      _requests.where((r) => r.authorName == _userName).toList(growable: false);

  /// Задачи, которые взял текущий пользователь.
  List<HelpRequest> get myTasks => _requests
      .where((r) => r.volunteers.any((v) => v.name == _userName))
      .toList(growable: false);

  HelpRequest? requestById(String id) {
    for (final r in _requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Отклик текущего пользователя на конкретный запрос (если он есть).
  HelpVolunteer? myVolunteer(HelpRequest request) {
    for (final v in request.volunteers) {
      if (v.name == _userName) return v;
    }
    return null;
  }

  Future<void> _init() async {
    _userName = (await _service.loadName()) ?? '';
    _isTeacher = (await _service.loadRole()) == 'teacher';
    _requests = await _service.loadRequests();

    // Один раз показываем примеры запросов, чтобы раздел не был пустым.
    if (_requests.isEmpty && !await _service.isDemoSeeded()) {
      _requests = _demoRequests();
      await _service.markDemoSeeded();
      await _service.saveRequests(_requests);
    }

    _ready = true;
    notifyListeners();
    _notifyRequests();
  }

  /// Отдать список запросов наружу (система оповещений).
  void _notifyRequests() {
    final callback = onRequestsLoaded;
    if (callback == null) return;
    // Не ждём: оповещения не должны задерживать интерфейс.
    unawaited(Future<void>(() => callback(_requests, _userName)));
  }

  /// Сохранить имя и роль пользователя.
  Future<void> setProfile({required String name, required String role}) async {
    _userName = name.trim();
    _isTeacher = role == 'teacher';
    await _service.saveProfile(name: _userName, role: role);
    notifyListeners();
  }

  /// Опубликовать новый запрос помощи.
  Future<HelpRequest> createRequest({
    required String title,
    required String authorName,
    required HelpCategory category,
    String description = '',
    String place = '',
    String timeText = '',
    int needed = 1,
  }) async {
    final request = HelpRequest(
      id: newHelpId(),
      title: title.trim(),
      authorName: authorName.trim(),
      createdAt: DateTime.now(),
      category: category,
      description: description.trim(),
      place: place.trim(),
      timeText: timeText.trim(),
      needed: needed < 1 ? 1 : needed,
    );
    _requests = <HelpRequest>[request, ..._requests];
    await _persist();
    return request;
  }

  /// Взять задачу: студент откликается со своим статусом.
  ///
  /// Возвращает false, если мест уже нет: на одну задачу нельзя набрать
  /// больше людей, чем нужно преподавателю.
  Future<bool> takeTask(
    String requestId, {
    required String statusKey,
    required String statusText,
  }) async {
    final request = requestById(requestId);
    if (request == null) return false;
    // Свой статус можно менять всегда — даже если мест уже нет.
    final alreadyMine = myVolunteer(request) != null;
    if (!alreadyMine && request.isFull) return false;

    _updateRequest(requestId, (request) {
      final mine = myVolunteer(request);
      if (mine != null) {
        return request.copyWith(
          volunteers: request.volunteers
              .map((v) => v.name == _userName
                  ? v.copyWith(
                      statusKey: statusKey,
                      statusText: statusText,
                      at: DateTime.now(),
                    )
                  : v)
              .toList(),
        );
      }
      return request.copyWith(
        volunteers: <HelpVolunteer>[
          ...request.volunteers,
          HelpVolunteer(
            id: newHelpId(),
            name: _userName,
            statusKey: statusKey,
            statusText: statusText,
            at: DateTime.now(),
          ),
        ],
      );
    });
    return true;
  }

  /// Обновить только свой статус в задаче.
  Future<bool> updateMyStatus(
    String requestId, {
    required String statusKey,
    required String statusText,
  }) =>
      takeTask(requestId, statusKey: statusKey, statusText: statusText);

  /// Отказаться от задачи.
  Future<void> leaveTask(String requestId) async {
    _updateRequest(requestId, (request) {
      return request.copyWith(
        volunteers: request.volunteers
            .where((v) => v.name != _userName)
            .toList(growable: false),
      );
    });
  }

  /// Закрыть или снова открыть запрос (для автора).
  Future<void> setClosed(String requestId, bool closed) async {
    _updateRequest(requestId, (request) => request.copyWith(closed: closed));
  }

  Future<void> deleteRequest(String requestId) async {
    _requests = _requests.where((r) => r.id != requestId).toList(growable: false);
    await _persist();
  }

  void _updateRequest(String id, HelpRequest Function(HelpRequest) change) {
    _requests = _requests
        .map((r) => r.id == id ? change(r) : r)
        .toList(growable: false);
    _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    await _service.saveRequests(_requests);
    _notifyRequests();
  }

  /// Демонстрационные запросы при первом запуске.
  List<HelpRequest> _demoRequests() {
    final now = DateTime.now();
    return <HelpRequest>[
      HelpRequest(
        id: newHelpId(),
        title: 'Помочь перетащить коробки в ауд. 213',
        authorName: 'Ковалёва И. П.',
        createdAt: now.subtract(const Duration(minutes: 25)),
        category: HelpCategory.moving,
        description: 'Нужно перенести материалы кафедры из 118 в 213. '
            'Коробки не тяжёлые, но их много (пример запроса).',
        place: 'корпус 4, аудитории 118 → 213',
        timeText: 'сегодня до 16:00',
        needed: 3,
        isDemo: true,
        volunteers: <HelpVolunteer>[
          HelpVolunteer(
            id: newHelpId(),
            name: 'Дарья К.',
            statusKey: 'en_route',
            statusText: '',
            at: now.subtract(const Duration(minutes: 12)),
          ),
          HelpVolunteer(
            id: newHelpId(),
            name: 'Максим П.',
            statusKey: 'in_5',
            statusText: '',
            at: now.subtract(const Duration(minutes: 4)),
          ),
        ],
      ),
      HelpRequest(
        id: newHelpId(),
        title: 'Настроить проектор перед парой',
        authorName: 'Сидоров А. Н.',
        createdAt: now.subtract(const Duration(hours: 3)),
        category: HelpCategory.tech,
        description: 'Не выводится изображение с ноутбука (пример запроса).',
        place: 'корпус 1, ауд. 305',
        timeText: 'завтра, 2 пара',
        needed: 1,
        isDemo: true,
        volunteers: <HelpVolunteer>[
          HelpVolunteer(
            id: newHelpId(),
            name: 'Илья В.',
            statusKey: HelpStatusOption.customKey,
            statusText: 'Буду за 10 минут до начала',
            at: now.subtract(const Duration(hours: 2)),
          ),
        ],
      ),
    ];
  }
}
