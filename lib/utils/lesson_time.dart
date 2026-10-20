/// Время пары из строки сайта.
///
/// Сайт отдаёт время как «8:30 - 10:05» (иногда с тире другого вида),
/// поэтому берём первое время в строке — начало пары.
DateTime? lessonStart(DateTime day, String time) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  if (hour > 23 || minute > 59) return null;
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// Дата из ключа дня расписания «19.10.2026 Понедельник».
DateTime? scheduleDayDate(String key) {
  final parts = key.split(' ').first.split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}
