import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/intelligence/data/datasources/impl/intelligence_remote_datasource_impl.dart';
import 'package:ohara/features/intelligence/data/datasources/intelligence_remote_datasource.dart';
import 'package:ohara/features/intelligence/data/repositories/intelligence_repository_impl.dart';
import 'package:ohara/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:ohara/features/intelligence/domain/entities/size_fit.dart';
import 'package:ohara/features/intelligence/domain/repositories/intelligence_repository.dart';

/// Wiring for the intelligence notes.
///
/// One family provider, keyed by product. No notifier: the notes are a read
/// over a nightly graph and there is nothing on the client to mutate.
///
/// Failures resolve to an empty list rather than an error state, deliberately.
/// These notes are an enhancement to a product page that works perfectly well
/// without them, and a red box where a helpful sentence might have been is a
/// worse page than one with no sentence at all.
final intelligenceDataSourceProvider = Provider<IntelligenceRemoteDataSource>(
  (ref) => IntelligenceRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final intelligenceRepositoryProvider = Provider<IntelligenceRepository>(
  (ref) => IntelligenceRepositoryImpl(ref.watch(intelligenceDataSourceProvider)),
);

final productNotesProvider = FutureProvider.autoDispose
    .family<List<IntelligenceNote>, String>((ref, productId) async {
      final result = await ref
          .watch(intelligenceRepositoryProvider)
          .notes(productId);
      return result.fold((_) => const <IntelligenceNote>[], (notes) => notes);
    });

/// How often each size of a product was kept. Empty on failure, for the same
/// reason as the notes: the size row works without it.
final productSizeFitProvider = FutureProvider.autoDispose
    .family<List<SizeFit>, String>((ref, productId) async {
      final result = await ref
          .watch(intelligenceRepositoryProvider)
          .sizeFit(productId);
      return result.fold((_) => const <SizeFit>[], (fits) => fits);
    });
