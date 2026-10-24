import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/user.dart';

/// One woman who watched her story or reel, and how she answered it.
class ContentViewer extends Equatable {
  const ContentViewer({
    required this.user,
    required this.viewedAt,
    this.reaction,
  });

  final User user;
  final DateTime viewedAt;

  /// The emoji she sent, if any.
  final String? reaction;

  @override
  List<Object?> get props => [user.id, viewedAt, reaction];
}

/// «شوهدت من قبل» — who watched one of her own pieces.
///
/// Owner-only on the server, for a shopper's story as much as a boutique's.
class ContentAudience extends Equatable {
  const ContentAudience({
    required this.contentId,
    this.views = 0,
    this.viewersCount = 0,
    this.reactions = 0,
    this.reactionBreakdown = const {},
    this.viewers = const [],
  });

  final String contentId;

  /// Every play, repeats included.
  final int views;

  /// Distinct women.
  final int viewersCount;
  final int reactions;
  final Map<String, int> reactionBreakdown;

  /// Most recent first.
  final List<ContentViewer> viewers;

  @override
  List<Object?> get props => [
    contentId,
    views,
    viewersCount,
    reactions,
    viewers,
  ];
}
