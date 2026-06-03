import 'package:reem/core/result/result.dart';

import '../entities/chat_message_entity.dart';
import '../repositories/chat_repository.dart';

class GetMessagesUseCase {
  const GetMessagesUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<List<ChatMessageEntity>>> call(String chatId) =>
      _repository.getMessages(chatId);
}
