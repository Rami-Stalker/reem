import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';

class GetMessagesUseCase {
  const GetMessagesUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<List<ChatMessageEntity>>> call(String chatId) =>
      _repository.getMessages(chatId);
}
