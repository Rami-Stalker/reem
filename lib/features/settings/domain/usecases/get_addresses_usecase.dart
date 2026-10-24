import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/settings/domain/entities/address_entity.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';

class GetAddressesUseCase {
  const GetAddressesUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<AddressEntity>>> call() => _repository.getAddresses();
}
