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

/// Базовый шаг рейтинга: с 1-го уровня на 2-й нужно 60 очков.
///
/// Дальше каждый уровень дороже на [levelStepGrowth] — 60, 90, 120…,
/// чтобы «Легенда» оставалась достижимой, но не за пару вечеров.
const int levelBasePoints = 60;

/// Насколько дороже каждый следующий уровень.
const int levelStepGrowth = 30;

/// Сколько очков нужно, чтобы пройти уровень [level] (1 → 2).
int pointsForLevelStep(int level) =>
    levelBasePoints + (level - 1) * levelStepGrowth;

/// Сколько всего очков нужно, чтобы дойти до уровня [level]
/// (для 1-го — ноль).
int pointsToReachLevel(int level) {
  final steps = level - 1;
  return steps * levelBasePoints + levelStepGrowth * steps * (steps - 1) ~/ 2;
}

/// Названия уровней: с 4-го — уже «Ветеран».
const List<String> levelTitles = <String>[
  'Новичок',
  'Участник',
  'Помощник',
  'Активист',
  'Ветеран',
  'Легенда',
];

/// Уровень по очкам: 1 — Новичок, дальше пороги растут.
int levelForPoints(int points) {
  var level = 1;
  while (points >= pointsToReachLevel(level + 1)) {
    level++;
  }
  return level;
}

/// Название уровня (после «Легенды» не меняется).
String levelTitle(int level) =>
    levelTitles[(level - 1).clamp(0, levelTitles.length - 1)];

/// Сколько очков осталось до следующего уровня.
int pointsToNextLevel(int points) {
  final level = levelForPoints(points);
  return pointsToReachLevel(level + 1) - points;
}

/// Прогресс до следующего уровня: 0.0–1.0.
double levelProgress(int points) {
  final level = levelForPoints(points);
  final start = pointsToReachLevel(level);
  final end = pointsToReachLevel(level + 1);
  final span = end - start;
  if (span <= 0) return 1;
  return ((points - start) / span).clamp(0.0, 1.0);
}
