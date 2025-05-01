class Lesson {
  final int number;
  final String time;
  final String type;
  final String name;
  final String teacher;
  final String auditory;
  final bool online;
  final String key;
  final int? subgroup;

  Lesson({
    required this.number,
    required this.time,
    required this.type,
    required this.name,
    required this.teacher,
    required this.auditory,
    required this.online,
    required this.key,
    this.subgroup,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      number: json['number'] as int? ?? 0,
      time: json['time'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      auditory: json['auditory'] as String? ?? '',
      online: json['online'] as bool? ?? false,
      key: json['key'] as String? ?? '${json['number'] ?? 0}_key',
      subgroup: json['subgroup'] as int?,
    );
  }
}