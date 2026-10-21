import 'dart:convert';

import '../models/chat_message.dart';
import 'base_services/base_storage_service.dart';

/// Переписки на телефоне.
///
/// Сервера у приложения нет: сообщения лежат в хранилище устройства.
/// Формат простой — список переписок с сообщениями внутри, чтобы позже
/// можно было без боли перейти на настоящий чат.
class ChatService extends BaseStorageService {
  static const String _conversationsKey = 'chat_conversations_v1';

  Set<String> getAllowedKeys() => <String>{_conversationsKey};

  Future<List<Conversation>> load() async {
    final raw = await getString(_conversationsKey);
    if (raw == null) return const <Conversation>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
          .where((conversation) => conversation.peerId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <Conversation>[];
    }
  }

  Future<void> save(List<Conversation> conversations) => setString(
        _conversationsKey,
        jsonEncode(
          conversations.map((conversation) => conversation.toJson()).toList(),
        ),
      );
}
