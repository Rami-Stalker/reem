import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/invoices/data/datasources/invoices_remote_datasource.dart';
import 'package:ohara/features/invoices/domain/entities/invoice.dart';
import 'package:ohara/features/invoices/domain/repositories/invoices_repository.dart';

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
