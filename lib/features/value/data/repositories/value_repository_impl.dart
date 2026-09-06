import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/value/data/datasources/value_remote_datasource.dart';
import 'package:reem/features/value/domain/entities/value_standing.dart';
import 'package:reem/features/value/domain/repositories/value_repository.dart';

class ValueRepositoryImpl with RepositoryHandler implements ValueRepository {
  const ValueRepositoryImpl(this.remote);

  final ValueRemoteDataSource remote;

  @override
  Future<Result<ValueStanding>> standing() => guard(remote.standing);

  @override
  Future<Result<ValueBadge>> badge() => guard(remote.badge);

  @override
  Future<Result<ValueEventPage>> events({
    String? pillar,
    int? limit,
    String? cursor,
  }) =>
      guard(() => remote.events(pillar: pillar, limit: limit, cursor: cursor));

  @override
  Future<Result<List<ValueRule>>> rules() => guard(remote.rules);

  @override
  Future<Result<List<ValueBenefit>>> benefits() => guard(remote.benefits);

  @override
  Future<Result<ValueGrant>> claimBenefit(String benefitKey) =>
      guard(() => remote.claimBenefit(benefitKey), operation: 'claim benefit');

  @override
  Future<Result<ValueGrant>> useGrant(
    String grantId, {
    required String usedOnType,
    required String usedOnId,
  }) =>
      guard(
        () => remote.useGrant(
          grantId,
          usedOnType: usedOnType,
          usedOnId: usedOnId,
        ),
      );
}
