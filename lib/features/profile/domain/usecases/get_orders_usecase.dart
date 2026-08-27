import 'package:reem/core/result/result.dart';

import 'package:reem/features/profile/domain/entities/order_entity.dart';
import 'package:reem/features/profile/domain/repositories/profile_repository.dart';

class GetOrdersUseCase {
  const GetOrdersUseCase(this._repository);
  final ProfileRepository _repository;

  Future<Result<List<OrderEntity>>> call() => _repository.getOrders();
}
