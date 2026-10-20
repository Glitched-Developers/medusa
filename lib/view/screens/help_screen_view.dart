import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/help_controller.dart';
import '../../models/help_request.dart';
import '../../themes/bsu_theme.dart';
import '../../utils/help_helpers.dart';
import '../widgets/help_sheets.dart';
import '../widgets/help_status_chip.dart';
import '../widgets/ripple_tap.dart';

/// Раздел «Помощь»: запросы преподавателей и отклики студентов.
///
/// Преподаватель публикует, что нужно сделать (например, перетащить вещи),
/// студенты берут задачу и пишут свой статус. В карточке сразу видно,
/// сколько студентов взялось и кто в каком статусе.
class HelpScreenView extends StatefulWidget {
  const HelpScreenView({super.key});

  @override
  State<HelpScreenView> createState() => _HelpScreenViewState();
}

enum _HelpFilter { all, myTasks, myRequests }

class _HelpScreenViewState extends State<HelpScreenView> {
  _HelpFilter _filter = _HelpFilter.all;

  @override
  Widget build(BuildContext context) {
    final help = context.watch<HelpController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Помощь', style: TextStyle(fontSize: 22)),
        actions: [
          IconButton(
            tooltip: help.hasProfile ? 'Вы: ${help.userName}' : 'Представиться',
            onPressed: () => showHelpProfileSheet(context),
            icon: Icon(
              help.isTeacher ? Icons.school_outlined : Icons.person_outline,
            ),
          ),
        ],
      ),
      body: !help.isReady
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, help, scheme),
      floatingActionButton: help.isTeacher && help.hasProfile
          ? RippleTap(
              borderRadius: 28,
              child: FloatingActionButton.extended(
                onPressed: () => showCreateHelpRequestSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Запрос помощи'),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    HelpController help,
    ColorScheme scheme,
  ) {
    final requests = switch (_filter) {
      _HelpFilter.all => help.openRequests,
      _HelpFilter.myTasks => help.myTasks,
      _HelpFilter.myRequests => help.myRequests,
    };

    return Column(
      children: [
        if (!help.hasProfile)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            color: scheme.primaryContainer.withValues(alpha: 0.6),
            child: ListTile(
              leading: const Icon(Icons.badge_outlined, color: BsuColors.green),
              title: const Text('Как вас подписать?'),
              subtitle: const Text(
                'Имя нужно, чтобы было видно, кто просит помощь '
                'и кто откликнулся.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showHelpProfileSheet(context),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<_HelpFilter>(
            segments: <ButtonSegment<_HelpFilter>>[
              ButtonSegment<_HelpFilter>(
                value: _HelpFilter.all,
                label: Text('Все (${help.openRequests.length})'),
              ),
              ButtonSegment<_HelpFilter>(
                value: _HelpFilter.myTasks,
                label: Text('Я взял (${help.myTasks.length})'),
              ),
              ButtonSegment<_HelpFilter>(
                value: _HelpFilter.myRequests,
                label: Text('Я прошу (${help.myRequests.length})'),
              ),
            ],
            selected: <_HelpFilter>{_filter},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _filter = selection.first),
          ),
        ),
        Expanded(
          child: requests.isEmpty
              ? _EmptyState(
                  filter: _filter,
                  isTeacher: help.isTeacher,
                  onProfile: () => showHelpProfileSheet(context),
                  onCreate: () => showCreateHelpRequestSheet(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: requests.length,
                  itemBuilder: (context, index) =>
                      _HelpRequestCard(request: requests[index]),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.isTeacher,
    required this.onProfile,
    required this.onCreate,
  });

  final _HelpFilter filter;
  final bool isTeacher;
  final VoidCallback onProfile;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, text) = switch (filter) {
      _HelpFilter.all => (
          Icons.volunteer_activism_outlined,
          'Пока нет запросов',
          'Здесь появятся просьбы преподавателей: помочь донести вещи, '
              'настроить технику, подежурить.',
        ),
      _HelpFilter.myTasks => (
          Icons.handshake_outlined,
          'Вы ещё не брали задачи',
          'Выберите запрос во вкладке «Все» и нажмите «Взять задачу».',
        ),
      _HelpFilter.myRequests => (
          Icons.campaign_outlined,
          'Вы ещё ничего не просили',
          isTeacher
              ? 'Нажмите «Запрос помощи», чтобы попросить студентов.'
              : 'Опубликовать запрос может преподаватель — включите роль '
                  'преподавателя в профиле.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 16),
            if (isTeacher)
              RippleTap(
                borderRadius: 22,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Запрос помощи'),
                ),
              )
            else
              RippleTap(
                // Кнопка светлая — волна фирменного зелёного.
                color: scheme.primary.withValues(alpha: 0.25),
                borderRadius: 22,
                child: OutlinedButton.icon(
                  onPressed: onProfile,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Представиться'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HelpRequestCard extends StatelessWidget {
  const _HelpRequestCard({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    final help = context.watch<HelpController>();
    final scheme = Theme.of(context).colorScheme;
    final mine = help.myVolunteer(request);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showHelpRequestDetailsSheet(context, request.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      helpCategoryIcon(request.category),
                      color: BsuColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            if (request.place.isNotEmpty)
                              _MetaText(
                                icon: Icons.place_outlined,
                                text: request.place,
                              ),
                            if (request.timeText.isNotEmpty)
                              _MetaText(
                                icon: Icons.schedule,
                                text: request.timeText,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(request: request),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 15, color: scheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.isDemo
                          ? 'Просит: ${request.authorName} · пример'
                          : 'Просит: ${request.authorName}',
                      style: TextStyle(fontSize: 13, color: scheme.outline),
                    ),
                  ),
                  Text(
                    helpTimeAgo(request.createdAt),
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ],
              ),
              if (request.volunteers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final volunteer in request.volunteers)
                      HelpStatusChip(volunteer: volunteer, dense: true),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (mine != null)
                    HelpStatusChip(volunteer: mine, dense: true)
                  else if (request.closed)
                    Text(
                      'Запрос закрыт',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  const Spacer(),
                  if (mine == null && !request.closed && !request.isFull)
                    RippleTap(
                      color: scheme.primary.withValues(alpha: 0.22),
                      borderRadius: 20,
                      child: FilledButton.tonalIcon(
                        onPressed: () => showTakeTaskSheet(context, request.id),
                        icon: const Icon(Icons.handshake_outlined, size: 18),
                        label: const Text('Взять задачу'),
                      ),
                    )
                  else if (mine == null && !request.closed && request.isFull)
                    // Мест больше нет — взять задачу нельзя.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: BsuColors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Мест нет',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BsuColors.green,
                          ),
                        ),
                      ],
                    )
                  else if (mine != null)
                    RippleTap(
                      color: scheme.primary.withValues(alpha: 0.18),
                      borderRadius: 20,
                      child: TextButton.icon(
                        onPressed: () => showTakeTaskSheet(context, request.id),
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('Изменить статус'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.outline),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12.5, color: scheme.outline)),
      ],
    );
  }
}

/// «2 из 3» — сколько студентов взялось.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final full = request.isFull;
    final color = full ? BsuColors.green : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            full ? Icons.check_circle_outline : Icons.groups_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${request.takenCount} из ${request.needed}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
