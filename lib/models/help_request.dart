import 'dart:math' as math;

/// Категория запроса помощи — подсказывает иконку и подпись в карточке.
enum HelpCategory {
  moving('Перетащить вещи'),
  duty('Дежурство / присмотреть'),
  tech('Техника и компьютер'),
  print('Печать и копии'),
  other('Другое');

  const HelpCategory(this.label);

  final String label;

  static HelpCategory fromKey(String? key) => HelpCategory.values.firstWhere(
        (c) => c.name == key,
        orElse: () => HelpCategory.other,
      );
}

/// Готовые статусы студента, который взял задачу.
///
/// Кроме них можно ввести свой текст — тогда используется [customKey].
class HelpStatusOption {
  const HelpStatusOption(this.key, this.label);

  final String key;
  final String label;

  static const String customKey = 'custom';

  static const List<HelpStatusOption> presets = <HelpStatusOption>[
    HelpStatusOption('en_route', 'Уже в пути'),
    HelpStatusOption('in_5', 'Приду через пять минут'),
    HelpStatusOption('soon', 'Скоро буду'),
    HelpStatusOption('ready', 'Свободен прямо сейчас'),
    HelpStatusOption('here', 'Я уже на месте'),
  ];

  /// Подпись статуса: для своего текста берём то, что написал студент.
  static String labelFor(String key, String text) {
    if (key == customKey) return text;
    for (final p in presets) {
      if (p.key == key) return p.label;
    }
    return text.isEmpty ? 'Взял задачу' : text;
  }
}

/// Студент, который откликнулся на запрос.
class HelpVolunteer {
  const HelpVolunteer({
    required this.id,
    required this.name,
    required this.statusKey,
    required this.statusText,
    required this.at,
  });

  final String id;
  final String name;

  /// Ключ статуса из [HelpStatusOption.presets] или [HelpStatusOption.customKey].
  final String statusKey;

  /// Свой текст статуса (пустой для готовых вариантов).
  final String statusText;

  /// Когда студент взял задачу / обновил статус.
  final DateTime at;

  String get statusLabel => HelpStatusOption.labelFor(statusKey, statusText);

  HelpVolunteer copyWith({String? statusKey, String? statusText, DateTime? at}) {
    return HelpVolunteer(
      id: id,
      name: name,
      statusKey: statusKey ?? this.statusKey,
      statusText: statusText ?? this.statusText,
      at: at ?? this.at,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'statusKey': statusKey,
        'statusText': statusText,
        'at': at.toIso8601String(),
      };

  factory HelpVolunteer.fromJson(Map<String, dynamic> json) {
    return HelpVolunteer(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      statusKey: (json['statusKey'] ?? '') as String,
      statusText: (json['statusText'] ?? '') as String,
      at: DateTime.tryParse((json['at'] ?? '') as String) ?? DateTime.now(),
    );
  }
}

/// Запрос помощи: его создаёт преподаватель, а студенты откликаются.
class HelpRequest {
  const HelpRequest({
    required this.id,
    required this.title,
    required this.authorName,
    required this.createdAt,
    this.category = HelpCategory.other,
    this.description = '',
    this.place = '',
    this.timeText = '',
    this.needed = 1,
    this.closed = false,
    this.isDemo = false,
    this.volunteers = const <HelpVolunteer>[],
  });

  final String id;
  final String title;

  /// Кто просит помощь (ФИО преподавателя).
  final String authorName;

  /// Когда запрос опубликован.
  final DateTime createdAt;

  final HelpCategory category;

  /// Подробности: что именно нужно сделать.
  final String description;

  /// Где: корпус, аудитория и т.п.
  final String place;

  /// Когда: «сегодня до 15:00», «в среду после 3 пары».
  final String timeText;

  /// Сколько студентов нужно.
  final int needed;

  /// Запрос закрыт автором — больше не откликается.
  final bool closed;

  /// Демонстрационный запрос (показывается один раз при первом запуске).
  /// Такой запрос можно удалить с любого устройства-профиля.
  final bool isDemo;

  final List<HelpVolunteer> volunteers;

  /// Сколько студентов уже взялись.
  int get takenCount => volunteers.length;

  /// Набрано ли нужное количество.
  bool get isFull => takenCount >= needed;

  HelpRequest copyWith({
    String? title,
    String? authorName,
    HelpCategory? category,
    String? description,
    String? place,
    String? timeText,
    int? needed,
    bool? closed,
    bool? isDemo,
    List<HelpVolunteer>? volunteers,
  }) {
    return HelpRequest(
      id: id,
      title: title ?? this.title,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt,
      category: category ?? this.category,
      description: description ?? this.description,
      place: place ?? this.place,
      timeText: timeText ?? this.timeText,
      needed: needed ?? this.needed,
      closed: closed ?? this.closed,
      isDemo: isDemo ?? this.isDemo,
      volunteers: volunteers ?? this.volunteers,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
        'category': category.name,
        'description': description,
        'place': place,
        'timeText': timeText,
        'needed': needed,
        'closed': closed,
        'isDemo': isDemo,
        'volunteers': volunteers.map((v) => v.toJson()).toList(),
      };

  factory HelpRequest.fromJson(Map<String, dynamic> json) {
    final raw = json['volunteers'];
    return HelpRequest(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      authorName: (json['authorName'] ?? '') as String,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '') as String) ?? DateTime.now(),
      category: HelpCategory.fromKey(json['category'] as String?),
      description: (json['description'] ?? '') as String,
      place: (json['place'] ?? '') as String,
      timeText: (json['timeText'] ?? '') as String,
      needed: (json['needed'] as num?)?.toInt() ?? 1,
      closed: json['closed'] == true,
      isDemo: json['isDemo'] == true,
      volunteers: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => HelpVolunteer.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const <HelpVolunteer>[],
    );
  }
}

/// Короткий уникальный идентификатор для локальных записей.
String newHelpId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd = math.Random().nextInt(1 << 20).toRadixString(36);
  return '$now-$rnd';
}
