import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';

/// Long-press → «حذف لدي» or «حذف عند الجميع».
class DeleteMessageUseCase {
  const DeleteMessageUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<void>> call(
    String chatId,
    String messageId, {
    required bool forEveryone,
  }) =>
      _repository.deleteMessage(chatId, messageId, forEveryone: forEveryone);
}
