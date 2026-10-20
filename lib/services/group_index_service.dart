import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'base_services/base_storage_service.dart';
import 'bsu_api_service.dart';

/// Полный список групп вуза, чтобы искать их по неполному номеру.
///
/// Автоподсказки сайта отдают максимум 10 совпадений, поэтому по «9000»
/// находилась лишь десятая часть групп. Здесь список скачивается целиком
/// (раз в неделю), кешируется и по нему ищется локально.
class GroupIndexService extends BaseStorageService {
  GroupIndexService(this._api);

  static const String _groupsKey = 'groups_index_v1';
  static const String _updatedKey = 'groups_index_updated_v1';

  /// Как часто перекачиваем список. Группы меняются редко.
  static const Duration _ttl = Duration(days: 7);

  final BsuApiService _api;

  List<String> _groups = const <String>[];
  Future<void>? _loading;
  DateTime? _lastFailedAt;

  /// Все известные группы (отсортированы).
  List<String> get groups => _groups;

  bool get isReady => _groups.isNotEmpty;

  @override
  Set<String> getAllowedKeys() =>
      <String>{_groupsKey, _updatedKey};

  /// Загружает кеш из хранилища и, если он устарел, обновляет из сети.
  Future<void> load() async {
    if (_groups.isEmpty) {
      final cached = await getString(_groupsKey);
      if (cached != null) {
        try {
          _groups = (jsonDecode(cached) as List)
              .map((item) => '$item')
              .where((item) => item.isNotEmpty)
              .toList()
            ..sort();
        } catch (_) {
          _groups = const <String>[];
        }
      }
    }

    final updated = await getInt(_updatedKey) ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch - updated <
        _ttl.inMilliseconds;
    if (_groups.isNotEmpty && fresh) return;

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
      final groups = await _api.fetchAllGroups();
      _groups = groups;
      _lastFailedAt = null;
      await setString(_groupsKey, jsonEncode(groups));
      await setInt(_updatedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _lastFailedAt = DateTime.now();
      debugPrint('Не удалось обновить список групп: $e');
    }
  }

  /// Группы, начинающиеся с введённых цифр.
  ///
  /// Пустой запрос и запросы с буквами (поиск преподавателя) сюда не идут.
  List<String> suggest(String query, {int limit = 60}) {
    final value = query.trim();
    if (value.isEmpty || !RegExp(r'^\d+$').hasMatch(value)) {
      return const <String>[];
    }
    final result = <String>[];
    for (final group in _groups) {
      if (!group.startsWith(value)) continue;
      result.add(group);
      if (result.length >= limit) break;
    }
    return result;
  }
}
