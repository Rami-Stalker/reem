import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/invoices/data/datasources/impl/invoices_remote_datasource_impl.dart';
import 'package:reem/features/invoices/data/datasources/invoices_remote_datasource.dart';
import 'package:reem/features/invoices/data/repositories/invoices_repository_impl.dart';
import 'package:reem/features/invoices/domain/entities/invoice.dart';
import 'package:reem/features/invoices/domain/repositories/invoices_repository.dart';

final invoicesRemoteDataSourceProvider = Provider<InvoicesRemoteDataSource>(
  (ref) => InvoicesRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final invoicesRepositoryProvider = Provider<InvoicesRepository>(
  (ref) => InvoicesRepositoryImpl(ref.watch(invoicesRemoteDataSourceProvider)),
);

/// The documents raised against one order.
///
/// Issues the customer's copy on first read: a document nobody has asked for
/// does not need to exist, but the moment she opens the screen she has asked.
final orderInvoicesProvider =
    FutureProvider.autoDispose.family<List<InvoiceSummary>, String>((
      ref,
      orderId,
    ) async {
      final repository = ref.watch(invoicesRepositoryProvider);

      final existing = await repository.listForOrder(orderId);
      final rows = switch (existing) {
        Success(:final data) => data,
        Error(:final failure) => throw Exception(failure.message),
      };
      if (rows.isNotEmpty) return rows;

      // Nothing issued yet — raise hers, then re-read so any seller copies
      // raised in the meantime come along too.
      final issued = await repository.issueForOrder(orderId);
      if (issued case Error(:final failure)) {
        throw Exception(failure.message);
      }

      final refreshed = await repository.listForOrder(orderId);
      return switch (refreshed) {
        Success(:final data) => data,
        Error(:final failure) => throw Exception(failure.message),
      };
    });

final invoiceDetailProvider = FutureProvider.autoDispose
    .family<Invoice, String>((ref, invoiceId) async {
      final result = await ref.watch(invoicesRepositoryProvider).byId(invoiceId);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw Exception(failure.message),
      };
    });
