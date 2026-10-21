import 'dart:math' as math;

/// Сообщение в чате.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.at,
    required this.fromMe,
    this.isDemoReply = false,
  });

  final String id;
  final String text;
  final DateTime at;

  /// Сообщение отправил я (иначе — собеседник).
  final bool fromMe;

  /// Ответ демо-собеседника: приложение отвечает само, пока нет сервера.
  final bool isDemoReply;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'at': at.toIso8601String(),
        'fromMe': fromMe,
        'isDemoReply': isDemoReply,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: '${json['id'] ?? ''}',
        text: '${json['text'] ?? ''}',
        at: DateTime.tryParse('${json['at'] ?? ''}') ?? DateTime.now(),
        fromMe: json['fromMe'] == true,
        isDemoReply: json['isDemoReply'] == true,
      );
}

/// Переписка с одним человеком.
///
/// Имя, аватар и роль храним рядом с сообщениями: если профиль поменяется,
/// история всё равно откроется.
class Conversation {
  const Conversation({
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.peerRole,
    this.messages = const <ChatMessage>[],
    this.unread = 0,
    this.isDemo = false,
  });

  final String peerId;
  final String peerName;
  final String peerAvatar;
  final String peerRole;
  final List<ChatMessage> messages;
  final int unread;
  final bool isDemo;

  bool get isTeacher => peerRole == 'teacher';

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  DateTime get lastAt =>
      lastMessage?.at ?? DateTime.fromMillisecondsSinceEpoch(0);

  Conversation copyWith({
    String? peerName,
    String? peerAvatar,
    String? peerRole,
    List<ChatMessage>? messages,
    int? unread,
    bool? isDemo,
  }) {
    return Conversation(
      peerId: peerId,
      peerName: peerName ?? this.peerName,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      peerRole: peerRole ?? this.peerRole,
      messages: messages ?? this.messages,
      unread: unread ?? this.unread,
      isDemo: isDemo ?? this.isDemo,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'peerId': peerId,
        'peerName': peerName,
        'peerAvatar': peerAvatar,
        'peerRole': peerRole,
        'unread': unread,
        'isDemo': isDemo,
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    return Conversation(
      peerId: '${json['peerId'] ?? ''}',
      peerName: '${json['peerName'] ?? ''}',
      peerAvatar: '${json['peerAvatar'] ?? '🎓'}',
      peerRole: '${json['peerRole'] ?? 'student'}',
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      isDemo: json['isDemo'] == true,
      messages: raw is List
          ? raw
              .whereType<Map>()
              .map((item) => ChatMessage.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <ChatMessage>[],
    );
  }
}

/// Короткий уникальный id сообщения.
String newChatId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd = math.Random().nextInt(1 << 20).toRadixString(36);
  return '$now-$rnd';
}
