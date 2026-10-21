import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/help_controller.dart';
import '../../models/chat_message.dart';
import '../../models/persona.dart';
import '../transitions/fade_up_page_route.dart';
import '../widgets/ripple_tap.dart';
import 'chat_screen_view.dart';

/// Список переписок и вход в новый чат.
class ChatsScreenView extends StatelessWidget {
  const ChatsScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatController>();
    final conversations = chats.conversations;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Чаты'),
        actions: [
          IconButton(
            tooltip: 'Новый чат',
            onPressed: () => _newChat(context),
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      body:
          conversations.isEmpty
              ? _empty(context, scheme)
              : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return _ChatTile(
                    conversation: conversation,
                    onTap: () => _openChat(context, conversation),
                    onLongPress: () => _confirmDelete(context, conversation),
                  );
                },
              ),
    );
  }

  Widget _empty(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'Пока ни одной переписки',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Найдите человека в помощи или выберите из списка — '
              'преподаватели и студенты уже там.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            const SizedBox(height: 18),
            RippleTap(
              borderRadius: 22,
              child: FilledButton.icon(
                onPressed: () => _newChat(context),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Начать чат'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, Conversation conversation) {
    final persona =
        PersonaCatalog.byId(conversation.peerId) ??
        Persona(
          id: conversation.peerId,
          name: conversation.peerName,
          role: conversation.peerRole,
          avatar: conversation.peerAvatar,
          isDemo: conversation.isDemo,
        );
    Navigator.of(
      context,
    ).push(FadeUpPageRoute(page: ChatScreenView(peer: persona)));
  }

  Future<void> _newChat(BuildContext context) async {
    final chats = context.read<ChatController>();
    final help = context.read<HelpController>();
    final people = _people(help);
    final me = help.userName;

    final picked = await showModalBottomSheet<Persona>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Кому написать',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Список собран из раздела помощи и демо-профилей.',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final person in people)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: scheme.surfaceContainerHighest,
                            child: Text(
                              person.avatar,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          title: Text(person.name),
                          subtitle: Text(
                            _personSubtitle(person),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing:
                              person.name == me
                                  ? const Text(
                                    'это вы',
                                    style: TextStyle(fontSize: 11),
                                  )
                                  : const Icon(Icons.chevron_right),
                          enabled: person.name != me,
                          onTap: () => Navigator.of(sheetContext).pop(person),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    await chats.ensureConversation(picked);
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(FadeUpPageRoute(page: ChatScreenView(peer: picked)));
  }

  /// Люди, с которыми можно начать чат: демо-профили и все, кто
  /// встречается в запросах помощи.
  List<Persona> _people(HelpController help) {
    final byId = <String, Persona>{};
    for (final persona in PersonaCatalog.demo) {
      byId[persona.id] = persona;
    }
    for (final request in help.requests) {
      final names = <String>[
        request.authorName,
        ...request.volunteers.map((volunteer) => volunteer.name),
      ];
      for (final name in names) {
        if (name.trim().isEmpty) continue;
        final persona = PersonaCatalog.resolve(name);
        byId.putIfAbsent(persona.id, () => persona);
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) {
      if (a.isTeacher != b.isTeacher) return a.isTeacher ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Conversation conversation,
  ) async {
    final chats = context.read<ChatController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Удалить переписку?'),
            content: Text(
              'Сообщения с ${conversation.peerName} исчезнут с этого телефона.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await chats.deleteConversation(conversation.peerId);
    }
  }
}

/// «Преподаватель · кафедра» или «Студент · группа».
String _personSubtitle(Persona person) {
  if (person.isTeacher) {
    return person.about.isEmpty
        ? 'Преподаватель'
        : 'Преподаватель · ${person.about}';
  }
  return person.group.isEmpty ? 'Студент' : 'Студент · ${person.group}';
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = conversation.lastMessage;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer.withValues(alpha: 0.6),
            child: Text(
              conversation.peerAvatar,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          if (conversation.unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unread}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.onError,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              conversation.peerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (conversation.isTeacher) ...[
            const SizedBox(width: 4),
            Icon(Icons.school_outlined, size: 13, color: scheme.outline),
          ],
          if (conversation.isDemo) ...[
            const SizedBox(width: 4),
            Icon(Icons.science_outlined, size: 13, color: scheme.outline),
          ],
        ],
      ),
      subtitle: Text(
        last == null
            ? 'Нет сообщений'
            : '${last.fromMe ? 'Вы: ' : ''}${last.text}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: last == null ? scheme.outline : scheme.onSurfaceVariant,
          fontStyle: last == null ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      trailing:
          last == null
              ? null
              : Text(
                _chatTime(last.at),
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
    );
  }

  String _chatTime(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    String two(int value) => value.toString().padLeft(2, '0');
    if (day == today) return '${two(at.hour)}:${two(at.minute)}';
    if (today.difference(day).inDays == 1) return 'вчера';
    return '${two(at.day)}.${two(at.month)}';
  }
}
