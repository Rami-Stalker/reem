import 'package:equatable/equatable.dart';

/// The engagement snapshot returned after like/save/share mutations.
class PostEngagement extends Equatable {
  final bool isLiked;
  final int likesCount;
  final bool isSaved;
  final int savesCount;
  final int sharesCount;

  const PostEngagement({
    required this.isLiked,
    required this.likesCount,
    required this.isSaved,
    required this.savesCount,
    required this.sharesCount,
  });

  @override
  List<Object?> get props =>
      [isLiked, likesCount, isSaved, savesCount, sharesCount];
}
