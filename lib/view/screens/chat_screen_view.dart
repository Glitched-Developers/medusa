import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../models/chat_message.dart';
import '../../models/persona.dart';
import '../transitions/fade_up_page_route.dart';
import '../widgets/aurora_rays.dart';
import 'public_profile_screen.dart';

/// Чат с человеком: сообщения на фоне северного сияния.
class ChatScreenView extends StatefulWidget {
  const ChatScreenView({super.key, required this.peer});

  final Persona peer;

  @override
  State<ChatScreenView> createState() => _ChatScreenViewState();
}

class _ChatScreenViewState extends State<ChatScreenView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ChatController? _chats;
  int _lastCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chats = context.read<ChatController>();
    if (identical(_chats, chats)) return;
    _chats = chats;
    // Открываем чат после кадра: markRead обновляет провайдер, а менять
    // провайдер прямо во время построения дерева нельзя.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      chats.open(widget.peer.id);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _chats?.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final chats = context.read<ChatController>();
    _input.clear();
    await chats.send(widget.peer.id, text);
    _scrollToBottom();
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(FadeUpPageRoute(page: PublicProfileScreen(persona: widget.peer)));
  }

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatController>();
    final conversation = chats.conversationFor(widget.peer.id);
    final messages = conversation?.messages ?? const <ChatMessage>[];
    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      _scrollToBottom();
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AuroraRays(
        intensity: 0.9,
        child: Container(
          color: scheme.surface.withValues(alpha: 0.16),
          child: Column(
            children: [
              _topBar(context, scheme),
              Expanded(
                child:
                    messages.isEmpty
                        ? _emptyState(context, scheme)
                        : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                          itemCount: messages.length,
                          itemBuilder:
                              (context, index) => _bubble(
                                context,
                                messages[index],
                                showTail: index == messages.length - 1,
                              ),
                        ),
              ),
              _inputBar(context, scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surface.withValues(alpha: 0.75),
            scheme.surface.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Назад',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _openProfile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: scheme.surface.withValues(
                            alpha: 0.85,
                          ),
                          child: Text(
                            widget.peer.avatar,
                            style: const TextStyle(fontSize: 19),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.peer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                widget.peer.isTeacher
                                    ? 'Преподаватель'
                                    : 'Студент',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Профиль',
                onPressed: _openProfile,
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.peer.avatar, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text(
              'Напишите первым',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              widget.peer.name,
              style: TextStyle(fontSize: 13, color: scheme.outline),
            ),
            if (widget.peer.isDemo) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Это демо-профиль: собеседник ответит сам, чтобы показать, '
                  'как выглядит диалог.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: scheme.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    ChatMessage message, {
    bool showTail = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromMe;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border:
              mine
                  ? null
                  : Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: mine ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isDemoReply) ...[
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 11,
                    color: scheme.outline,
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  _time(message.at),
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        mine
                            ? scheme.onPrimary.withValues(alpha: 0.75)
                            : scheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(BuildContext context, ColorScheme scheme) {
    return Container(
      color: scheme.surface.withValues(alpha: 0.92),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Сообщение…',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.7,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Отправить',
                onPressed: _send,
                icon: const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _time(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(at.hour)}:${two(at.minute)}';
}
