import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/profile/domain/entities/profile_overview.dart';

/// Source of the bespoke profile-centre data (completion, achievements,
/// loyalty, orders snapshot, followed stores, referral, reviews summary).
abstract interface class ProfileOverviewRepository {
  Future<Result<ProfileOverview>> getOverview();
}
