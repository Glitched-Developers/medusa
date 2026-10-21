import 'package:flutter/material.dart';

import '../../models/user_badge.dart';
import 'badge_medal.dart';

/// Рассказ о значке: что это и за что его выдают.
///
/// Открывается по нажатию на значок — и в своём профиле, и в чужом.
/// [ownerName] — чей это профиль (для чужого: «есть в профиле: …»).
Future<void> showBadgeDetails(
  BuildContext context,
  UserBadge badge, {
  bool earned = false,
  String? ownerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (sheetContext) => _BadgeDetailsSheet(
          badge: badge,
          earned: earned,
          ownerName: ownerName,
        ),
  );
}

class _BadgeDetailsSheet extends StatelessWidget {
  const _BadgeDetailsSheet({
    required this.badge,
    required this.earned,
    this.ownerName,
  });

  final UserBadge badge;
  final bool earned;
  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final owner = ownerName?.trim() ?? '';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeMedal(
              badge: badge,
              earned: earned,
              size: 92,
              animate: badge.isExclusive && earned,
            ),
            const SizedBox(height: 14),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _Chip(
                  icon:
                      badge.isExclusive
                          ? Icons.auto_awesome
                          : Icons.workspace_premium_outlined,
                  label: badge.isExclusive ? 'Эксклюзивный' : 'За активность',
                  highlighted: badge.isExclusive,
                ),
                _Chip(
                  icon:
                      earned ? Icons.check_circle_outline : Icons.lock_outline,
                  label: earned ? 'Получен' : 'Пока нет',
                  highlighted: earned,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 17, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'За что выдают',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    badge.description,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusText(owner),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Понятно'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(String owner) {
    if (earned && owner.isNotEmpty) {
      return 'Этот значок есть в профиле: $owner.';
    }
    if (earned) {
      return 'Этот значок уже в вашем профиле.';
    }
    if (badge.isExclusive) {
      return 'Эксклюзивный значок: его выдаёт команда Медузки кодом '
          'активации — код можно ввести в своём профиле.';
    }
    return 'Значок появится в профиле автоматически, как только выполните '
        'условие.';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color:
            highlighted
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainerHighest,
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
