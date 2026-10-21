// Чаты: создание переписки, отправка, демо-ответы и сохранение на телефоне.
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/controllers/chat_controller.dart';
import 'package:medusa/models/persona.dart';
import 'package:medusa/services/chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ChatController> _controller({
  Duration replyDelay = const Duration(hours: 1),
}) async {
  final controller = ChatController(ChatService(), replyDelay: replyDelay);
  await controller.ready;
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await ChatService().getPrefs();
    await prefs.clear();
  });

  test('переписка создаётся один раз, текст обрезается', () async {
    final chats = await _controller();
    expect(chats.conversations, isEmpty);

    final first = await chats.ensureConversation(PersonaCatalog.daria);
    await chats.ensureConversation(PersonaCatalog.daria);

    expect(chats.conversations, hasLength(1));
    expect(chats.conversationFor(first.peerId)?.peerName, 'Дарья К.');

    await chats.send(first.peerId, '  привет  ');
    final messages = chats.conversationFor(first.peerId)!.messages;
    expect(messages, hasLength(1));
    expect(messages.single.text, 'привет');
    expect(messages.single.fromMe, isTrue);

    // Пустое сообщение не отправляется.
    await chats.send(first.peerId, '   ');
    expect(chats.conversationFor(first.peerId)!.messages, hasLength(1));

    chats.dispose();
  });

  test('переписка переживает перезапуск приложения', () async {
    final persona = PersonaCatalog.resolve('Анна С.');
    expect(persona.isDemo, isFalse);

    final first = await _controller();
    final conversation = await first.ensureConversation(persona);
    await first.send(conversation.peerId, 'сообщение');
    first.dispose();

    final second = await _controller();
    final restored = second.conversationFor(conversation.peerId);
    expect(restored, isNotNull);
    expect(restored!.messages.single.text, 'сообщение');
    second.dispose();
  });

  test('демо-собеседник отвечает, ответ помечен и даёт непрочитанное',
      () async {
    final chats = await _controller(
      replyDelay: const Duration(milliseconds: 5),
    );
    final conversation =
        await chats.ensureConversation(PersonaCatalog.kovaleva);

    await chats.send(conversation.peerId, 'Здравствуйте!');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final messages = chats.conversationFor(conversation.peerId)!.messages;
    expect(messages, hasLength(2));
    expect(messages.last.fromMe, isFalse);
    expect(messages.last.isDemoReply, isTrue);
    expect(messages.last.text, isNotEmpty);

    // Экран чата закрыт — сообщение считается непрочитанным.
    expect(chats.unreadTotal, 1);

    await chats.open(conversation.peerId);
    expect(chats.unreadTotal, 0);

    chats.dispose();
  });

  test('открытый чат не копит непрочитанные', () async {
    final chats = await _controller(
      replyDelay: const Duration(milliseconds: 5),
    );
    final conversation =
        await chats.ensureConversation(PersonaCatalog.sidorov);
    await chats.open(conversation.peerId);

    await chats.send(conversation.peerId, 'Добрый день');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(chats.unreadTotal, 0);
    chats.dispose();
  });

  test('переписку можно удалить', () async {
    final chats = await _controller();
    final conversation = await chats.ensureConversation(PersonaCatalog.maxim);
    await chats.send(conversation.peerId, 'тест');

    await chats.deleteConversation(conversation.peerId);
    expect(chats.conversations, isEmpty);

    final restored = await _controller();
    expect(restored.conversationFor(conversation.peerId), isNull);
    restored.dispose();
    chats.dispose();
  });
}
