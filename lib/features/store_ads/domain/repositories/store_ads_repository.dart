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

  Future<Result<AdPaymentOptions>> paymentOptions();

  /// [method] is [adPayFromEarnings] or a transfer method's wire name.
  Future<Result<AdPurchaseResult>> purchase(
    AdTier tier,
    String method, {
    required String idempotencyKey,
  });

  Future<Result<AdPlanPurchase>> submitReference(String id, String reference);

  Future<Result<AdPlanPurchase>> cancelPurchase(String id);
}

/// Finance's side of plan payments.
abstract interface class AdminAdsRepository {
  Future<Result<AdAdminSummary>> summary();
  Future<Result<List<AdPendingPayment>>> pending();
  Future<Result<void>> confirm(String id);
  Future<Result<void>> reject(String id, String reason);
  Future<Result<Map<String, String?>>> instructions();
  Future<Result<void>> saveInstructions(Map<String, String> values);
}
