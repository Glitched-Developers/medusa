/// Аудитория вуза: кабинет, в котором идут пары.
///
/// На сайте у каждой аудитории есть числовой id (`aud_json.php`),
/// а в расписании показывается короткое название — «6-12», «316 Физика».
class Auditorium {
  const Auditorium({required this.id, required this.name});

  /// id аудитории на сайте (нужен для запроса расписания).
  final String id;

  /// Название, как его видит студент.
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};

  factory Auditorium.fromJson(Map<String, dynamic> json) => Auditorium(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
      );

  @override
  String toString() => 'Auditorium($id, $name)';
}
