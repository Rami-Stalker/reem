import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/seller_store/data/models/seller_store_models.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';

/// The shop's settings, team, activity and codes over HTTP.
final class SellerStoreRemoteDataSource extends BaseRemoteDataSource {
  const SellerStoreRemoteDataSource(super.dio);

  Future<StorePolicies> policies() async => SellerStoreMapper.policies(
    await getJson(ApiEndpoints.sellerStorePolicies),
  );

  Future<StorePolicies> savePolicies(Map<String, dynamic> body) async =>
      SellerStoreMapper.policies(
        await putJson(ApiEndpoints.sellerStorePolicies, body: body),
      );

  Future<ShippingSettings> shipping() async => SellerStoreMapper.shipping(
    await getJson(ApiEndpoints.sellerShippingSettings),
  );

  Future<ShippingSettings> saveShipping(Map<String, dynamic> body) async =>
      SellerStoreMapper.shipping(
        await putJson(ApiEndpoints.sellerShippingSettings, body: body),
      );

  Future<List<StoreTeamMember>> team() async => [
    for (final row in (await getList(ApiEndpoints.sellerTeam)).whereType<Map>())
      SellerStoreMapper.member(row.cast<String, dynamic>()),
  ];

  Future<StoreTeamMember> invite(String phone, StoreTeamRole role) async =>
      SellerStoreMapper.member(
        await postJson(
          ApiEndpoints.sellerTeam,
          body: {'phone': phone, 'role': role.wire},
        ),
      );

  Future<StoreTeamMember> changeRole(String id, StoreTeamRole role) async =>
      SellerStoreMapper.member(
        await patchJson(
          ApiEndpoints.sellerTeamMember(id),
          body: {'role': role.wire},
        ),
      );

  Future<void> removeMember(String id) =>
      deleteRequest(ApiEndpoints.sellerTeamMember(id));

  Future<ActivityPage> activity({String? before}) async =>
      SellerStoreMapper.activity(
        await getJson(
          ApiEndpoints.sellerActivity,
          query: {'limit': 30, 'before': ?before},
        ),
      );

  Future<List<StoreMembership>> memberships() async => [
    for (final row
        in (await getList(ApiEndpoints.storeMemberships)).whereType<Map>())
      SellerStoreMapper.membership(row.cast<String, dynamic>()),
  ];

  Future<List<StoreMembership>> respond(String id, String verb) async => [
    for (final row in (await postList(
      switch (verb) {
        'accept' => ApiEndpoints.storeMembershipAccept(id),
        'decline' => ApiEndpoints.storeMembershipDecline(id),
        _ => ApiEndpoints.storeMembershipLeave(id),
      },
    )).whereType<Map>())
      SellerStoreMapper.membership(row.cast<String, dynamic>()),
  ];

  Future<List<SellerCoupon>> coupons() async => [
    for (final row
        in (await getList(ApiEndpoints.sellerCoupons)).whereType<Map>())
      SellerStoreMapper.coupon(row.cast<String, dynamic>()),
  ];

  Future<SellerCoupon> createCoupon(Map<String, dynamic> body) async =>
      SellerStoreMapper.coupon(
        await postJson(ApiEndpoints.sellerCoupons, body: body),
      );

  Future<SellerCoupon> setCouponActive(String id, {required bool active}) async =>
      SellerStoreMapper.coupon(
        await patchJson(
          active
              ? ApiEndpoints.sellerCouponActivate(id)
              : ApiEndpoints.sellerCouponDeactivate(id),
        ),
      );

  /// Puts a listing on sale, or — with [compareAt] null — ends the sale.
  Future<void> setSale(
    String offerId, {
    required String price,
    required String? compareAt,
  }) => patchJson(
    ApiEndpoints.sellerOfferById(offerId),
    body: {'price': price, 'compare_at_price': compareAt},
  );

  /// What a shopper reads about a shop: its policies and how it ships.
  Future<(StorePolicies, ShippingSettings)> storeInfo(String sellerId) async {
    final json = await getJson(ApiEndpoints.sellerStoreInfo(sellerId));
    return (
      SellerStoreMapper.policies(
        (json['policies'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      SellerStoreMapper.shipping(
        (json['shipping'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}
