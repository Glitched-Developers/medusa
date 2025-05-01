import 'package:flutter/material.dart';
import 'package:medusa/models/lesson.dart';

class LessonTile extends StatelessWidget {
  final Lesson lesson;

  const LessonTile({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${lesson.number}', style: const TextStyle(fontSize: 22)),
            Text(lesson.time, style: const TextStyle(fontSize: 12)),
          ],
        ),
        title: Text(
          lesson.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8.0, // Горизонтальный пробел между элементами
              runSpacing: 4.0, // Вертикальный пробел между строками
              children: [
                Chip(
                  label: Text(lesson.type),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                if (lesson.subgroup != null)
                  Chip(
                    label: Text('П/г ${lesson.subgroup}'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                if (lesson.online)
                  Chip(
                    label: const Text('Онлайн'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Преподаватель: ${lesson.teacher}'),
            Text('Аудитория: ${lesson.auditory}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}