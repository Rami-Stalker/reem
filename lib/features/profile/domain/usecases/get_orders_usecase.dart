import 'package:reem/core/result/result.dart';

import '../entities/order_entity.dart';
import '../repositories/profile_repository.dart';

class GetOrdersUseCase {
  const GetOrdersUseCase(this._repository);
  final ProfileRepository _repository;

  Future<Result<List<OrderEntity>>> call() => _repository.getOrders();
}
