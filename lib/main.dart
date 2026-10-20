import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:medusa/view/screens/splash_screen_view.dart';
import 'package:provider/provider.dart';
import 'controllers/badges_controller.dart';
import 'controllers/bug_reports_controller.dart';
import 'controllers/favorites_controller.dart';
import 'controllers/help_controller.dart';
import 'controllers/notifications_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/schedule_controller.dart';
import 'controllers/settings_controller.dart';
import 'repositories/schedule_repository.dart';
import 'services/bsu_api_service.dart';
import 'services/auditorium_index_service.dart';
import 'services/badges_service.dart';
import 'services/bug_report_service.dart';
import 'services/favorites_service.dart';
import 'services/group_index_service.dart';
import 'services/help_service.dart';
import 'services/notification_service.dart';
import 'services/notifications_settings_service.dart';
import 'services/profile_service.dart';
import 'services/schedule_cache_service.dart';
import 'services/settings_service.dart';
import 'themes/provider/theme_provider.dart';
import 'utils/constants.dart';
import 'view/widgets/theme_reveal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services - IMPORTANT: we must initialize before providing
  final settingsService = SettingsService();
  final cacheService = ScheduleCacheService();
  final helpService = HelpService();
  final favoritesService = FavoritesService();
  final profileService = ProfileService();

  // Initialize in order
  await settingsService.init();
  await cacheService.init();
  await helpService.init();
  await favoritesService.init();
  await profileService.init();

  // Create API service
  final apiService = BsuApiService(ApiConstants.apiServerUrl);

  // Полный список групп для поиска по неполному номеру (кешируется).
  final groupIndexService = GroupIndexService(apiService);
  // Список аудиторий — для поиска и расписания по кабинету.
  final auditoriumIndexService = AuditoriumIndexService(apiService);

  // Оповещения: системные уведомления и их настройки.
  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (e) {
    debugPrint('Оповещения недоступны: $e');
  }
  final notificationsSettings = NotificationsSettingsService();
  await notificationsSettings.init();
  final notificationsController = NotificationsController(
    notificationService,
    notificationsSettings,
  );

  // Create repository with initialized services
  final repository = ScheduleRepository(apiService, cacheService);

  // Create controllers
  final scheduleController = ScheduleController(
    repository,
    onScheduleLoaded: notificationsController.onScheduleLoaded,
  );
  final settingsController = SettingsController(settingsService);
  // Срок хранения расписания на телефоне берётся из настроек:
  // без сети приложение живёт на этом снимке.
  cacheService.retentionDays = settingsController.offlineRetentionDays;
  settingsController.addListener(() {
    cacheService.retentionDays = settingsController.offlineRetentionDays;
  });
  unawaited(settingsController.ready.then((_) async {
    cacheService.retentionDays = settingsController.offlineRetentionDays;
    await cacheService.pruneExpired();
  }));
  final themeProvider = ThemeProvider(settingsService);
  final helpController = HelpController(
    helpService,
    onRequestsLoaded: (requests, name) =>
        notificationsController.onHelpRequests(requests, myName: name),
  );
  final favoritesController = FavoritesController(favoritesService);
  final profileController = ProfileController(profileService);
  final bugReportsController = BugReportsController(BugReportService());

  // Значки и рейтинг: зависят от профиля, помощи, избранного и группы.
  final badgesController = BadgesController(
    BadgesService(),
    help: helpController,
    favorites: favoritesController,
    profile: profileController,
    settings: settingsController,
  );

  // Списки групп и аудиторий докачиваются в фоне: они нужны для поиска
  // по неполному номеру и для перехода в расписание кабинета.
  unawaited(groupIndexService.load());
  unawaited(auditoriumIndexService.load());

  // Now run app with all services/controllers pre-initialized
    runApp(MyApp(
    settingsService: settingsService,
    cacheService: cacheService,
    apiService: apiService,
    groupIndexService: groupIndexService,
    auditoriumIndexService: auditoriumIndexService,
    repository: repository,
    scheduleController: scheduleController,
    settingsController: settingsController,
    themeProvider: themeProvider,
    helpService: helpService,
    helpController: helpController,
    favoritesService: favoritesService,
    profileService: profileService,
    favoritesController: favoritesController,
    profileController: profileController,
    notificationsController: notificationsController,
    badgesController: badgesController,
    bugReportsController: bugReportsController,
  ));
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;
  final ScheduleCacheService cacheService;
  final BsuApiService apiService;
  final GroupIndexService groupIndexService;
  final AuditoriumIndexService auditoriumIndexService;
  final ScheduleRepository repository;
  final ScheduleController scheduleController;
  final SettingsController settingsController;
  final ThemeProvider themeProvider;
  final HelpService helpService;
  final HelpController helpController;
  final FavoritesService favoritesService;
  final ProfileService profileService;
  final FavoritesController favoritesController;
  final ProfileController profileController;
  final NotificationsController notificationsController;
  final BadgesController badgesController;
  final BugReportsController bugReportsController;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.cacheService,
    required this.apiService,
    required this.groupIndexService,
    required this.auditoriumIndexService,
    required this.repository,
    required this.scheduleController,
    required this.settingsController,
    required this.themeProvider,
    required this.helpService,
    required this.helpController,
    required this.favoritesService,
    required this.profileService,
    required this.favoritesController,
    required this.profileController,
    required this.notificationsController,
    required this.badgesController,
    required this.bugReportsController,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        Provider.value(value: settingsService),
        Provider.value(value: apiService),
        Provider.value(value: groupIndexService),
        ChangeNotifierProvider.value(value: auditoriumIndexService),
        Provider.value(value: cacheService),
        Provider.value(value: repository),
        Provider.value(value: helpService),
        Provider.value(value: favoritesService),
        Provider.value(value: profileService),
        ChangeNotifierProvider.value(value: scheduleController),
        ChangeNotifierProvider.value(value: settingsController),
        ChangeNotifierProvider.value(value: helpController),
        ChangeNotifierProvider.value(value: favoritesController),
        ChangeNotifierProvider.value(value: profileController),
        ChangeNotifierProvider.value(value: notificationsController),
        ChangeNotifierProvider.value(value: badgesController),
        ChangeNotifierProvider.value(value: bugReportsController),
      ],

      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Medusa',
            debugShowCheckedModeBanner: false,
            // Корневой RepaintBoundary — из него снимается «фотография»
            // экрана для перехода при смене темы.
            builder: (context, child) => RepaintBoundary(
              key: appRootBoundaryKey,
              child: child ?? const SizedBox.shrink(),
            ),
            themeMode: themeProvider.themeMode,
            theme: themeProvider.currentTheme,
            darkTheme: themeProvider.currentTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ru', 'RU'),  // Russian
              Locale('en', 'US'),  // English
            ],

            home: SplashScreenView()
            //home: settingsController.isFirstLaunchCompleted
            //    ? const ScheduleScreenView()  // Если не первый запуск - основной экран
            //    : const WelcomeScreenView(),  // Если первый запуск - экран приветствия
          );
        },
      ),
    );
  }
}