import 'package:flutter/foundation.dart';

import '../models/user_badge.dart';
import '../models/user_rating.dart';
import '../services/badges_service.dart';
import 'favorites_controller.dart';
import 'help_controller.dart';
import 'profile_controller.dart';
import 'settings_controller.dart';

/// Значки и рейтинг пользователя.
///
/// Обычные значки выдаются автоматически: контроллер слушает профиль,
/// избранное, настройки и раздел «Помощь», пересчитывает статистику и
/// сохраняет новые значки. Эксклюзивные открываются кодом [redeem].
class BadgesController extends ChangeNotifier {
  BadgesController(
    this._service, {
    required this.help,
    required this.favorites,
    required this.profile,
    required this.settings,
  }) {
    for (final listenable in <Listenable>[help, favorites, profile, settings]) {
      listenable.addListener(_evaluate);
    }
    _loading = _load();
  }

  final BadgesService _service;
  final HelpController help;
  final FavoritesController favorites;
  final ProfileController profile;
  final SettingsController settings;

  /// Сколько значков помещается на витрине профиля.
  static const int showcaseLimit = 5;

  Set<String> _earned = <String>{};
  Set<String> _showcase = <String>{};
  bool _showcaseCustom = false;
  bool _ready = false;
  List<UserBadge> _justEarned = const <UserBadge>[];
  Future<void>? _loading;

  bool get isReady => _ready;

  /// Готовность загрузки значков (удобно в тестах).
  Future<void> get ready => _loading ?? Future<void>.value();

  /// Текущая статистика (очки, взятые задачи и т.д.).
  BadgeStats get stats => BadgeStats(
        taken: help.myTasks.length,
        closed: help.myTasks.where((request) => request.closed).length,
        created: help.myRequests.length,
        favorites: favorites.items.length,
        hasProfile: profile.profile.hasProfile,
        hasGroup: settings.selectedGroup != null,
      );

  int get points => stats.points;
  int get level => levelForPoints(points);
  String get levelName => levelTitle(level);
  int get toNextLevel => pointsToNextLevel(points);
  double get progress => levelProgress(points);

  /// Полученные значки — в порядке каталога.
  List<UserBadge> get earnedBadges => BadgeCatalog.all
      .where((badge) => _earned.contains(badge.id))
      .toList(growable: false);

  /// Пока не полученные — для витрины «как получить».
  List<UserBadge> get lockedBadges => BadgeCatalog.all
      .where((badge) => !_earned.contains(badge.id))
      .toList(growable: false);

  List<UserBadge> get exclusiveBadges => BadgeCatalog.exclusive;

  bool has(String badgeId) => _earned.contains(badgeId);

  /// Значки, которые человек показывает в профиле.
  ///
  /// Пока витрину не настраивали, это первые полученные значки. Дальше —
  /// ровно то, что выбрал сам пользователь (можно оставить и пусто).
  List<UserBadge> get showcasedBadges {
    if (!_showcaseCustom) {
      return earnedBadges.take(showcaseLimit).toList(growable: false);
    }
    return BadgeCatalog.all
        .where((badge) => _earned.contains(badge.id) && _showcase.contains(badge.id))
        .take(showcaseLimit)
        .toList(growable: false);
  }

  /// Значок сейчас на витрине профиля.
  bool isShowcased(String badgeId) =>
      showcasedBadges.any((badge) => badge.id == badgeId);

  /// Свободные места на витрине.
  int get showcaseSlotsLeft => showcaseLimit - showcasedBadges.length;

  /// Показать или убрать значок с витрины.
  ///
  /// Возвращает текст для подсказки: почему не получилось или что вышло.
  Future<String?> toggleShowcase(String badgeId) async {
    if (!_earned.contains(badgeId)) return 'Сначала получите значок';
    final badge = BadgeCatalog.byId(badgeId);
    if (badge == null) return null;

    final next = <String>{...showcasedBadges.map((item) => item.id)};
    String? message;
    if (next.contains(badgeId)) {
      next.remove(badgeId);
      message = '«${badge.title}» убран с витрины';
    } else {
      if (next.length >= showcaseLimit) {
        return 'На витрине максимум $showcaseLimit значков';
      }
      next.add(badgeId);
      message = '«${badge.title}» на витрине';
    }

    _showcase = next;
    _showcaseCustom = true;
    await _service.saveShowcase(custom: true, ids: _showcase);
    notifyListeners();
    return message;
  }

  /// Значки, полученные только что: экран профиля показывает их всплывашкой.
  List<UserBadge> takeJustEarned() {
    final badges = _justEarned;
    _justEarned = const <UserBadge>[];
    return badges;
  }

  Future<void> _load() async {
    _earned = await _service.loadEarned();
    final showcase = await _service.loadShowcase();
    _showcaseCustom = showcase.custom;
    _showcase = showcase.ids;
    _ready = true;
    await _evaluate();
    notifyListeners();
  }

  /// Пересчитать значки. Вызывается на каждое изменение профиля, помощи,
  /// избранного и выбранной группы.
  Future<void> _evaluate() async {
    if (!_ready) return;
    final current = stats;
    final fresh = <UserBadge>[];
    for (final badge in BadgeCatalog.regular) {
      if (_earned.contains(badge.id)) continue;
      if (!_isSatisfied(badge, current)) continue;
      fresh.add(badge);
    }
    if (fresh.isEmpty) return;

    _earned = <String>{..._earned, ...fresh.map((badge) => badge.id)};
    _justEarned = <UserBadge>[..._justEarned, ...fresh];
    await _service.saveEarned(_earned);
    notifyListeners();
  }

  /// Условия обычных значков (эксклюзивные только кодом).
  bool _isSatisfied(UserBadge badge, BadgeStats s) {
    switch (badge.id) {
      case 'first_step':
        return s.hasProfile;
      case 'schedule':
        return s.hasGroup;
      case 'helper':
        return s.taken >= 1;
      case 'reliable':
        return s.taken >= 3;
      case 'legend':
        return s.taken >= 5;
      case 'author':
        return s.created >= 1;
      case 'collector':
        return s.favorites >= 3;
      case 'closer':
        return s.closed >= 3;
      default:
        return false;
    }
  }

  /// Активировать эксклюзивный значок кодом.
  ///
  /// Возвращает значок или null, если код не подошёл.
  Future<UserBadge?> redeem(String code) async {
    final badge = BadgeCatalog.byCode(code);
    if (badge == null) return null;
    if (_earned.contains(badge.id)) return badge;

    _earned = <String>{..._earned, badge.id};
    _justEarned = <UserBadge>[..._justEarned, badge];
    await _service.saveEarned(_earned);
    notifyListeners();
    return badge;
  }
}
