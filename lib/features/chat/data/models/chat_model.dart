class ChatModel {

  final String id;

  final String name;

  final String image;

  final String lastMessage;

  final int unreadCount;

  final bool online;

  final DateTime lastSeen;

  ChatModel({

    required this.id,

    required this.name,

    required this.image,

    required this.lastMessage,

    required this.unreadCount,

    required this.online,

    required this.lastSeen,
  });
}