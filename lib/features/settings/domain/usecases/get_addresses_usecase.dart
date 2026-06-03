import 'package:reem/core/result/result.dart';

import '../entities/address_entity.dart';
import '../repositories/settings_repository.dart';

class GetAddressesUseCase {
  const GetAddressesUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<AddressEntity>>> call() => _repository.getAddresses();
}
