import 'package:medusa/models/lesson.dart';
import 'package:medusa/models/metadata.dart';

// lib/models/schedule_response.dart
class ScheduleResponse {
  final Metadata metadata;
  final Map<String, List<Lesson>> schedule;

  ScheduleResponse({
    required this.metadata,
    required this.schedule,
  });

  factory ScheduleResponse.fromJson(Map<String, dynamic> json) {
    // Проверяем наличие ключа schedule в JSON
    if (json['schedule'] == null) {
      return ScheduleResponse(
        metadata: Metadata.fromJson(json['metadata'] ?? {'timestamp': ''}),
        schedule: {},
      );
    }

    // Обрабатываем расписание
    Map<String, List<Lesson>> scheduleMap = {};
    final scheduleJson = json['schedule'] as Map<String, dynamic>;

    scheduleJson.forEach((day, lessons) {
      if (lessons is List) {
        scheduleMap[day] = lessons
            .map((lesson) =>
            Lesson.fromJson(lesson is Map<String, dynamic>
                ? lesson
                : {}))
            .toList();
      } else {
        scheduleMap[day] = [];
      }
    });

    return ScheduleResponse(
      metadata: Metadata.fromJson(json['metadata'] ?? {'timestamp': ''}),
      schedule: scheduleMap,
    );
  }
}
