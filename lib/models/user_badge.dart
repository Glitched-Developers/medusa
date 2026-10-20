import 'package:flutter/material.dart';

/// Вид значка.
///
/// Обычные выдаются автоматически за активность, эксклюзивные — только
/// вручную: код активации передаёт команда Медузки.
enum BadgeTier { regular, exclusive }

/// Значок профиля — как в Discord: иконка, название и подсказка,
/// за что он выдан.
class UserBadge {
  const UserBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.tier = BadgeTier.regular,
    this.code,
    this.color,
  });

  /// Стабильный id: он и хранится в настройках.
  final String id;

  /// Название значка.
  final String title;

  /// Как получить (для эксклюзивных — «выдаётся командой»).
  final String description;

  /// Иконка Material.
  final IconData icon;

  final BadgeTier tier;

  /// Код активации — только у эксклюзивных.
  final String? code;

  /// Фирменный цвет обычных значков.
  final Color? color;

  bool get isExclusive => tier == BadgeTier.exclusive;
}

/// Каталог всех значков приложения.
///
/// Обычные появляются сами, когда выполнено условие. Эксклюзивные
/// открываются кодом: так их можно выдать конкретному человеку, не
/// выпуская новую сборку.
class BadgeCatalog {
  BadgeCatalog._();

  // ── Обычные: выдаются за активность ──────────────────────────────────

  static const UserBadge firstStep = UserBadge(
    id: 'first_step',
    title: 'Первый шаг',
    description: 'Заполнить профиль',
    icon: Icons.flag_outlined,
    color: Color(0xFF2E7D32),
  );

  static const UserBadge schedule = UserBadge(
    id: 'schedule',
    title: 'По расписанию',
    description: 'Выбрать свою группу',
    icon: Icons.calendar_month_outlined,
    color: Color(0xFF00796B),
  );

  static const UserBadge helper = UserBadge(
    id: 'helper',
    title: 'Помощник',
    description: 'Взять первую задачу в разделе «Помощь»',
    icon: Icons.volunteer_activism_outlined,
    color: Color(0xFF1565C0),
  );

  static const UserBadge reliable = UserBadge(
    id: 'reliable',
    title: 'Надёжный',
    description: 'Взять три задачи помощи',
    icon: Icons.handshake_outlined,
    color: Color(0xFF3949AB),
  );

  static const UserBadge legend = UserBadge(
    id: 'legend',
    title: 'Легенда помощи',
    description: 'Взять пять задач помощи',
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFF6A1B9A),
  );

  static const UserBadge author = UserBadge(
    id: 'author',
    title: 'Автор',
    description: 'Опубликовать запрос помощи',
    icon: Icons.campaign_outlined,
    color: Color(0xFFEF6C00),
  );

  static const UserBadge collector = UserBadge(
    id: 'collector',
    title: 'Коллекционер',
    description: 'Добавить три группы или преподавателя в избранное',
    icon: Icons.star_outline,
    color: Color(0xFFF9A825),
  );

  static const UserBadge closer = UserBadge(
    id: 'closer',
    title: 'До конца',
    description: 'Довести три задачи помощи до закрытия',
    icon: Icons.task_alt,
    color: Color(0xFF00838F),
  );

  // ── Эксклюзивные: выдаются командой Медузки кодом ────────────────────

  static const UserBadge developer = UserBadge(
    id: 'developer',
    title: 'Разработчик',
    description: 'Эксклюзивный значок команды Медузки',
    icon: Icons.code,
    tier: BadgeTier.exclusive,
    code: 'MEDUZA-DEV',
    color: Color(0xFF00C853),
  );

  static const UserBadge tester = UserBadge(
    id: 'tester',
    title: 'Тестировщик',
    description: 'Эксклюзивный значок за помощь с тестами',
    icon: Icons.bug_report_outlined,
    tier: BadgeTier.exclusive,
    code: 'MEDUZA-TEST',
    color: Color(0xFF7C4DFF),
  );

  static const UserBadge founder = UserBadge(
    id: 'founder',
    title: 'Основатель',
    description: 'Эксклюзивный значок у истоков проекта',
    icon: Icons.diamond_outlined,
    tier: BadgeTier.exclusive,
    code: 'MEDUZA-FOUNDER',
    color: Color(0xFFFFB300),
  );

  static const UserBadge night = UserBadge(
    id: 'night',
    title: 'Ночная Медузка',
    description: 'Секретный эксклюзивный значок',
    icon: Icons.nightlight_outlined,
    tier: BadgeTier.exclusive,
    code: 'MEDUZA-NIGHT',
    color: Color(0xFF3D5AFE),
  );

  /// Все значки: сначала обычные, потом эксклюзивные.
  static const List<UserBadge> all = <UserBadge>[
    firstStep,
    schedule,
    helper,
    reliable,
    legend,
    author,
    collector,
    closer,
    developer,
    tester,
    founder,
    night,
  ];

  static UserBadge? byId(String id) {
    for (final badge in all) {
      if (badge.id == id) return badge;
    }
    return null;
  }

  /// Значок по коду активации (регистр и пробелы не важны).
  static UserBadge? byCode(String code) {
    final value = code.trim().toUpperCase();
    if (value.isEmpty) return null;
    for (final badge in all) {
      if (badge.code == value) return badge;
    }
    return null;
  }

  static List<UserBadge> get regular =>
      all.where((badge) => !badge.isExclusive).toList(growable: false);

  static List<UserBadge> get exclusive =>
      all.where((badge) => badge.isExclusive).toList(growable: false);
}
