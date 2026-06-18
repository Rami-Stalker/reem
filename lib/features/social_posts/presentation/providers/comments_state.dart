import 'package:reem/core/shared/entities/comment.dart';

class CommentsState {
  const CommentsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.comments = const [],
    this.error,
    this.page = 1,
    this.hasNextPage = false,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<Comment> comments;
  final String? error;
  final int page;
  final bool hasNextPage;

  bool get isEmpty => !isLoading && comments.isEmpty;

  CommentsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Comment>? comments,
    String? error,
    int? page,
    bool? hasNextPage,
    bool clearError = false,
  }) {
    return CommentsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      comments: comments ?? this.comments,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
    );
  }
}
