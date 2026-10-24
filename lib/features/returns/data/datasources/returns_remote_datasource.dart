import 'package:ohara/features/returns/domain/entities/return_eligibility.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';

/// The customer's half of `/returns`.
///
/// Every route here has existed since the returns module landed and had no
/// caller: the seller's desk could approve, refuse and receive a return that
/// no customer had any way to open. The reason and status vocabulary is shared
/// with the seller's side rather than duplicated — one wire contract, one set
/// of Arabic labels.
abstract interface class ReturnsRemoteDataSource {
  /// What this parcel can still send back, read before the form is drawn.
  Future<ReturnEligibility> eligibility(String sellerOrderId);

  /// Her own returns, newest first.
  Future<List<ReturnRequest>> mine();

  Future<ReturnRequest> request({
    required String sellerOrderId,
    required ReturnReason reason,
    String? reasonNote,
    List<String>? evidence,
    required List<({String orderItemId, int quantity})> items,
  });

  Future<ReturnRequest> cancel(String id);
}
