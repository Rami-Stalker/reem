import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';

class GetMessagesUseCase {
  const GetMessagesUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<List<ChatMessageEntity>>> call(
    String chatId, {
    DateTime? before,
    int limit = 50,
    String? currentUserId,
  }) =>
      _repository.getMessages(
        chatId,
        before: before,
        limit: limit,
        currentUserId: currentUserId,
      );
}
