import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/impl/post_social_remote_datasource_impl.dart';
import '../../data/datasources/post_social_remote_datasource.dart';
import '../../data/repositories/post_social_repository_impl.dart';
import '../../domain/repositories/post_social_repository.dart';
import '../../domain/usecases/add_comment_usecase.dart';
import '../../domain/usecases/delete_comment_usecase.dart';
import '../../domain/usecases/get_comments_usecase.dart';
import '../../domain/usecases/post_engagement_usecases.dart';
import 'comments_notifier.dart';
import 'comments_state.dart';

final postSocialRemoteDataSourceProvider =
    Provider<PostSocialRemoteDataSource>(
  (ref) => PostSocialRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final postSocialRepositoryProvider = Provider<PostSocialRepository>(
  (ref) => PostSocialRepositoryImpl(
    ref.watch(postSocialRemoteDataSourceProvider),
  ),
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
