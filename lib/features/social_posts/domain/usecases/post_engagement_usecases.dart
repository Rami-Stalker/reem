import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/social_posts/domain/entities/post_engagement.dart';
import 'package:ohara/features/social_posts/domain/repositories/post_social_repository.dart';

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
