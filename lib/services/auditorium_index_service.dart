import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/auditorium.dart';
import 'base_services/base_storage_service.dart';
import 'bsu_api_service.dart';

/// Полный список аудиторий вуза, чтобы искать расписание по кабинету.
///
/// У сайта нет поиска по кабинетам: страница аудиторий отдаёт корпуса,
/// а кабинеты корпуса — отдельным запросом. Скачиваем всё один раз
/// (раз в неделю), кешируем и дальше ищем локально.
class AuditoriumIndexService extends ChangeNotifier {
  AuditoriumIndexService(this._api);

  static const String _itemsKey = 'aud_index_v2';
  static const String _updatedKey = 'aud_index_updated_v2';

  /// Как часто перекачиваем список. Кабинеты меняются редко.
  static const Duration _ttl = Duration(days: 7);

  final BsuApiService _api;
  final _AuditoriumStorage _storage = _AuditoriumStorage();

  List<Auditorium> _items = const <Auditorium>[];
  Future<void>? _loading;
  DateTime? _lastFailedAt;

  /// Все известные аудитории (отсортированы по названию).
  List<Auditorium> get items => _items;

  bool get isReady => _items.isNotEmpty;

  /// Загружает кеш из хранилища и, если он устарел, обновляет из сети.
  Future<void> load() async {
    if (_items.isEmpty) {
      final cached = await _storage.getString(_itemsKey);
      if (cached != null) {
        try {
          _items = (jsonDecode(cached) as List)
              .whereType<Map>()
              .map((item) =>
                  Auditorium.fromJson(Map<String, dynamic>.from(item)))
              .where((aud) => aud.id.isNotEmpty && aud.name.isNotEmpty)
              .toList();
          if (_items.isNotEmpty) notifyListeners();
        } catch (_) {
          _items = const <Auditorium>[];
        }
      }
    }

    final updated = await _storage.getInt(_updatedKey) ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch - updated <
        _ttl.inMilliseconds;
    if (_items.isNotEmpty && fresh) return;

    // Сеть только что не ответила — не долбим сайт на каждый запрос.
    if (_failedRecently) return;

    await refresh();
  }

  /// Недавняя неудачная попытка: повторяем не чаще раза в 30 секунд.
  bool get _failedRecently {
    final at = _lastFailedAt;
    return at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 30);
  }

  /// Принудительно обновить список с сайта.
  Future<void> refresh() {
    return _loading ??= _refresh().whenComplete(() => _loading = null);
  }

  Future<void> _refresh() async {
    try {
      final items = await _api.fetchAllAuditoriums();
      _items = items;
      _lastFailedAt = null;
      debugPrint('Auditoriums loaded: ${items.length}');
      await _storage.setString(
        _itemsKey,
        jsonEncode(items.map((aud) => aud.toJson()).toList()),
      );
      await _storage.setInt(_updatedKey, DateTime.now().millisecondsSinceEpoch);
      notifyListeners();
    } catch (e) {
      _lastFailedAt = DateTime.now();
      debugPrint('Не удалось обновить список аудиторий: $e');
    }
  }

  /// Кабинеты, подходящие под запрос.
  ///
  /// Сначала точное совпадение, затем «начинается с», затем «содержит»:
  /// по «6-12» первым должен идти кабинет 6-12, а не 6-12-2.
  List<Auditorium> suggest(String query, {int limit = 20}) {
    final value = query.trim().toLowerCase();
    if (value.length < 2) return const <Auditorium>[];

    final exact = <Auditorium>[];
    final starts = <Auditorium>[];
    final contains = <Auditorium>[];
    for (final aud in _items) {
      final name = aud.name.toLowerCase();
      if (name == value) {
        exact.add(aud);
      } else if (name.startsWith(value)) {
        starts.add(aud);
      } else if (name.contains(value)) {
        contains.add(aud);
      }
    }
    return <Auditorium>[...exact, ...starts, ...contains].take(limit).toList();
  }

  /// Аудитория по названию из расписания.
  ///
  /// В паре кабинет приходит как «6-12» или «6-12 (Учебный корпус №15)»,
  /// поэтому сравниваем и по короткому названию до скобки/запятой.
  Auditorium? resolve(String text) {
    var value = text.trim().toLowerCase();
    if (value.isEmpty) return null;
    for (final separator in const <String>[' (', ',']) {
      final index = value.indexOf(separator);
      if (index > 0) value = value.substring(0, index).trim();
    }
    if (value.isEmpty) return null;

    Auditorium? byPrefix;
    for (final aud in _items) {
      final name = aud.name.toLowerCase();
      if (name == value) return aud;
      byPrefix ??= name.startsWith(value) ? aud : null;
    }
    return byPrefix;
  }
}

/// Хранилище кеша аудиторий: сервис сам наследуется от ChangeNotifier,
/// поэтому работа с prefs вынесена в отдельный маленький класс.
class _AuditoriumStorage extends BaseStorageService {}
