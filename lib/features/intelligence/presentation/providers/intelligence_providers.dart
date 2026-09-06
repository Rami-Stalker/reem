import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/intelligence/data/datasources/impl/intelligence_remote_datasource_impl.dart';
import 'package:reem/features/intelligence/data/datasources/intelligence_remote_datasource.dart';
import 'package:reem/features/intelligence/data/repositories/intelligence_repository_impl.dart';
import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:reem/features/intelligence/domain/repositories/intelligence_repository.dart';

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
