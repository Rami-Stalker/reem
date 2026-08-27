import 'package:reem/features/invoices/data/models/invoice_model.dart';

abstract interface class InvoicesRemoteDataSource {
  /// Every document raised against one order (Q51 — hers and each seller's).
  Future<List<InvoiceSummaryModel>> listForOrder(String orderId);

  Future<InvoiceModel> byId(String invoiceId);

  /// Issues the customer's copy. Idempotent — the backend returns the same
  /// document with the same number on every call after the first.
  Future<InvoiceSummaryModel> issueForOrder(String orderId);
}
