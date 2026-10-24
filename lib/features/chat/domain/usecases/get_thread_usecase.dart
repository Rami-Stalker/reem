import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';

class GetThreadUseCase {
  const GetThreadUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<ChatThreadEntity>> call(String chatId) =>
      _repository.getThread(chatId);
}
