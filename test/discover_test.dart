import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_message.dart';
import 'package:ohara/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/stylist_chat_notifier.dart';
import 'package:ohara/features/rooms/domain/entities/room.dart';
import 'package:ohara/features/search/presentation/discover_waiting.dart';

/// Discover opens on what her life says she needs, and on a question that
/// arrives at the stylist already asked. These pin both halves.
void main() {
  group('the rooms Discover opens with', () {
    Room room(
      String id, {
      DateTime? on,
      RoomStatus status = RoomStatus.deciding,
    }) => Room(
      id: id,
      kind: RoomKind.occasion,
      status: status,
      title: id,
      targetDate: on,
    );

    // 21:30 UTC is already 00:30 the next day in Damascus.
    final clock = DateTime.utc(2026, 10, 21, 21, 30);

    test('days are counted on her calendar, not the handset\'s', () {
      final upcoming = upcomingRooms([
        room('wedding', on: DateTime.utc(2026, 10, 22, 6)),
      ], clock: clock);

      expect(upcoming.single.daysLeft, 0, reason: 'it is already the 22nd');
    });

    test('only open, dated rooms still ahead of her, soonest first', () {
      final upcoming = upcomingRooms(
        [
          room('later', on: DateTime.utc(2026, 11, 2, 9)),
          room('undated'),
          room('past', on: DateTime.utc(2026, 10, 19, 9)),
          room(
            'bought',
            on: DateTime.utc(2026, 10, 23, 9),
            status: RoomStatus.purchased,
          ),
          room(
            'archived',
            on: DateTime.utc(2026, 10, 23, 9),
            status: RoomStatus.archived,
          ),
          room('soon', on: DateTime.utc(2026, 10, 24, 9)),
        ],
        clock: clock,
        limit: 5,
      );

      expect(upcoming.map((u) => u.room.id), ['soon', 'later']);
      expect(upcoming.map((u) => u.daysLeft), [2, 11]);
    });

    test('at most two, so the question stays the first thing she sees', () {
      final upcoming = upcomingRooms([
        for (var day = 23; day <= 27; day++)
          room('r$day', on: DateTime.utc(2026, 10, day, 9)),
      ], clock: clock);

      expect(upcoming, hasLength(2));
    });
  });

  group('a question asked on Discover', () {
    test('opens a fresh conversation carrying it', () async {
      final repository = _Repository();
      final notifier = StylistChatNotifier(repository);
      repository.releaseBootstraps();

      await notifier.ask('فستان لعرس صيفي');

      expect(repository.asked, ['فستان لعرس صيفي']);
      expect(notifier.state.messages.map((m) => m.content), [
        'فستان لعرس صيفي',
        'جمعتُ لكِ ثلاث إطلالات',
      ]);
      expect(notifier.state.brief.occasion, 'WEDDING');
    });

    test('a slow opening load cannot undo the answer it was outrun by', () async {
      final repository = _Repository();
      // The constructor's bootstrap is still in flight when she asks.
      final notifier = StylistChatNotifier(repository);

      final asking = notifier.ask('فستان لعرس صيفي');
      // Release the ask's own bootstrap, let the turn complete, and only then
      // let the constructor's stale bootstrap land.
      repository.releaseBootstrap(1);
      await asking;
      repository.releaseBootstrap(0);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.brief.occasion, 'WEDDING');
      expect(notifier.state.messages, hasLength(2));
    });

    test('an empty question asks nothing', () async {
      final repository = _Repository();
      final notifier = StylistChatNotifier(repository);
      repository.releaseBootstraps();

      await notifier.ask('   ');

      expect(repository.asked, isEmpty);
    });
  });
}

/// A stylist whose opening loads finish only when the test says so.
class _Repository implements AiStylistRepository {
  final _bootstraps = <Completer<Result<StylistBootstrap>>>[];
  final asked = <String>[];
  bool _releaseAll = false;

  void releaseBootstrap(int index) => _bootstraps[index].complete(
    const Success(
      StylistBootstrap(seedBrief: StyleBrief(occasion: 'SEED')),
    ),
  );

  void releaseBootstraps() {
    _releaseAll = true;
    for (var i = 0; i < _bootstraps.length; i++) {
      if (!_bootstraps[i].isCompleted) releaseBootstrap(i);
    }
  }

  @override
  Future<Result<StylistBootstrap>> bootstrap() {
    final completer = Completer<Result<StylistBootstrap>>();
    _bootstraps.add(completer);
    if (_releaseAll) releaseBootstrap(_bootstraps.length - 1);
    return completer.future;
  }

  @override
  Future<Result<StylistTurn>> startConversation({
    String? title,
    String? message,
  }) async {
    asked.add(message ?? '');
    final at = DateTime.utc(2026, 10, 21);
    const brief = StyleBrief(intent: 'BUILD_OUTFIT', occasion: 'WEDDING');
    return Success(
      StylistTurn(
        conversation: StylistConversation(id: 'c1', createdAt: at),
        userMessage: StylistMessage(
          id: 'm1',
          conversationId: 'c1',
          role: StylistRole.user,
          content: message ?? '',
          createdAt: at,
        ),
        assistantMessage: StylistMessage(
          id: 'm2',
          conversationId: 'c1',
          role: StylistRole.assistant,
          content: 'جمعتُ لكِ ثلاث إطلالات',
          createdAt: at,
        ),
        brief: brief,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
