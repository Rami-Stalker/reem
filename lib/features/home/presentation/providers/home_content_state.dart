import 'package:equatable/equatable.dart';

import 'package:reem/features/home/domain/entities/home_content.dart';

/// State for the aggregated home merchandising content.
class HomeContentState extends Equatable {
  const HomeContentState({
    this.isLoading = true,
    this.content,
    this.error,
  });

  final bool isLoading;
  final HomeContent? content;
  final String? error;

  bool get hasContent => content != null;

  /// Loading the very first time (no content to show yet) → full skeletons.
  bool get isInitialLoading => isLoading && content == null;

  HomeContentState copyWith({
    bool? isLoading,
    HomeContent? content,
    String? error,
    bool clearError = false,
  }) {
    return HomeContentState(
      isLoading: isLoading ?? this.isLoading,
      content: content ?? this.content,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [isLoading, content, error];
}
