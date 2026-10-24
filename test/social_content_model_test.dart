// Guards the social feed's decode path.
//
// The repository wraps every parse in `guard()`, so one throw inside
// `ContentModel.fromJson` does not produce a broken card — it swallows the
// entire feed into a single silent failure and the woman sees an empty screen
// with nothing in the logs. That exact failure has shipped twice on this
// project (a post with no product, a category that arrived as an object),
// which is why `post_model_test.dart` exists. This is its successor.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/features/social/data/models/content_model.dart';
import 'package:ohara/features/social/domain/entities/content.dart';

Map<String, dynamic> _author({bool verified = true}) => {
  'id': 'a1b2c3d4-0000-4000-8000-000000000001',
  'name': 'مها',
  'username': 'maha_shops',
  'bio': null,
  'image_url': null,
  'location': null,
  'role': 'customer',
  'seller_level': 'basic',
  'seller_verified_at': null,
  'seller_premium_until': null,
  'is_verified': verified,
  'followers_count': 3,
  'following_count': 8,
  'created_at': '2026-01-01T00:00:00.000Z',
};

Map<String, dynamic> _content({
  String contentType = 'product_post',
  String authorKind = 'customer',
  List<dynamic>? media,
  List<dynamic>? productTags,
  Map<String, dynamic>? analytics,
  Map<String, dynamic>? viewer,
  String moderationState = 'active',
  String? expiresAt,
}) => {
  'id': 'c0000000-0000-4000-8000-000000000001',
  'author': _author(),
  'author_kind': authorKind,
  'content_type': contentType,
  'title': null,
  'body': 'لبستها اليوم 💕',
  'locale': 'ar',
  'status': 'published',
  'visibility': 'public',
  'moderation_status': 'approved',
  'moderation_state': moderationState,
  'removal_reason': null,
  'removed_at': null,
  'payload': {'caption': 'لبستها اليوم 💕'},
  'metadata': null,
  'publication_targets': ['home_feed'],
  'scheduled_at': null,
  'published_at': '2026-09-01T10:00:00.000Z',
  'expires_at': expiresAt,
  'archived_at': null,
  'pinned_until': null,
  'media': media ?? const [],
  'product_tags': productTags ?? const [],
  'analytics': analytics ?? const {},
  'created_at': '2026-09-01T10:00:00.000Z',
  'updated_at': '2026-09-01T10:00:00.000Z',
  'viewer': ?viewer,
};

void main() {
  group('ContentModel', () {
    test('decodes a bare content-only post', () {
      // No media, no products, no viewer block, no analytics. Every one of
      // those is a shape the server genuinely sends, and each has emptied a
      // feed before.
      final content = ContentModel.fromJson(_content());
      expect(content.id, isNotEmpty);
      expect(content.caption, 'لبستها اليوم 💕');
      expect(content.hasMedia, isFalse);
      expect(content.hasProducts, isFalse);
      expect(content.counts.likes, 0);
      expect(content.viewer.isLiked, isFalse);
    });

    test('reads the author kind as a fact, not from the role', () {
      // What she was when she wrote it. A shopper who later opens a boutique
      // did not retroactively write marketing.
      expect(
        ContentModel.fromJson(_content(authorKind: 'customer')).authorKind,
        ContentAuthorKind.customer,
      );
      expect(
        ContentModel.fromJson(_content(authorKind: 'seller')).authorKind,
        ContentAuthorKind.seller,
      );
    });

    test('an unknown format degrades to a post rather than throwing', () {
      // A format enabled server-side must appear in the feed on the day it is
      // enabled, looking plain — not crash the client that has not shipped
      // support for it.
      final content = ContentModel.fromJson(
        _content(contentType: 'something_new'),
      );
      expect(content.format, ContentFormat.post);
    });

    test('a reel exposes its clip', () {
      final content = ContentModel.fromJson(
        _content(
          contentType: 'reel',
          media: [
            {
              'id': 'm1',
              'url': 'https://example.com/clip.mp4',
              'type': 'video',
              'thumbnail_url': 'https://example.com/clip.jpg',
              'blur_hash': null,
              'duration_ms': 12000,
              'sort_order': 0,
            },
          ],
        ),
      );
      expect(content.format, ContentFormat.reel);
      expect(content.video, isNotNull);
      expect(content.video!.url, 'https://example.com/clip.mp4');
    });

    test('a tag whose product was delisted is dropped, not rendered', () {
      // The server sends the tag without a product when the catalogue entry is
      // gone. Keeping it would draw a "shop this" plate that leads nowhere.
      final content = ContentModel.fromJson(
        _content(
          productTags: [
            {'id': 't1', 'role': 'featured', 'sort_order': 0, 'product': null},
          ],
        ),
      );
      expect(content.productTags, isEmpty);
      expect(content.primaryTag, isNull);
    });

    test('counters survive arriving as doubles', () {
      // They are BigInt columns server-side; a JSON parser may widen them.
      final content = ContentModel.fromJson(
        _content(
          analytics: {
            'views': 1845.0,
            'reactions': 12,
            'replies': 3,
            'saves': 48.0,
            'shares': 38,
            'product_clicks': 111,
          },
        ),
      );
      expect(content.counts.views, 1845);
      expect(content.counts.likes, 12);
      expect(content.counts.saves, 48);
    });

    test('the viewer block is what a card renders, and it is optional', () {
      final without = ContentModel.fromJson(_content());
      expect(without.viewer.isLiked, isFalse);
      expect(without.viewer.isReshared, isFalse);

      final with_ = ContentModel.fromJson(
        _content(
          viewer: {
            'is_liked': true,
            'my_reaction': '😍',
            'is_saved': true,
            'is_reshared': true,
          },
        ),
      );
      expect(with_.viewer.isLiked, isTrue);
      expect(with_.viewer.myReaction, '😍');
      expect(with_.viewer.isReshared, isTrue);
    });

    test('a live story knows it has not expired', () {
      final future = DateTime.now()
          .add(const Duration(hours: 5))
          .toIso8601String();
      final content = ContentModel.fromJson(
        _content(contentType: 'story', expiresAt: future),
      );
      expect(content.isLiveStory, isTrue);

      final past = DateTime.now()
          .subtract(const Duration(hours: 5))
          .toIso8601String();
      expect(
        ContentModel.fromJson(
          _content(contentType: 'story', expiresAt: past),
        ).isLiveStory,
        isFalse,
      );
    });

    test('removed content says so, and carries its reason', () {
      final json = _content(moderationState: 'removed');
      json['removal_reason'] = 'الصورة لا تلتزم بسياسة المحتوى.';
      final content = ContentModel.fromJson(json);
      expect(content.isRemoved, isTrue);
      expect(content.removalReason, isNotNull);
    });
  });

  group('timelineEntryFromJson', () {
    test('a reshare nests the original whole, with its own author', () {
      // The requirement, as a decode assertion: the boutique keeps the credit,
      // and the resharer cannot be mistaken for the source.
      final entry = timelineEntryFromJson({
        'kind': 'reshare',
        'id': 'r1',
        'resharer': _author(),
        'note': 'لقيتها هون',
        'reshared_at': '2026-09-05T12:00:00.000Z',
        'content': _content(authorKind: 'seller'),
      });

      expect(entry, isA<ResharedContentEntry>());
      final reshare = (entry as ResharedContentEntry).reshare;
      expect(reshare.note, 'لقيتها هون');
      expect(reshare.content.authorKind, ContentAuthorKind.seller);
      expect(entry.entryId, startsWith('reshare:'));
    });

    test('her own post is an own entry, keyed apart from a reshare', () {
      final entry = timelineEntryFromJson({
        'kind': 'own',
        'content': _content(),
      });
      expect(entry, isA<OwnContentEntry>());
      expect(entry.entryId, startsWith('own:'));
    });

    test('a reshare and its original never collide as list keys', () {
      final own = timelineEntryFromJson({'kind': 'own', 'content': _content()});
      final reshared = timelineEntryFromJson({
        'kind': 'reshare',
        'id': 'r1',
        'resharer': _author(),
        'note': null,
        'reshared_at': '2026-09-05T12:00:00.000Z',
        'content': _content(),
      });
      expect(own.entryId, isNot(reshared.entryId));
    });
  });

  test('a real feed envelope decodes end to end', () {
    // The shape the datasource actually receives, cursor pagination included.
    final body =
        jsonDecode(
              jsonEncode({
                'data': [_content(), _content(contentType: 'reel')],
                'pagination': {
                  'limit': 20,
                  'has_next_page': true,
                  'next_cursor': 'MjAyNi0wOS0wMXwx',
                },
              }),
            )
            as Map<String, dynamic>;

    final items = (body['data'] as List)
        .map((item) => ContentModel.fromJson(item as Map<String, dynamic>))
        .toList();
    expect(items, hasLength(2));
    expect(items[1].format, ContentFormat.reel);
    expect((body['pagination'] as Map)['next_cursor'], isNotEmpty);
  });
}
