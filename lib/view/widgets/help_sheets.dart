import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/help_controller.dart';
import '../../models/help_request.dart';
import '../../themes/bsu_theme.dart';
import '../../utils/help_helpers.dart';
import '../../utils/profanity_filter.dart';
import 'help_status_chip.dart';
import 'ripple_tap.dart';

/// ---------- Профиль: как подписываться и в какой роли ----------

Future<void> showHelpProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _HelpProfileSheet(),
  );
}

class _HelpProfileSheet extends StatefulWidget {
  const _HelpProfileSheet();

  @override
  State<_HelpProfileSheet> createState() => _HelpProfileSheetState();
}

class _HelpProfileSheetState extends State<_HelpProfileSheet> {
  late final TextEditingController _name;
  String _role = 'student';
  bool _nameBad = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final help = context.read<HelpController>();
    _name.text = help.userName;
    _role = help.userRole;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // Оскорбительные слова в имени не пропускаем.
    if (ProfanityFilter.contains(name)) {
      setState(() => _nameBad = true);
      return;
    }
    setState(() => _nameBad = false);
    final help = context.read<HelpController>();
    final messenger = ScaffoldMessenger.of(context);
    await help.setProfile(name: name, role: _role);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Вы: $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Кто вы?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Имя нужно, чтобы студенты видели, кто просит помощь, '
              'а преподаватель — кто откликнулся.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Имя и фамилия',
                hintText: 'Иванов Иван',
                border: const OutlineInputBorder(),
                errorText: _nameBad ? ProfanityFilter.message : null,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Я студент'),
                  avatar: const Icon(Icons.person_outline, size: 18),
                  selected: _role == 'student',
                  onSelected: (_) => setState(() => _role = 'student'),
                ),
                ChoiceChip(
                  label: const Text('Я преподаватель'),
                  avatar: const Icon(Icons.school_outlined, size: 18),
                  selected: _role == 'teacher',
                  onSelected: (_) => setState(() => _role = 'teacher'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: RippleTap(
                borderRadius: 25,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- Взять задачу / сменить свой статус ----------

Future<void> showTakeTaskSheet(BuildContext context, String requestId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TakeTaskSheet(requestId: requestId),
  );
}

class _TakeTaskSheet extends StatefulWidget {
  const _TakeTaskSheet({required this.requestId});

  final String requestId;

  @override
  State<_TakeTaskSheet> createState() => _TakeTaskSheetState();
}

class _TakeTaskSheetState extends State<_TakeTaskSheet> {
  late final TextEditingController _name;
  late final TextEditingController _custom;
  String _statusKey = HelpStatusOption.presets.first.key;
  bool _nameMissing = false;
  bool _customMissing = false;
  bool _nameBad = false;
  bool _customBad = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _custom = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final help = context.read<HelpController>();
    _name.text = help.userName;
    final request = help.requestById(widget.requestId);
    final mine = request == null ? null : help.myVolunteer(request);
    if (mine != null) {
      _statusKey = mine.statusKey;
      if (mine.statusKey == HelpStatusOption.customKey) {
        _custom.text = mine.statusText;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final help = context.read<HelpController>();
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final customText = _custom.text.trim();
    setState(() {
      _nameMissing = name.isEmpty;
      _customMissing =
          _statusKey == HelpStatusOption.customKey && customText.isEmpty;
      // Отклик увидят все — нецензурные слова не пропускаем.
      _nameBad = ProfanityFilter.contains(name);
      _customBad = ProfanityFilter.contains(customText);
    });
    if (_nameMissing || _customMissing) return;
    if (_nameBad || _customBad) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Уберите недопустимые слова из отклика'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final request = help.requestById(widget.requestId);
    final wasTaken = request != null && help.myVolunteer(request) != null;

    if (name != help.userName) {
      await help.setProfile(name: name, role: help.userRole);
    }
    final taken = await help.takeTask(
      widget.requestId,
      statusKey: _statusKey,
      statusText:
          _statusKey == HelpStatusOption.customKey ? customText : '',
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          !taken
              ? 'Все места уже заняты — задачу взяли без вас'
              : (wasTaken ? 'Статус обновлён' : 'Вы взяли задачу 🙂'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final help = context.watch<HelpController>();
    final request = help.requestById(widget.requestId);
    final mine = request == null ? null : help.myVolunteer(request);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine == null ? 'Взять задачу' : 'Мой статус',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (request != null) ...[
              const SizedBox(height: 4),
              Text(
                request.title,
                style: TextStyle(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Ваше имя',
                hintText: 'Петрова Анна',
                border: const OutlineInputBorder(),
                errorText: _nameBad
                    ? ProfanityFilter.message
                    : (_nameMissing ? 'Без имени не подписать отклик' : null),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Ваш статус', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in HelpStatusOption.presets)
                  ChoiceChip(
                    label: Text(option.label),
                    avatar: Icon(helpStatusIcon(option.key), size: 18),
                    selected: _statusKey == option.key,
                    onSelected: (_) =>
                        setState(() => _statusKey = option.key),
                  ),
                ChoiceChip(
                  label: const Text('Свой вариант'),
                  avatar: const Icon(Icons.edit_note, size: 18),
                  selected: _statusKey == HelpStatusOption.customKey,
                  onSelected: (_) => setState(
                    () => _statusKey = HelpStatusOption.customKey,
                  ),
                ),
              ],
            ),
            if (_statusKey == HelpStatusOption.customKey) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _custom,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Свой статус',
                  hintText: 'Приду через полчаса',
                  border: const OutlineInputBorder(),
                  errorText:
                      _customBad ? ProfanityFilter.message : (_customMissing ? 'Напишите статус' : null),
                ),
              ),
            ],
            if (request != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.groups_outlined, size: 18, color: scheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    'Уже взялись: ${request.takenCount} из ${request.needed}',
                    style: TextStyle(color: scheme.outline),
                  ),
                ],
              ),
            ],
            if (request != null && mine == null && request.isFull) ...[
              const SizedBox(height: 12),
              Text(
                'Все места заняты — взять задачу уже нельзя',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: RippleTap(
                borderRadius: 25,
                child: FilledButton.icon(
                  onPressed: (request != null &&
                          mine == null &&
                          request.isFull)
                      ? null
                      : _submit,
                  icon: const Icon(Icons.handshake_outlined),
                  label: Text(
                    request != null && mine == null && request.isFull
                        ? 'Мест нет'
                        : (mine == null ? 'Взять задачу' : 'Обновить статус'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- Новый запрос помощи (для преподавателя) ----------

Future<void> showCreateHelpRequestSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CreateHelpRequestSheet(),
  );
}

class _CreateHelpRequestSheet extends StatefulWidget {
  const _CreateHelpRequestSheet();

  @override
  State<_CreateHelpRequestSheet> createState() =>
      _CreateHelpRequestSheetState();
}

class _CreateHelpRequestSheetState extends State<_CreateHelpRequestSheet> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _time = TextEditingController();
  HelpCategory _category = HelpCategory.moving;
  int _needed = 2;
  bool _titleMissing = false;
  bool _authorMissing = false;
  bool _titleBad = false;
  bool _descBad = false;
  bool _authorBad = false;
  bool _placeBad = false;
  bool _timeBad = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _author.text = context.read<HelpController>().userName;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    _place.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final help = context.read<HelpController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _titleMissing = _title.text.trim().isEmpty;
      _authorMissing = _author.text.trim().isEmpty;
      // Запрос увидят все студенты — нецензурные слова не пропускаем.
      _titleBad = ProfanityFilter.contains(_title.text);
      _descBad = ProfanityFilter.contains(_description.text);
      _authorBad = ProfanityFilter.contains(_author.text);
      _placeBad = ProfanityFilter.contains(_place.text);
      _timeBad = ProfanityFilter.contains(_time.text);
    });
    if (_titleMissing || _authorMissing) return;
    if (_titleBad || _descBad || _authorBad || _placeBad || _timeBad) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Уберите недопустимые слова из запроса'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await help.createRequest(
      title: _title.text,
      authorName: _author.text,
      category: _category,
      description: _description.text,
      place: _place.text,
      timeText: _time.text,
      needed: _needed,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Запрос опубликован — студенты увидят его сразу'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Новый запрос помощи',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Расскажите, что нужно сделать. Студенты увидят запрос и '
              'подпишутся, указав свой статус.',
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Что нужно сделать',
                hintText: 'Перетащить вещи в ауд. 213',
                border: const OutlineInputBorder(),
                errorText: _titleBad
                    ? ProfanityFilter.message
                    : (_titleMissing ? 'Опишите задачу' : null),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Подробности (необязательно)',
                border: const OutlineInputBorder(),
                errorText: _descBad ? ProfanityFilter.message : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _place,
                    decoration: InputDecoration(
                      labelText: 'Где',
                      hintText: 'корпус 4, ауд. 118',
                      border: const OutlineInputBorder(),
                      errorText: _placeBad ? ProfanityFilter.message : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _time,
                    decoration: InputDecoration(
                      labelText: 'Когда',
                      hintText: 'сегодня до 16:00',
                      border: const OutlineInputBorder(),
                      errorText: _timeBad ? ProfanityFilter.message : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Категория', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in HelpCategory.values)
                  ChoiceChip(
                    label: Text(category.label),
                    avatar: Icon(helpCategoryIcon(category), size: 18),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.groups_outlined, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Сколько студентов нужно')),
                IconButton(
                  tooltip: 'Меньше',
                  onPressed: _needed > 1
                      ? () => setState(() => _needed -= 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_needed',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  tooltip: 'Больше',
                  onPressed: _needed < 20
                      ? () => setState(() => _needed += 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _author,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Кто просит',
                border: const OutlineInputBorder(),
                errorText: _authorBad
                    ? ProfanityFilter.message
                    : (_authorMissing ? 'Укажите имя' : null),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: RippleTap(
                borderRadius: 25,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Опубликовать'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- Подробности запроса и список откликнувшихся ----------

Future<void> showHelpRequestDetailsSheet(BuildContext context, String requestId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HelpRequestDetailsSheet(requestId: requestId),
  );
}

class _HelpRequestDetailsSheet extends StatelessWidget {
  const _HelpRequestDetailsSheet({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final help = context.watch<HelpController>();
    final request = help.requestById(requestId);
    final scheme = Theme.of(context).colorScheme;
    if (request == null) return const SizedBox.shrink();

    final mine = help.myVolunteer(request);
    final isAuthor = request.authorName == help.userName;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    helpCategoryIcon(request.category),
                    color: BsuColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        request.isDemo
                            ? '${request.category.label} · пример запроса'
                            : request.category.label,
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                if (request.closed)
                  Chip(
                    label: const Text('Закрыт'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (request.description.isNotEmpty) ...[
              Text(request.description),
              const SizedBox(height: 12),
            ],
            _InfoRow(icon: Icons.person_outline, text: 'Просит: ${request.authorName}'),
            if (request.place.isNotEmpty)
              _InfoRow(icon: Icons.place_outlined, text: request.place),
            if (request.timeText.isNotEmpty)
              _InfoRow(icon: Icons.schedule, text: request.timeText),
            _InfoRow(
              icon: Icons.groups_outlined,
              text: 'Взялись: ${request.takenCount} из ${request.needed}',
            ),
            _InfoRow(
              icon: Icons.history,
              text: 'Опубликован ${helpTimeAgo(request.createdAt)}',
            ),
            const SizedBox(height: 16),
            Text(
              request.volunteers.isEmpty
                  ? 'Пока никто не откликнулся'
                  : 'Кто взялся (${request.takenCount})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final volunteer in request.volunteers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        helpInitials(volunteer.name),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            volunteer.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            helpTimeAgo(volunteer.at),
                            style: TextStyle(fontSize: 11, color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                    HelpStatusChip(volunteer: volunteer),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (!request.closed && (mine != null || !request.isFull))
              SizedBox(
                width: double.infinity,
                height: 48,
                child: RippleTap(
                  borderRadius: 24,
                  child: FilledButton.icon(
                    onPressed: () => showTakeTaskSheet(context, request.id),
                    icon: Icon(
                      mine == null ? Icons.handshake_outlined : Icons.sync,
                    ),
                    label: Text(
                      mine == null ? 'Взять задачу' : 'Изменить свой статус',
                    ),
                  ),
                ),
              )
            else if (!request.closed && request.isFull)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: BsuColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 18, color: BsuColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Все места заняты: ${request.takenCount} '
                        'из ${request.needed}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BsuColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (mine != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: RippleTap(
                  color: scheme.primary.withValues(alpha: 0.18),
                  borderRadius: 22,
                  child: TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await help.leaveTask(request.id);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Вы отказались от задачи'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Отказаться от задачи'),
                  ),
                ),
              ),
            ],
            if (isAuthor || request.isDemo) ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (isAuthor)
                    Expanded(
                      child: RippleTap(
                        color: scheme.primary.withValues(alpha: 0.2),
                        borderRadius: 22,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              help.setClosed(request.id, !request.closed),
                          icon: Icon(
                            request.closed
                                ? Icons.lock_open
                                : Icons.lock_outline,
                          ),
                          label: Text(
                              request.closed ? 'Открыть снова' : 'Закрыть'),
                        ),
                      ),
                    ),
                  if (isAuthor) const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Удалить запрос',
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await help.deleteRequest(request.id);
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Запрос удалён'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: scheme.outline))),
        ],
      ),
    );
  }
}
