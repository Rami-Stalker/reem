import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_thread_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl with RepositoryHandler implements ChatRepository {
  const ChatRepositoryImpl({required this.remote});

  final ChatRemoteDataSource remote;

  @override
  Future<Result<List<ChatThreadEntity>>> getThreads() =>
      guard(() => remote.getThreads());

  @override
  Future<Result<List<ChatMessageEntity>>> getMessages(String chatId) =>
      guard(() => remote.getMessages(chatId));

  @override
  Future<Result<ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
  }) =>
      guard(
        () => remote.sendMessage(
          chatId: chatId,
          content: content,
          kind: kind,
          attachments: attachments,
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
