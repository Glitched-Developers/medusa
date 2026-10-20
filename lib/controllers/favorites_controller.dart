import 'package:flutter/foundation.dart';

import '../models/favorite_entry.dart';
import '../services/favorites_service.dart';

/// Избранные группы и преподаватели.
///
/// Звёздочку можно поставить в подсказках поиска, на экране расписания
/// (для текущей группы) и на расписании преподавателя. Отмеченное
/// поднимается вверх списков и доступно в один тап с начального экрана.
class FavoritesController extends ChangeNotifier {
  FavoritesController(this._service) {
    _load();
  }

  final FavoritesService _service;

  List<FavoriteEntry> _items = <FavoriteEntry>[];
  bool _ready = false;

  List<FavoriteEntry> get items => List<FavoriteEntry>.unmodifiable(_items);
  bool get isReady => _ready;
  bool get isEmpty => _items.isEmpty;

  Future<void> _load() async {
    _items = await _service.load();
    _ready = true;
    notifyListeners();
  }

  bool isFavorite(String name, {bool isGroup = true}) {
    final key = FavoriteEntry(name: name, isGroup: isGroup).key;
    return _items.any((f) => f.key == key);
  }

  /// Поставить или снять звёздочку.
  Future<void> toggle(FavoriteEntry entry) async {
    if (entry.name.trim().isEmpty) return;
    final exists = _items.any((f) => f.key == entry.key);
    _items = exists
        ? _items.where((f) => f.key != entry.key).toList(growable: false)
        : <FavoriteEntry>[entry, ..._items];
    notifyListeners();
    await _service.save(_items);
  }

  Future<void> remove(FavoriteEntry entry) async {
    if (!_items.any((f) => f.key == entry.key)) return;
    _items = _items.where((f) => f.key != entry.key).toList(growable: false);
    notifyListeners();
    await _service.save(_items);
  }

  /// Избранное — вверх списка; остальное сохраняет исходный порядок.
  List<T> favoritesFirst<T>(
    List<T> source, {
    required String Function(T) nameOf,
    required bool Function(T) isGroupOf,
  }) {
    if (_items.isEmpty || source.isEmpty) return source;
    final keys = _items.map((f) => f.key).toSet();
    final favorite = <T>[];
    final rest = <T>[];
    for (final item in source) {
      final key =
          FavoriteEntry(name: nameOf(item), isGroup: isGroupOf(item)).key;
      (keys.contains(key) ? favorite : rest).add(item);
    }
    return <T>[...favorite, ...rest];
  }
}
