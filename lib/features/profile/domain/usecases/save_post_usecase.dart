import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/profile/domain/repositories/profile_repository.dart';

class SavePostUseCase {
  const SavePostUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<void>> call(String postId) => repository.savePost(postId);
}
