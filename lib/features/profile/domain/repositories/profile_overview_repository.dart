import 'package:reem/core/result/result.dart';
import 'package:reem/features/profile/domain/entities/profile_overview.dart';

/// Source of the bespoke profile-centre data (completion, achievements,
/// loyalty, orders snapshot, followed stores, referral, reviews summary).
abstract interface class ProfileOverviewRepository {
  Future<Result<ProfileOverview>> getOverview();
}
