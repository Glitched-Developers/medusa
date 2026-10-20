import 'dart:convert';

import 'base_services/base_storage_service.dart';

/// Хранилище значков.
///
/// Храним только id: сами значки описаны в [BadgeCatalog], поэтому
/// название или иконку можно поменять, не ломая профили.
class BadgesService extends BaseStorageService {
  static const String _earnedKey = 'badges_earned_v1';
  static const String _showcaseKey = 'badges_showcase_v1';

  Set<String> getAllowedKeys() => <String>{_earnedKey, _showcaseKey};

  Future<Set<String>> loadEarned() async {
    final raw = await getString(_earnedKey);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((item) => '$item').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveEarned(Set<String> ids) =>
      setString(_earnedKey, jsonEncode(ids.toList()..sort()));

  /// Витрина профиля: какие значки человек выбрал показывать.
  ///
  /// [custom] отличает «ещё не выбирал» от «выбрал и оставил пусто»:
  /// пока выбор не сделан, показываем первые полученные значки.
  Future<({bool custom, Set<String> ids})> loadShowcase() async {
    final raw = await getString(_showcaseKey);
    if (raw == null) return (custom: false, ids: <String>{});
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ids = (data['ids'] as List? ?? const <dynamic>[])
          .map((item) => '$item')
          .toSet();
      return (custom: data['custom'] == true, ids: ids);
    } catch (_) {
      return (custom: false, ids: <String>{});
    }
  }

  Future<void> saveShowcase({
    required bool custom,
    required Set<String> ids,
  }) =>
      setString(
        _showcaseKey,
        jsonEncode(<String, dynamic>{
          'custom': custom,
          'ids': ids.toList()..sort(),
        }),
      );
}
