import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../../models/invoice_model.dart';
import '../invoices_remote_datasource.dart';

final class InvoicesRemoteDataSourceImpl extends BaseRemoteDataSource
    implements InvoicesRemoteDataSource {
  const InvoicesRemoteDataSourceImpl(super.dio);

  @override
  Future<List<InvoiceSummaryModel>> listForOrder(String orderId) async {
    final rows = await getList(ApiEndpoints.invoicesForOrder(orderId));
    return rows
        .whereType<Map<String, dynamic>>()
        .map(InvoiceSummaryModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<InvoiceModel> byId(String invoiceId) async {
    final json = await getJson(ApiEndpoints.invoiceById(invoiceId));
    return InvoiceModel.fromJson(json);
  }

  @override
  Future<InvoiceSummaryModel> issueForOrder(String orderId) async {
    final json = await postJson(ApiEndpoints.invoicesForOrder(orderId));
    return InvoiceSummaryModel.fromJson(json);
  }
}
