import '../errors/app_exception.dart';
import '../errors/failure.dart';
import '../result/result.dart';

mixin RepositoryHandler {
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository operation',
  }) async {
    try {
      final data = await action();
      return Success(data);
    } on AppException catch (e, stackTrace) {
      return Error(e.toFailure(stackTrace: stackTrace));
    } on Object catch (e, stackTrace) {
      return Error(
        ServerFailure(
          'Unexpected error while running $operation.',
          cause: e,
          stackTrace: stackTrace,
          isRetryable: false,
        ),
      );
    }
  }
}
