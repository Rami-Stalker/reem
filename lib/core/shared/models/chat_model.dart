// shared/models/chat_model.dart

import '../entities/chat.dart';
import 'user_model.dart';

class ChatModel extends Chat {
  const ChatModel({
    required super.id,
    required super.sender,
    required super.receiver,
    required super.message,
    required super.isSeen,
    required super.createdAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'],
      sender: UserModel.fromJson(json['sender']),
      receiver: UserModel.fromJson(json['receiver']),
      message: json['message'],
      isSeen: json['is_seen'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': (sender as UserModel).toJson(),
      'receiver': (receiver as UserModel).toJson(),
      'message': message,
      'is_seen': isSeen,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatModel copyWith({
    String? id,
    UserModel? sender,
    UserModel? receiver,
    String? message,
    bool? isSeen,
    DateTime? createdAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      message: message ?? this.message,
      isSeen: isSeen ?? this.isSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}