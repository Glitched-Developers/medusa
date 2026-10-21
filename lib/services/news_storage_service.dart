import 'dart:convert';

import '../models/news_item.dart';
import 'base_services/base_storage_service.dart';

/// Кеш ленты новостей: без интернета показываем последнюю загруженную.
class NewsStorageService extends BaseStorageService {
  static const String _itemsKey = 'news_items_v1';
  static const String _cachedAtKey = 'news_cached_at_v1';

  Set<String> getAllowedKeys() => <String>{_itemsKey, _cachedAtKey};

  Future<List<NewsItem>> loadItems() async {
    final raw = await getString(_itemsKey);
    if (raw == null) return const <NewsItem>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => NewsItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.title.isNotEmpty && item.url.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <NewsItem>[];
    }
  }

  Future<void> saveItems(List<NewsItem> items) => setString(
        _itemsKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );

  Future<DateTime?> loadCachedAt() async {
    final value = await getInt(_cachedAtKey);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> saveCachedAt(DateTime at) =>
      setInt(_cachedAtKey, at.millisecondsSinceEpoch);
}
