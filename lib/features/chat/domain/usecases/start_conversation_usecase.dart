import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';

/// Opens the conversation a request describes, or reopens the one that already
/// covers it — the server matches on the (buyer, seller, product, parcel) tuple
/// before it creates anything, so this is safe to call on every tap.
class StartConversationUseCase {
  const StartConversationUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<ChatThreadEntity>> call(ChatStartRequest request) =>
      _repository.startConversation(request);
}
