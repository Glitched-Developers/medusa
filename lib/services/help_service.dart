import '../models/help_request.dart';
import 'base_services/base_storage_service.dart';

/// Хранилище запросов помощи и профиля пользователя.
///
/// Сейчас всё лежит локально (SharedPreferences), поэтому запросы и отклики
/// видны только на этом устройстве. Когда появится общий сервер, достаточно
/// заменить методы этого класса: контроллер и экраны знают только о нём.
class HelpService extends BaseStorageService {
  static const String _requestsKey = 'help_requests';
  static const String _nameKey = 'help_profile_name';
  static const String _roleKey = 'help_profile_role';
  static const String _seededKey = 'help_demo_seeded';

  /// Ключи, которыми пользуется раздел (для наглядности и совместимости
  /// с остальными сервисами приложения).
  Set<String> getAllowedKeys() {
    return <String>{_requestsKey, _nameKey, _roleKey, _seededKey};
  }

  /// Все запросы: сначала самые свежие.
  Future<List<HelpRequest>> loadRequests() async {
    final raw = await getObjectList(_requestsKey) ?? const <Map<String, dynamic>>[];
    final list = raw.map(HelpRequest.fromJson).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveRequests(List<HelpRequest> requests) async {
    await saveObjectList(
      _requestsKey,
      requests.map((r) => r.toJson()).toList(),
    );
  }

  Future<String?> loadName() => getString(_nameKey);

  Future<String?> loadRole() => getString(_roleKey);

  Future<void> saveProfile({required String name, required String role}) async {
    await setString(_nameKey, name);
    await setString(_roleKey, role);
  }

  Future<bool> isDemoSeeded() async => (await getBool(_seededKey)) ?? false;

  Future<void> markDemoSeeded() => setBool(_seededKey, true);
}
