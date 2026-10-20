/// Профиль пользователя: имя, роль, аватар и пара слов о себе.
///
/// Всё хранится только на устройстве — сервера у приложения пока нет.
class UserProfile {
  const UserProfile({
    this.name = '',
    this.role = 'student',
    this.avatar = '🌿',
    this.about = '',
  });

  /// Имя и фамилия — им подписываются запросы помощи.
  final String name;

  /// 'student' или 'teacher'.
  final String role;

  /// Эмодзи-аватар: хранить картинки пока незачем.
  final String avatar;

  /// Короткая подпись о себе (необязательно).
  final String about;

  bool get isEmpty => name.trim().isEmpty;
  bool get hasProfile => name.trim().isNotEmpty;
  bool get isTeacher => role == 'teacher';

  UserProfile copyWith({
    String? name,
    String? role,
    String? avatar,
    String? about,
  }) {
    return UserProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      about: about ?? this.about,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'role': role,
        'avatar': avatar,
        'about': about,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'student',
        avatar: json['avatar'] as String? ?? '🌿',
        about: json['about'] as String? ?? '',
      );
}
