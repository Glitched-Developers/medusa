import 'dart:convert';

import 'lesson.dart';
import 'metadata.dart';

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

  // Fixed: Return Map<String, dynamic> instead of String
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    final Map<String, List<Map<String, dynamic>>> scheduleData = {};

    schedule.forEach((day, lessons) {
      scheduleData[day] = lessons.map((lesson) => {
        'number': lesson.number,
        'time': lesson.time,
        'type': lesson.type,
        'name': lesson.name,
        'teacher': lesson.teacher,
        'auditory': lesson.auditory,
        'online': lesson.online,
        'key': lesson.key,
        if (lesson.subgroup != null) 'subgroup': lesson.subgroup,
      }).toList();
    });

    data['metadata'] = {
      'timestamp': metadata.timestamp,
    };
    data['schedule'] = scheduleData;

    return data;
  }
}