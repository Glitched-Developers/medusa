// lib/views/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:medusa/controllers/settings_controller.dart';
import 'package:provider/provider.dart';
import '../../controllers/schedule_controller.dart';
import 'schedule_screen_view.dart';

class HomeScreenView extends StatelessWidget {
  const HomeScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ScheduleController>(context, listen: false);

    return Scaffold(
      body:
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                final selectedGroup = 90002493; // Получено из формы
                Provider.of<SettingsController>(context, listen: false)
                    .setSelectedGroup(selectedGroup);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreenView()),
                );
              },
              child: Text('Сохранить'),
            ),

            ElevatedButton(
              onPressed: () async {
                int? group = Provider.of<SettingsController>(context, listen: false).selectedGroup;

                if (group == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Выберите группу'),
                    ),
                  );
                  return;
                }

                await controller.loadSchedule(group);

                if (controller.error == null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScheduleScreen(),
                    ),
                  );
                }
              },

              child: const Text('Загрузить расписание', textScaler: TextScaler.linear(1.5),),
            )
          ],
        ),
      ),
    );
  }
}

