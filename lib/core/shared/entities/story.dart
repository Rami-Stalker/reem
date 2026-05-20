// shared/entities/story.dart

import 'package:equatable/equatable.dart';

import 'product_media.dart';
import 'user.dart';

class Story extends Equatable {
  final String id;
  final User user;
  final ProductMedia media;
  final String? link;
  final bool isViewed;
  final DateTime expiresAt;
  final DateTime createdAt;

  const Story({
    required this.id,
    required this.user,
    required this.media,
    this.link,
    required this.isViewed,
    required this.expiresAt,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    user,
    media,
    link,
    isViewed,
    expiresAt,
    createdAt,
  ];
}
