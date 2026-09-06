import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/user.dart';

import 'package:reem/features/user_profile/domain/entities/seller_stats.dart';

/// A user's profile as seen by a viewer: the user plus the viewer's
/// relationship to them and aggregate engagement/commerce stats.
class UserProfile extends Equatable {
  final User user;
  final bool isMe;
  final bool isFollowing;
  final int productsCount;
  final int postsCount;
  final SellerStats? sellerStats;

  const UserProfile({
    required this.user,
    this.isMe = false,
    this.isFollowing = false,
    this.productsCount = 0,
    this.postsCount = 0,
    this.sellerStats,
  });

  bool get isSeller => user.isSeller;

  UserProfile copyWith({
    User? user,
    bool? isMe,
    bool? isFollowing,
    int? productsCount,
    int? postsCount,
    SellerStats? sellerStats,
  }) {
    return UserProfile(
      user: user ?? this.user,
      isMe: isMe ?? this.isMe,
      isFollowing: isFollowing ?? this.isFollowing,
      productsCount: productsCount ?? this.productsCount,
      postsCount: postsCount ?? this.postsCount,
      sellerStats: sellerStats ?? this.sellerStats,
    );
  }

  @override
  List<Object?> get props => [
    user,
    isMe,
    isFollowing,
    productsCount,
    postsCount,
    sellerStats,
  ];
}
