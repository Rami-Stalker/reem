import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/profile/domain/repositories/profile_repository.dart';

class SaveSellerUseCase {
  const SaveSellerUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<void>> call(String sellerId) => repository.saveSeller(sellerId);
}
