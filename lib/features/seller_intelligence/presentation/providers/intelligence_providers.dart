import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/seller_intelligence/data/datasources/impl/seller_intelligence_remote_datasource_impl.dart';
import 'package:ohara/features/seller_intelligence/data/datasources/seller_intelligence_remote_datasource.dart';
import 'package:ohara/features/seller_intelligence/data/repositories/seller_intelligence_repository_impl.dart';
import 'package:ohara/features/seller_intelligence/domain/entities/intelligence.dart';
import 'package:ohara/features/seller_intelligence/domain/repositories/seller_intelligence_repository.dart';

/// Wiring for the three intelligence screens.
///
/// `FutureProvider` rather than a notifier per screen: none of these screens
/// has state of its own beyond "what came back". They are read-only views over
/// a nightly pipeline, and the only mutation in the whole feature is the
/// snapshot button — which invalidates rather than patching, because the
/// server recomputes more than the button knows about.
final sellerIntelligenceDataSourceProvider =
    Provider<SellerIntelligenceRemoteDataSource>(
      (ref) => SellerIntelligenceRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final sellerIntelligenceRepositoryProvider =
    Provider<SellerIntelligenceRepository>(
      (ref) => SellerIntelligenceRepositoryImpl(
        ref.watch(sellerIntelligenceDataSourceProvider),
      ),
    );

/// The radar. Nightly data, so it is cached for the session and refreshed by
/// pull-to-refresh rather than re-fetched on every visit.
final demandRadarProvider = FutureProvider.autoDispose<DemandRadar>((ref) async {
  final result = await ref.watch(sellerIntelligenceRepositoryProvider).radar();
  return result.fold((failure) => throw failure, (data) => data);
});

final productIntelligenceProvider =
    FutureProvider.autoDispose<ProductHealthList>((ref) async {
      final result = await ref
          .watch(sellerIntelligenceRepositoryProvider)
          .products(limit: 100);
      return result.fold((failure) => throw failure, (data) => data);
    });

final productHealthProvider = FutureProvider.autoDispose
    .family<ProductHealth, String>((ref, productId) async {
      final result = await ref
          .watch(sellerIntelligenceRepositoryProvider)
          .product(productId);
      return result.fold((failure) => throw failure, (data) => data);
    });

final sellerHealthProvider = FutureProvider.autoDispose<SellerHealth>((
  ref,
) async {
  final result = await ref.watch(sellerIntelligenceRepositoryProvider).health();
  return result.fold((failure) => throw failure, (data) => data);
});

/// What is slipping, and why.
///
/// Live rather than nightly — it reads order rows directly — so it is not
/// cached beyond the screen that shows it.
final decliningListingsProvider =
    FutureProvider.autoDispose<List<DecliningListing>>((ref) async {
      final result = await ref
          .watch(sellerIntelligenceRepositoryProvider)
          .declining();
      return result.fold((failure) => throw failure, (data) => data);
    });

final sellerHealthHistoryProvider =
    FutureProvider.autoDispose<List<HealthPoint>>((ref) async {
      final result = await ref
          .watch(sellerIntelligenceRepositoryProvider)
          .healthHistory();
      return result.fold((failure) => throw failure, (data) => data);
    });

/// The one action in the feature.
final intelligenceActionsProvider = Provider<IntelligenceActions>(
  IntelligenceActions.new,
);

class IntelligenceActions {
  IntelligenceActions(this._ref);

  final Ref _ref;

  /// Freeze today's figures, then reload everything that depends on them.
  ///
  /// Invalidating rather than patching: the snapshot rescored every listing
  /// too, and a client that only updated the number it happened to know about
  /// would leave the product screen showing yesterday's.
  Future<bool> snapshot() async {
    final result = await _ref
        .read(sellerIntelligenceRepositoryProvider)
        .snapshot();

    return result.fold((_) => false, (_) {
      _ref.invalidate(sellerHealthProvider);
      _ref.invalidate(sellerHealthHistoryProvider);
      _ref.invalidate(productIntelligenceProvider);
      return true;
    });
  }
}
