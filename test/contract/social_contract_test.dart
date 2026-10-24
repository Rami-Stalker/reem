// Contract tests for the social surface, run against responses captured from a
// live server *before* the content platform merge.
//
// They exist for one reason. `/posts/*` and `/stories/*` are being
// re-implemented on top of `CommerceContent`, and the promise that made that
// safe was "the JSON does not change" — a promise nothing was holding, because
// `test/contract/` covered neither endpoint and `test/fixtures/posts_feed.json`
// was the sole artifact in the repository.
//
// So these assert the **wire shape**, not just that the client can decode it.
// A key added, renamed or dropped by the new implementation fails here, which
// is the whole point: the fixtures are regenerated from the new code at cutover
// and the diff must be empty.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/shared/models/comment_model.dart';
import 'package:ohara/core/shared/models/post_model.dart';
import 'package:ohara/core/shared/models/story_model.dart';
import 'package:ohara/features/social_posts/data/models/comment_page_model.dart';
import 'package:ohara/features/social_posts/data/models/post_engagement_model.dart';
import 'package:ohara/features/stories/data/models/story_analytics_model.dart';
import 'package:ohara/features/stories/data/models/story_viewer_model.dart';

dynamic _raw(String name) =>
    jsonDecode(File('test/contract/$name').readAsStringSync());

Map<String, dynamic> _object(String name) => _raw(name) as Map<String, dynamic>;

List<dynamic> _array(String name) => _raw(name) as List<dynamic>;

/// The offset envelope every paged customer endpoint speaks. The new
/// `/content/*` routes are cursor-paged instead, which is exactly why this has
/// to be pinned: the legacy routes must keep answering in the old shape.
const _paginationKeys = <String>{
  'page',
  'limit',
  'total',
  'total_pages',
  'has_next_page',
};

const _postKeys = <String>{
  'id',
  'author',
  'product',
  'caption',
  'likes_count',
  'comments_count',
  'shares_count',
  'saves_count',
  'is_liked',
  'is_saved',
  'is_reshared',
  'created_at',
};

const _commentKeys = <String>{
  'id',
  'user',
  'content',
  'likes_count',
  'created_at',
};

const _storyKeys = <String>{
  'id',
  'user',
  'media',
  'link',
  'is_viewed',
  'my_reaction',
  'expires_at',
  'created_at',
};

void _expectEnvelope(Map<String, dynamic> body) {
  expect(body.keys.toSet(), {'data', 'pagination'});
  final pagination = body['pagination'] as Map<String, dynamic>;
  expect(pagination.keys.toSet(), _paginationKeys);
  expect(pagination['page'], isA<int>());
  expect(pagination['total'], isA<int>());
  expect(pagination['has_next_page'], isA<bool>());
}

void main() {
  group('GET /posts/feed', () {
    late Map<String, dynamic> body;
    late List<dynamic> data;

    setUpAll(() {
      body = _object('posts_feed.json');
      data = body['data'] as List<dynamic>;
    });

    test('answers in the offset envelope, exactly these keys', () {
      _expectEnvelope(body);
    });

    test('every post carries exactly the twelve contract keys', () {
      expect(data, isNotEmpty);
      for (final item in data) {
        expect((item as Map<String, dynamic>).keys.toSet(), _postKeys);
      }
    });

    test('the fixture covers both post shapes', () {
      // A post that tags a product and one that tags none. The second is the
      // shape that used to throw inside `PostModel.fromJson` and empty the
      // whole feed, so a fixture without it proves nothing.
      final tagged = data.where((p) => (p as Map)['product'] != null);
      final untagged = data.where((p) => (p as Map)['product'] == null);
      expect(tagged, isNotEmpty, reason: 'no post tags a product');
      expect(untagged, isNotEmpty, reason: 'no post is content-only');
    });

    test('decodes into PostModel, counters and viewer flags intact', () {
      for (final item in data) {
        final json = Map<String, dynamic>.from(item as Map);
        final post = PostModel.fromJson(json);
        expect(post.id, isNotEmpty);
        expect(post.author.id, isNotEmpty);
        expect(post.likesCount, json['likes_count']);
        expect(post.savesCount, json['saves_count']);
        expect(post.isLiked, json['is_liked']);
        expect(post.isSaved, json['is_saved']);
        expect(post.hasProduct, json['product'] != null);
      }
    });

    test('a post reads its engagement summary from the same payload', () {
      // `POST /posts/:id/like` answers with the serialized post, and the client
      // parses it as an engagement summary. Both readings must hold.
      final json = Map<String, dynamic>.from(data.first as Map);
      final engagement = PostEngagementModel.fromJson(json);
      expect(engagement.likesCount, json['likes_count']);
      expect(engagement.sharesCount, json['shares_count']);
    });
  });

  group('GET /posts/:id', () {
    test('a single post is the same object as a feed entry', () {
      final body = _object('post_single.json');
      expect(body.keys.toSet(), _postKeys);
      expect(PostModel.fromJson(body).id, body['id']);
    });
  });

  group('GET /posts/seller/:id', () {
    test('is the feed envelope narrowed to one author', () {
      final body = _object('posts_by_seller.json');
      _expectEnvelope(body);
      final data = body['data'] as List<dynamic>;
      expect(data, isNotEmpty);
      final authors = <String>{
        for (final p in data) ((p as Map)['author'] as Map)['id'] as String,
      };
      expect(authors.length, 1, reason: 'a seller page mixed in another author');
    });
  });

  group('GET /posts/saved', () {
    test('is the feed envelope, and every entry is saved', () {
      final body = _object('posts_saved.json');
      _expectEnvelope(body);
      final data = body['data'] as List<dynamic>;
      expect(data, isNotEmpty);
      for (final item in data) {
        expect(
          (item as Map)['is_saved'],
          isTrue,
          reason: 'the saved list returned a post the viewer has not saved',
        );
      }
    });
  });

  group('GET /posts/:id/comments', () {
    late Map<String, dynamic> body;

    setUpAll(() => body = _object('post_comments.json'));

    test('is the feed envelope with comment objects', () {
      _expectEnvelope(body);
      for (final item in body['data'] as List<dynamic>) {
        expect((item as Map<String, dynamic>).keys.toSet(), _commentKeys);
      }
    });

    test('decodes through CommentPageModel and CommentModel', () {
      final page = CommentPageModel.fromJson(body);
      expect(page.items, isNotEmpty);
      expect(page.page, (body['pagination'] as Map)['page']);
      expect(page.hasNextPage, (body['pagination'] as Map)['has_next_page']);
      for (final comment in page.items) {
        expect(comment.content, isNotEmpty);
        expect(comment.user.id, isNotEmpty);
      }
    });

    test('likes_count is present and always zero', () {
      // Nothing writes it — `serializeComment` emits a literal. Pinned so the
      // rewrite keeps emitting the key (the client reads it) without anyone
      // mistaking it for a number with a source behind it.
      final first = CommentModel.fromJson(
        Map<String, dynamic>.from((body['data'] as List).first as Map),
      );
      expect(first.likesCount, 0);
    });
  });

  group('GET /stories', () {
    late List<dynamic> data;

    setUpAll(() => data = _array('stories_list.json'));

    test('is a bare array, not an envelope', () {
      // The one customer list endpoint with no pagination. If the rewrite wraps
      // it, every stories rail in the app goes blank.
      expect(data, isNotEmpty);
    });

    test('every story carries exactly the eight contract keys', () {
      for (final item in data) {
        expect((item as Map<String, dynamic>).keys.toSet(), _storyKeys);
      }
    });

    test('media is a single object, and viewer state survives decoding', () {
      for (final item in data) {
        final json = Map<String, dynamic>.from(item as Map);
        expect(
          json['media'],
          isA<Map<String, dynamic>>(),
          reason: 'the contract sends one media object, not a list',
        );
        expect((json['media'] as Map).keys.toSet(), {'url', 'type'});

        final story = StoryModel.fromJson(json);
        expect(story.media, hasLength(1));
        expect(story.isViewed, json['is_viewed']);
        expect(story.myReaction, json['my_reaction']);

        // The **window**, not `isActive`. `isActive` is
        // `expiresAt.isAfter(DateTime.now())`, and these fixtures are a frozen
        // capture — so asserting it here was asserting the wall clock, and it
        // started failing the day the captured story aged past its own expiry.
        // What the contract actually promises is the pair of timestamps and
        // the 24-hour life between them; that holds no matter when the suite
        // runs.
        expect(story.expiresAt, DateTime.parse(json['expires_at'] as String));
        expect(
          story.expiresAt.difference(story.createdAt).inMinutes,
          closeTo(24 * 60, 1),
          reason: 'a story lives for a day from the moment it is posted',
        );
      }
    });
  });

  group('GET /seller/stories/:id/analytics', () {
    test('keys and derived engagement rate hold', () {
      final body = _object('story_analytics.json');
      expect(body.keys.toSet(), {
        'story_id',
        'views_count',
        'reactions_count',
        'reaction_breakdown',
        'engagement_rate',
        'expires_at',
        'created_at',
      });

      final analytics = StoryAnalyticsModel.fromJson(body);
      expect(analytics.viewsCount, body['views_count']);
      expect(analytics.reactionsCount, body['reactions_count']);
      expect(analytics.reactionBreakdown, isNotEmpty);
      // Computed server-side as reactions/views, to one decimal place.
      expect(
        analytics.engagementRate,
        closeTo(analytics.reactionsCount / analytics.viewsCount * 100, 0.1),
      );
    });
  });

  group('GET /seller/stories/:id/viewers', () {
    test('is a bare array of user + viewed_at + reaction', () {
      final data = _array('story_viewers.json');
      expect(data, isNotEmpty);
      for (final item in data) {
        expect((item as Map<String, dynamic>).keys.toSet(), {
          'user',
          'viewed_at',
          'reaction',
        });
        final entry = StoryViewerModel.fromJson(Map<String, dynamic>.from(item));
        expect(entry.user.id, isNotEmpty);
      }
    });
  });
}
