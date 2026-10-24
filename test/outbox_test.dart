// The offline write queue. The property worth most of these tests: the like
// endpoint is a *toggle*, so a naive replay of a request that actually landed
// would undo her. The queue stores the state she wanted and reconciles, which
// is what makes a replay safe.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/observability/error_reporter.dart';
import 'package:ohara/core/sync/outbox.dart';
import 'package:ohara/core/sync/outbox_intent.dart';

/// A server we can lie to.
class _FakeHandler implements OutboxHandler {
  _FakeHandler(this.kind, {this.state = false});

  @override
  final String kind;

  /// What the server currently says. Null means "unreachable".
  bool? state;

  /// Thrown by [readState] instead of answering.
  Object? readError;

  int reads = 0;
  int toggles = 0;

  @override
  Future<bool?> readState(String entityId) async {
    reads++;
    final error = readError;
    if (error != null) throw error;
    return state;
  }

  @override
  Future<void> toggle(String entityId) async {
    toggles++;
    state = !(state ?? false);
  }
}

void main() {
  late Directory dir;
  late DateTime clock;

  Outbox build({int maxAttempts = 5, Duration? maxAge, int capacity = 200}) =>
      Outbox(
        directory: dir,
        now: () => clock,
        maxAttempts: maxAttempts,
        maxAge: maxAge ?? const Duration(days: 3),
        capacity: capacity,
      );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('reem_outbox_test');
    clock = DateTime(2026, 9, 1, 12);
    ErrorReporter.clearBreadcrumbs();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('a queued intent the server already agrees with is not re-sent',
      () async {
    // She tapped like, it landed, the response was lost. A request replay
    // would un-like it. Reconciling notices the server already agrees.
    final handler = _FakeHandler('post.like', state: true);
    final outbox = build()..register(handler);

    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    await outbox.drain();

    expect(handler.toggles, 0, reason: 'her like was already there');
    expect(handler.reads, 1);
    expect(outbox.pending, isEmpty);
  });

  test('a queued intent the server disagrees with is sent once', () async {
    final handler = _FakeHandler('post.like');
    final outbox = build()..register(handler);

    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    await outbox.drain();

    expect(handler.toggles, 1);
    expect(handler.state, true);
    expect(outbox.pending, isEmpty);
  });

  test('repeated taps on one heart collapse into the last one', () async {
    final handler = _FakeHandler('post.like');
    final outbox = build()..register(handler);

    // Liked, un-liked, liked again — all while offline.
    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: false);
    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);

    expect(outbox.pending, hasLength(1), reason: 'one entity, one intent');

    await outbox.drain();
    expect(handler.toggles, 1);
    expect(handler.state, true);
  });

  test('likes and saves on the same post are separate intents', () async {
    final like = _FakeHandler('post.like');
    final save = _FakeHandler('post.save');
    final outbox = build()
      ..register(like)
      ..register(save);

    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    await outbox.enqueue(kind: 'post.save', entityId: 'p1', desired: true);

    expect(outbox.pending, hasLength(2));
    await outbox.drain();
    expect(like.toggles, 1);
    expect(save.toggles, 1);
  });

  test('an unreachable server defers rather than guessing', () async {
    final handler = _FakeHandler('post.like')..state = null;
    final outbox = build()..register(handler);

    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    await outbox.drain();

    expect(handler.toggles, 0, reason: 'an unknown state is not `false`');
    expect(outbox.pending, hasLength(1));
    expect(outbox.pending.single.attempts, 1);
  });

  test('a connection failure defers; a refusal is abandoned', () async {
    final flaky = _FakeHandler('post.like')
      ..readError = const SocketException('connection failed');
    final refusing = _FakeHandler('post.save')
      ..readError = StateError('post was deleted');
    final outbox = build()
      ..register(flaky)
      ..register(refusing);

    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    await outbox.enqueue(kind: 'post.save', entityId: 'p1', desired: true);
    await outbox.drain();

    expect(outbox.pending.map((i) => i.kind), ['post.like']);
  });

  test('it gives up out loud rather than retrying forever', () async {
    final handler = _FakeHandler('post.like')..state = null;
    final outbox = build(maxAttempts: 3)..register(handler);

    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    for (var i = 0; i < 4; i++) {
      await outbox.drain();
    }

    expect(outbox.pending, isEmpty);
    expect(
      ErrorReporter.breadcrumbs.map((c) => c.message).join(' '),
      contains('abandoned'),
    );
  });

  test('an intent older than its window is dropped', () async {
    final handler = _FakeHandler('post.like')..state = null;
    final outbox = build(maxAge: const Duration(hours: 1))
      ..register(handler);

    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);
    clock = clock.add(const Duration(hours: 2));
    await outbox.drain();

    expect(outbox.pending, isEmpty);
    expect(handler.reads, 0, reason: 'a stale intent is not worth a request');
  });

  test('the queue survives the app being killed', () async {
    final first = build()..register(_FakeHandler('post.like'));
    await first.enqueue(kind: 'post.like', entityId: 'p1', desired: true);

    // A new launch: fresh object, same folder.
    final handler = _FakeHandler('post.like');
    final second = build()..register(handler);
    await second.drain();

    expect(handler.toggles, 1, reason: 'her tap outlived the process');
  });

  test('the queue is bounded, dropping the oldest', () async {
    final outbox = build(capacity: 2)..register(_FakeHandler('post.like'));

    for (final id in ['p1', 'p2', 'p3']) {
      clock = clock.add(const Duration(seconds: 1));
      await outbox.enqueue(kind: 'post.like', entityId: id, desired: true);
    }

    expect(
      outbox.pending.map((i) => i.entityId),
      ['p2', 'p3'],
    );
  });

  test('the UI can ask what is still hers but unsent', () async {
    final outbox = build()..register(_FakeHandler('post.like'));
    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);

    expect(outbox.isPending('post.like', 'p1'), isTrue);
    expect(outbox.desiredState('post.like', 'p1'), isTrue);
    expect(outbox.isPending('post.like', 'p2'), isFalse);
    expect(outbox.desiredState('post.save', 'p1'), isNull);
  });

  test('an intent whose handler no longer exists is dropped, not retried',
      () async {
    final first = build()..register(_FakeHandler('legacy.kind'));
    await first.enqueue(kind: 'legacy.kind', entityId: 'p1', desired: true);

    // A later build that no longer knows that kind.
    final second = build();
    await second.drain();

    expect(second.pending, isEmpty);
  });

  test('concurrent drains share one pass', () async {
    final handler = _FakeHandler('post.like');
    final outbox = build()..register(handler);
    await outbox.enqueue(kind: 'post.like', entityId: 'p1', desired: true);

    await Future.wait([outbox.drain(), outbox.drain(), outbox.drain()]);

    expect(handler.toggles, 1, reason: 'not sent three times');
  });
}
