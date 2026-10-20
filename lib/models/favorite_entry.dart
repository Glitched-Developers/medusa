/// Избранное: группа или преподаватель, которых отметили звёздочкой.
///
/// Такие записи показываются первыми и открываются в один тап — без ввода.
class FavoriteEntry {
  const FavoriteEntry({required this.name, required this.isGroup});

  /// Название: номер группы («90002493») или ФИО преподавателя.
  final String name;

  /// Группа это или преподаватель.
  final bool isGroup;

  /// Ключ для сравнения: регистр и лишние пробелы не важны.
  String get key => '${isGroup ? 'g' : 't'}:${name.trim().toLowerCase()}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'isGroup': isGroup,
      };

  factory FavoriteEntry.fromJson(Map<String, dynamic> json) => FavoriteEntry(
        name: (json['name'] as String? ?? '').trim(),
        isGroup: json['isGroup'] as bool? ?? true,
      );

  @override
  String toString() => 'FavoriteEntry($name, isGroup: $isGroup)';
}
