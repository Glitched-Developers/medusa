import 'package:flutter/material.dart';

import '../models/help_request.dart';
import '../themes/bsu_theme.dart';

/// Иконка категории запроса помощи.
IconData helpCategoryIcon(HelpCategory category) => switch (category) {
      HelpCategory.moving => Icons.inventory_2_outlined,
      HelpCategory.duty => Icons.visibility_outlined,
      HelpCategory.tech => Icons.computer_outlined,
      HelpCategory.print => Icons.print_outlined,
      HelpCategory.other => Icons.volunteer_activism_outlined,
    };

/// Цвет статуса студента: «в пути» — синий, «через 5 минут» — оранжевый,
/// «на месте» — зелёный, свой текст — нейтральный.
Color helpStatusColor(String key, ColorScheme scheme) => switch (key) {
      'en_route' => const Color(0xFF1E88E5),
      'in_5' => const Color(0xFFEF6C00),
      'soon' => const Color(0xFF8E24AA),
      'ready' => BsuColors.green,
      'here' => BsuColors.green,
      _ => scheme.outline,
    };

/// Иконка статуса студента.
IconData helpStatusIcon(String key) => switch (key) {
      'en_route' => Icons.directions_walk,
      'in_5' => Icons.timer_outlined,
      'soon' => Icons.schedule,
      'ready' => Icons.pan_tool_alt_outlined,
      'here' => Icons.place_outlined,
      _ => Icons.edit_note,
    };

/// «5 мин назад», «3 ч назад», «вчера», «12.10».
String helpTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return '${diff.inHours} ч назад';
  if (diff.inDays == 1) return 'вчера';
  final d = time.day.toString().padLeft(2, '0');
  final m = time.month.toString().padLeft(2, '0');
  return '$d.$m';
}

/// Инициалы для аватарки: «Дарья К.» -> «ДК».
String helpInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Правильное слово: 1 студент, 2 студента, 5 студентов.
String studentsWord(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'студентов';
  if (mod10 == 1) return 'студент';
  if (mod10 >= 2 && mod10 <= 4) return 'студента';
  return 'студентов';
}
