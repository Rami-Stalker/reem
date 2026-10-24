import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:ohara/features/chat/data/models/chat_message_model.dart';
import 'package:ohara/features/chat/data/models/chat_thread_model.dart';
import 'package:ohara/features/chat/domain/entities/chat_start_request.dart';

final class ChatRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ChatRemoteDataSource {
  const ChatRemoteDataSourceImpl(super.dio);

  @override
  Future<List<ChatThreadModel>> getThreads({String? query}) async {
    final term = query?.trim();
    final list = await getList(
      ApiEndpoints.chats,
      query: {if (term != null && term.isNotEmpty) 'q': term},
    );
    return list
        .whereType<Map>()
        .map((e) => ChatThreadModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ChatThreadModel> getThread(String chatId) async {
    return ChatThreadModel.fromJson(
      await getJson(ApiEndpoints.chatThread(chatId)),
    );
  }

  @override
  Future<ChatThreadModel> startConversation(ChatStartRequest request) async {
    return ChatThreadModel.fromJson(
      await postJson(ApiEndpoints.chats, body: request.toJson()),
    );
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
    String chatId, {
    DateTime? before,
    int limit = 50,
    String? currentUserId,
  }) async {
    final list = await getList(
      ApiEndpoints.chatMessages(chatId),
      query: {
        'limit': limit,
        if (before != null) 'before': before.toUtc().toIso8601String(),
      },
    );
    return list
        .whereType<Map>()
        .map(
          (e) => ChatMessageModel.fromJson(
            Map<String, dynamic>.from(e),
            chatId: chatId,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
    String? currentUserId,
    String? productId,
  }) async {
    final json = await postJson(
      ApiEndpoints.chatMessages(chatId),
      body: {
        'content': content,
        'kind': kind,
        'client_id': ?clientId,
        'product_id': ?productId,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
    final messageJson = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;
    return ChatMessageModel.fromJson(
      messageJson,
      chatId: chatId,
      currentUserId: currentUserId,
    );
  }

  @override
  Future<void> markRead(String chatId, {String? messageId}) async {
    await patchJson(
      ApiEndpoints.chatRead(chatId),
      body: {'message_id': ?messageId},
    );
  }

  @override
  Future<void> blockUser(String userId, {String? reason}) async {
    await postJson(
      ApiEndpoints.chatBlock(userId),
      body: {'reason': ?reason},
    );
  }

  @override
  Future<void> reportUser({
    required String chatId,
    required String reportedUserId,
    required String reason,
    String? messageId,
    String? description,
  }) async {
    await postJson(
      ApiEndpoints.chatReports(chatId),
      body: {
        'reported_user_id': reportedUserId,
        'reason': reason,
        'message_id': ?messageId,
        'description': ?description,
      },
    );
  }
}
