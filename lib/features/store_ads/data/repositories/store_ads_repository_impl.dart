import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/store_ads/data/datasources/store_ads_remote_datasource.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/domain/repositories/store_ads_repository.dart';

class StoreAdsRepositoryImpl
    with RepositoryHandler
    implements StoreAdsRepository {
  const StoreAdsRepositoryImpl(this.remote);

  final StoreAdsRemoteDataSource remote;

  @override
  Future<Result<AdPlansView>> plans() => guard(remote.plans);

  @override
  Future<Result<AdPlansView>> subscribe(
    AdTier tier, {
    required String idempotencyKey,
  }) => guard(() => remote.subscribe(tier, idempotencyKey: idempotencyKey));

  @override
  Future<Result<AdQuote>> quote(AdCampaignDraft draft) =>
      guard(() => remote.quote(draft));

  @override
  Future<Result<AdCampaign>> launch(
    AdCampaignDraft draft, {
    required String idempotencyKey,
  }) => guard(() => remote.launch(draft, idempotencyKey: idempotencyKey));

  @override
  Future<Result<List<AdCampaign>>> campaigns() => guard(remote.campaigns);

  @override
  Future<Result<AdCampaign>> setStatus(String id, AdCampaignStatus status) =>
      guard(() => remote.setStatus(id, status));

  @override
  Future<Result<List<AdSuggestion>>> suggestions() => guard(remote.suggestions);

  @override
  Future<Result<AdsOverview>> overview() => guard(remote.overview);

  @override
  Future<Result<List<AdGovernorate>>> governorates() =>
      guard(remote.governorates);

  @override
  Future<Result<AdPaymentOptions>> paymentOptions() =>
      guard(remote.paymentOptions);

  @override
  Future<Result<AdPurchaseResult>> purchase(
    AdTier tier,
    String method, {
    required String idempotencyKey,
  }) => guard(
    () => remote.purchase(tier, method, idempotencyKey: idempotencyKey),
  );

  @override
  Future<Result<AdPlanPurchase>> submitReference(String id, String reference) =>
      guard(() => remote.submitReference(id, reference));

  @override
  Future<Result<AdPlanPurchase>> cancelPurchase(String id) =>
      guard(() => remote.cancelPurchase(id));
}

class AdminAdsRepositoryImpl
    with RepositoryHandler
    implements AdminAdsRepository {
  const AdminAdsRepositoryImpl(this.remote);

  final StoreAdsRemoteDataSource remote;

  @override
  Future<Result<AdAdminSummary>> summary() => guard(remote.adminSummary);

  @override
  Future<Result<List<AdPendingPayment>>> pending() =>
      guard(remote.adminPending);

  @override
  Future<Result<void>> confirm(String id) =>
      guard(() => remote.adminConfirm(id));

  @override
  Future<Result<void>> reject(String id, String reason) =>
      guard(() => remote.adminReject(id, reason));

  @override
  Future<Result<Map<String, String?>>> instructions() =>
      guard(remote.adminInstructions);

  @override
  Future<Result<void>> saveInstructions(Map<String, String> values) =>
      guard(() => remote.adminSaveInstructions(values));
}
