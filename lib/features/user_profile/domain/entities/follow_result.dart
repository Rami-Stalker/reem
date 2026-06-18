import 'package:equatable/equatable.dart';

/// Outcome of a follow/unfollow mutation, used to update UI optimistically.
class FollowResult extends Equatable {
  final bool isFollowing;
  final int followersCount;

  const FollowResult({
    required this.isFollowing,
    required this.followersCount,
  });

  @override
  List<Object?> get props => [isFollowing, followersCount];
}
