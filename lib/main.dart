import 'package:flutter/material.dart';
import 'package:medusa/view/screens/schedule_screen_view.dart';
import 'package:medusa/view/screens/welcome_screen_view.dart';
import 'package:provider/provider.dart';
import 'controllers/schedule_controller.dart';
import 'controllers/settings_controller.dart';
import 'repositories/schedule_repository.dart';
import 'services/bsu_api_service.dart';
import 'services/schedule_cache_service.dart';
import 'services/settings_service.dart';
import 'themes/provider/theme_provider.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services - IMPORTANT: we must initialize before providing
  final settingsService = SettingsService();
  final cacheService = ScheduleCacheService();

  // Initialize in order
  await settingsService.init();
  await cacheService.init();

  // Create API service
  final apiService = BsuApiService(ApiConstants.apiServerUrl);

  // Create repository with initialized services
  final repository = ScheduleRepository(apiService, cacheService);

  // Create controllers
  final scheduleController = ScheduleController(repository);
  final settingsController = SettingsController(settingsService);
  final themeProvider = ThemeProvider(settingsService);

  // Now run app with all services/controllers pre-initialized
  runApp(MyApp(
    settingsService: settingsService,
    cacheService: cacheService,
    apiService: apiService,
    repository: repository,
    scheduleController: scheduleController,
    settingsController: settingsController,
    themeProvider: themeProvider,
  ));
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;
  final ScheduleCacheService cacheService;
  final BsuApiService apiService;
  final ScheduleRepository repository;
  final ScheduleController scheduleController;
  final SettingsController settingsController;
  final ThemeProvider themeProvider;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.cacheService,
    required this.apiService,
    required this.repository,
    required this.scheduleController,
    required this.settingsController,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        Provider.value(value: settingsService),
        Provider.value(value: apiService),
        Provider.value(value: cacheService),
        Provider.value(value: repository),
        ChangeNotifierProvider.value(value: scheduleController),
        ChangeNotifierProvider.value(value: settingsController),
      ],

      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Medusa',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: themeProvider.currentTheme,
            darkTheme: themeProvider.currentTheme,
            supportedLocales: const [
              Locale('ru', 'RU'),  // Russian
              Locale('en', 'US'),  // English
            ],
            home: settingsController.isFirstLaunchCompleted
                ? const ScheduleScreenView()  // Если не первый запуск - основной экран
                : const WelcomeScreenView(),  // Если первый запуск - экран приветствия
          );
        },
      ),
    );
  }
}