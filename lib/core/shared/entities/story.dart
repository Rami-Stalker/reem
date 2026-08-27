// shared/entities/story.dart

import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/user.dart';

class Story extends Equatable {
  final String id;
  final User user;

  /// One or more media frames that make up the story.
  final List<MediaItem> media;

  final String? link;
  final bool isViewed;

  /// The current viewer's reaction emoji, if any.
  final String? myReaction;

  final DateTime expiresAt;
  final DateTime createdAt;

  const Story({
    required this.id,
    required this.user,
    this.media = const [],
    this.link,
    this.isViewed = false,
    this.myReaction,
    required this.expiresAt,
    required this.createdAt,
  });

  /// First frame — the story's cover.
  MediaItem? get cover => media.isNotEmpty ? media.first : null;
  String? get coverUrl => cover?.displayUrl;

  bool get isActive => expiresAt.isAfter(DateTime.now());
  bool get hasReacted => myReaction != null;

  @override
  List<Object?> get props => [
        id,
        user,
        media,
        link,
        isViewed,
        myReaction,
        expiresAt,
        createdAt,
      ];
}
