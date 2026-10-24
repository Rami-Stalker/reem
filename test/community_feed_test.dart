// The community feed's state: the «أتابع» wire shape, gestures that reach a
// post and every reshare of it, «تراجع» without duplicates, and a next page
// that arrives after a refresh being dropped rather than appended.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/presentation/providers/paginated_notifier.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/social/data/models/content_model.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/repositories/social_repository.dart';
import 'package:ohara/features/social/presentation/providers/content_feed_notifier.dart';

void main() {
  group('«أتابع» wire shape', () {
    test('own and reshared entries decode as timeline entries', () {
      final own = timelineEntryFromJson({
        'kind': 'own',
        'content': _json('c1', 'u-a'),
      });
      final reshared = timelineEntryFromJson({
        'kind': 'reshare',
        'id': 'r1',
        'resharer': _userJson('u-b', 'لينا'),
        'note': 'بحبها',
        'reshared_at': '2026-10-01T10:00:00.000Z',
        'content': _json('c2', 'u-a'),
      });

      expect(own, isA<OwnContentEntry>());
      expect(own.content.id, 'c1');
      expect(reshared, isA<ResharedContentEntry>());
      final reshare = (reshared as ResharedContentEntry).reshare;
      expect(reshare.resharer.name, 'لينا');
      expect(reshare.content.id, 'c2');
      // The boutique keeps the credit.
      expect(reshare.content.author.id, 'u-a');
    });
  });

  group('TimelineFeedNotifier', () {
    test('a like reaches the post and every reshare of it', () async {
      final repo = _Repo();
      final notifier = TimelineFeedNotifier(
        repo,
        (_) async => Success(
          PaginatedData(
            items: [
              OwnContentEntry(_content('c1')),
              _reshare('r1', _content('c1')),
              OwnContentEntry(_content('c2')),
            ],
            pageInfo: const PageInfo(page: 1),
          ),
        ),
      );
      await notifier.load();

      await notifier.toggleLike('c1');

      final items = notifier.state.items;
      expect(items[0].content.viewer.isLiked, isTrue);
      expect(items[1].content.viewer.isLiked, isTrue);
      expect(items[1], isA<ResharedContentEntry>());
      expect(items[2].content.viewer.isLiked, isFalse);
      expect(items[0].content.counts.likes, 1);
      notifier.dispose();
    });

    test('a failed like is put back exactly as it was', () async {
      final repo = _Repo(fail: true);
      final notifier = TimelineFeedNotifier(
        repo,
        (_) async => Success(
          PaginatedData(
            items: [OwnContentEntry(_content('c1'))],
            pageInfo: const PageInfo(page: 1),
          ),
        ),
      );
      await notifier.load();
      await notifier.toggleLike('c1');
      expect(notifier.state.items.single.content.viewer.isLiked, isFalse);
      expect(notifier.state.items.single.content.counts.likes, 0);
      notifier.dispose();
    });

    test('«تراجع» restores what was hidden, once', () async {
      final notifier = TimelineFeedNotifier(
        _Repo(),
        (_) async => Success(
          PaginatedData(
            items: [
              OwnContentEntry(_content('c1')),
              _reshare('r1', _content('c1')),
              OwnContentEntry(_content('c2')),
            ],
            pageInfo: const PageInfo(page: 1),
          ),
        ),
      );
      await notifier.load();

      final removed = notifier.removeWhere((c) => c.id == 'c1');
      expect(removed, hasLength(2));
      expect(notifier.state.items, hasLength(1));

      notifier
        ..restore(removed)
        ..restore(removed);
      expect(
        notifier.state.items.map((e) => e.entryId),
        ['own:c1', 'reshare:r1', 'own:c2'],
      );
      notifier.dispose();
    });
  });

  group('PaginatedNotifier', () {
    test('a next page that lands after a refresh is dropped', () async {
      final pending = Completer<Result<PaginatedData<int>>>();
      var call = 0;
      final notifier = PaginatedNotifier<int>((request) {
        call++;
        if (call == 1) {
          return Future.value(
            Success(
              PaginatedData(
                items: [1, 2],
                pageInfo: const PageInfo(page: 1, hasNextPage: true),
              ),
            ),
          );
        }
        if (call == 2) return pending.future; // the slow next page
        return Future.value(
          Success(
            PaginatedData(
              items: [10, 11],
              pageInfo: const PageInfo(page: 1, hasNextPage: true),
            ),
          ),
        );
      });

      await notifier.load();
      final more = notifier.loadMore();
      await notifier.refresh();
      pending.complete(
        Success(
          PaginatedData(
            items: [3, 4],
            pageInfo: const PageInfo(page: 2, hasNextPage: false),
          ),
        ),
      );
      await more;

      expect(notifier.state.items, [10, 11]);
      expect(notifier.state.isLoadingMore, isFalse);
      expect(notifier.state.hasNextPage, isTrue);
      notifier.dispose();
    });

    test('a request that settles after dispose does not throw', () async {
      final pending = Completer<Result<PaginatedData<int>>>();
      final notifier = PaginatedNotifier<int>((_) => pending.future);
      final load = notifier.load();
      notifier.dispose();
      pending.complete(Success(PaginatedData.empty<int>()));
      await expectLater(load, completes);
    });
  });
}

// ── Fixtures ────────────────────────────────────────────────────────────────

final _author = User(
  id: 'u-a',
  name: 'أتيليه',
  username: 'atelier',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

final _resharer = User(
  id: 'u-b',
  name: 'لينا',
  username: 'lina',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

Content _content(String id) => Content(
  id: id,
  author: _author,
  authorKind: ContentAuthorKind.seller,
  format: ContentFormat.post,
  status: ContentStatus.published,
  moderationState: ContentModerationState.active,
  visibility: ContentVisibility.public,
  createdAt: DateTime(2026, 10, 1),
);

TimelineEntry _reshare(String id, Content content) => ResharedContentEntry(
  ContentReshare(
    id: id,
    resharer: _resharer,
    content: content,
    resharedAt: DateTime(2026, 10, 2),
  ),
);

Map<String, dynamic> _userJson(String id, String name) => {
  'id': id,
  'name': name,
  'username': id,
  'created_at': '2026-01-01T00:00:00.000Z',
};

Map<String, dynamic> _json(String id, String authorId) => {
  'id': id,
  'author': _userJson(authorId, 'أتيليه'),
  'author_kind': 'seller',
  'content_type': 'post',
  'status': 'published',
  'visibility': 'public',
  'created_at': '2026-10-01T10:00:00.000Z',
};

class _Repo implements SocialRepository {
  _Repo({this.fail = false});

  final bool fail;

  @override
  Future<Result<ContentViewerState>> react(
    String contentId, {
    String? emoji,
  }) async {
    if (fail) return const Error(NetworkFailure('offline'));
    return const Success(ContentViewerState(isLiked: true));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
