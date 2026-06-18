import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/comment.dart';

import '../../domain/entities/comment_page.dart';
import '../../domain/entities/post_engagement.dart';
import '../../domain/repositories/post_social_repository.dart';
import '../datasources/post_social_remote_datasource.dart';

class PostSocialRepositoryImpl
    with RepositoryHandler
    implements PostSocialRepository {
  const PostSocialRepositoryImpl(this.remote);

  final PostSocialRemoteDataSource remote;

  @override
  Future<Result<CommentPage>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
  }) =>
      guard(() => remote.getComments(postId, page: page, limit: limit));

  @override
  Future<Result<Comment>> addComment(String postId, String content) =>
      guard(() => remote.addComment(postId, content));

  @override
  Future<Result<void>> deleteComment(String postId, String commentId) =>
      guard(() => remote.deleteComment(postId, commentId));

  @override
  Future<Result<PostEngagement>> toggleLike(String postId) =>
      guard(() => remote.toggleLike(postId));

  @override
  Future<Result<PostEngagement>> toggleSave(String postId) =>
      guard(() => remote.toggleSave(postId));

  @override
  Future<Result<PostEngagement>> share(String postId) =>
      guard(() => remote.share(postId));
}
