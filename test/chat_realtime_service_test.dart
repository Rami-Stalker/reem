// The chat socket on a phone is cut all the time. These cases pin what the
// service does about it: reconnect with a growing backoff, join the
// conversations again, tell the screens to fetch what they missed — and stop
// for good when told to disconnect.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/storage/secure_storage_service.dart';
import 'package:ohara/features/chat/data/services/chat_realtime_service.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _TokenStorage extends SecureStorageService {
  _TokenStorage(this.token);
  String? token;

  @override
  Future<String?> read(String key) async =>
      key == SecureStorageKeys.accessToken ? token : null;
}

class _FakeSink extends Fake implements WebSocketSink {
  final sent = <Map<String, dynamic>>[];
  final _done = Completer<void>();

  @override
  void add(dynamic data) =>
      sent.add(Map<String, dynamic>.from(jsonDecode(data as String) as Map));

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

class _FakeChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeChannel({this.fail = false, this.hang = false});

  final bool fail;
  /// A handshake nobody answers — the network dropped it, or the host is
  /// still starting.
  final bool hang;
  final incoming = StreamController<dynamic>();
  // Closed by the service under test; nothing else writes to it.
  @override
  // ignore: close_sinks
  final _FakeSink sink = _FakeSink();
  final List<String> protocols = [];

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  Future<void> get ready => hang
      ? Completer<void>().future
      : fail
      ? Future.error(WebSocketChannelException('refused'))
      : Future.value();

  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;

  void ready_() => incoming.add(jsonEncode({'event': 'connection.ready'}));
  void drop() => incoming.close();
}

class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  test('a dropped connection comes back, rejoins its rooms and says so', () {
    fakeAsync((async) {
      final opened = <_FakeChannel>[];
      final service = ChatRealtimeService(
        _TokenStorage('token-1'),
        random: _ZeroRandom(),
        channelFactory: (uri, protocols) {
          final channel = _FakeChannel()..protocols.addAll(protocols);
          opened.add(channel);
          return channel;
        },
      );
      final events = <String>[];
      service.events.listen((e) => events.add(e['event'] as String));

      service.connect();
      async.flushMicrotasks();
      expect(opened, hasLength(1));
      // The token rides as a subprotocol, never in the URL.
      expect(opened.first.protocols, ['reem.auth.bearer', 'token-1']);

      opened.first.ready_();
      async.flushMicrotasks();
      service.join('chat-1');
      expect(events, ['connection.ready']);

      opened.first.drop();
      async.flushMicrotasks();
      expect(service.isConnected, isFalse);

      async.elapse(const Duration(milliseconds: 1100));
      expect(opened, hasLength(2), reason: 'reconnected after the first backoff');
      opened[1].ready_();
      async.flushMicrotasks();

      expect(
        opened[1].sink.sent,
        contains(equals({'event': 'conversation.join', 'chat_id': 'chat-1'})),
      );
      expect(events, ['connection.ready', 'connection.ready', 'connection.restored']);
      service.disconnect();
      async.flushMicrotasks();
    });
  });

  test('a refused handshake is retried with a growing backoff', () {
    fakeAsync((async) {
      var attempts = 0;
      final service = ChatRealtimeService(
        _TokenStorage('t'),
        random: _ZeroRandom(),
        channelFactory: (uri, protocols) {
          attempts += 1;
          return _FakeChannel(fail: true);
        },
      );
      service.connect();
      async.flushMicrotasks();
      expect(attempts, 1);
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 2);
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 2, reason: 'second wait is two seconds');
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 3);
      service.disconnect();
      async.flushMicrotasks();
    });
  });

  test('a handshake nobody answers is abandoned and retried', () {
    fakeAsync((async) {
      var attempts = 0;
      final service = ChatRealtimeService(
        _TokenStorage('t'),
        random: _ZeroRandom(),
        channelFactory: (uri, protocols) {
          attempts += 1;
          return _FakeChannel(hang: attempts == 1);
        },
      );
      service.connect();
      async.flushMicrotasks();
      expect(attempts, 1);
      // Still waiting within the limit: a sleeping host takes about a minute.
      async.elapse(const Duration(seconds: 60));
      expect(attempts, 1);
      async.elapse(ChatRealtimeService.handshakeTimeout);
      async.elapse(const Duration(seconds: 2));
      expect(attempts, 2, reason: 'retried after the handshake limit');
      service.disconnect();
      async.flushMicrotasks();
    });
  });

  test('disconnect stops every retry', () {
    fakeAsync((async) {
      var attempts = 0;
      final service = ChatRealtimeService(
        _TokenStorage('t'),
        random: _ZeroRandom(),
        channelFactory: (uri, protocols) {
          attempts += 1;
          return _FakeChannel(fail: true);
        },
      );
      service.connect();
      async.flushMicrotasks();
      service.disconnect();
      async.elapse(const Duration(minutes: 5));
      expect(attempts, 1);
    });
  });

  test('signed out, it does not try to connect at all', () {
    fakeAsync((async) {
      var attempts = 0;
      final service = ChatRealtimeService(
        _TokenStorage(null),
        channelFactory: (uri, protocols) {
          attempts += 1;
          return _FakeChannel();
        },
      );
      service.connect();
      async.elapse(const Duration(minutes: 1));
      expect(attempts, 0);
    });
  });

  test('backoff doubles to a thirty-second ceiling, with bounded jitter', () {
    final zero = _ZeroRandom();
    expect(ChatRealtimeService.backoffFor(0, zero), const Duration(seconds: 1));
    expect(ChatRealtimeService.backoffFor(3, zero), const Duration(seconds: 8));
    expect(ChatRealtimeService.backoffFor(20, zero), const Duration(seconds: 30));
    final jittered = ChatRealtimeService.backoffFor(20, Random(7));
    expect(jittered.inMilliseconds, inInclusiveRange(30000, 36000));
  });
}
