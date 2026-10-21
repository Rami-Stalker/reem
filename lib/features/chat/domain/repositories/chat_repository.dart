import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';

abstract interface class ChatRepository {
  Future<Result<List<ChatThreadEntity>>> getThreads({String? query});

  Future<Result<ChatThreadEntity>> getThread(String chatId);

  Future<Result<ChatThreadEntity>> startConversation(ChatStartRequest request);

  Future<Result<List<ChatMessageEntity>>> getMessages(String chatId);

  Future<Result<ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
  });

  Future<Result<void>> markRead(String chatId, {String? messageId});

  Future<Result<void>> blockUser(String userId, {String? reason});

  Future<Result<void>> reportUser({
    required String chatId,
    required String reportedUserId,
    required String reason,
    String? messageId,
    String? description,
  });
}
