// lib/views/screens/schedule_screen_view.dart
import 'package:flutter/material.dart';
import 'package:medusa/models/lesson.dart';
import 'package:medusa/view/screens/Initial_setup_screen_view.dart';
import 'package:medusa/view/screens/chats_screen_view.dart';
import 'package:medusa/view/screens/help_screen_view.dart';
import 'package:medusa/view/screens/news_screen_view.dart';
import 'package:medusa/view/screens/settings_screen_view.dart';
import 'package:medusa/view/transitions/fade_up_page_route.dart';
import 'package:medusa/view/widgets/blur_fade.dart';
import 'package:medusa/view/widgets/lesson_title.dart';
import 'package:medusa/view/widgets/ripple_tap.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../controllers/help_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../models/favorite_entry.dart';
import '../../themes/bsu_theme.dart';
import '../../utils/group_format.dart';

class ScheduleScreenView extends StatelessWidget {
  const ScheduleScreenView({super.key});

  Future<void> _refresh(BuildContext context) async {
    final schedule = context.read<ScheduleController>();
    // Принудительно: минуя кеш, иначе pull-to-refresh бесполезен
    await schedule.refreshSchedule();
  }

  void _changeGroup(BuildContext context) {
    Navigator.of(context).pushReplacement(
      FadeUpPageRoute(page: const InitialSetupScreenView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = context.watch<SettingsController>().selectedGroup;
    final controller = context.watch<ScheduleController>();
    final helpCount = context.watch<HelpController>().openCount;
    final chatCount = context.watch<ChatController>().unreadTotal;
    final favorites = context.watch<FavoritesController>();
    // Номер группы на сайте — всегда восемь цифр: ведущие нули значимы
    // (01002205 и 1002205 — для сайта разные группы).
    final groupName = group == null ? '' : formatGroupNumber(group);
    final isFavoriteGroup =
        group != null && favorites.isFavorite(groupName, isGroup: true);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: MaterialButton(
          onPressed: () => _changeGroup(context),
          child: Text(
            group == null ? 'Группа не выбрана' : groupName,
            style: const TextStyle(fontSize: 22),
          ),
        ),
        actions: [
          if (group != null)
            IconButton(
              tooltip: isFavoriteGroup
                  ? 'Убрать группу из избранного'
                  : 'Группа в избранное',
              onPressed: () => favorites.toggle(
                FavoriteEntry(name: groupName, isGroup: true),
              ),
              icon: Icon(
                isFavoriteGroup ? Icons.star : Icons.star_border,
                color: isFavoriteGroup ? BsuColors.green : null,
              ),
            ),
          IconButton(
            tooltip: 'Помощь',
            onPressed: () {
              Navigator.push(
                context,
                FadeUpPageRoute(page: const HelpScreenView()),
              );
            },
            icon: Badge(
              isLabelVisible: helpCount > 0,
              label: Text('$helpCount'),
              child: const Icon(Icons.volunteer_activism_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Чаты',
            onPressed: () {
              Navigator.push(
                context,
                FadeUpPageRoute(page: const ChatsScreenView()),
              );
            },
            icon: Badge(
              isLabelVisible: chatCount > 0,
              label: Text('$chatCount'),
              child: const Icon(Icons.forum_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Новости БелГУ',
            onPressed: () {
              Navigator.push(
                context,
                FadeUpPageRoute(page: const NewsScreenView()),
              );
            },
            icon: const Icon(Icons.newspaper_outlined),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                FadeUpPageRoute(page: const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
        bottom: _weekBar(context, controller),
      ),
      body: Consumer<ScheduleController>(
        builder: (context, controller, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // Направленный переход: при листании вперёд новый день
            // въезжает справа, назад — слева (см. weekDirection).
            transitionBuilder: (child, animation) {
              final dir = controller.weekDirection.toDouble();
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0.22 * dir, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildBody(context, controller),
          );
        },
      ),
    );
  }

  /// Нижняя панель AppBar: переключатель недель «‹ даты ›».
  PreferredSize? _weekBar(BuildContext context, ScheduleController controller) {
    final schedule = controller.schedule;
    if (schedule == null || schedule.isEmpty) return null;

    const offsetTitles = {
      0: 'Эта неделя',
      -1: 'Прошлая неделя',
      1: 'Следующая неделя',
    };
    final offset = controller.weekOffset;
    final title = offsetTitles[offset] ??
        (offset > 0 ? 'Через $offset нед.' : '${-offset} нед. назад');

    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Прошлая неделя',
                  onPressed: controller.isLoading
                      ? null
                      : () => controller.changeWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: InkWell(
                      key: ValueKey(offset),
                      borderRadius: BorderRadius.circular(12),
                      onTap: offset != 0 && !controller.isLoading
                          ? () => controller.goToCurrentWeek()
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              _weekRange(schedule),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Следующая неделя',
                  onPressed: controller.isLoading
                      ? null
                      : () => controller.changeWeek(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (controller.isLoading)
            const SizedBox(height: 2, child: LinearProgressIndicator()),
        ],
      ),
    );
  }

  /// Диапазон дат недели по ключам расписания: "12.10.2026 Пн" -> "12.10 – 18.10".
  String _weekRange(Map<String, List<Lesson>> schedule) {
    DateTime? parse(String key) {
      final part = key.split(' ').first.split('.');
      if (part.length != 3) return null;
      final d = int.tryParse(part[0]);
      final m = int.tryParse(part[1]);
      final y = int.tryParse(part[2]);
      if (d == null || m == null || y == null) return null;
      return DateTime(y, m, d);
    }

    final dates =
        schedule.keys.map(parse).whereType<DateTime>().toList()..sort();
    if (dates.isEmpty) return '';
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    return '${fmt(dates.first)} – ${fmt(dates.last)}';
  }

  Widget _buildBody(BuildContext context, ScheduleController controller) {
    if (controller.isLoading && controller.schedule == null) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (controller.error != null && controller.schedule == null) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ошибка: ${controller.error}',
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
                  onPressed: () => _refresh(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ),
              const SizedBox(height: 8),
              RippleTap(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.18),
                borderRadius: 20,
                child: TextButton(
                  onPressed: () => _changeGroup(context),
                  child: const Text('Сменить группу'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final schedule = controller.schedule;
    if (schedule == null || schedule.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Нет данных о расписании'),
            const SizedBox(height: 16),
            RippleTap(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.25),
              borderRadius: 20,
              child: ElevatedButton.icon(
                onPressed: () => _refresh(context),
                icon: const Icon(Icons.refresh),
                label: const Text('Загрузить'),
              ),
            ),
          ],
        ),
      );
    }

    final days = schedule.keys.toList();
    final today = DateTime.now();
    final todayStr =
        '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';

    final list = RefreshIndicator(
      // Ключ по первой дате: при смене недели содержимое плавно переключается
      key: ValueKey('schedule_${schedule.keys.first}'),
      onRefresh: () => _refresh(context),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final lessons = schedule[day] ?? [];
          final parts = day.split(' ');
          // Заголовок вида "12.10.2026 Понедельник"
          final date = parts.isNotEmpty ? parts[0] : day;
          final weekday = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          final isToday = date == todayStr;

          return BlurFade(
            // Волна: дни расписания проявляются один за другим.
            delay: Duration(milliseconds: index * 70),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: isToday
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.45)
                      : null,
                  leading: isToday
                      ? const Icon(Icons.today, color: BsuColors.green)
                      : null,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        weekday,
                        style: TextStyle(
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          color: isToday ? BsuColors.green : null,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  initiallyExpanded: true,
                  children: lessons
                      .map((lesson) =>
                          LessonTile(lesson: lesson, isToday: isToday))
                      .toList(),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!controller.isOffline) return list;

    // Сети нет — честно говорим, что это сохранённый снимок.
    return Column(
      children: [
        _OfflineBanner(snapshotAt: controller.offlineSnapshotAt),
        Expanded(child: list),
      ],
    );
  }
}

/// «Нет интернета — показано сохранённое расписание от 20.10, 14:30».
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({this.snapshotAt});

  final DateTime? snapshotAt;

  String _when() {
    final at = snapshotAt;
    if (at == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return 'от ${two(at.day)}.${two(at.month)}, '
        '${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              snapshotAt == null
                  ? 'Нет интернета — показано сохранённое расписание'
                  : 'Нет интернета — сохранённое расписание ${_when()}',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
