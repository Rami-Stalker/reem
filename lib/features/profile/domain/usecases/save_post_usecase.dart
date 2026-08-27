import 'package:reem/core/result/result.dart';

import 'package:reem/features/profile/domain/repositories/profile_repository.dart';

class SavePostUseCase {
  const SavePostUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<void>> call(String postId) => repository.savePost(postId);
}
