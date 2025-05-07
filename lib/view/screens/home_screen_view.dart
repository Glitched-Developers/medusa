import 'package:flutter/material.dart';
import 'package:medusa/controllers/settings_controller.dart';
import 'package:provider/provider.dart';
import '../../controllers/schedule_controller.dart';
import 'schedule_screen_view.dart';

class HomeScreenView extends StatelessWidget {
  const HomeScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleController = Provider.of<ScheduleController>(context, listen: false);
    // Используем Consumer для реагирования на изменения в SettingsController
    return Consumer<SettingsController>(
      builder: (context, settingsController, _) {
        final currentGroup = settingsController.selectedGroup;

        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentGroup != null
                      ? 'Текущая группа: $currentGroup'
                      : 'Группа не выбрана',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    final selectedGroup = 90002493;
                    settingsController.setSelectedGroup(selectedGroup);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Группа сохранена'),
                      ),
                    );
                  },
                  child: Text('Сохранить'),
                ),

                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: currentGroup == null
                      ? null // Делаем кнопку неактивной, если группа не выбрана
                      : () async {
                    await scheduleController.loadSchedule(currentGroup);

                    if (scheduleController.error == null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScheduleScreenView(),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Загрузить расписание',
                    textScaler: TextScaler.linear(1.5),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}