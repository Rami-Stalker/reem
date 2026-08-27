import 'package:reem/core/result/result.dart';

import 'package:reem/features/settings/domain/entities/address_entity.dart';
import 'package:reem/features/settings/domain/repositories/settings_repository.dart';

class GetAddressesUseCase {
  const GetAddressesUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<AddressEntity>>> call() => _repository.getAddresses();
}
