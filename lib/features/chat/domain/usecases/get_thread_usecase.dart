import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';

class GetThreadUseCase {
  const GetThreadUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<ChatThreadEntity>> call(String chatId) =>
      _repository.getThread(chatId);
}
