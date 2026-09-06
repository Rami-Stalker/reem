import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';

class GetThreadsUseCase {
  const GetThreadsUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<List<ChatThreadEntity>>> call({String? query}) =>
      _repository.getThreads(query: query);
}
