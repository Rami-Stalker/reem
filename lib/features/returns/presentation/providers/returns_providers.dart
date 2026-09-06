import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/returns/data/datasources/impl/returns_remote_datasource_impl.dart';
import 'package:reem/features/returns/data/datasources/returns_remote_datasource.dart';
import 'package:reem/features/returns/data/repositories/returns_repository_impl.dart';
import 'package:reem/features/returns/domain/entities/return_eligibility.dart';
import 'package:reem/features/returns/domain/repositories/returns_repository.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';

final returnsRemoteDataSourceProvider = Provider<ReturnsRemoteDataSource>(
  (ref) => ReturnsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final returnsRepositoryProvider = Provider<ReturnsRepository>(
  (ref) => ReturnsRepositoryImpl(ref.watch(returnsRemoteDataSourceProvider)),
);

/// What this parcel can still send back.
///
/// Keyed by seller order rather than by order: a two-boutique order is two
/// parcels with two delivery dates and two windows, and asking one question
/// about both would be answering neither.
final returnEligibilityProvider =
    FutureProvider.family<ReturnEligibility, String>((ref, sellerOrderId) async {
      final result = await ref
          .watch(returnsRepositoryProvider)
          .eligibility(sellerOrderId);
      return result.fold(
        (failure) => throw FailureException(failure),
        (eligibility) => eligibility,
      );
    });

/// Her own returns, newest first.
final myReturnsProvider = FutureProvider<List<ReturnRequest>>((ref) async {
  final result = await ref.watch(returnsRepositoryProvider).mine();
  return result.fold(
    (failure) => throw FailureException(failure),
    (requests) => requests,
  );
});
