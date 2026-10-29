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
}
