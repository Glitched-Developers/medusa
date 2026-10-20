class Lesson {
  final int number;
  final String time;
  final String type;
  final String name;
  final String teacher;
  final int? teacherId;
  final String auditory;
  final bool online;
  final String key;
  final int? subgroup;

  /// Ссылка на курс в Pegasus, если она есть в расписании на сайте.
  /// Открывается по тапу на название пары.
  final String? url;

  Lesson({
    required this.number,
    required this.time,
    required this.type,
    required this.name,
    required this.teacher,
    this.teacherId,
    required this.auditory,
    required this.online,
    required this.key,
    this.subgroup,
    this.url,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      number: json['number'] as int? ?? 0,
      time: json['time'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      teacherId: json['teacherId'] as int?,
      auditory: json['auditory'] as String? ?? '',
      online: json['online'] as bool? ?? false,
      key: json['key'] as String? ?? '${json['number'] ?? 0}_key',
      subgroup: json['subgroup'] as int?,
      url: (json['url'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['url'] as String).trim(),
    );
  }

  // Added toJson method
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'time': time,
      'type': type,
      'name': name,
      'teacher': teacher,
      if (teacherId != null) 'teacherId': teacherId,
      'auditory': auditory,
      'online': online,
      'key': key,
      if (subgroup != null) 'subgroup': subgroup,
      if (url != null) 'url': url,
    };
  }
}
