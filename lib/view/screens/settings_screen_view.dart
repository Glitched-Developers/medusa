import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../../controllers/ui/settings_screen_controller.dart';
import '../../themes/provider/theme_provider.dart';
import '../widgets/theme_selection_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final controller = SettingsScreenController(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Темная тема'),
            subtitle: const Text('Переключить на темный режим'),
            value: controller.isDarkMode(),
            onChanged: (value) => controller.setDarkMode(value),
            secondary: Icon(
              controller.isDarkMode()
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
          ),

          // Список выбора тем
          ListTile(
            title: const Text('Выбрать тему'),
            subtitle: Text('Текущая: ${controller.getCurrentTheme()}'),
            leading: const Icon(Icons.color_lens),
            onTap: () async {
              final selectedScheme = await showDialog<FlexScheme>(
                context: context,
                builder: (_) {
                  return ThemeSelectionDialog(
                    controller: controller,
                  );
                },
              );

              if (selectedScheme != null) {
                controller.setTheme(selectedScheme);
              }
            },
          ),

          const Divider(),

          ListTile(
            title: const Text('Использовать системную тему'),
            subtitle: const Text('Автоматически следовать настройкам системы'),
            leading: const Icon(Icons.settings_system_daydream),
            onTap: () => controller.useSystemTheme(),
          ),



          const Divider(),


        ],
      ),
    );
  }
}