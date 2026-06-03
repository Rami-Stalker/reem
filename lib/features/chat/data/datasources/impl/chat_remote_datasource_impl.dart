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
  }) async {
    final json = await postJson(
      ApiEndpoints.chatMessages(chatId),
      body: {'content': content},
    );
    final messageJson = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;
    return ChatMessageModel.fromJson(messageJson, chatId: chatId);
  }
}
