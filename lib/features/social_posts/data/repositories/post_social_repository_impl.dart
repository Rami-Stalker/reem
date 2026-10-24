import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/comment.dart';
import 'package:ohara/features/social_posts/data/datasources/post_social_remote_datasource.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_page.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_thread.dart';
import 'package:ohara/features/social_posts/domain/entities/post_engagement.dart';
import 'package:ohara/features/social_posts/domain/repositories/post_social_repository.dart';

class PostSocialRepositoryImpl
    with RepositoryHandler
    implements PostSocialRepository {
  const PostSocialRepositoryImpl(this.remote);

  final PostSocialRemoteDataSource remote;

  @override
  Future<Result<CommentPage>> getComments(
    CommentThread thread, {
    int page = 1,
    int limit = 20,
  }) =>
      guard(() => remote.getComments(thread, page: page, limit: limit));

  @override
  Future<Result<Comment>> addComment(CommentThread thread, String content) =>
      guard(() => remote.addComment(thread, content));

  @override
  Future<Result<void>> deleteComment(CommentThread thread, String commentId) =>
      guard(() => remote.deleteComment(thread, commentId));

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
