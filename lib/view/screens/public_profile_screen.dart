import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../models/persona.dart';
import '../../models/user_badge.dart';
import '../transitions/fade_up_page_route.dart';
import '../widgets/badge_medal.dart';
import '../widgets/badge_details_sheet.dart';
import '../widgets/ripple_tap.dart';
import 'chat_screen_view.dart';

/// Профиль другого человека: имя, роль, уровень, значки и кнопка
/// «Написать». Открывается по нажатию на имя в помощи или в чате.
class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.persona});

  final Persona persona;

  Future<void> _startChat(BuildContext context) async {
    final chats = context.read<ChatController>();
    await chats.ensureConversation(persona);
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(FadeUpPageRoute(page: ChatScreenView(peer: persona)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _header(context, scheme),
          const SizedBox(height: 16),
          _badges(context, scheme),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: RippleTap(
              borderRadius: 25,
              child: FilledButton.icon(
                onPressed: () => _startChat(context),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Написать'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Переписка хранится на этом телефоне. Когда появится общий '
            'сервер, сообщения начнут доходить до собеседника.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.outline, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme scheme) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: <Color>[
            scheme.primaryContainer.withValues(alpha: 0.85),
            scheme.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: scheme.surface,
                  child: Text(
                    persona.avatar,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.name.isEmpty ? 'Без имени' : persona.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill(
                          context,
                          icon:
                              persona.isTeacher
                                  ? Icons.school_outlined
                                  : Icons.person_outline,
                          label: persona.roleLabel,
                        ),
                        _pill(
                          context,
                          icon: Icons.military_tech_outlined,
                          label: 'Ур. ${persona.level} · ${persona.levelName}',
                          highlighted: true,
                        ),
                        if (persona.isDemo)
                          _pill(
                            context,
                            icon: Icons.science_outlined,
                            label: 'демо-профиль',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (persona.about.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              persona.about,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (persona.group.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 14, color: scheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Группа ${persona.group}',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${persona.points} очков',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                'до следующего уровня: ${persona.toNextLevel}',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: persona.progress,
              minHeight: 6,
              backgroundColor: scheme.surface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badges(BuildContext context, ColorScheme scheme) {
    final badges = persona.badges;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Значки', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Text(
                  '${badges.length} из ${BadgeCatalog.all.length}',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (badges.isEmpty)
              Text(
                'Пока без значков',
                style: TextStyle(fontSize: 12, color: scheme.outline),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final badge in badges)
                    GestureDetector(
                      onTap:
                          () => showBadgeDetails(
                            context,
                            badge,
                            earned: true,
                            ownerName: persona.name,
                          ),
                      child: BadgeMedal(badge: badge, size: 44),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            highlighted
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlighted ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
              color: highlighted ? scheme.primary : scheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
