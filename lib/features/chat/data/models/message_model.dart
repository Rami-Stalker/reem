class MessageModel {

  final String id;

  final String message;

  final bool isMe;

  final DateTime createdAt;

  final MessageType type;

  final String? image;

  final String? audio;

  final bool seen;

  MessageModel({

    required this.id,

    required this.message,

    required this.isMe,

    required this.createdAt,

    required this.type,

    this.image,

    this.audio,

    this.seen = false,
  });
}

enum MessageType {

  text,

  image,

  voice,

  story,

  product,
}