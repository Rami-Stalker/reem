import 'package:ohara/features/value/domain/entities/value_standing.dart';
import 'package:ohara/features/value/domain/repositories/value_repository.dart';

abstract interface class ValueRemoteDataSource {
  Future<ValueStanding> standing();

  Future<ValueBadge> badge();

  Future<ValueEventPage> events({String? pillar, int? limit, String? cursor});

  Future<List<ValueRule>> rules();

  Future<List<ValueBenefit>> benefits();

  Future<ValueGrant> claimBenefit(String benefitKey);

  Future<ValueGrant> useGrant(
    String grantId, {
    required String usedOnType,
    required String usedOnId,
  });
}
