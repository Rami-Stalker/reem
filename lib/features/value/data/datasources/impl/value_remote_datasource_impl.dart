import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/value/data/datasources/value_remote_datasource.dart';
import 'package:reem/features/value/data/models/value_models.dart';
import 'package:reem/features/value/domain/entities/value_standing.dart';
import 'package:reem/features/value/domain/repositories/value_repository.dart';

final class ValueRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ValueRemoteDataSource {
  const ValueRemoteDataSourceImpl(super.dio);

  @override
  Future<ValueStanding> standing() async =>
      standingFromJson(await getJson(ApiEndpoints.value));

  @override
  Future<ValueBadge> badge() async =>
      badgeFromJson(await getJson(ApiEndpoints.valueBadge));

  @override
  Future<ValueEventPage> events({
    String? pillar,
    int? limit,
    String? cursor,
  }) async {
    final json = await getJson(
      ApiEndpoints.valueEvents,
      query: {'pillar': ?pillar, 'limit': ?limit, 'cursor': ?cursor},
    );
    return ValueEventPage(
      events: eventsFromJson(json['events']),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  @override
  Future<List<ValueRule>> rules() async =>
      rulesFromJson(await getJson(ApiEndpoints.valueRules));

  @override
  Future<List<ValueBenefit>> benefits() async =>
      benefitsFromJson(await getList(ApiEndpoints.valueBenefits));

  @override
  Future<ValueGrant> claimBenefit(String benefitKey) async {
    final json = await postJson(
      ApiEndpoints.valueBenefitClaim,
      body: {'benefit_key': benefitKey},
    );
    return grantFromJson(json) ??
        ValueGrant(id: json['id']?.toString() ?? '', status: 'OFFERED');
  }

  @override
  Future<ValueGrant> useGrant(
    String grantId, {
    required String usedOnType,
    required String usedOnId,
  }) async {
    final json = await postJson(
      ApiEndpoints.valueGrantUse(grantId),
      body: {'used_on_type': usedOnType, 'used_on_id': usedOnId},
    );
    return grantFromJson(json) ?? ValueGrant(id: grantId, status: 'USED');
  }
}
