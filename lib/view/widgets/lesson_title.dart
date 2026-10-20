import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/services/auditorium_index_service.dart';
import 'package:medusa/themes/bsu_theme.dart';
import 'package:medusa/view/screens/auditorium_schedule_screen.dart';
import 'package:medusa/view/screens/teacher_schedule_screen.dart';
import 'package:medusa/view/transitions/fade_up_page_route.dart';

import 'border_beam.dart';

class LessonTile extends StatelessWidget {
  final Lesson lesson;

  /// Расписание отображается для сегодняшнего дня:
  /// пары подсвечиваются, прошедшие — «тухнут».
  final bool isToday;

  /// Карточка внутри расписания аудитории: в поле «аудитория» сайт кладёт
  /// номер группы, поэтому подписываем его как группу, а не как кабинет.
  final bool inAuditorium;

  const LessonTile({
    super.key,
    required this.lesson,
    this.isToday = false,
    this.inAuditorium = false,
  });

  /// Нормализует «грязный» тип пары из API и возвращает пару (цвет, короткое название).
  (Color, String) _lessonTypeStyle(String rawType) {
    final t = rawType.trim().toLowerCase();

    if (t.contains('лек') || t == 'лк') {
      return (Colors.indigo, 'Лекция');
    }
    if (t.contains('практ') || t.contains('семинар') || t == 'пр') {
      return (BsuColors.green, 'Практика');
    }
    if (t.contains('лаб')) {
      return (Colors.orange, 'Лабораторная');
    }
    if (t.contains('консульт')) {
      return (Colors.teal, 'Консультация');
    }
    if (t.contains('экзам') || t.contains('зачёт') || t.contains('зачет')) {
      return (Colors.red, 'Экзамен');
    }
    // Fallback — нейтральный цвет, чтобы не было «кислоты»
    return (Colors.blueGrey, rawType);
  }

  /// Название пары. Если в расписании на сайте у пары есть ссылка на курс
  /// (Pegasus), по тапу открываем её в браузере: авторизацию курс попросит
  /// сам, нам достаточно перейти по встроенной ссылке.
  Widget _title(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w600);
    final url = lesson.url;
    if (url == null) return Text(lesson.name, style: style);

    return InkWell(
      onTap: () => _openCourse(context, url),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(lesson.name, style: style)),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.open_in_new,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCourse(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть курс в браузере')),
      );
    }
  }

  /// "8:30 - 10:05" -> (510, 605) — минуты от полуночи; null, если не разобрано.
  static (int, int)? timeRange(String time) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})')
        .firstMatch(time);
    if (m == null) return null;
    int toMin(String h, String min) => int.parse(h) * 60 + int.parse(min);
    return (
      toMin(m.group(1)!, m.group(2)!),
      toMin(m.group(3)!, m.group(4)!),
    );
  }

  /// Индекс аудиторий, если он подключён в дереве провайдеров.
  /// Слушаем изменения: когда список кабинетов докачается, карточка
  /// перестроится и кабинет станет кликабельным.
  AuditoriumIndexService? _roomIndex(BuildContext context) {
    try {
      return Provider.of<AuditoriumIndexService>(context);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (typeColor, typeLabel) = _lessonTypeStyle(lesson.type);
    final theme = Theme.of(context);

    // Кабинет из расписания («6-12») -> аудитория сайта с её id.
    // Индекс аудиторий может быть не подключён (например, в тестах) —
    // без него карточка пары работает как раньше.
    // В расписании кабинета это не кабинет, а группа — не резолвим.
    final room = lesson.auditory.isEmpty || inAuditorium
        ? null
        : _roomIndex(context)?.resolve(lesson.auditory);

    // Состояние пары для сегодняшнего дня
    final range = timeRange(lesson.time);
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final passed =
        isToday && range != null && nowMin > range.$2;
    final ongoing =
        isToday && range != null && nowMin >= range.$1 && nowMin <= range.$2;
    // Сегодняшние непрошедшие пары — подсвечиваем фоном
    final highlight = isToday && !passed;

    Widget card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: highlight
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.65)
          : theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Кружок с номером пары + время под ним
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: typeColor,
                    child: Text(
                      '${lesson.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lesson.time,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Содержимое пары
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(context),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          typeLabel,
                          style:
                              TextStyle(fontSize: 12, color: typeColor),
                        ),
                      ),
                      if (ongoing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BsuColors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 2),
                              Text('Идёт сейчас',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      if (lesson.subgroup != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'П/г ${lesson.subgroup}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (lesson.online)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi,
                                  size: 12, color: Colors.blue),
                              SizedBox(width: 4),
                              Text('Онлайн',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (lesson.teacher.isNotEmpty)
                    _InfoRow(
                      icon: Icons.person_outline,
                      text: lesson.teacher,
                      // Тап по ФИО — расписание преподавателя (все его пары)
                      onTap: lesson.teacherId != null
                          ? () => Navigator.push(
                                context,
                                FadeUpPageRoute(
                                  page: TeacherScheduleScreen(
                                    teacherId: lesson.teacherId!,
                                    teacherName: lesson.teacher,
                                  ),
                                ),
                              )
                          : null,
                    ),
                  if (lesson.auditory.isNotEmpty)
                    _InfoRow(
                      icon: inAuditorium
                          ? Icons.groups_outlined
                          : Icons.place_outlined,
                      text: inAuditorium
                          ? 'Группа ${lesson.auditory}'
                          : lesson.auditory,
                      // Тап по кабинету — расписание этой аудитории.
                      onTap: room == null
                          ? null
                          : () => Navigator.push(
                                context,
                                FadeUpPageRoute(
                                  page: AuditoriumScheduleScreen(
                                    auditoriumId: room.id,
                                    auditoriumName: room.name,
                                  ),
                                ),
                              ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Пара идёт прямо сейчас: по рамке бегут две полосы — зелёная и
    // тёплая, друг напротив друга. Скорость у них одна, поэтому
    // расстояние не меняется: одна будто догоняет вторую.
    if (ongoing) {
      card = BorderBeam(
        borderRadius: 14,
        borderWidth: 2,
        beamLengthFraction: 0.22,
        duration: const Duration(seconds: 5),
        colorFrom: BsuColors.green,
        colorTo: const Color(0xFF7FC79E),
        extras: const <BorderBeamSpec>[
          BorderBeamSpec(
            offset: 0.5,
            colorFrom: Color(0xFFE39B24),
            colorTo: Color(0xFFF4D79A),
            beamLengthFraction: 0.22,
          ),
        ],
        child: card,
      );
    }

    card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: card,
    );

    // Прошедшая пара «тухнет»: приглушаем, чтобы не отвлекать
    if (passed) {
      return Opacity(opacity: 0.45, child: card);
    }
    return card;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final content = Row(
      children: [
        Icon(icon, size: 14, color: style?.color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: style?.copyWith(
              decoration: onTap != null ? TextDecoration.underline : null,
              decorationColor: style.color?.withValues(alpha: 0.4),
            ),
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right, size: 16, color: style?.color),
      ],
    );

    if (onTap == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 2), child: content);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: content,
      ),
    );
  }
}
