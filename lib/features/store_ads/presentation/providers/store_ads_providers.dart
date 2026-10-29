import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/store_ads/data/datasources/impl/store_ads_remote_datasource_impl.dart';
import 'package:ohara/features/store_ads/data/datasources/store_ads_remote_datasource.dart';
import 'package:ohara/features/store_ads/data/repositories/store_ads_repository_impl.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/domain/repositories/store_ads_repository.dart';

final storeAdsRemoteDataSourceProvider = Provider<StoreAdsRemoteDataSource>(
  (ref) => StoreAdsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final storeAdsRepositoryProvider = Provider<StoreAdsRepository>(
  (ref) => StoreAdsRepositoryImpl(ref.watch(storeAdsRemoteDataSourceProvider)),
);

T _unwrap<T>(Result<T> result) =>
    result.fold((failure) => throw failure, (data) => data);

final adPlansProvider = FutureProvider.autoDispose<AdPlansView>(
  (ref) async => _unwrap(await ref.watch(storeAdsRepositoryProvider).plans()),
);

final adsOverviewProvider = FutureProvider.autoDispose<AdsOverview>(
  (ref) async =>
      _unwrap(await ref.watch(storeAdsRepositoryProvider).overview()),
);

final adCampaignsProvider = FutureProvider.autoDispose<List<AdCampaign>>(
  (ref) async =>
      _unwrap(await ref.watch(storeAdsRepositoryProvider).campaigns()),
);

final adSuggestionsProvider = FutureProvider.autoDispose<List<AdSuggestion>>(
  (ref) async =>
      _unwrap(await ref.watch(storeAdsRepositoryProvider).suggestions()),
);

final adGovernoratesProvider = FutureProvider.autoDispose<List<AdGovernorate>>(
  (ref) async =>
      _unwrap(await ref.watch(storeAdsRepositoryProvider).governorates()),
);

/// Which refusal the server gave, so the screen can word it — and, for a
/// locked placement, offer the plan that unlocks it.
AdFailureKind adFailureKind(Failure failure) => switch (failure.code) {
  'INSUFFICIENT_BALANCE' => AdFailureKind.insufficientBalance,
  'CAMPAIGN_LIMIT' => AdFailureKind.campaignLimit,
  'FEED_POST_REQUIRED' => AdFailureKind.feedPostRequired,
  'PLACEMENT_LOCKED' ||
  'TARGETING_LOCKED' ||
  'INTEREST_TARGETING_LOCKED' => AdFailureKind.planLocked,
  _ => AdFailureKind.other,
};

/// One key per intent: a retried tap on a slow line is answered by the
/// server from its record of the first, rather than charged a second time.
String _intentKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Everything that changes her advertising, and refreshes what it changed.
class StoreAdsActions {
  StoreAdsActions(this._ref);

  final Ref _ref;
  final Map<AdTier, String> _planKeys = {};

  StoreAdsRepository get _repo => _ref.read(storeAdsRepositoryProvider);

  void _refreshAll() {
    _ref
      ..invalidate(adPlansProvider)
      ..invalidate(adsOverviewProvider)
      ..invalidate(adCampaignsProvider)
      ..invalidate(adSuggestionsProvider);
  }

  /// Returns null on success, the failure otherwise.
  Future<Failure?> subscribe(AdTier tier) async {
    final key = _planKeys[tier] ??= _intentKey();
    final result = await _repo.subscribe(tier, idempotencyKey: key);
    if (result case Error(:final failure)) return failure;
    _planKeys.remove(tier);
    _refreshAll();
    return null;
  }

  Future<Failure?> setStatus(
    AdCampaign campaign,
    AdCampaignStatus status,
  ) async {
    final result = await _repo.setStatus(campaign.id, status);
    if (result case Error(:final failure)) return failure;
    _refreshAll();
    return null;
  }

  void refresh() => _refreshAll();
}

final storeAdsActionsProvider = Provider.autoDispose<StoreAdsActions>(
  StoreAdsActions.new,
);

// ---------------------------------------------------------------------------
// The campaign composer
// ---------------------------------------------------------------------------

class CampaignComposerState {
  const CampaignComposerState({
    this.draft,
    this.productTitle,
    this.productImage,
    this.quote,
    this.isQuoting = false,
    this.quoteFailure,
    this.isLaunching = false,
  });

  /// Null until she picks a piece.
  final AdCampaignDraft? draft;
  final String? productTitle;
  final String? productImage;
  final AdQuote? quote;
  final bool isQuoting;
  final Failure? quoteFailure;
  final bool isLaunching;

  bool get canLaunch =>
      draft != null &&
      quote != null &&
      quote!.canLaunch &&
      !isQuoting &&
      !isLaunching;

  CampaignComposerState copyWith({
    AdCampaignDraft? draft,
    String? productTitle,
    String? productImage,
    AdQuote? quote,
    bool? isQuoting,
    Failure? quoteFailure,
    bool? isLaunching,
    bool clearQuote = false,
    bool clearFailure = false,
  }) => CampaignComposerState(
    draft: draft ?? this.draft,
    productTitle: productTitle ?? this.productTitle,
    productImage: productImage ?? this.productImage,
    quote: clearQuote ? null : (quote ?? this.quote),
    isQuoting: isQuoting ?? this.isQuoting,
    quoteFailure: clearFailure ? null : (quoteFailure ?? this.quoteFailure),
    isLaunching: isLaunching ?? this.isLaunching,
  );
}

/// The campaign she is putting together, re-quoted as she changes it.
///
/// Quotes are debounced and generation-checked: dragging the duration slider
/// sends one request when she lets go, not thirty, and an answer that arrives
/// after a newer question is dropped rather than shown.
class CampaignComposerNotifier extends StateNotifier<CampaignComposerState> {
  CampaignComposerNotifier(this._repo, this._onLaunched)
    : super(const CampaignComposerState());

  final StoreAdsRepository _repo;
  final void Function() _onLaunched;
  Timer? _debounce;
  int _generation = 0;
  String? _launchKey;

  void choose({
    required AdCampaignDraft draft,
    required String title,
    String? image,
  }) {
    _launchKey = null;
    state = CampaignComposerState(
      draft: draft,
      productTitle: title,
      productImage: image,
    );
    _requote(immediately: true);
  }

  void update(AdCampaignDraft Function(AdCampaignDraft) change) {
    final draft = state.draft;
    if (draft == null) return;
    // A different campaign is a different intent.
    _launchKey = null;
    state = state.copyWith(draft: change(draft));
    _requote();
  }

  void _requote({bool immediately = false}) {
    _debounce?.cancel();
    state = state.copyWith(isQuoting: true, clearFailure: true);
    _debounce = Timer(
      immediately ? Duration.zero : const Duration(milliseconds: 350),
      _quote,
    );
  }

  Future<void> _quote() async {
    final draft = state.draft;
    if (draft == null) return;
    final generation = ++_generation;
    final result = await _repo.quote(draft);
    if (!mounted || generation != _generation) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        quote: data,
        isQuoting: false,
        clearFailure: true,
      ),
      Error(:final failure) => state.copyWith(
        isQuoting: false,
        quoteFailure: failure,
        clearQuote: true,
      ),
    };
  }

  /// Charges and starts it. Returns null on success, the failure otherwise.
  Future<Failure?> launch() async {
    final draft = state.draft;
    if (draft == null || !state.canLaunch) return null;
    state = state.copyWith(isLaunching: true);
    final key = _launchKey ??= _intentKey();
    final result = await _repo.launch(draft, idempotencyKey: key);
    if (!mounted) return null;
    state = state.copyWith(isLaunching: false);
    if (result case Error(:final failure)) return failure;
    _launchKey = null;
    _onLaunched();
    return null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final campaignComposerProvider =
    StateNotifierProvider.autoDispose<
      CampaignComposerNotifier,
      CampaignComposerState
    >(
      (ref) => CampaignComposerNotifier(
        ref.watch(storeAdsRepositoryProvider),
        () => ref.read(storeAdsActionsProvider).refresh(),
      ),
    );
