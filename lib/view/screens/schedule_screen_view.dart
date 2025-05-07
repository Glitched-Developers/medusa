// lib/views/screens/schedule_screen_view.dart
import 'package:flutter/material.dart';
import 'package:medusa/view/screens/settings_screen_view.dart';
import 'package:medusa/view/widgets/lesson_title.dart';
import 'package:provider/provider.dart';
import '../../controllers/schedule_controller.dart';

class ScheduleScreenView extends StatelessWidget {
  const ScheduleScreenView({super.key});

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: MaterialButton(
          onPressed: () {},
          child: Text("90002493", style: TextStyle(fontSize: 22)),
        ),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              icon: Icon(Icons.settings)
          ),
        ],
      ),


      body: Consumer<ScheduleController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null) {
            return Center(
              child: Text(
                'Ошибка: ${controller.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final schedule = controller.schedule;
          if (schedule == null || schedule.isEmpty) {
            return const Center(child: Text('Нет данных о расписании'));
          }

          return ListView.builder(
            itemCount: schedule.keys.length,
            itemBuilder: (context, index) {
              final day = schedule.keys.elementAt(index);
              final lessons = schedule[day] ?? [];
              List<String> parts = day.split(' ');

              return ExpansionTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Распределит элементы по краям
                  children: [
                    Text(parts[1]), // День недели (Понедельник)
                    Text(parts[0]), // Дата (12.01.2022)
                  ],
                ),
                initiallyExpanded: true,
                children: lessons.map((lesson) => LessonTile(lesson: lesson)).toList(),
              );
            },
          );
        },
      ),
    );

  }
}

