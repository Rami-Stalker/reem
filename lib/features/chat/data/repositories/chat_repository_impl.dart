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
  }) =>
      guard(() => remote.sendMessage(chatId: chatId, content: content));
}
