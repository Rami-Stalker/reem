import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:reem/features/chat/data/models/chat_message_model.dart';
import 'package:reem/features/chat/data/models/chat_thread_model.dart';

final class ChatRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ChatRemoteDataSource {
  const ChatRemoteDataSourceImpl(super.dio);

  @override
  Future<List<ChatThreadModel>> getThreads() async {
    final list = await getList(ApiEndpoints.chats);
    return list
        .whereType<Map>()
        .map((e) => ChatThreadModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String chatId) async {
    final list = await getList(ApiEndpoints.chatMessages(chatId));
    return list
        .whereType<Map>()
        .map(
          (e) => ChatMessageModel.fromJson(
            Map<String, dynamic>.from(e),
            chatId: chatId,
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
  }) async {
    final json = await postJson(
      ApiEndpoints.chatMessages(chatId),
      body: {
        'content': content,
        'kind': kind,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
    final messageJson = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;
    return ChatMessageModel.fromJson(messageJson, chatId: chatId);
  }

  @override
  Future<void> markRead(String chatId, {String? messageId}) async {
    await patchJson(
      ApiEndpoints.chatRead(chatId),
      body: {if (messageId != null) 'message_id': messageId},
    );
  }

  @override
  Future<void> blockUser(String userId, {String? reason}) async {
    await postJson(
      ApiEndpoints.chatBlock(userId),
      body: {if (reason != null) 'reason': reason},
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
        if (messageId != null) 'message_id': messageId,
        if (description != null) 'description': description,
      },
    );
  }
}
