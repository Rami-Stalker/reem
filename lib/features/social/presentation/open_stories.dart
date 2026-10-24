import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/story.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/repositories/social_repository.dart';
import 'package:ohara/features/stories/presentation/screens/story_viewer_screen.dart';

/// Opens the one story viewer on stories that came from the content platform.
///
/// The community tray used to push its `List<StoryGroup>` straight into the
/// route's `extra`, and the route reads a `StoryViewerArgs` — so tapping a
/// story there threw a cast error instead of playing it. The viewer speaks
/// `Story`; a story is a `Content` with the story format and the same id, so
/// the conversion is a projection, and every legacy call the viewer makes
/// (view, react) addresses the right row.
///
/// Completes when the viewer closes, so a tray can redraw its rings as seen.
Future<void> openStoryGroups(
  BuildContext context,
  List<StoryGroup> groups, {
  int startGroup = 0,
}) async {
  final stories = [
    for (final group in groups.skip(startGroup))
      for (final story in group.stories) storyFromContent(story, group.allSeen),
  ];
  if (stories.isEmpty) return;
  await context.push<void>(
    RoutePaths.storyViewer,
    extra: StoryViewerArgs(stories: stories),
  );
}

/// The viewer's arguments for a flat run of stories, starting at one of them.
StoryViewerArgs storyViewerArgsFor(
  List<Content> stories, {
  int initialIndex = 0,
}) => StoryViewerArgs(
  stories: [for (final story in stories) storyFromContent(story)],
  initialIndex: initialIndex,
);

Story storyFromContent(Content content, [bool seen = false]) {
  final created = content.publishedAt ?? content.createdAt;
  return Story(
    id: content.id,
    user: content.author,
    media: content.media,
    productId: content.primaryTag?.product.id,
    isViewed: seen,
    myReaction: content.viewer.myReaction,
    // A story without an expiry is a data fault, not a permanent story: the
    // format's own rule is a day.
    expiresAt: content.expiresAt ?? created.add(const Duration(hours: 24)),
    createdAt: created,
  );
}
