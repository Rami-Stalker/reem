import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/result/result.dart';

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
