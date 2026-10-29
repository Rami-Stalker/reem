import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';

abstract interface class StoreAdsRepository {
  Future<Result<AdPlansView>> plans();

  /// Buys or upgrades; answers with the plans as they now stand.
  Future<Result<AdPlansView>> subscribe(
    AdTier tier, {
    required String idempotencyKey,
  });

  Future<Result<AdQuote>> quote(AdCampaignDraft draft);

  /// Charges and starts it. [idempotencyKey] is minted once per intent, so a
  /// retried tap on a slow line is one campaign, not two charges.
  Future<Result<AdCampaign>> launch(
    AdCampaignDraft draft, {
    required String idempotencyKey,
  });

  Future<Result<List<AdCampaign>>> campaigns();

  Future<Result<AdCampaign>> setStatus(String id, AdCampaignStatus status);

  Future<Result<List<AdSuggestion>>> suggestions();

  Future<Result<AdsOverview>> overview();

  Future<Result<List<AdGovernorate>>> governorates();
}
