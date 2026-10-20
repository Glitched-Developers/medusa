import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/notifications_controller.dart';
import '../../services/notifications_settings_service.dart';

/// Настройки системы оповещений.
///
/// Отдельный экран, чтобы не засорять общие настройки: здесь главный
/// выключатель, напоминания о парах (с настраиваемым временем), изменения
/// расписания и новые запросы помощи.
class NotificationsScreenView extends StatefulWidget {
  const NotificationsScreenView({super.key});

  @override
  State<NotificationsScreenView> createState() =>
      _NotificationsScreenViewState();
}

class _NotificationsScreenViewState extends State<NotificationsScreenView> {
  /// Разрешены ли уведомления в системе (Android 13+ спрашивает отдельно).
  bool? _permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPermission());
  }

  Future<void> _refreshPermission() async {
    if (!mounted) return;
    final granted =
        await context.read<NotificationsController>().hasPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
  }

  Future<void> _askPermission() async {
    final granted =
        await context.read<NotificationsController>().requestPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Разрешите уведомления в настройках телефона'),
        ),
      );
    }
  }

  /// Своё время напоминания: 1–60 минут.
  Future<void> _pickCustomMinutes(NotificationsController controller) async {
    final textController = TextEditingController(
      text: '${controller.settings.minutesBefore}',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('За сколько минут?'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Минут до начала пары',
            helperText: 'От 1 до 60',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(textController.text.trim());
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result == null) return;
    await controller.setMinutesBefore(result.clamp(1, 60));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оповещения'),
        centerTitle: true,
      ),
      body: Consumer<NotificationsController>(
        builder: (context, controller, _) {
          final settings = controller.settings;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SummaryCard(enabled: settings.enabled),
              const SizedBox(height: 12),
              if (_permission == false) ...[
                _PermissionCard(
                  onAllow: _askPermission,
                  onOpenSettings: () => _openSystemSettings(context),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        settings.enabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                      ),
                      title: const Text('Оповещения'),
                      subtitle: Text(
                        settings.enabled
                            ? 'Включены'
                            : 'Полностью выключены',
                      ),
                      value: settings.enabled,
                      onChanged: (value) async {
                        await controller.setEnabled(value);
                        await _refreshPermission();
                      },
                    ),
                    if (settings.enabled) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.schedule_outlined),
                        title: const Text('Напоминать о паре'),
                        subtitle:
                            Text('За ${settings.minutesBefore} мин до начала'),
                        value: settings.lessonReminder,
                        onChanged: controller.setLessonReminder,
                      ),
                      if (settings.lessonReminder)
                        _minutesPicker(context, controller, settings),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.edit_calendar_outlined),
                        title: const Text('Изменения в расписании'),
                        subtitle:
                            const Text('Когда пары поменялись на сайте'),
                        value: settings.scheduleChanges,
                        onChanged: controller.setScheduleChanges,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary:
                            const Icon(Icons.volunteer_activism_outlined),
                        title: const Text('Новые запросы помощи'),
                        subtitle: const Text('От преподавателей'),
                        value: settings.helpRequests,
                        onChanged: controller.setHelpRequests,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_none),
                        title: const Text('Проверить оповещения'),
                        subtitle: const Text('Показать тестовое уведомление'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await controller.sendTest();
                          await _refreshPermission();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Напоминания о парах планируются на две недели вперёд и '
                'обновляются при каждой загрузке расписания. Изменения '
                'расписания проверяются при запуске и обновлении, новые '
                'запросы помощи — когда подгружается список запросов.',
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _minutesPicker(
    BuildContext context,
    NotificationsController controller,
    NotificationSettings settings,
  ) {
    final scheme = Theme.of(context).colorScheme;
    const presets = <int>[5, 10, 15, 20, 30];
    final custom = !presets.contains(settings.minutesBefore);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Время напоминания',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in presets)
                ChoiceChip(
                  label: Text('$minutes мин'),
                  selected: settings.minutesBefore == minutes,
                  onSelected: (_) => controller.setMinutesBefore(minutes),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.edit, size: 16),
                label: Text(custom ? '${settings.minutesBefore} мин' : 'Своё'),
                selected: custom,
                onSelected: (_) => _pickCustomMinutes(controller),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openSystemSettings(BuildContext context) async {
    // Отдельного плагина настроек нет — подсказываем путь в системе.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Откройте «Настройки → Приложения → Медузка → Уведомления»',
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            enabled
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
            size: 32,
            color: enabled ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Оповещения включены' : 'Оповещения выключены',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'Напомним о паре и сообщим, если что-то поменялось'
                      : 'Ничего не будем присылать, пока не включите',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.onAllow,
    required this.onOpenSettings,
  });

  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_paused_outlined,
                  color: scheme.error, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Телефон не показывает уведомления приложения',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Разрешите уведомления — иначе напоминания не придут.',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: onAllow,
                child: const Text('Разрешить'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('Настройки'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
