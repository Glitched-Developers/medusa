// Значки и рейтинг:
// 1) каталог значков и коды эксклюзивных;
// 2) очки и уровни;
// 3) автоматическая выдача значков за активность и их сохранение;
// 4) активация эксклюзивного значка кодом.
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/controllers/badges_controller.dart';
import 'package:medusa/controllers/favorites_controller.dart';
import 'package:medusa/controllers/help_controller.dart';
import 'package:medusa/controllers/profile_controller.dart';
import 'package:medusa/controllers/settings_controller.dart';
import 'package:medusa/models/favorite_entry.dart';
import 'package:medusa/models/user_badge.dart';
import 'package:medusa/models/user_profile.dart';
import 'package:medusa/models/user_rating.dart';
import 'package:medusa/services/badges_service.dart';
import 'package:medusa/services/favorites_service.dart';
import 'package:medusa/services/help_service.dart';
import 'package:medusa/services/profile_service.dart';
import 'package:medusa/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Собирает контроллеры так же, как main.dart, но с пустым хранилищем.
Future<BadgesController> _badges({bool reset = true}) async {
  if (reset) {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Хранилище в тестах общее и живёт дольше одного теста: чистим его,
    // иначе значки из предыдущего теста остаются выданными.
    final prefs = await BadgesService().getPrefs();
    await prefs.clear();
  }
  final settingsService = SettingsService();
  final helpService = HelpService();
  final favoritesService = FavoritesService();
  final profileService = ProfileService();
  await settingsService.init();
  await helpService.init();
  await favoritesService.init();
  await profileService.init();

  final controller = BadgesController(
    BadgesService(),
    help: HelpController(helpService),
    favorites: FavoritesController(favoritesService),
    profile: ProfileController(profileService),
    settings: SettingsController(settingsService),
  );
  await controller.ready;
  // Даём профилю и помощи загрузиться из хранилища.
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Каталог значков', () {
    test('обычных восемь, эксклюзивных четыре', () {
      expect(BadgeCatalog.regular.length, 8);
      expect(BadgeCatalog.exclusive.length, 4);
      expect(BadgeCatalog.all.length, 12);
    });

    test('код эксклюзивного значка не зависит от регистра', () {
      expect(BadgeCatalog.byCode('MEDUZA-DEV')?.id, 'developer');
      expect(BadgeCatalog.byCode('  meduza-dev ')?.id, 'developer');
      expect(BadgeCatalog.byCode('MEDUZA-FOUNDER')?.id, 'founder');
      expect(BadgeCatalog.byCode('что-то не то'), isNull);
      expect(BadgeCatalog.byCode(''), isNull);
    });

    test('у обычных значков кода нет', () {
      for (final badge in BadgeCatalog.regular) {
        expect(badge.code, isNull);
        expect(badge.description, isNotEmpty);
      }
    });
  });

  group('Рейтинг', () {
    test('очки складываются из активности', () {
      const stats = BadgeStats(
        taken: 3,
        closed: 1,
        created: 1,
        favorites: 2,
        hasProfile: true,
        hasGroup: true,
      );
      expect(stats.points, 3 * 10 + 1 * 15 + 1 * 5 + 2 * 2 + 20 + 10);
    });

    test('избранное даёт очки не больше чем за десять записей', () {
      expect(const BadgeStats(favorites: 50).points,
          const BadgeStats(favorites: 10).points);
    });

    test('уровни и прогресс', () {
      expect(levelForPoints(0), 1);
      expect(levelForPoints(59), 1);
      expect(levelForPoints(60), 2);
      expect(levelTitle(1), 'Новичок');
      expect(levelTitle(8), 'Легенда');
      expect(pointsToNextLevel(0), 60);
      expect(pointsToNextLevel(59), 1);
      expect(levelProgress(30), closeTo(0.5, 0.001));
    });
  });

  group('Выдача значков', () {
    test('за профиль выдаётся «Первый шаг» и остаётся', () async {
      final badges = await _badges();
      expect(badges.has('first_step'), isFalse);
      expect(badges.points, 0);

      final profile = badges.profile;
      await profile.save(const UserProfile(name: 'Иван', role: 'student'));

      expect(badges.has('first_step'), isTrue,
          reason: 'значок должен выдаться сразу после сохранения профиля');
      expect(badges.points, greaterThan(0));

      // Чистим профиль: значок остаётся, очки за профиль пропадают.
      await profile.save(const UserProfile());
      expect(badges.has('first_step'), isTrue);
    });

    test('эксклюзивный значок открывается только правильным кодом',
        () async {
      final badges = await _badges();

      expect(await badges.redeem('НЕ-КОД'), isNull);
      expect(badges.has('developer'), isFalse);

      final badge = await badges.redeem('meduza-dev');
      expect(badge?.id, 'developer');
      expect(badges.has('developer'), isTrue);
      expect(badges.earnedBadges.map((b) => b.id), contains('developer'));

      // Повторная активация не дублирует значок.
      expect(await badges.redeem('MEDUZA-DEV'), isNotNull);
      expect(
        badges.earnedBadges.where((b) => b.id == 'developer').length,
        1,
      );
    });

    test('значок за избранное: три записи', () async {
      final badges = await _badges();
      final favorites = badges.favorites;

      await favorites.toggle(const FavoriteEntry(name: '90002411', isGroup: true));
      await favorites.toggle(const FavoriteEntry(name: '90002493', isGroup: true));
      expect(badges.has('collector'), isFalse);

      await favorites.toggle(const FavoriteEntry(name: '12002301', isGroup: true));
      expect(badges.has('collector'), isTrue);
    });
  });

  group('Витрина профиля', () {
    test('пока не настроена — показываем первые полученные значки', () async {
      final badges = await _badges();
      expect(badges.showcasedBadges, isEmpty);

      await badges.profile
          .save(const UserProfile(name: 'Иван', role: 'student'));
      await badges.redeem('MEDUZA-DEV');

      final ids = badges.showcasedBadges.map((badge) => badge.id);
      expect(ids, containsAll(<String>['first_step', 'developer']));
      expect(badges.showcasedBadges.length, lessThanOrEqualTo(5));
    });

    test('значок можно убрать и вернуть, выбор переживает перезапуск', () async {
      final badges = await _badges();
      await badges.profile
          .save(const UserProfile(name: 'Иван', role: 'student'));
      await badges.redeem('MEDUZA-TEST');

      expect(badges.isShowcased('first_step'), isTrue);
      expect(await badges.toggleShowcase('first_step'), isNotNull);
      expect(badges.isShowcased('first_step'), isFalse);

      // Эксклюзивный значок можно снять и вернуть.
      expect(badges.isShowcased('tester'), isTrue);
      await badges.toggleShowcase('tester');
      expect(badges.isShowcased('tester'), isFalse);
      await badges.toggleShowcase('tester');
      expect(badges.isShowcased('tester'), isTrue);

      final again = await _badges(reset: false);
      expect(again.isShowcased('tester'), isTrue,
          reason: 'витрина должна сохраняться на телефоне');
      expect(again.isShowcased('first_step'), isFalse);
    });

    test('неполученный значок на витрину не попадает', () async {
      final badges = await _badges();
      expect(await badges.toggleShowcase('developer'),
          'Сначала получите значок');
      expect(badges.isShowcased('developer'), isFalse);
    });

    test('на витрине не больше пяти значков', () async {
      final badges = await _badges();
      await badges.profile
          .save(const UserProfile(name: 'Иван', role: 'student'));
      await badges.settings.setSelectedGroup(90002493);
      await badges.redeem('MEDUZA-DEV');
      await badges.redeem('MEDUZA-TEST');
      await badges.redeem('MEDUZA-FOUNDER');
      await badges.redeem('MEDUZA-NIGHT');

      expect(badges.earnedBadges.length, 6);
      expect(badges.showcasedBadges.length, BadgesController.showcaseLimit);
      expect(await badges.toggleShowcase('night'),
          'На витрине максимум ${BadgesController.showcaseLimit} значков');
      expect(badges.isShowcased('night'), isFalse);

      // Освободили место — шестой значок встаёт.
      await badges.toggleShowcase('first_step');
      await badges.toggleShowcase('night');
      expect(badges.isShowcased('night'), isTrue);
      expect(badges.showcasedBadges.length, BadgesController.showcaseLimit);
    });
  });
}
