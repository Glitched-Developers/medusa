// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/provider/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Получаем текущую тему из провайдера
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Опция переключения темы
          SwitchListTile(
            title: const Text('Темная тема'),
            subtitle: const Text('Переключить на темный режим'),
            value: themeProvider.isDarkMode,
            onChanged: (value) => themeProvider.setDarkMode(value),
            secondary: Icon(
              themeProvider.isDarkMode
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
          ),

          const Divider(),

          // Опция использования системной темы
          ListTile(
            title: const Text('Использовать системную тему'),
            subtitle: const Text('Автоматически следовать настройкам системы'),
            leading: const Icon(Icons.settings_system_daydream),
            onTap: () => themeProvider.useSystemTheme(),
          ),
        ],
      ),
    );
  }
}