import '../../../../core/result/result.dart';
import '../entities/profile_overview.dart';
import '../repositories/profile_overview_repository.dart';

/// Fetches the aggregated profile-centre overview.
class GetProfileOverviewUseCase {
  const GetProfileOverviewUseCase(this._repository);

  final ProfileOverviewRepository _repository;

  Future<Result<ProfileOverview>> call() => _repository.getOverview();
}
