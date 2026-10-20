import 'package:flutter/material.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/services/bsu_api_service.dart';
import 'package:medusa/view/widgets/blur_fade.dart';
import 'package:medusa/view/widgets/lesson_title.dart';
import 'package:medusa/view/widgets/ripple_tap.dart';
import 'package:provider/provider.dart';

/// Расписание одной аудитории: какие пары идут в кабинете за неделю.
/// Открывается тапом по номеру кабинета в карточке пары или из поиска.
class AuditoriumScheduleScreen extends StatefulWidget {
  final String auditoriumId;
  final String auditoriumName;

  const AuditoriumScheduleScreen({
    super.key,
    required this.auditoriumId,
    required this.auditoriumName,
  });

  @override
  State<AuditoriumScheduleScreen> createState() =>
      _AuditoriumScheduleScreenState();
}

class _AuditoriumScheduleScreenState extends State<AuditoriumScheduleScreen> {
  Map<String, List<Lesson>>? _schedule;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<BsuApiService>();
      final data = await api.getAuditoriumSchedule(widget.auditoriumId);
      final scheduleJson = data['schedule'] as Map<String, dynamic>;
      final schedule = scheduleJson.map((day, lessons) => MapEntry(
            day,
            (lessons as List)
                .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
                .toList(),
          ));
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание аудитории'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _nameBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary,
            child: const Icon(Icons.meeting_room_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Аудитория',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.auditoriumName,
                  softWrap: true,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Column(
        children: [
          _nameBanner(context),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ошибка: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    RippleTap(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.25),
                      borderRadius: 20,
                      child: ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final schedule = _schedule;
    if (schedule == null || schedule.isEmpty) {
      return Column(
        children: [
          _nameBanner(context),
          const Expanded(
            child: Center(
              child: Text('В этой аудитории пар на неделю нет'),
            ),
          ),
        ],
      );
    }

    final totalLessons =
        schedule.values.fold<int>(0, (sum, list) => sum + list.length);
    final days = schedule.keys.toList();
    final today = DateTime.now();
    final todayStr =
        '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';

    return Column(
      children: [
        _nameBanner(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Занятий на неделю: $totalLessons',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
                ...days.indexed.map((entry) {
                  final index = entry.$1;
                  final day = entry.$2;
                  final lessons = schedule[day] ?? [];
                  final parts = day.split(' ');
                  final date = parts.isNotEmpty ? parts[0] : day;
                  final weekday =
                      parts.length > 1 ? parts.sublist(1).join(' ') : '';
                  final isToday = date == todayStr;

                  return BlurFade(
                    // Волна: дни проявляются один за другим.
                    delay: Duration(milliseconds: index * 70),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: isToday,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          backgroundColor: isToday
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.45)
                              : null,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                weekday,
                                style: TextStyle(
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.w500),
                              ),
                              Text(
                                date,
                                style: TextStyle(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          children: lessons
                              .map((lesson) => LessonTile(
                                  lesson: lesson,
                                  isToday: isToday,
                                  inAuditorium: true))
                              .toList(),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
