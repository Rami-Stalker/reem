import 'package:reem/core/result/result.dart';

import '../entities/coupon_entity.dart';
import '../repositories/settings_repository.dart';

class GetCouponsUseCase {
  const GetCouponsUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<CouponEntity>>> call() => _repository.getCoupons();
}
