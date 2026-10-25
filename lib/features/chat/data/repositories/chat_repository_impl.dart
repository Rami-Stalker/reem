import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/entities/chat_start_request.dart';
import 'package:ohara/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl with RepositoryHandler implements ChatRepository {
  const ChatRepositoryImpl({required this.remote});

  final ChatRemoteDataSource remote;

  @override
  Future<Result<List<ChatThreadEntity>>> getThreads({String? query}) =>
      guard(() => remote.getThreads(query: query));

  @override
  Future<Result<ChatThreadEntity>> getThread(String chatId) =>
      guard(() => remote.getThread(chatId));

  @override
  Future<Result<ChatThreadEntity>> startConversation(
    ChatStartRequest request,
  ) =>
      guard(() => remote.startConversation(request));

  @override
  Future<Result<List<ChatMessageEntity>>> getMessages(
    String chatId, {
    DateTime? before,
    int limit = 50,
    String? currentUserId,
  }) =>
      guard(
        () => remote.getMessages(
          chatId,
          before: before,
          limit: limit,
          currentUserId: currentUserId,
        ),
      );

  @override
  Future<Result<ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
    String? currentUserId,
    String? productId,
  }) =>
      guard(
        () => remote.sendMessage(
          chatId: chatId,
          content: content,
          kind: kind,
          attachments: attachments,
          clientId: clientId,
          currentUserId: currentUserId,
          productId: productId,
        ),
      );

  @override
  Future<Result<void>> markRead(String chatId, {String? messageId}) =>
      guard(() => remote.markRead(chatId, messageId: messageId));

  @override
  Future<Result<void>> blockUser(String userId, {String? reason}) =>
      guard(() => remote.blockUser(userId, reason: reason));

  @override
  Future<Result<void>> reportUser({
    required String chatId,
    required String reportedUserId,
    required String reason,
    String? messageId,
    String? description,
  }) =>
      guard(
        () => remote.reportUser(
          chatId: chatId,
          reportedUserId: reportedUserId,
          reason: reason,
          messageId: messageId,
          description: description,
        ),
      );
}
