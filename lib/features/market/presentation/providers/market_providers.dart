import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/market/data/datasources/impl/market_remote_datasource_impl.dart';
import 'package:ohara/features/market/data/datasources/market_remote_datasource.dart';
import 'package:ohara/features/market/data/repositories/market_repository_impl.dart';
import 'package:ohara/features/market/domain/entities/market.dart';
import 'package:ohara/features/market/domain/repositories/market_repository.dart';

/// Wiring for Ohara Market Evolution.
///
/// Read providers throughout, no notifiers. Everything on these screens is
/// derived on the server from a nightly sweep or from her own rows, so there
/// is no client-side state that could be more correct than a re-read — and the
/// few writes (drafting a listing, declining a mission) invalidate rather than
/// mutate, which is what keeps the screen and the database agreeing.

final marketDataSourceProvider = Provider<MarketRemoteDataSource>(
  (ref) => MarketRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepositoryImpl(ref.watch(marketDataSourceProvider)),
);

// ── Drops ───────────────────────────────────────────────────────────────

/// The drops open to her.
///
/// Empty on failure rather than an error state: a drop rail is an addition to
/// a home screen that works without it, and a red box where a launch might
/// have been is worse than no rail at all.
final openDropsProvider = FutureProvider.autoDispose<List<Drop>>((ref) async {
  final result = await ref.watch(marketRepositoryProvider).openDrops();
  return result.fold((_) => const <Drop>[], (drops) => drops);
});

// ── Bundles ─────────────────────────────────────────────────────────────

final bundlesProvider = FutureProvider.autoDispose
    .family<List<Bundle>, String?>((ref, occasion) async {
      final result = await ref
          .watch(marketRepositoryProvider)
          .bundles(occasion: occasion, limit: 12);
      return result.fold((_) => const <Bundle>[], (bundles) => bundles);
    });

/// One bundle in full. Errors surface here, unlike the list — she navigated to
/// this on purpose and an empty screen would leave her with nothing to do.
final bundleProvider = FutureProvider.autoDispose.family<Bundle, String>((
  ref,
  bundleId,
) async {
  final result = await ref.watch(marketRepositoryProvider).bundle(bundleId);
  return result.fold((failure) => throw failure, (bundle) => bundle);
});

final bundleAlternativesProvider = FutureProvider.autoDispose
    .family<List<BundleAlternative>, String>((ref, bundleId) async {
      final result = await ref
          .watch(marketRepositoryProvider)
          .bundleAlternatives(bundleId);
      return result.fold(
        (_) => const <BundleAlternative>[],
        (alternatives) => alternatives,
      );
    });

// ── Wardrobe ────────────────────────────────────────────────────────────

final wardrobeSummaryProvider = FutureProvider.autoDispose<WardrobeSummary?>((
  ref,
) async {
  final result = await ref.watch(marketRepositoryProvider).wardrobeSummary();
  return result.fold((_) => null, (summary) => summary);
});

final wardrobeAttentionProvider =
    FutureProvider.autoDispose<List<WardrobePiece>>((ref) async {
      final result = await ref
          .watch(marketRepositoryProvider)
          .wardrobeAttention(limit: 6);
      return result.fold((_) => const <WardrobePiece>[], (items) => items);
    });

final wardrobePieceProvider = FutureProvider.autoDispose
    .family<WardrobePiece, String>((ref, closetItemId) async {
      final result = await ref
          .watch(marketRepositoryProvider)
          .wardrobeItem(closetItemId);
      return result.fold((failure) => throw failure, (piece) => piece);
    });

// ── Resale ──────────────────────────────────────────────────────────────

final resaleMarketProvider = FutureProvider.autoDispose
    .family<List<ResaleListing>, String?>((ref, slot) async {
      final result = await ref
          .watch(marketRepositoryProvider)
          .resaleMarket(slot: slot, limit: 24);
      return result.fold((_) => const <ResaleListing>[], (rows) => rows);
    });

final myListingsProvider = FutureProvider.autoDispose<List<ResaleListing>>((
  ref,
) async {
  final result = await ref.watch(marketRepositoryProvider).myListings();
  return result.fold((_) => const <ResaleListing>[], (rows) => rows);
});

// ── Missions ────────────────────────────────────────────────────────────

final missionsProvider = FutureProvider.autoDispose<List<Mission>>((ref) async {
  final result = await ref.watch(marketRepositoryProvider).missions();
  return result.fold((_) => const <Mission>[], (missions) => missions);
});

// ── Seller ──────────────────────────────────────────────────────────────

final sellerOpportunitiesProvider =
    FutureProvider.autoDispose<List<MarketOpportunity>>((ref) async {
      final result = await ref
          .watch(marketRepositoryProvider)
          .sellerOpportunities(limit: 8);
      return result.fold(
        (_) => const <MarketOpportunity>[],
        (opportunities) => opportunities,
      );
    });

final dropCandidatesProvider = FutureProvider.autoDispose<List<DropCandidate>>((
  ref,
) async {
  final result = await ref
      .watch(marketRepositoryProvider)
      .dropCandidates(limit: 10);
  return result.fold((_) => const <DropCandidate>[], (rows) => rows);
});

final sellerDropsProvider = FutureProvider.autoDispose<List<Drop>>((ref) async {
  final result = await ref.watch(marketRepositoryProvider).sellerDrops();
  return result.fold((_) => const <Drop>[], (drops) => drops);
});
