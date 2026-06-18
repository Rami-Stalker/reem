import 'package:reem/core/result/result.dart';

import '../entities/post_engagement.dart';
import '../repositories/post_social_repository.dart';

class ToggleLikeUseCase {
  const ToggleLikeUseCase(this._repository);
  final PostSocialRepository _repository;
  Future<Result<PostEngagement>> call(String postId) =>
      _repository.toggleLike(postId);
}

class ToggleSaveUseCase {
  const ToggleSaveUseCase(this._repository);
  final PostSocialRepository _repository;
  Future<Result<PostEngagement>> call(String postId) =>
      _repository.toggleSave(postId);
}

class SharePostUseCase {
  const SharePostUseCase(this._repository);
  final PostSocialRepository _repository;
  Future<Result<PostEngagement>> call(String postId) =>
      _repository.share(postId);
}
