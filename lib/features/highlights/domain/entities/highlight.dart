import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/entities/story.dart';

/// «الأبرز» — a named shelf of stories a woman keeps on her page.
///
/// A story lasts a day. A highlight is the permission to keep one longer, and
/// the shelf it stands on: the boutique's size guide, the salon's
/// before-and-after, a shopper's «إطلالاتي». It points at the stories rather
/// than copying them, so one taken down disappears from here too.
class Highlight extends Equatable {
  const Highlight({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.itemsCount,
    required this.sortOrder,
    required this.isMine,
    this.coverUrl,
    this.stories = const [],
  });

  final String id;
  final String ownerId;
  final String title;

  /// Her own cover, or the first story's still when she has not picked one.
  final String? coverUrl;

  final int itemsCount;
  final int sortOrder;

  /// True when the person looking at the rail is the person who owns it, which
  /// is what decides whether the edit affordances are drawn.
  final bool isMine;

  /// Only present on the detail read; the rail carries covers and counts.
  final List<Story> stories;

  bool get isEmpty => itemsCount == 0;

  @override
  List<Object?> get props => [
    id,
    ownerId,
    title,
    coverUrl,
    itemsCount,
    sortOrder,
    isMine,
    stories,
  ];
}
