/// Статистика профиля, из которой считаются рейтинг и значки.
class BadgeStats {
  const BadgeStats({
    this.taken = 0,
    this.closed = 0,
    this.created = 0,
    this.favorites = 0,
    this.hasProfile = false,
    this.hasGroup = false,
  });

  /// Сколько задач помощи взято.
  final int taken;

  /// Сколько из них закрыто (доведено до конца).
  final int closed;

  /// Сколько запросов помощи опубликовано.
  final int created;

  /// Сколько групп и преподавателей в избранном.
  final int favorites;

  final bool hasProfile;
  final bool hasGroup;

  /// Очки рейтинга. Считаются из текущей активности: пропали запросы —
  /// пропали и очки, а вот значки остаются навсегда.
  int get points =>
      taken * 10 +
      closed * 15 +
      created * 5 +
      (favorites > 10 ? 10 : favorites) * 2 +
      (hasProfile ? 20 : 0) +
      (hasGroup ? 10 : 0);
}

/// Сколько очков нужно на следующий уровень.
const int pointsPerLevel = 60;

/// Названия уровней: с 4-го — уже «Ветеран».
const List<String> levelTitles = <String>[
  'Новичок',
  'Участник',
  'Помощник',
  'Активист',
  'Ветеран',
  'Легенда',
];

/// Уровень по очкам: 1 — Новичок, дальше по 60 очков.
int levelForPoints(int points) => 1 + points ~/ pointsPerLevel;

/// Название уровня (после «Легенды» не меняется).
String levelTitle(int level) =>
    levelTitles[(level - 1).clamp(0, levelTitles.length - 1)];

/// Сколько очков осталось до следующего уровня.
int pointsToNextLevel(int points) => pointsPerLevel - (points % pointsPerLevel);

/// Прогресс до следующего уровня: 0.0–1.0.
double levelProgress(int points) => (points % pointsPerLevel) / pointsPerLevel;
