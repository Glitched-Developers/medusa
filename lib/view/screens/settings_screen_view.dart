import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/notifications_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/ui/settings_screen_controller.dart';
import '../../themes/provider/theme_provider.dart';
import '../../utils/theme_mapper.dart';
import '../screens/notifications_screen_view.dart';
import '../screens/profile_screen_view.dart';
import '../screens/reports_screen_view.dart';
import '../transitions/fade_up_page_route.dart';
import '../widgets/theme_reveal.dart';
import '../widgets/theme_selection_dialog.dart';

class SettingsScreen extends StatelessWidget {
  /// Метка сборки передаётся через --dart-define=APP_BUILD=...
  /// и помогает понять, какая версия JS крутится в браузере.
  static const String _buildTag = String.fromEnvironment('APP_BUILD');

  /// Плитка переключателя темы — чтобы знать, из какой точки «расходится»
  /// круг при смене темы.
  static final GlobalKey _themeSwitchKey = GlobalKey();
  static final GlobalKey _themePickKey = GlobalKey();
  static final GlobalKey _systemThemeKey = GlobalKey();

  const SettingsScreen({Key? key}) : super(key: key);

  /// «неделю», «месяц», «90 дней» — подпись для срока хранения.
  static String _retentionLabel(int days) {
    if (days == 7) return 'неделю';
    if (days == 30) return 'месяц';
    if (days == 90) return '3 месяца';
    if (days == 180) return 'полгода';
    if (days == 365) return 'год';
    return '$days ${_daysWord(days)}';
  }

  static String _daysWord(int days) {
    final mod100 = days % 100;
    final mod10 = days % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  /// Выбор срока: неделя / месяц / 3 месяца / своё число дней.
  Future<void> _pickRetention(
    BuildContext context,
    SettingsController settings,
  ) async {
    final current = settings.offlineRetentionDays;
    final choice = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        Widget option(int days, String title, String subtitle) {
          final selected = days == current;
          return ListTile(
            leading: Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(dialogContext).colorScheme.primary
                  : null,
            ),
            title: Text(title),
            subtitle: Text(subtitle),
            onTap: () => Navigator.of(dialogContext).pop(days),
          );
        }

        return SimpleDialog(
          title: const Text('Сколько хранить расписание'),
          children: [
            option(7, 'Неделя', '7 дней — минимум места'),
            option(30, 'Месяц', '30 дней — по умолчанию'),
            option(90, 'Три месяца', '90 дней'),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Своё количество дней'),
              subtitle: Text('Сейчас: $current'),
              onTap: () async {
                final days = await _askDays(dialogContext, current);
                if (days != null && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(days);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Text(
                'Снимок расписания лежит на телефоне: без интернета его '
                'можно открыть, выйти из приложения и зайти снова. '
                'Когда сеть появится, расписание обновится само.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(dialogContext).colorScheme.outline,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (choice == null) return;
    await settings.setOfflineRetentionDays(choice);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Расписание хранится ${_retentionLabel(choice)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Своё число дней: 1–365.
  Future<int?> _askDays(BuildContext context, int current) async {
    final controller = TextEditingController(text: '$current');
    final days = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Сколько дней хранить'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Дней (1–365)',
                errorText: error,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  if (value == null || value < 1 || value > 365) {
                    setState(() => error = 'Введите число от 1 до 365');
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Готово'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    return days;
  }

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
            key: _themeSwitchKey,
            title: const Text('Темная тема'),
            subtitle: const Text('Переключить на темный режим'),
            value: controller.isDarkMode(),
            // Смену темы закрываем «растущим кругом» от самого переключателя.
            onChanged: (value) {
              final anchor = _themeSwitchKey.currentContext
                  ?.findRenderObject();
              animateThemeSwitch(
                context: context,
                origin: anchorOrigin(
                  context,
                  anchor,
                  fromRight: 34,
                ),
                switchTheme: () => controller.setDarkMode(value),
              );
            },
            secondary: Icon(
              controller.isDarkMode()
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
          ),

          // Список выбора тем
          ListTile(
            key: _themePickKey,
            title: const Text('Выбрать тему'),
            subtitle: Text('Текущая: ${controller.getCurrentTheme()}'),
            leading: const Icon(Icons.color_lens),
            onTap: () async {
              final selectedScheme = await showDialog<String>(
                context: context,
                builder: (_) {
                  return ThemeSelectionDialog(
                    controller: controller,
                  );
                },
              );

              if (selectedScheme != null && context.mounted) {
                // Новая схема тоже «раскрывается» кругом из этой плитки.
                animateThemeSwitch(
                  context: context,
                  origin: anchorOrigin(
                    context,
                    _themePickKey.currentContext?.findRenderObject(),
                  ),
                  switchTheme: () => controller.setTheme(selectedScheme),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Тема: ${ThemeMapper.getDisplayNameFor(selectedScheme)}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),

          const Divider(),

          ListTile(
            key: _systemThemeKey,
            title: const Text('Использовать системную тему'),
            subtitle: const Text('Автоматически следовать настройкам системы'),
            leading: const Icon(Icons.settings_system_daydream),
            onTap: () => animateThemeSwitch(
              context: context,
              origin: anchorOrigin(
                context,
                _systemThemeKey.currentContext?.findRenderObject(),
              ),
              switchTheme: controller.useSystemTheme,
            ),
          ),



          const Divider(),

          // Профиль необязательный, но с ним удобнее: имя подставляется
          // в запросы помощи, а аватар виден на стартовом экране.
          Consumer<ProfileController>(
            builder: (context, profile, _) {
              final me = profile.profile;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(me.avatar),
                ),
                title: Text(me.hasProfile ? me.name : 'Профиль'),
                subtitle: Text(
                  me.hasProfile
                      ? (me.isTeacher ? 'Преподаватель' : 'Студент')
                      : 'Создать профиль — это необязательно',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  FadeUpPageRoute(page: const ProfileScreenView()),
                ),
              );
            },
          ),

          const Divider(),

          // Оповещения живут на отдельном экране: настроек там много,
          // и в общем списке они бы занимали пол-экрана.
          Consumer<NotificationsController>(
            builder: (context, notifications, _) {
              final settings = notifications.settings;
              final details = <String>[
                if (settings.lessonReminder)
                  'за ${settings.minutesBefore} мин до пары',
                if (settings.scheduleChanges) 'изменения расписания',
                if (settings.helpRequests) 'запросы помощи',
              ];
              return ListTile(
                leading: Icon(
                  settings.enabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: const Text('Оповещения'),
                subtitle: Text(
                  !settings.enabled
                      ? 'Выключены'
                      : details.isEmpty
                          ? 'Включены'
                          : details.join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  FadeUpPageRoute(page: const NotificationsScreenView()),
                ),
              );
            },
          ),

          const Divider(),

          // Сколько расписание живёт на телефоне.
          Consumer<SettingsController>(
            builder: (context, settings, _) {
              final days = settings.offlineRetentionDays;
              return ListTile(
                leading: const Icon(Icons.offline_pin_outlined),
                title: const Text('Расписание без интернета'),
                subtitle: Text(
                  'Хранить ${_retentionLabel(days)} — расписание откроется '
                  'даже без сети',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickRetention(context, settings),
              );
            },
          ),

          const Divider(),

          // Обратная связь: баг-репорт или пожелание.
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Сообщить о проблеме'),
            subtitle: const Text('Баги и пожелания — с данными об устройстве'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              FadeUpPageRoute(page: const ReportsScreenView()),
            ),
          ),

          const Divider(),

          if (_buildTag.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text(
                  'Сборка $_buildTag',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),


        ],
      ),
    );
  }
}