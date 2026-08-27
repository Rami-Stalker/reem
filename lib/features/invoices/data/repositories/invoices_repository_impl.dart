import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../datasources/invoices_remote_datasource.dart';

class InvoicesRepositoryImpl with RepositoryHandler implements InvoicesRepository {
  const InvoicesRepositoryImpl(this.remote);

  final InvoicesRemoteDataSource remote;

  @override
  Future<Result<List<InvoiceSummary>>> listForOrder(String orderId) =>
      guard(() => remote.listForOrder(orderId));

  @override
  Future<Result<Invoice>> byId(String invoiceId) =>
      guard(() => remote.byId(invoiceId));

  @override
  Future<Result<InvoiceSummary>> issueForOrder(String orderId) =>
      guard(() => remote.issueForOrder(orderId));
}
