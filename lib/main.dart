// lib/main.dart
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:medusa/controllers/settings_controller.dart';
import 'package:medusa/services/settings_service.dart';
import 'package:medusa/themes/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'utils/constants.dart';
import 'controllers/schedule_controller.dart';
import 'repositories/schedule_repository.dart';
import 'services/bsu_api_service.dart';
import 'view/screens/home_screen_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),

        Provider(
          create: (_) => SettingsService(),
        ),

        Provider(
          create: (_) => BsuApiService(ApiConstants.apiServerUrl),
          dispose: (_, service) => service.dispose(),
        ),

        ProxyProvider<BsuApiService, ScheduleRepository>(
          update: (_, service, __) => ScheduleRepository(service),
        ),

        ChangeNotifierProxyProvider<ScheduleRepository, ScheduleController>(
          create: (context) => ScheduleController(
            Provider.of<ScheduleRepository>(context, listen: false),
          ),
          update: (_, repository, previous) =>
          previous ?? ScheduleController(repository),
        ),

        ChangeNotifierProvider(
          create: (context) => SettingsController(
            Provider.of<SettingsService>(context, listen: false),
          ),
        ),

      ],

      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'JellyFish',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: FlexThemeData.light(scheme: FlexScheme.shadGray),
            darkTheme: FlexThemeData.dark(scheme: FlexScheme.shadGray),
            supportedLocales: const [
              Locale('ru', 'RU'),  // Russian
              Locale('en', 'US'),  // English
            ],
            home: const HomeScreenView(),
          );
        },
      ),
    );
  }
}

