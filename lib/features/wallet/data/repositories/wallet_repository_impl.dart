import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:ohara/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:ohara/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl with RepositoryHandler implements WalletRepository {
  const WalletRepositoryImpl(this.remote);

  final WalletRemoteDataSource remote;

  @override
  Future<Result<WalletSummary>> load({int take = 30}) =>
      guard(() => remote.load(take: take));

  @override
  Future<Result<WalletSummary>> convertPoints(int points) =>
      guard(() => remote.convertPoints(points));
}
