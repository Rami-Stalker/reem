import 'package:reem/core/result/result.dart';
import 'package:reem/features/invoices/domain/entities/invoice.dart';

abstract interface class InvoicesRepository {
  Future<Result<List<InvoiceSummary>>> listForOrder(String orderId);
  Future<Result<Invoice>> byId(String invoiceId);
  Future<Result<InvoiceSummary>> issueForOrder(String orderId);
}
