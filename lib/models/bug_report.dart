/// Данные об устройстве, которые прикладываются к обращению.
///
/// Нужны, чтобы понять, на каких телефонах что-то ломается: модель,
/// версия Android, размер экрана и сборка приложения. Больше ничего
/// не собираем — ни аккаунтов, ни файлов, ни местоположения.
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.manufacturer,
    required this.android,
    required this.appBuild,
    this.screen = '',
  });

  final String model;
  final String manufacturer;
  final String android;
  final String appBuild;
  final String screen;

  /// «Google Pixel 7 · Android 14 (SDK 34) · сборка 20.10-…».
  String get summary {
    final device = '$manufacturer $model'.trim();
    final parts = <String>[
      if (device.isNotEmpty) device,
      if (android.isNotEmpty) 'Android $android',
      if (appBuild.isNotEmpty) 'сборка $appBuild',
      if (screen.isNotEmpty) 'экран $screen',
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'model': model,
        'manufacturer': manufacturer,
        'android': android,
        'appBuild': appBuild,
        'screen': screen,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        model: '${json['model'] ?? ''}',
        manufacturer: '${json['manufacturer'] ?? ''}',
        android: '${json['android'] ?? ''}',
        appBuild: '${json['appBuild'] ?? ''}',
        screen: '${json['screen'] ?? ''}',
      );

  static const DeviceInfo unknown = DeviceInfo(
    model: 'неизвестно',
    manufacturer: '',
    android: '',
    appBuild: '',
  );
}

/// Вид обращения.
enum ReportKind {
  bug('Баг', 'Что-то не работает'),
  idea('Пожелание', 'Чего не хватает');

  const ReportKind(this.label, this.hint);

  final String label;
  final String hint;

  static ReportKind fromName(String name) =>
      name == 'idea' ? ReportKind.idea : ReportKind.bug;

  String get storageName => name;
}

/// Баг-репорт или пожелание, сохранённое на телефоне.
class BugReport {
  const BugReport({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
    required this.device,
    this.sent = false,
  });

  final String id;
  final ReportKind kind;
  final String text;
  final DateTime createdAt;
  final DeviceInfo device;

  /// Пользователь отправил обращение (скопировал/поделился).
  final bool sent;

  BugReport copyWith({bool? sent}) => BugReport(
        id: id,
        kind: kind,
        text: text,
        createdAt: createdAt,
        device: device,
        sent: sent ?? this.sent,
      );

  /// Текст для «Поделиться» / буфера обмена.
  String asMessage() {
    String two(int v) => v.toString().padLeft(2, '0');
    final at = '${two(createdAt.day)}.${two(createdAt.month)}.'
        '${createdAt.year} ${two(createdAt.hour)}:${two(createdAt.minute)}';
    return 'Медузка — ${kind.label}\n'
        'Дата: $at\n'
        'Устройство: ${device.summary}\n\n'
        '$text';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.storageName,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'device': device.toJson(),
        'sent': sent,
      };

  factory BugReport.fromJson(Map<String, dynamic> json) => BugReport(
        id: '${json['id'] ?? ''}',
        kind: ReportKind.fromName('${json['kind'] ?? 'bug'}'),
        text: '${json['text'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
        device: json['device'] is Map
            ? DeviceInfo.fromJson(
                Map<String, dynamic>.from(json['device'] as Map))
            : DeviceInfo.unknown,
        sent: json['sent'] == true,
      );
}
