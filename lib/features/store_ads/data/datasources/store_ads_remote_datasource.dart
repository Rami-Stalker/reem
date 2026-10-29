import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';

abstract interface class StoreAdsRemoteDataSource {
  Future<AdPlansView> plans();
  Future<AdPlansView> subscribe(AdTier tier, {required String idempotencyKey});
  Future<AdQuote> quote(AdCampaignDraft draft);
  Future<AdCampaign> launch(
    AdCampaignDraft draft, {
    required String idempotencyKey,
  });
  Future<List<AdCampaign>> campaigns();
  Future<AdCampaign> setStatus(String id, AdCampaignStatus status);
  Future<List<AdSuggestion>> suggestions();
  Future<AdsOverview> overview();
  Future<List<AdGovernorate>> governorates();
  Future<AdPaymentOptions> paymentOptions();
  Future<AdPurchaseResult> purchase(
    AdTier tier,
    String method, {
    required String idempotencyKey,
  });
  Future<AdPlanPurchase> submitReference(String id, String reference);
  Future<AdPlanPurchase> cancelPurchase(String id);

  Future<AdAdminSummary> adminSummary();
  Future<List<AdPendingPayment>> adminPending();
  Future<void> adminConfirm(String id);
  Future<void> adminReject(String id, String reason);
  Future<Map<String, String?>> adminInstructions();
  Future<void> adminSaveInstructions(Map<String, String> values);
}
