import 'package:flutter/foundation.dart';

import '../models/news_item.dart';
import '../services/news_service.dart';
import '../services/news_storage_service.dart';

/// Лента новостей НИУ «БелГУ».
///
/// Сначала показываем сохранённую ленту (если она есть), затем тихо
/// обновляем из сети. Без интернета лента остаётся читаемой, а сверху
/// появляется пометка «сохранено …».
class NewsController extends ChangeNotifier {
  NewsController(this._service, this._storage);

  final NewsService _service;
  final NewsStorageService _storage;

  List<NewsItem> _items = const <NewsItem>[];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  bool _offline = false;
  DateTime? _cachedAt;

  List<NewsItem> get items => _items;

  /// Первая загрузка ещё идёт — показываем скелетон.
  bool get isLoading => _loading;

  /// Идёт обновление при уже показанной ленте.
  bool get isRefreshing => _refreshing;

  String? get error => _error;

  /// Ленту не удалось обновить: показываем сохранённую.
  bool get isOffline => _offline;

  DateTime? get cachedAt => _cachedAt;

  Future<void> load() async {
    final cached = await _storage.loadItems();
    if (cached.isNotEmpty) {
      _items = cached;
      _cachedAt = await _storage.loadCachedAt();
      _loading = false;
      notifyListeners();
    }
    await refresh();
  }

  Future<void> refresh() async {
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      final fresh = await _service.fetchNews();
      if (fresh.isNotEmpty) {
        _items = fresh;
        _cachedAt = DateTime.now();
        _offline = false;
        await _storage.saveItems(fresh);
        await _storage.saveCachedAt(_cachedAt!);
      }
    } catch (e) {
      if (_items.isEmpty) {
        _error = 'Не удалось загрузить новости. Проверьте интернет.';
      } else {
        _offline = true;
      }
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Открыть полный текст новости.
  Future<NewsArticle> openArticle(NewsItem item) =>
      _service.fetchArticle(item.url);
}
