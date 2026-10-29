import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/store_ads/data/datasources/store_ads_remote_datasource.dart';
import 'package:ohara/features/store_ads/data/models/store_ads_mapper.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';

final class StoreAdsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements StoreAdsRemoteDataSource {
  const StoreAdsRemoteDataSourceImpl(super.dio);

  @override
  Future<AdPlansView> plans() async =>
      StoreAdsMapper.plans(await getJson(ApiEndpoints.adsPlans));

  @override
  Future<AdPlansView> subscribe(
    AdTier tier, {
    required String idempotencyKey,
  }) async => StoreAdsMapper.plans(
    await postJson(
      ApiEndpoints.adsSubscribe,
      body: {'tier': tier.wire},
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<AdQuote> quote(AdCampaignDraft draft) async => StoreAdsMapper.quote(
    await postJson(
      ApiEndpoints.adsQuote,
      body: StoreAdsMapper.draftToJson(draft),
    ),
  );

  @override
  Future<AdCampaign> launch(
    AdCampaignDraft draft, {
    required String idempotencyKey,
  }) async => StoreAdsMapper.campaign(
    await postJson(
      ApiEndpoints.adsCampaigns,
      body: {...StoreAdsMapper.draftToJson(draft), 'launch': true},
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<List<AdCampaign>> campaigns() async =>
      StoreAdsMapper.campaigns(await getList(ApiEndpoints.adsCampaigns));

  @override
  Future<AdCampaign> setStatus(String id, AdCampaignStatus status) async =>
      StoreAdsMapper.campaign(
        await patchJson(
          ApiEndpoints.adsCampaignStatus(id),
          body: {'status': status.wire},
        ),
      );

  @override
  Future<List<AdSuggestion>> suggestions() async =>
      StoreAdsMapper.suggestions(await getList(ApiEndpoints.adsSuggestions));

  @override
  Future<AdsOverview> overview() async =>
      StoreAdsMapper.overview(await getJson(ApiEndpoints.adsOverview));

  @override
  Future<List<AdGovernorate>> governorates() async =>
      StoreAdsMapper.governorates(await getList(ApiEndpoints.adsGovernorates));

  @override
  Future<AdPaymentOptions> paymentOptions() async =>
      StoreAdsMapper.paymentOptions(
        await getJson(ApiEndpoints.adsPaymentOptions),
      );

  @override
  Future<AdPurchaseResult> purchase(
    AdTier tier,
    String method, {
    required String idempotencyKey,
  }) async => StoreAdsMapper.purchaseResult(
    await postJson(
      ApiEndpoints.adsPurchases,
      body: {'tier': tier.wire, 'method': method},
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<AdPlanPurchase> submitReference(String id, String reference) async =>
      StoreAdsMapper.purchase(
        await postJson(
          ApiEndpoints.adsPurchaseReference(id),
          body: {'reference': reference},
        ),
      );

  @override
  Future<AdPlanPurchase> cancelPurchase(String id) async =>
      StoreAdsMapper.purchase(
        await postJson(ApiEndpoints.adsPurchaseCancel(id)),
      );

  @override
  Future<AdAdminSummary> adminSummary() async =>
      StoreAdsMapper.adminSummary(await getJson(ApiEndpoints.adminAdsSummary));

  @override
  Future<List<AdPendingPayment>> adminPending() async =>
      StoreAdsMapper.pendingPayments(
        await getList(ApiEndpoints.adminAdsPurchases),
      );

  @override
  Future<void> adminConfirm(String id) async {
    await postJson(ApiEndpoints.adminAdsPurchaseConfirm(id));
  }

  @override
  Future<void> adminReject(String id, String reason) async {
    await postJson(
      ApiEndpoints.adminAdsPurchaseReject(id),
      body: {'reason': reason},
    );
  }

  @override
  Future<Map<String, String?>> adminInstructions() async => {
    for (final row in (await getList(
      ApiEndpoints.adminAdsPaymentInstructions,
    )).whereType<Map>())
      '${row['method']}': row['instructions'] as String?,
  };

  @override
  Future<void> adminSaveInstructions(Map<String, String> values) async {
    await putJson(ApiEndpoints.adminAdsPaymentInstructions, body: values);
  }
}
