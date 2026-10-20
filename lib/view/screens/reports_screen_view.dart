import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/bug_reports_controller.dart';
import '../../models/bug_report.dart';
import '../../services/device_info_service.dart';
import '../../themes/bsu_theme.dart';
import '../../utils/profanity_filter.dart';
import '../widgets/ripple_tap.dart';

/// Обратная связь: баг-репорт или пожелание.
///
/// Вместе с текстом к обращению прикладываются данные об устройстве
/// (модель, версия Android, сборка приложения) — об этом честно
/// предупреждаем прямо под полем ввода.
class ReportsScreenView extends StatefulWidget {
  const ReportsScreenView({super.key});

  @override
  State<ReportsScreenView> createState() => _ReportsScreenViewState();
}

class _ReportsScreenViewState extends State<ReportsScreenView> {
  final _text = TextEditingController();
  ReportKind _kind = ReportKind.bug;
  String? _error;
  bool _sending = false;
  DeviceInfo? _device;

  @override
  void initState() {
    super.initState();
    // Показываем, какие данные уйдут вместе с обращением, ещё до отправки.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final device = await DeviceInfoService().collect(screen: _screen);
      if (!mounted) return;
      setState(() => _device = device);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _screen {
    final size = MediaQuery.of(context).size;
    return '${size.width.round()}x${size.height.round()}';
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'Опишите подробнее — хотя бы 10 символов');
      return;
    }
    if (ProfanityFilter.contains(text)) {
      setState(() => _error = ProfanityFilter.message);
      return;
    }

    setState(() {
      _error = null;
      _sending = true;
    });

    final controller = context.read<BugReportsController>();
    final report = await controller.submit(
      kind: _kind,
      text: text,
      screen: _screen,
    );
    if (!mounted) return;

    _text.clear();
    setState(() => _sending = false);
    FocusScope.of(context).unfocus();

    await _share(report, controller);
  }

  /// Отправить обращение: системное «Поделиться» (Telegram, почта, …).
  /// Если поделиться не получилось — копируем текст в буфер.
  Future<void> _share(BugReport report, BugReportsController controller) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: report.asMessage(),
          subject: 'Медузка — ${report.kind.label}',
        ),
      );
      await controller.markSent(report.id);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: report.asMessage()));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Обращение сохранено — его видно в «Мои обращения»'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copy(BugReport report) async {
    await Clipboard.setData(ClipboardData(text: report.asMessage()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Скопировано — вставьте в Telegram или письмо'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = context.watch<BugReportsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Обратная связь'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Что случилось?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Баг — если что-то не работает. Пожелание — если чего-то '
            'не хватает.',
            style: TextStyle(fontSize: 13, color: scheme.outline),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in ReportKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  avatar: Icon(
                    kind == ReportKind.bug
                        ? Icons.bug_report_outlined
                        : Icons.lightbulb_outline,
                    size: 18,
                  ),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _kind == ReportKind.bug
                  ? 'Например: на вкладке «Расписание» не открывается пара, '
                      'приложение закрывается при поиске группы…'
                  : 'Например: хочу видеть расписание звонков и напоминание '
                      'о зачётной неделе…',
              border: const OutlineInputBorder(),
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          _DeviceCard(device: _device ?? (controller.reports.isEmpty
              ? null
              : controller.reports.first.device)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: RippleTap(
              borderRadius: 25,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Отправить отчёт'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (controller.reports.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Мои обращения',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${controller.reports.length}',
                  style: TextStyle(fontSize: 13, color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final report in controller.reports)
              _ReportCard(
                report: report,
                onCopy: () => _copy(report),
                onDelete: () => context
                    .read<BugReportsController>()
                    .remove(report.id),
              ),
          ],
        ],
      ),
    );
  }
}

/// Данные, которые уйдут вместе с обращением + предупреждение.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({this.device});

  final DeviceInfo? device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Данные об устройстве',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            device?.summary ??
                'Модель телефона, версия Android, размер экрана и сборка '
                    'приложения.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Эти данные автоматически отправятся вместе с обращением — '
                  'так проще понять, на каких устройствах происходит сбой. '
                  'Больше ничего приложение не собирает.',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onCopy,
    required this.onDelete,
  });

  final BugReport report;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  String get _date {
    final at = report.createdAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.day)}.${two(at.month)}.${at.year} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              report.kind == ReportKind.bug
                  ? Icons.bug_report_outlined
                  : Icons.lightbulb_outline,
              size: 18,
              color: report.kind == ReportKind.bug
                  ? scheme.error
                  : BsuColors.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_date · ${report.kind.label.toLowerCase()}'
                    '${report.sent ? ' · отправлено' : ''}',
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Скопировать',
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
            ),
            IconButton(
              tooltip: 'Удалить',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
