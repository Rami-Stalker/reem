import 'package:reem/core/result/result.dart';

import '../entities/chat_message_entity.dart';
import '../entities/chat_thread_entity.dart';

abstract interface class ChatRepository {
  Future<Result<List<ChatThreadEntity>>> getThreads();

  Future<Result<List<ChatMessageEntity>>> getMessages(String chatId);

  Future<Result<ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
  });
}
