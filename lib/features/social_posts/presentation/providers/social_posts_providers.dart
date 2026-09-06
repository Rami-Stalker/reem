import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/social_posts/data/datasources/impl/post_social_remote_datasource_impl.dart';
import 'package:reem/features/social_posts/data/datasources/post_social_remote_datasource.dart';
import 'package:reem/features/social_posts/data/repositories/post_social_repository_impl.dart';
import 'package:reem/features/social_posts/domain/repositories/post_social_repository.dart';
import 'package:reem/features/social_posts/domain/usecases/add_comment_usecase.dart';
import 'package:reem/features/social_posts/domain/usecases/delete_comment_usecase.dart';
import 'package:reem/features/social_posts/domain/usecases/get_comments_usecase.dart';
import 'package:reem/features/social_posts/domain/usecases/post_engagement_usecases.dart';
import 'package:reem/features/social_posts/presentation/providers/comments_notifier.dart';
import 'package:reem/features/social_posts/presentation/providers/comments_state.dart';

final postSocialRemoteDataSourceProvider = Provider<PostSocialRemoteDataSource>(
  (ref) => PostSocialRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final postSocialRepositoryProvider = Provider<PostSocialRepository>(
  (ref) =>
      PostSocialRepositoryImpl(ref.watch(postSocialRemoteDataSourceProvider)),
);

final getCommentsUseCaseProvider = Provider(
  (ref) => GetCommentsUseCase(ref.watch(postSocialRepositoryProvider)),
);
final addCommentUseCaseProvider = Provider(
  (ref) => AddCommentUseCase(ref.watch(postSocialRepositoryProvider)),
);
final deleteCommentUseCaseProvider = Provider(
  (ref) => DeleteCommentUseCase(ref.watch(postSocialRepositoryProvider)),
);
final toggleLikeUseCaseProvider = Provider(
  (ref) => ToggleLikeUseCase(ref.watch(postSocialRepositoryProvider)),
);
final toggleSaveUseCaseProvider = Provider(
  (ref) => ToggleSaveUseCase(ref.watch(postSocialRepositoryProvider)),
);
final sharePostUseCaseProvider = Provider(
  (ref) => SharePostUseCase(ref.watch(postSocialRepositoryProvider)),
);

/// Comment thread for a given post id.
final commentsNotifierProvider = StateNotifierProvider.autoDispose
    .family<CommentsNotifier, CommentsState, String>((ref, postId) {
      return CommentsNotifier(
        postId: postId,
        getComments: ref.watch(getCommentsUseCaseProvider),
        addComment: ref.watch(addCommentUseCaseProvider),
        deleteComment: ref.watch(deleteCommentUseCaseProvider),
        currentUser: ref.watch(authNotifierProvider.select((s) => s.user)),
      )..load();
    });
