import '../models/favorite_entry.dart';
import 'base_services/base_storage_service.dart';

/// Хранилище избранного — локально, в SharedPreferences.
class FavoritesService extends BaseStorageService {
  static const String _favoritesKey = 'favorites_v1';

  Set<String> getAllowedKeys() => <String>{_favoritesKey};

  Future<List<FavoriteEntry>> load() async {
    final raw =
        await getObjectList(_favoritesKey) ?? const <Map<String, dynamic>>[];
    return raw
        .map(FavoriteEntry.fromJson)
        .where((f) => f.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> save(List<FavoriteEntry> favorites) async {
    await saveObjectList(
      _favoritesKey,
      favorites.map((f) => f.toJson()).toList(),
    );
  }
}
