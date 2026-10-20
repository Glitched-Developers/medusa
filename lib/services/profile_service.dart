import '../models/user_profile.dart';
import 'base_services/base_storage_service.dart';

/// Хранилище профиля — локально, в SharedPreferences.
///
/// Имя и роль дополнительно пишутся в ключи раздела «Помощь»: раньше
/// профиль жил только там, и отклики должны подписываться тем же именем.
class ProfileService extends BaseStorageService {
  static const String _nameKey = 'profile_name';
  static const String _roleKey = 'profile_role';
  static const String _avatarKey = 'profile_avatar';
  static const String _aboutKey = 'profile_about';
  static const String _helpNameKey = 'help_profile_name';
  static const String _helpRoleKey = 'help_profile_role';

  Set<String> getAllowedKeys() => <String>{
        _nameKey,
        _roleKey,
        _avatarKey,
        _aboutKey,
        _helpNameKey,
        _helpRoleKey,
      };

  Future<UserProfile> load() async {
    var name = await getString(_nameKey) ?? '';
    var role = await getString(_roleKey) ?? '';

    // Профиль ещё не заводили, но имя могло быть введено в разделе
    // «Помощь» — переносим его, чтобы не спрашивать дважды.
    if (name.trim().isEmpty) {
      name = await getString(_helpNameKey) ?? '';
      if (role.isEmpty) role = await getString(_helpRoleKey) ?? '';
    }

    return UserProfile(
      name: name,
      role: role.isEmpty ? 'student' : role,
      avatar: await getString(_avatarKey) ?? '🌿',
      about: await getString(_aboutKey) ?? '',
    );
  }

  Future<void> save(UserProfile profile) async {
    await setString(_nameKey, profile.name);
    await setString(_roleKey, profile.role);
    await setString(_avatarKey, profile.avatar);
    await setString(_aboutKey, profile.about);
    // Раздел «Помощь» читает те же имя и роль — держим их в согласии.
    await setString(_helpNameKey, profile.name);
    await setString(_helpRoleKey, profile.role);
  }
}
