import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/persona.dart';
import '../services/chat_service.dart';

/// Переписки: список чатов, отправка сообщений, непрочитанные.
///
/// Пока сервера нет, переписка живёт на телефоне. Демо-собеседники
/// отвечают сами — это подсказка, как будет выглядеть настоящий чат;
/// такие ответы помечены в интерфейсе.
class ChatController extends ChangeNotifier {
  ChatController(
    this._service, {
    this.replyDelay = const Duration(milliseconds: 1600),
  }) {
    _loading = _load();
  }

  final ChatService _service;

  /// Через сколько демо-собеседник «ответит».
  final Duration replyDelay;

  List<Conversation> _conversations = const <Conversation>[];
  final Map<String, Timer> _pendingReplies = <String, Timer>{};
  Future<void>? _loading;
  bool _ready = false;
  String? _activePeerId;

  bool get isReady => _ready;
  Future<void> get ready => _loading ?? Future<void>.value();

  /// Чаты: свежие сверху.
  List<Conversation> get conversations {
    final list = List<Conversation>.of(_conversations);
    list.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return list;
  }

  int get unreadTotal =>
      _conversations.fold<int>(0, (sum, chat) => sum + chat.unread);

  Conversation? conversationFor(String peerId) {
    for (final conversation in _conversations) {
      if (conversation.peerId == peerId) return conversation;
    }
    return null;
  }

  Future<void> _load() async {
    _conversations = await _service.load();
    _ready = true;
    notifyListeners();
  }

  /// Открыть чат с человеком (создать при первом обращении).
  Future<Conversation> ensureConversation(Persona peer) async {
    final existing = conversationFor(peer.id);
    if (existing != null) {
      return existing;
    }
    final conversation = Conversation(
      peerId: peer.id,
      peerName: peer.name,
      peerAvatar: peer.avatar,
      peerRole: peer.role,
      isDemo: peer.isDemo,
    );
    _conversations = <Conversation>[conversation, ..._conversations];
    await _persist();
    return conversation;
  }

  /// Экран чата открыт: сообщения этого человека считаются прочитанными.
  Future<void> open(String peerId) async {
    _activePeerId = peerId;
    await markRead(peerId);
  }

  /// Экран чата закрыт.
  void close() {
    _activePeerId = null;
  }

  Future<void> markRead(String peerId) async {
    final index = _indexOf(peerId);
    if (index < 0) return;
    final conversation = _conversations[index];
    if (conversation.unread == 0) return;
    _replace(index, conversation.copyWith(unread: 0));
    await _persist();
  }

  Future<void> send(String peerId, String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final index = _indexOf(peerId);
    if (index < 0) return;

    final conversation = _conversations[index];
    final message = ChatMessage(
      id: newChatId(),
      text: clean,
      at: DateTime.now(),
      fromMe: true,
    );
    _replace(
      index,
      conversation.copyWith(
        messages: <ChatMessage>[...conversation.messages, message],
        unread: 0,
      ),
    );
    await _persist();

    if (conversation.isDemo) {
      _scheduleDemoReply(peerId);
    }
  }

  Future<void> deleteConversation(String peerId) async {
    _pendingReplies.remove(peerId)?.cancel();
    _conversations =
        _conversations.where((chat) => chat.peerId != peerId).toList();
    await _persist();
  }

  /// Демо-собеседник «отвечает» через [replyDelay] — чтобы было видно,
  /// как выглядит настоящий диалог. Ответы помечены в пузыре.
  void _scheduleDemoReply(String peerId) {
    _pendingReplies.remove(peerId)?.cancel();
    _pendingReplies[peerId] = Timer(replyDelay, () async {
      final index = _indexOf(peerId);
      if (index < 0) return;
      final conversation = _conversations[index];
      final reply = ChatMessage(
        id: newChatId(),
        text: _demoReply(conversation.messages.length),
        at: DateTime.now(),
        fromMe: false,
        isDemoReply: true,
      );
      final unread = _activePeerId == peerId ? 0 : conversation.unread + 1;
      _replace(
        index,
        conversation.copyWith(
          messages: <ChatMessage>[...conversation.messages, reply],
          unread: unread,
        ),
      );
      await _persist();
    });
  }

  String _demoReply(int messageCount) {
    const replies = <String>[
      'Здравствуйте! Да, я на связи. Чем помочь?',
      'Понял(а). Сейчас посмотрю расписание и отвечу точнее.',
      'Спасибо, что написали! Давайте встретимся после пар у кафедры.',
      'Хорошо, договорились. Напишу, если что-то изменится.',
    ];
    final index = (messageCount ~/ 2) % replies.length;
    return replies[index];
  }

  int _indexOf(String peerId) =>
      _conversations.indexWhere((chat) => chat.peerId == peerId);

  void _replace(int index, Conversation conversation) {
    final list = List<Conversation>.of(_conversations);
    list[index] = conversation;
    _conversations = list;
    notifyListeners();
  }

  Future<void> _persist() async {
    notifyListeners();
    await _service.save(_conversations);
  }

  @override
  void dispose() {
    for (final timer in _pendingReplies.values) {
      timer.cancel();
    }
    _pendingReplies.clear();
    super.dispose();
  }
}
