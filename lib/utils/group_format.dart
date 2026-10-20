/// Номер группы в том виде, в каком его понимает сайт.
///
/// Номера групп в БелГУ — восемь цифр, и ведущие нули значимы:
/// «01002205» и «1002205» для сайта разные (по второму расписание пустое).
/// Поэтому в запросах, избранном и подписях всегда используем полную запись.
String formatGroupNumber(int group) => group.toString().padLeft(8, '0');

/// Полная запись номера группы из строки (для текста, введённого вручную).
String formatGroupName(String group) {
  final value = int.tryParse(group.trim());
  return value == null ? group.trim() : formatGroupNumber(value);
}
