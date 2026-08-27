import 'package:reem/features/chat/data/models/chat_message_model.dart';
import 'package:reem/features/chat/data/models/chat_thread_model.dart';

abstract interface class ChatRemoteDataSource {
  Future<List<ChatThreadModel>> getThreads();

  Future<List<ChatMessageModel>> getMessages(String chatId);

  Future<ChatMessageModel> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
  });

  Future<void> markRead(String chatId, {String? messageId});

  Future<void> blockUser(String userId, {String? reason});

  Future<void> reportUser({
    required String chatId,
    required String reportedUserId,
    required String reason,
    String? messageId,
    String? description,
  });
}
