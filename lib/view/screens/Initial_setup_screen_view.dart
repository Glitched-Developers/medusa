import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medusa/view/screens/auditorium_schedule_screen.dart';
import 'package:medusa/view/screens/help_screen_view.dart';
import 'package:medusa/view/screens/profile_screen_view.dart';
import 'package:medusa/view/screens/schedule_screen_view.dart';
import 'package:medusa/view/screens/settings_screen_view.dart';
import 'package:medusa/view/screens/teacher_schedule_screen.dart';
import 'package:medusa/view/transitions/fade_up_page_route.dart';
import 'package:provider/provider.dart';

import '../../controllers/favorites_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../models/auditorium.dart';
import '../../models/favorite_entry.dart';
import '../../services/auditorium_index_service.dart';
import '../../services/bsu_api_service.dart';
import '../../services/group_index_service.dart';
import '../widgets/border_beam.dart';
import '../widgets/light_rays.dart';
import '../widgets/ripple_background.dart';
import '../widgets/ripple_tap.dart';
import '../widgets/salute_overlay.dart';

class InitialSetupScreenView extends StatefulWidget {
  const InitialSetupScreenView({super.key});

  @override
  State<InitialSetupScreenView> createState() => _InitialSetupScreenViewState();
}

class _InitialSetupScreenViewState extends State<InitialSetupScreenView> {
  final _groupController = TextEditingController();
  String? _error;
  bool _loading = false;

  /// Подсказки поиска: группы и преподаватели с сайта.
  List<ScheduleSearchEntry> _suggestions = [];
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Полный список групп качается в фоне: он нужен, чтобы по неполному
    // номеру («9000») находились все группы, а не только десять с сайта.
    // Список аудиторий — для поиска по кабинету.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GroupIndexService>().load();
      context.read<AuditoriumIndexService>().load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _groupController.dispose();
    super.dispose();
  }

  /// Старт: группа вводится цифрами или выбирается из подсказок поиска.
  Future<void> _start() async {
    final group = int.tryParse(_groupController.text.trim());
    if (group == null || group <= 0) {
      setState(() => _error = 'Введите номер группы цифрами');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });

    final settings = context.read<SettingsController>();
    final schedule = context.read<ScheduleController>();

    await settings.setSelectedGroup(group);
    await schedule.loadSchedule(group);

    if (!mounted) return;

    if (schedule.error != null) {
      setState(() {
        _loading = false;
        // Ошибка не блокирует: расписание можно догрузить на следующем экране
        _error = schedule.error!;
      });
      return;
    }

    // Группа найдена и расписание загрузилось — празднуем!
    showSalute(context);

    Navigator.of(context).pushReplacement(
      FadeUpPageRoute(page: const ScheduleScreenView()),
    );
  }

  /// Выбор группы из подсказок — сразу запускаем.
  Future<void> _selectGroup(ScheduleSearchEntry entry) async {
    FocusScope.of(context).unfocus();
    _groupController.text = entry.name;
    setState(() => _suggestions = []);
    await _start();
  }

  /// Выбор преподавателя: резолвим его ID на сайте и открываем расписание.
  Future<void> _openTeacher(ScheduleSearchEntry entry) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });

    final api = context.read<BsuApiService>();
    try {
      final teacherId = await api.resolveTeacherId(entry.name);
      if (!mounted) return;
      // Преподаватель найден в системе — празднуем!
      showSalute(context);
      Navigator.of(context).push(
        FadeUpPageRoute(
          page: TeacherScheduleScreen(
            teacherId: teacherId,
            teacherName: entry.name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Выбор аудитории: сразу открываем расписание кабинета.
  Future<void> _openAuditorium(ScheduleSearchEntry entry) async {
    FocusScope.of(context).unfocus();
    final id = entry.roomId;
    if (id == null) return;
    setState(() => _suggestions = []);
    showSalute(context);
    Navigator.of(context).push(
      FadeUpPageRoute(
        page: AuditoriumScheduleScreen(
          auditoriumId: id,
          auditoriumName: entry.name,
        ),
      ),
    );
  }

  /// Ввод с задержкой ищет совпадения на сайте (как автоподсказки сайта).
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final api = context.read<BsuApiService>();
    final index = context.read<GroupIndexService>();
    final rooms = context.read<AuditoriumIndexService>();

    // Сайт отдаёт не больше десяти подсказок и без сети может не ответить,
    // поэтому его список — дополнение к локальному, а не единственный.
    List<ScheduleSearchEntry> remote = const [];
    try {
      remote = await api.searchEntries(query);
    } catch (_) {
      // Без сети ищем только по сохранённым спискам групп и аудиторий.
    }

    final entries = _mergeEntries(
      index.suggest(query),
      remote,
      rooms.suggest(query),
    );
    if (!mounted || _groupController.text.trim() != query) return;
    setState(() {
      _suggestions = entries;
      _searching = false;
    });

    // Списки могли ещё качаться — когда они готовы, повторяем поиск,
    // чтобы показать все группы и кабинеты по введённому началу.
    // Повторяем только при успехе: иначе поиск зациклится на офлайне.
    if (!index.isReady) {
      unawaited(index.load().then((_) {
        if (index.isReady) _retrySearch(query);
      }));
    }
    if (!rooms.isReady) {
      unawaited(rooms.load().then((_) {
        if (rooms.isReady) _retrySearch(query);
      }));
    }
  }

  /// Повторный поиск, если списки докачались и запрос не сменился.
  void _retrySearch(String query) {
    if (!mounted) return;
    if (_groupController.text.trim() != query) return;
    _search(query);
  }

  /// Локальные группы (все совпадения) + подсказки сайта и кабинеты.
  List<ScheduleSearchEntry> _mergeEntries(
    List<String> localGroups,
    List<ScheduleSearchEntry> remote,
    List<Auditorium> rooms,
  ) {
    final result = <ScheduleSearchEntry>[];
    final seen = <String>{};
    void add(ScheduleSearchEntry entry) {
      final prefix = entry.isRoom ? 'r' : (entry.isGroup ? 'g' : 't');
      final key = '$prefix:${entry.name.toLowerCase()}';
      if (!seen.add(key)) return;
      result.add(entry);
    }

    for (final group in localGroups) {
      add(ScheduleSearchEntry(group, true));
    }
    for (final entry in remote) {
      // Сайт вперемешку с ФИО отдаёт и кабинеты («316 Физика»):
      // их нельзя открывать как преподавателя — ищем id в списке.
      if (!entry.isGroup && RegExp(r'^\d').hasMatch(entry.name)) {
        Auditorium? room;
        for (final aud in rooms) {
          if (aud.name.toLowerCase() == entry.name.trim().toLowerCase()) {
            room = aud;
            break;
          }
        }
        if (room != null) {
          add(ScheduleSearchEntry(room.name, false, roomId: room.id));
        }
        continue;
      }
      add(entry);
    }
    for (final room in rooms) {
      add(ScheduleSearchEntry(room.name, false, roomId: room.id));
    }
    return result;
  }

  /// Избранное: показываем, когда строка поиска пуста — нужное
  /// открывается в один тап, без ввода.
  Widget _favoritesBlock(BuildContext context) {
    final favorites = context.watch<FavoritesController>().items;
    if (favorites.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        Row(
          children: [
            const Icon(Icons.star, size: 18, color: Colors.amber),
            const SizedBox(width: 6),
            Text(
              'Избранное',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            Text(
              'тап — открыть',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final favorite in favorites)
              InputChip(
                avatar: Icon(
                  favorite.isGroup
                      ? Icons.groups_outlined
                      : Icons.person_outline,
                  size: 18,
                ),
                label: Text(favorite.name),
                onPressed: () => favorite.isGroup
                    ? _selectGroup(ScheduleSearchEntry(favorite.name, true))
                    : _openTeacher(ScheduleSearchEntry(favorite.name, false)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () =>
                    context.read<FavoritesController>().remove(favorite),
              ),
          ],
        ),
      ],
    );
  }

  /// Подсказки поиска: избранное — сверху, звёздочка ставит отметку.
  Widget _suggestionsList(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final ordered = favorites.favoritesFirst(
      _suggestions,
      nameOf: (entry) => entry.name,
      isGroupOf: (entry) => entry.isGroup,
    );

    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        for (final entry in ordered)
          ListTile(
            dense: true,
            leading: Icon(entry.isRoom
                ? Icons.meeting_room_outlined
                : entry.isGroup
                    ? Icons.groups_outlined
                    : Icons.person_outline),
            title: Text(entry.name),
            subtitle: Text(entry.isRoom
                ? 'Аудитория'
                : entry.isGroup
                    ? 'Группа'
                    : 'Преподаватель'),
            onTap: () => entry.isRoom
                ? _openAuditorium(entry)
                : entry.isGroup
                    ? _selectGroup(entry)
                    : _openTeacher(entry),
            // Кабинеты в избранное не добавляем: у них нет «своей» закладки.
            trailing: entry.isRoom
                ? null
                : IconButton(
                    tooltip: favorites.isFavorite(entry.name,
                            isGroup: entry.isGroup)
                        ? 'Убрать из избранного'
                        : 'Добавить в избранное',
                    onPressed: () => favorites.toggle(
                      FavoriteEntry(
                          name: entry.name, isGroup: entry.isGroup),
                    ),
                    icon: Icon(
                      favorites.isFavorite(entry.name,
                              isGroup: entry.isGroup)
                          ? Icons.star
                          : Icons.star_border,
                      color: favorites.isFavorite(entry.name,
                              isGroup: entry.isGroup)
                          ? Colors.amber
                          : null,
                    ),
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // С открытой клавиатурой прячем большую заставку: иначе подсказкам
    // поиска не остаётся места и список уезжает под клавиатуру.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      // Позади содержимого — мягкие лучи света сверху, а поверх них
      // тихие «круги на воде»: вместе это общий фон стартового экрана.
      body: Stack(
        children: [
          const Positioned.fill(child: LightRaysBackground()),
          const Positioned.fill(child: RippleBackground()),
          // Настройки доступны сразу — ещё до ввода группы.
          Positioned(
            top: 0,
            left: 4,
            child: SafeArea(
              child: RippleTap(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.18),
                borderRadius: 22,
                child: IconButton(
                  tooltip: 'Настройки',
                  onPressed: () => Navigator.of(context).push(
                    FadeUpPageRoute(page: const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
            ),
          ),
          // Профиль необязательный, но с ним удобнее: запросы помощи
          // и отклики подписываются именем сразу.
          Positioned(
            top: 0,
            right: 8,
            child: SafeArea(
              child: Consumer<ProfileController>(
                builder: (context, profile, _) {
                  final me = profile.profile;
                  return RippleTap(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.18),
                    borderRadius: 20,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        FadeUpPageRoute(page: const ProfileScreenView()),
                      ),
                      icon: Text(
                        me.avatar,
                        style: const TextStyle(fontSize: 16),
                      ),
                      label: Text(
                        me.hasProfile ? me.name.split(' ').first : 'Профиль',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(),
                  if (!keyboardOpen) ...[
                    // После заставки — тот же листик, что и на ней.
                    Icon(
                      Icons.spa_outlined,
                      size: 132,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Медузка',
                      style:
                          TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Расписание НИУ БелГУ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Группа, преподаватель\nили аудитория',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 12),
                  BorderBeam(
                    borderRadius: 16,
                    beamLengthFraction: 0.26,
                    duration: const Duration(seconds: 5),
                    child: TextField(
                      controller: _groupController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                      keyboardType: TextInputType.text,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        // Подложка поля — плотная (белая в светлой теме):
                        // лучи и круги за ним не просвечивают.
                        filled: true,
                        fillColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        hintText: '12002301, Иванов Иван, 6-12',
                        labelStyle: const TextStyle(fontSize: 24),
                        hintStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ],
                  Expanded(
                    child: _suggestions.isEmpty
                        ? _favoritesBlock(context)
                        : _suggestionsList(context),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: RippleTap(
                      // Кнопка светлая — волна фирменного зелёного.
                      color: scheme.primary.withValues(alpha: 0.28),
                      borderRadius: 25,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _start,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Начать работу',
                                style: TextStyle(fontSize: 24),
                              ),
                      ),
                    ),
                  ),
                  RippleTap(
                    color: scheme.primary.withValues(alpha: 0.18),
                    borderRadius: 20,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          FadeUpPageRoute(page: const HelpScreenView()),
                        );
                      },
                      icon: const Icon(
                        Icons.volunteer_activism_outlined,
                        size: 18,
                      ),
                      label: const Text('Помощь студентам и преподавателям'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
