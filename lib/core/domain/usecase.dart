import '../result/result.dart';

/// Domain-layer contract for application actions.
///
/// Use cases depend only on repositories and value objects. They never import
/// Flutter, Dio, data models, widgets, or provider classes.
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

abstract interface class StreamUseCase<T, Params> {
  Stream<Result<T>> call(Params params);
}

final class NoParams {
  const NoParams();
}
