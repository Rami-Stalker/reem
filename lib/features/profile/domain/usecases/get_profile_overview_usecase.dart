import 'package:reem/core/result/result.dart';
import 'package:reem/features/profile/domain/entities/profile_overview.dart';
import 'package:reem/features/profile/domain/repositories/profile_overview_repository.dart';

/// Fetches the aggregated profile-centre overview.
class GetProfileOverviewUseCase {
  const GetProfileOverviewUseCase(this._repository);

  final ProfileOverviewRepository _repository;

  Future<Result<ProfileOverview>> call() => _repository.getOverview();
}
