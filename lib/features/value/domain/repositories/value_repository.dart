import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/value/domain/entities/value_standing.dart';

class ValueEventPage {
  final List<ValueEvent> events;
  final String? nextCursor;

  const ValueEventPage({this.events = const [], this.nextCursor});

  bool get hasMore => nextCursor != null;
}

/// Ohara Value's client contract.
///
/// Note what is missing and will stay missing: there is no `earn`, no `redeem`,
/// no `convert`. Standing is computed by the server from evidence it already
/// holds, and a client method that could move it would be a client method that
/// could be forged. [claimBenefit] is the only write, and it costs nothing.
abstract interface class ValueRepository {
  Future<Result<ValueStanding>> standing();

  Future<Result<ValueBadge>> badge();

  Future<Result<ValueEventPage>> events({
    String? pillar,
    int? limit,
    String? cursor,
  });

  /// The whole earning table, published.
  Future<Result<List<ValueRule>>> rules();

  Future<Result<List<ValueBenefit>>> benefits();

  /// Take up a benefit her standing already opened. Nothing is spent.
  Future<Result<ValueGrant>> claimBenefit(String benefitKey);

  Future<Result<ValueGrant>> useGrant(
    String grantId, {
    required String usedOnType,
    required String usedOnId,
  });
}
