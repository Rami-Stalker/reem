import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/entities/chat_start_request.dart';
import 'package:ohara/features/chat/domain/entities/chat_thread_entity.dart';

abstract interface class ChatRepository {
  Future<Result<List<ChatThreadEntity>>> getThreads({String? query});

  Future<Result<ChatThreadEntity>> getThread(String chatId);

  Future<Result<ChatThreadEntity>> startConversation(ChatStartRequest request);

  /// The newest page of a conversation, or the page just older than
  /// [before]. Oldest first. [currentUserId] decides which messages are hers.
  Future<Result<List<ChatMessageEntity>>> getMessages(
    String chatId, {
    DateTime? before,
    int limit = 50,
    String? currentUserId,
  });

  Future<Result<ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
    String? currentUserId,
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
