import '../../../../core/result/result.dart';
import '../entities/profile_overview.dart';

/// Source of the bespoke profile-centre data (completion, achievements,
/// loyalty, orders snapshot, followed stores, referral, reviews summary).
abstract interface class ProfileOverviewRepository {
  Future<Result<ProfileOverview>> getOverview();
}
