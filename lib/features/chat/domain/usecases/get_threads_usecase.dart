import 'package:reem/core/result/result.dart';

import '../entities/chat_thread_entity.dart';
import '../repositories/chat_repository.dart';

class GetThreadsUseCase {
  const GetThreadsUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<List<ChatThreadEntity>>> call() => _repository.getThreads();
}
