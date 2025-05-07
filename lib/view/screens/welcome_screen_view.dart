import 'package:vector_graphics/vector_graphics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medusa/controllers/settings_controller.dart';
import 'package:provider/provider.dart';
import 'schedule_screen_view.dart';

class WelcomeScreenView extends StatelessWidget {
  const WelcomeScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);
    const Widget svg = SvgPicture(AssetBytesLoader('assets/logo.svg.vec'));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              svg,
              Text(
                'Добро пожаловать!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Для начала, необходимо выполнить базавую настройку. Для этого нажмите на кнопку ниже!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const Spacer(),
              // Кнопка начала работы
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Устанавливаем флаг, что приложение было запущено
                    settingsController.setFirstLaunchCompleted();

                    // Переходим на основной экран
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const ScheduleScreenView(),
                      ),
                    );
                  },
                  child: const Text('Начать работу'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}