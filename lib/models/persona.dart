import 'user_badge.dart';
import 'user_rating.dart';

/// Публичный профиль человека: то, что видно при нажатии на имя
/// в помощи или в чате.
///
/// Сервера у приложения нет, поэтому часть людей — демонстрационные
/// профили: у них есть значки, очки и уровень, чтобы было видно, как это
/// выглядит. Свои данные человек видит в обычном профиле.
class Persona {
  const Persona({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    this.about = '',
    this.points = 0,
    this.group = '',
    this.badgeIds = const <String>[],
    this.isDemo = false,
  });

  final String id;
  final String name;

  /// 'student' или 'teacher'.
  final String role;
  final String avatar;
  final String about;
  final int points;
  final String group;
  final List<String> badgeIds;

  /// Демонстрационный профиль (данные придуманы для примера).
  final bool isDemo;

  bool get isTeacher => role == 'teacher';

  int get level => levelForPoints(points);
  String get levelName => levelTitle(level);
  int get toNextLevel => pointsToNextLevel(points);
  double get progress => levelProgress(points);

  List<UserBadge> get badges => badgeIds
      .map(BadgeCatalog.byId)
      .whereType<UserBadge>()
      .toList(growable: false);

  String get roleLabel => isTeacher ? 'Преподаватель' : 'Студент';

  /// Стабильный id по имени: имя — единственное, что у нас есть.
  static String idFor(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Persona copyWith({
    String? name,
    String? role,
    String? avatar,
    String? about,
    int? points,
    String? group,
    List<String>? badgeIds,
  }) {
    return Persona(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      about: about ?? this.about,
      points: points ?? this.points,
      group: group ?? this.group,
      badgeIds: badgeIds ?? this.badgeIds,
      isDemo: isDemo,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'role': role,
        'avatar': avatar,
        'about': about,
        'points': points,
        'group': group,
        'badgeIds': badgeIds,
        'isDemo': isDemo,
      };

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        role: '${json['role'] ?? 'student'}',
        avatar: '${json['avatar'] ?? '🎓'}',
        about: '${json['about'] ?? ''}',
        points: (json['points'] as num?)?.toInt() ?? 0,
        group: '${json['group'] ?? ''}',
        badgeIds: (json['badgeIds'] as List? ?? const <dynamic>[])
            .map((item) => '$item')
            .toList(growable: false),
        isDemo: json['isDemo'] == true,
      );
}

/// Кто есть в приложении: преподаватели и студенты, с которыми можно
/// связаться. Список локальный — как и всё остальное до появления сервера.
class PersonaCatalog {
  PersonaCatalog._();

  static const Persona kovaleva = Persona(
    id: 'ковалёва и. п.',
    name: 'Ковалёва И. П.',
    role: 'teacher',
    avatar: '👩‍🏫',
    about: 'Доцент кафедры прикладной математики и компьютерных наук',
    points: 215,
    badgeIds: <String>['author', 'helper', 'founder'],
    isDemo: true,
  );

  static const Persona sidorov = Persona(
    id: 'сидоров а. н.',
    name: 'Сидоров А. Н.',
    role: 'teacher',
    avatar: '👨‍🏫',
    about: 'Старший преподаватель кафедры информатики',
    points: 140,
    badgeIds: <String>['author', 'reliable'],
    isDemo: true,
  );

  static const Persona daria = Persona(
    id: 'дарья к.',
    name: 'Дарья К.',
    role: 'student',
    avatar: '👩‍🎓',
    about: '2 курс, педагогический институт',
    points: 95,
    group: '90002493',
    badgeIds: <String>['first_step', 'schedule', 'helper', 'tester'],
    isDemo: true,
  );

  static const Persona maxim = Persona(
    id: 'максим п.',
    name: 'Максим П.',
    role: 'student',
    avatar: '🧑‍🎓',
    about: '1 курс, институт инженерных и цифровых технологий',
    points: 60,
    group: '90002411',
    badgeIds: <String>['first_step', 'schedule', 'collector'],
    isDemo: true,
  );

  static const Persona ilya = Persona(
    id: 'илья в.',
    name: 'Илья В.',
    role: 'student',
    avatar: '🧑‍🎓',
    about: '3 курс, факультет математики и естественно-научного образования',
    points: 45,
    group: '90002473',
    badgeIds: <String>['first_step', 'schedule'],
    isDemo: true,
  );

  static const List<Persona> demo = <Persona>[
    kovaleva,
    sidorov,
    daria,
    maxim,
    ilya,
  ];

  /// Найти человека по имени. Незнакомое имя становится обычным
  /// студентом без значков — профиль всё равно можно открыть и написать.
  static Persona resolve(String name) {
    final id = Persona.idFor(name);
    for (final persona in demo) {
      if (persona.id == id) return persona;
    }
    return Persona(
      id: id,
      name: name.trim(),
      role: 'student',
      avatar: '🎓',
    );
  }

  static Persona? byId(String id) {
    for (final persona in demo) {
      if (persona.id == id) return persona;
    }
    return null;
  }
}
