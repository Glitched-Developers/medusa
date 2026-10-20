import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import '../../controllers/ui/settings_screen_controller.dart';
import '../../themes/bsu_theme.dart';
import '../../utils/theme_mapper.dart';

class ThemeSelectionDialog extends StatelessWidget {
  final SettingsScreenController controller;

  const ThemeSelectionDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themes = controller.getAvailableThemes();

    return SimpleDialog(
      title: const Text('Выберите тему'),
      children: themes.map((schemeName) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, schemeName),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getColorForScheme(schemeName, context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                ThemeMapper.getDisplayNameFor(schemeName),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Получает основной цвет для схемы (для превью)
  Color _getColorForScheme(String schemeName, BuildContext context) {
    if (schemeName == ThemeMapper.belguScheme) return BsuColors.green;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = FlexScheme.values.firstWhere(
          (s) => s.name == schemeName,
      orElse: () => FlexScheme.material,
    );

    try {
      if (isDark) {
        return FlexColorScheme.dark(scheme: scheme).toScheme.primary;
      } else {
        return FlexColorScheme.light(scheme: scheme).toScheme.primary;
      }
    } catch (_) {
      return BsuColors.green;
    }
  }
}
