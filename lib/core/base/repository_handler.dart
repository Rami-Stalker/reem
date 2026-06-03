import '../errors/app_exception.dart';
import '../errors/failure.dart';
import '../result/result.dart';

mixin RepositoryHandler {
  Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      final data = await action();
      return Success(data);
    } on AppException catch (e) {
      return Error(e.toFailure());
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
