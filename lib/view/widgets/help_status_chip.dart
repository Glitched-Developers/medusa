import 'package:flutter/material.dart';

import '../../models/help_request.dart';
import '../../utils/help_helpers.dart';

/// Компактная плашка со статусом студента: «Уже в пути», «Приду через
/// пять минут», «Я на месте» или свой текст.
class HelpStatusChip extends StatelessWidget {
  const HelpStatusChip({
    super.key,
    required this.volunteer,
    this.dense = false,
  });

  final HelpVolunteer volunteer;

  /// Компактный вариант — для карточки в списке.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = helpStatusColor(volunteer.statusKey, scheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(helpStatusIcon(volunteer.statusKey), size: dense ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            volunteer.statusLabel,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
