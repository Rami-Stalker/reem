import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';

abstract interface class ChatRemoteDataSource {
  Future<List<ChatThreadModel>> getThreads();

  Future<List<ChatMessageModel>> getMessages(String chatId);

  Future<ChatMessageModel> sendMessage({
    required String chatId,
    required String content,
  });
}
