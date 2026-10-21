import 'package:reem/features/chat/data/models/chat_message_model.dart';
import 'package:reem/features/chat/data/models/chat_thread_model.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';

abstract interface class ChatRemoteDataSource {
  /// [query] is matched by the server against titles, participant names and
  /// message bodies, so searching is one request rather than a local filter
  /// over whatever happens to be loaded.
  Future<List<ChatThreadModel>> getThreads({String? query});

  Future<ChatThreadModel> getThread(String chatId);

  /// Opens — or reopens — the conversation [request] describes and returns it.
  Future<ChatThreadModel> startConversation(ChatStartRequest request);

  Future<List<ChatMessageModel>> getMessages(String chatId);

  Future<ChatMessageModel> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
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
