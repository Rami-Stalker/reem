import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/user_profile/domain/entities/seller_stats.dart';

/// A user's profile as seen by a viewer: the user plus the viewer's
/// relationship to them and aggregate engagement/commerce stats.
class UserProfile extends Equatable {
  final User user;
  final bool isMe;
  final bool isFollowing;
  final int productsCount;
  final int postsCount;

  /// Pieces she added to her page that this viewer may see.
  final int picksCount;

  /// A live story this viewer may watch — the ring on her avatar.
  final bool hasStory;

  /// Whether her page is open. A shopper's page is private until she opens
  /// it; a boutique is always public. A closed page has to be able to say so,
  /// or a visitor reads an empty page as a woman who never posted.
  final bool profileIsPublic;
  final SellerStats? sellerStats;

  const UserProfile({
    required this.user,
    this.isMe = false,
    this.isFollowing = false,
    this.productsCount = 0,
    this.postsCount = 0,
    this.picksCount = 0,
    this.hasStory = false,
    this.profileIsPublic = false,
    this.sellerStats,
  });

  bool get isSeller => user.isSeller;

  /// Whether a visitor may see what is on this page. Her own page is always
  /// readable to her; a boutique's to everyone.
  bool get isReadable => isMe || isSeller || profileIsPublic;

  UserProfile copyWith({
    User? user,
    bool? isMe,
    bool? isFollowing,
    int? productsCount,
    int? postsCount,
    int? picksCount,
    bool? hasStory,
    bool? profileIsPublic,
    SellerStats? sellerStats,
  }) {
    return UserProfile(
      user: user ?? this.user,
      isMe: isMe ?? this.isMe,
      isFollowing: isFollowing ?? this.isFollowing,
      productsCount: productsCount ?? this.productsCount,
      postsCount: postsCount ?? this.postsCount,
      picksCount: picksCount ?? this.picksCount,
      hasStory: hasStory ?? this.hasStory,
      profileIsPublic: profileIsPublic ?? this.profileIsPublic,
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
    picksCount,
    hasStory,
    profileIsPublic,
    sellerStats,
  ];
}
