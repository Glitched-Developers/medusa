import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import '../../controllers/ui/settings_screen_controller.dart';
import '../../utils/theme_mapper.dart';

class ThemeSelectionDialog extends StatelessWidget {
  final SettingsScreenController controller;

  const ThemeSelectionDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themes = controller.getAvailableThemes();

    return SimpleDialog(
      title: const Text('Выберите тему'),
      children: themes.map((scheme) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, scheme),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getColorForScheme(scheme, context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                ThemeMapper.getDisplayName(scheme),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Получает основной цвет для схемы (для превью)
  Color _getColorForScheme(FlexScheme scheme, BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return FlexColorScheme.dark(scheme: scheme).toScheme.primary;
    } else {
      return FlexColorScheme.light(scheme: scheme).toScheme.primary;
    }
  }
}