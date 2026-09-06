import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/errors/failure.dart';
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

/// What the invoices screen is looking at: the documents, or the reason there
/// are none.
///
/// The two are not the same thing and the screen used to show one message for
/// both — an order too early to invoice and a request that failed outright
/// both read as «لا فواتير بعد», so a network problem looked like a rule.
sealed class InvoicesView {
  const InvoicesView();
}

/// Documents exist and here they are.
final class InvoicesIssued extends InvoicesView {
  const InvoicesIssued(this.rows);
  final List<InvoiceSummary> rows;
}

/// The order cannot be invoiced yet — it has not started moving (Q39/Q51).
final class InvoicesNotYet extends InvoicesView {
  const InvoicesNotYet();
}

/// The documents raised against one order.
///
/// Issues the customer's copy on first read: a document nobody has asked for
/// does not need to exist, but the moment she opens the screen she has asked.
final orderInvoicesProvider =
    FutureProvider.autoDispose.family<InvoicesView, String>((
      ref,
      orderId,
    ) async {
      final repository = ref.watch(invoicesRepositoryProvider);

      final existing = await repository.listForOrder(orderId);
      final rows = switch (existing) {
        Success(:final data) => data,
        Error(:final failure) => throw failure,
      };
      if (rows.isNotEmpty) return InvoicesIssued(rows);

      // Nothing issued yet — raise hers, then re-read so any seller copies
      // raised in the meantime come along too.
      final issued = await repository.issueForOrder(orderId);
      if (issued case Error(:final failure)) {
        // The server refuses an order that is still changeable, which is the
        // ordinary case for a basket placed an hour ago, not a fault.
        if (failure is ForbiddenFailure) return const InvoicesNotYet();
        throw failure;
      }

      final refreshed = await repository.listForOrder(orderId);
      return switch (refreshed) {
        Success(:final data) => InvoicesIssued(data),
        Error(:final failure) => throw failure,
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
