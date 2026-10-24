import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';

/// She has read the conversation up to [messageId], or to its end.
///
/// Over HTTP rather than the socket: a frame sent while the socket is still
/// connecting — or reconnecting — is dropped, and the unread badge then stayed
/// on a conversation she had plainly read.
class MarkChatReadUseCase {
  const MarkChatReadUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<void>> call(String chatId, {String? messageId}) =>
      _repository.markRead(chatId, messageId: messageId);
}
