import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/wallet/domain/entities/wallet_transaction.dart';

/// Her store credit.
///
/// There is no `withdraw` here, and there must never be one: Q42 settles that
/// the balance is spendable inside Ohara and not payable out as cash. The
/// restriction is expressed the same way it is on the server — by the absence
/// of a method rather than a flag someone can pass.
abstract interface class WalletRepository {
  Future<Result<WalletSummary>> load({int take});

  Future<Result<WalletSummary>> convertPoints(int points);
}
