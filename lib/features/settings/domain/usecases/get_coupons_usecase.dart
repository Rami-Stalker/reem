import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/settings/domain/entities/coupon_entity.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';

class GetCouponsUseCase {
  const GetCouponsUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<CouponEntity>>> call() => _repository.getCoupons();
}
