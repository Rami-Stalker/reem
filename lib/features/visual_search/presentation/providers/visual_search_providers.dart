import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/visual_search/data/datasources/impl/visual_search_remote_datasource_impl.dart';
import 'package:reem/features/visual_search/data/datasources/visual_search_remote_datasource.dart';
import 'package:reem/features/visual_search/data/repositories/visual_search_repository_impl.dart';
import 'package:reem/features/visual_search/domain/entities/visual_match.dart';
import 'package:reem/features/visual_search/domain/repositories/visual_search_repository.dart';
import 'package:reem/features/visual_search/presentation/providers/visual_search_notifier.dart';
import 'package:reem/features/visual_search/presentation/providers/visual_search_state.dart';

// ── Infrastructure ──────────────────────────────────────────────────────

final visualSearchRemoteDataSourceProvider =
    Provider<VisualSearchRemoteDataSource>(
      (ref) => VisualSearchRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final visualSearchRepositoryProvider = Provider<VisualSearchRepository>(
  (ref) =>
      VisualSearchRepositoryImpl(ref.watch(visualSearchRemoteDataSourceProvider)),
);

// ── The search screen ───────────────────────────────────────────────────

/// One notifier per search, keyed by session id.
///
/// The family key is nullable so a brand-new search and a resumed one use the
/// same notifier and the same code path — the null case simply has no row on
/// the server yet, and gets one when she picks a photograph.
final visualSearchProvider = StateNotifierProvider.autoDispose
    .family<VisualSearchNotifier, VisualSearchState, String?>((
      ref,
      sessionId,
    ) {
      // Kept alive briefly so opening a product from a card and coming back
      // does not throw away results that cost her an upload. Same treatment
      // the stylist thread gets, and for the same reason.
      final link = ref.keepAlive();
      Timer? release;
      ref.onCancel(() {
        release?.cancel();
        release = Timer(const Duration(minutes: 5), link.close);
      });
      ref.onResume(() => release?.cancel());
      ref.onDispose(() => release?.cancel());

      return VisualSearchNotifier(
        ref.watch(visualSearchRepositoryProvider),
        sessionId: sessionId,
      );
    });

// ── Rails ───────────────────────────────────────────────────────────────

/// "قطع شبيهة" for a product page.
///
/// Returns an empty list rather than throwing when the product has no
/// descriptor yet — the rail then simply does not render, which is the honest
/// answer while the indexer is still working through the catalogue.
final visuallySimilarProvider = FutureProvider.autoDispose
    .family<List<VisualMatch>, String>((ref, productId) async {
      final result = await ref
          .watch(visualSearchRepositoryProvider)
          .similarTo(productId, limit: 10);
      return switch (result) {
        Success(:final data) => data,
        Error() => const <VisualMatch>[],
      };
    });
