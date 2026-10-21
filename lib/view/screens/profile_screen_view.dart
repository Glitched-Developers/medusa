import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/badges_controller.dart';
import '../../controllers/help_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../models/user_badge.dart';
import '../../models/user_profile.dart';
import '../../utils/group_format.dart';
import '../../utils/profanity_filter.dart';
import '../transitions/fade_up_page_route.dart';
import '../widgets/badge_details_sheet.dart';
import '../widgets/badge_medal.dart';
import '../widgets/ripple_tap.dart';
import 'Initial_setup_screen_view.dart';

/// Профиль: аватар, имя, роль, рейтинг и значки.
///
/// Значки — как в Discord: витрина под именем и полный список с условиями.
/// Обычные выдаются за активность, эксклюзивные открываются кодом, который
/// передаёт команда Медузки.
class ProfileScreenView extends StatefulWidget {
  const ProfileScreenView({super.key});

  @override
  State<ProfileScreenView> createState() => _ProfileScreenViewState();
}

class _ProfileScreenViewState extends State<ProfileScreenView> {
  final _name = TextEditingController();
  final _about = TextEditingController();

  String _role = 'student';
  String _avatar = '🌿';
  String? _nameError;
  String? _aboutError;
  bool _ready = false;

  /// Набор аватаров: картинки грузить неоткуда, а эмодзи читается сразу.
  static const List<String> _avatars = <String>[
    '🌿',
    '🎓',
    '📚',
    '🧑‍🎓',
    '👩‍🎓',
    '🧑‍🏫',
    '🐢',
    '🦊',
    '🐳',
    '🌟',
    '☕',
    '🎧',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final profile = context.read<ProfileController>().profile;
    _name.text = profile.name;
    _about.text = profile.about;
    _role = profile.role;
    _avatar = profile.avatar;
  }

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final about = _about.text.trim();

    setState(() {
      _nameError =
          name.isEmpty
              ? 'Без имени профиль не сохранить'
              : (ProfanityFilter.contains(name)
                  ? ProfanityFilter.message
                  : null);
      _aboutError =
          ProfanityFilter.contains(about) ? ProfanityFilter.message : null;
    });
    if (_nameError != null || _aboutError != null) return;

    final profile = UserProfile(
      name: name,
      role: _role,
      avatar: _avatar,
      about: about,
    );
    final controller = context.read<ProfileController>();
    final help = context.read<HelpController>();
    final badges = context.read<BadgesController>();
    final messenger = ScaffoldMessenger.of(context);

    await controller.save(profile);
    // Раздел «Помощь» подписывается тем же именем и ролью.
    await help.setProfile(name: name, role: _role);

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    // За сохранение профиля может прилететь значок — покажем это сразу.
    final fresh = badges.takeJustEarned();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          fresh.isEmpty
              ? 'Профиль сохранён'
              : 'Новый значок: ${fresh.map((badge) => badge.title).join(', ')}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _AvatarSheet(avatars: _avatars, current: _avatar),
    );
    if (picked != null && mounted) setState(() => _avatar = picked);
  }

  /// Эксклюзивные значки открываются кодом.
  Future<void> _enterCode(BadgesController badges) async {
    final textController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Код значка'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Коды эксклюзивных значков выдаёт команда Медузки.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Например, MEDUZA-DEV',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted:
                      (value) => Navigator.of(dialogContext).pop(value.trim()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(
                      dialogContext,
                    ).pop(textController.text.trim()),
                child: const Text('Активировать'),
              ),
            ],
          ),
    );
    textController.dispose();

    if (code == null || code.isEmpty || !mounted) return;
    final badge = await badges.redeem(code);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (badge == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Код не подошёл')));
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Значок «${badge.title}» открыт')),
    );
  }

  Future<void> _showBadge(UserBadge badge, bool earned) {
    return showBadgeDetails(context, badge, earned: earned);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final group = context.watch<SettingsController>().selectedGroup;
    final badges = context.watch<BadgesController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Сохранить',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _header(context, badges),
          const SizedBox(height: 12),
          _badgesSection(context, badges),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Имя и фамилия',
              hintText: 'Иванов Иван',
              border: const OutlineInputBorder(),
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Кто вы', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Студент'),
                avatar: const Icon(Icons.person_outline, size: 18),
                selected: _role == 'student',
                onSelected: (_) => setState(() => _role = 'student'),
              ),
              ChoiceChip(
                label: const Text('Преподаватель'),
                avatar: const Icon(Icons.school_outlined, size: 18),
                selected: _role == 'teacher',
                onSelected: (_) => setState(() => _role = 'teacher'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(
                group == null
                    ? 'Группа не выбрана'
                    : 'Группа ${formatGroupNumber(group)}',
              ),
              subtitle: const Text('Расписание открывается для неё'),
              trailing: RippleTap(
                color: scheme.primary.withValues(alpha: 0.18),
                borderRadius: 20,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      FadeUpPageRoute(page: const InitialSetupScreenView()),
                    );
                  },
                  child: Text(group == null ? 'Выбрать' : 'Сменить'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _about,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'О себе (необязательно)',
              hintText: '3 курс, ФИТиЕС, люблю кофе',
              border: const OutlineInputBorder(),
              errorText: _aboutError,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: scheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Профиль и значки хранятся только на этом устройстве',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: RippleTap(
              borderRadius: 25,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Сохранить профиль'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Шапка профиля: аватар, имя, уровень и полученные значки.
  Widget _header(BuildContext context, BadgesController badges) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final name = _name.text.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: <Color>[
            scheme.primaryContainer.withValues(alpha: 0.85),
            scheme.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _pickAvatar,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.surface,
                    child: Text(_avatar, style: const TextStyle(fontSize: 30)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Без имени' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill(
                          context,
                          icon:
                              _role == 'teacher'
                                  ? Icons.school_outlined
                                  : Icons.person_outline,
                          label:
                              _role == 'teacher' ? 'Преподаватель' : 'Студент',
                        ),
                        _pill(
                          context,
                          icon: Icons.military_tech_outlined,
                          label: 'Ур. ${badges.level} · ${badges.levelName}',
                          highlighted: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${badges.points} очков',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                'до следующего уровня: ${badges.toNextLevel}',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: badges.progress,
              minHeight: 6,
              backgroundColor: scheme.surface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          _showcaseRow(context, badges),
        ],
      ),
    );
  }

  /// Витрина: значки, которые человек выбрал показывать.
  ///
  /// Порядок и состав выбираются вручную — кнопка «Изменить».
  Widget _showcaseRow(BuildContext context, BadgesController badges) {
    final scheme = Theme.of(context).colorScheme;
    final shown = badges.showcasedBadges;
    if (badges.earnedBadges.isEmpty) {
      return Text(
        'Значки появятся за активность: помощь, избранное, профиль',
        style: TextStyle(fontSize: 12, color: scheme.outline),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 13, color: scheme.outline),
            const SizedBox(width: 5),
            Text(
              'Витрина',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: scheme.outline,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${shown.length} из ${BadgesController.showcaseLimit}',
              style: TextStyle(fontSize: 10, color: scheme.outline),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickShowcase(badges),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 14, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Изменить',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (shown.isEmpty)
          GestureDetector(
            onTap: () => _pickShowcase(badges),
            child: Text(
              'Витрина пуста — выберите, что показать в профиле',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final badge in shown)
                GestureDetector(
                  onTap: () => _showBadge(badge, true),
                  child: BadgeMedal(badge: badge, size: 42),
                ),
            ],
          ),
      ],
    );
  }

  /// Выбор значков на витрину: только полученные, максимум пять.
  Future<void> _pickShowcase(BadgesController badges) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final earned = badges.earnedBadges;
            final shown = badges.showcasedBadges.length;

            Future<void> toggle(UserBadge badge) async {
              final messenger = ScaffoldMessenger.of(context);
              final message = await badges.toggleShowcase(badge.id);
              if (!mounted) return;
              setSheetState(() {});
              if (message == null) return;
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(message),
                    duration: const Duration(seconds: 2),
                  ),
                );
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Витрина профиля',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$shown из ${BadgesController.showcaseLimit}',
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нажмите на значок, чтобы показать его в профиле. '
                      'Эксклюзивные значки переливаются.',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                    const SizedBox(height: 14),
                    if (earned.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Сначала получите хотя бы один значок',
                          style: TextStyle(fontSize: 13, color: scheme.outline),
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 12,
                            children: [
                              for (final badge in earned)
                                _ShowcaseOption(
                                  badge: badge,
                                  selected: badges.isShowcased(badge.id),
                                  onTap: () => toggle(badge),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            highlighted
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.surface.withValues(alpha: 0.7),
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

  /// Полная витрина значков: полученные цветные, остальные под замком.
  Widget _badgesSection(BuildContext context, BadgesController badges) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final earned = badges.earnedBadges.length;
    final total = BadgeCatalog.all.length;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Значки', style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Text(
                  '$earned из $total',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _enterCode(badges),
                  icon: const Icon(Icons.key_outlined, size: 16),
                  label: const Text('Код'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              runSpacing: 10,
              children: [
                for (final badge in BadgeCatalog.all)
                  _BadgeTile(
                    badge: badge,
                    earned: badges.has(badge.id),
                    onTap: () => _showBadge(badge, badges.has(badge.id)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Значок в списке выбора витрины: выбранный обведён, остальные просто лежат.
class _ShowcaseOption extends StatelessWidget {
  const _ShowcaseOption({
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final UserBadge badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? scheme.primary.withValues(alpha: 0.10) : null,
          border: Border.all(
            color:
                selected
                    ? scheme.primary.withValues(alpha: 0.7)
                    : scheme.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                BadgeMedal(badge: badge, size: 44, animate: badge.isExclusive),
                if (selected)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Значок с подписью на витрине профиля.
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.earned,
    required this.onTap,
  });

  final UserBadge badge;
  final bool earned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              BadgeMedal(badge: badge, earned: earned, size: 42),
              const SizedBox(height: 6),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.15,
                  color: earned ? null : scheme.outline,
                  fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Выбор аватара-эмодзи.
class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet({required this.avatars, required this.current});

  final List<String> avatars;
  final String current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Аватар', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final avatar in avatars)
                InkWell(
                  onTap: () => Navigator.of(context).pop(avatar),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        avatar == current
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                    child: Text(avatar, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
