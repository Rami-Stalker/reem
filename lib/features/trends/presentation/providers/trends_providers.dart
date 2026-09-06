import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/trends/data/datasources/impl/trends_remote_datasource_impl.dart';
import 'package:reem/features/trends/data/datasources/trends_remote_datasource.dart';
import 'package:reem/features/trends/data/repositories/trends_repository_impl.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';
import 'package:reem/features/trends/domain/repositories/trends_repository.dart';

final trendsRemoteDataSourceProvider = Provider<TrendsRemoteDataSource>(
  (ref) => TrendsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final trendsRepositoryProvider = Provider<TrendsRepository>(
  (ref) => TrendsRepositoryImpl(ref.watch(trendsRemoteDataSourceProvider)),
);

// ── Seller ───────────────────────────────────────────────────────────────

class SellerTrendsState {
  const SellerTrendsState({
    this.window = TrendWindow.d7,
    this.overview,
    this.isLoading = false,
    this.error,
    this.busyInsightId,
  });

  final TrendWindow window;
  final SellerTrendOverview? overview;
  final bool isLoading;
  final String? error;

  /// The insight currently being acknowledged, so only its own button spins.
  final String? busyInsightId;

  /// A window switch keeps the previous figures on screen while the next ones
  /// load, so the page does not blink back to a spinner she has to wait out.
  bool get isInitialLoading => isLoading && overview == null;

  SellerTrendsState copyWith({
    TrendWindow? window,
    SellerTrendOverview? overview,
    bool? isLoading,
    String? error,
    String? busyInsightId,
    bool clearError = false,
    bool clearBusy = false,
  }) => SellerTrendsState(
    window: window ?? this.window,
    overview: overview ?? this.overview,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    busyInsightId: clearBusy ? null : (busyInsightId ?? this.busyInsightId),
  );
}

class SellerTrendsNotifier extends StateNotifier<SellerTrendsState> {
  SellerTrendsNotifier(this._repository) : super(const SellerTrendsState());

  final TrendsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.sellerOverview(state.window);
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, overview: data),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> refresh() => load();

  Future<void> setWindow(TrendWindow window) async {
    if (window == state.window) return;
    state = state.copyWith(window: window);
    await load();
  }

  /// Acknowledge or dismiss one recommended action.
  ///
  /// The list is rebuilt from the server's answer rather than mutated
  /// optimistically: an insight's status is the one piece of state a seller
  /// and a nightly run can both touch, and guessing at it locally is how a
  /// dismissed card reappears on the next pull-to-refresh.
  Future<void> updateInsight(String id, InsightStatus status) async {
    state = state.copyWith(busyInsightId: id);
    final result = await _repository.updateSellerInsight(id, status);
    if (!mounted) return;

    final overview = state.overview;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        clearBusy: true,
        overview: overview == null
            ? null
            : _replaceInsight(overview, data, status),
      ),
      Error(:final failure) => state.copyWith(
        clearBusy: true,
        error: failure.message,
      ),
    };
  }

  SellerTrendOverview _replaceInsight(
    SellerTrendOverview overview,
    TrendInsight updated,
    InsightStatus status,
  ) {
    final actions = [
      for (final action in overview.recommendedActions)
        if (action.id == updated.id) updated else action,
    ]..removeWhere((action) => action.status == InsightStatus.dismissed);

    return SellerTrendOverview(
      asOf: overview.asOf,
      window: overview.window,
      headline: overview.headline,
      demandSignals: overview.demandSignals,
      trending: overview.trending,
      emerging: overview.emerging,
      lowConversion: overview.lowConversion,
      stockOpportunities: overview.stockOpportunities,
      forecast: overview.forecast,
      series: overview.series,
      recommendedActions: actions,
      productCount: overview.productCount,
    );
  }
}

final sellerTrendsNotifierProvider =
    StateNotifierProvider.autoDispose<SellerTrendsNotifier, SellerTrendsState>(
      (ref) =>
          SellerTrendsNotifier(ref.watch(trendsRepositoryProvider))..load(),
    );

// ── Admin ────────────────────────────────────────────────────────────────

class AdminTrendsState {
  const AdminTrendsState({
    this.window = TrendWindow.d7,
    this.overview,
    this.opportunities = const [],
    this.sellers = const [],
    this.isLoading = false,
    this.isRecomputing = false,
    this.error,
    this.notice,
  });

  final TrendWindow window;
  final AdminTrendOverview? overview;
  final List<MarketOpportunity> opportunities;
  final List<SellerPerformanceRow> sellers;
  final bool isLoading;
  final bool isRecomputing;
  final String? error;

  /// A transient message — "the run finished", "the gap was marked sourced".
  final String? notice;

  bool get isInitialLoading => isLoading && overview == null;

  AdminTrendsState copyWith({
    TrendWindow? window,
    AdminTrendOverview? overview,
    List<MarketOpportunity>? opportunities,
    List<SellerPerformanceRow>? sellers,
    bool? isLoading,
    bool? isRecomputing,
    String? error,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
  }) => AdminTrendsState(
    window: window ?? this.window,
    overview: overview ?? this.overview,
    opportunities: opportunities ?? this.opportunities,
    sellers: sellers ?? this.sellers,
    isLoading: isLoading ?? this.isLoading,
    isRecomputing: isRecomputing ?? this.isRecomputing,
    error: clearError ? null : (error ?? this.error),
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

class AdminTrendsNotifier extends StateNotifier<AdminTrendsState> {
  AdminTrendsNotifier(this._repository) : super(const AdminTrendsState());

  final TrendsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    // Three calls rather than one fat endpoint: the overview is what the page
    // needs to paint, and the two lists below it can arrive a moment later
    // without holding the first paint hostage.
    final results = await Future.wait([
      _repository.adminOverview(state.window),
      _repository.adminOpportunities(state.window, limit: 15),
      _repository.adminSellers(days: state.window.days, limit: 15),
    ]);
    if (!mounted) return;

    final overview = results[0] as Result<AdminTrendOverview>;
    final opportunities = results[1] as Result<List<MarketOpportunity>>;
    final sellers = results[2] as Result<List<SellerPerformanceRow>>;

    state = switch (overview) {
      Success(:final data) => state.copyWith(
        isLoading: false,
        overview: data,
        // A failed side panel is an empty panel, not a failed page.
        opportunities: opportunities.dataOrNull ?? const [],
        sellers: sellers.dataOrNull ?? const [],
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> refresh() => load();

  Future<void> setWindow(TrendWindow window) async {
    if (window == state.window) return;
    state = state.copyWith(window: window);
    await load();
  }

  Future<void> updateInsight(String id, InsightStatus status) async {
    final result = await _repository.updateAdminInsight(id, status);
    if (!mounted) return;
    if (result.isError) {
      state = state.copyWith(error: result.failureOrNull?.message);
      return;
    }
    await load();
  }

  /// Move an unmet-demand gap along the buying workflow.
  Future<void> reviewUnmetDemand(String id, UnmetDemandStatus status) async {
    final result = await _repository.reviewUnmetDemand(id, status);
    if (!mounted) return;
    if (result.isError) {
      state = state.copyWith(error: result.failureOrNull?.message);
      return;
    }
    await load();
  }

  /// Re-run the pipeline now.
  ///
  /// The server refuses while a run is in flight, so the failure path here is
  /// a real message rather than a silent no-op.
  Future<void> recompute() async {
    if (state.isRecomputing) return;
    state = state.copyWith(
      isRecomputing: true,
      clearError: true,
      clearNotice: true,
    );
    final result = await _repository.recompute();
    if (!mounted) return;

    if (result.isError) {
      state = state.copyWith(
        isRecomputing: false,
        error: result.failureOrNull?.message,
      );
      return;
    }
    state = state.copyWith(isRecomputing: false);
    await load();
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);
}

final adminTrendsNotifierProvider =
    StateNotifierProvider.autoDispose<AdminTrendsNotifier, AdminTrendsState>(
      (ref) => AdminTrendsNotifier(ref.watch(trendsRepositoryProvider))..load(),
    );
