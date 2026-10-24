import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ohara/core/config/app_env.dart';
import 'package:ohara/core/storage/secure_storage_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Names the value that follows it as a bearer token.
///
/// The access token used to be a query parameter, which is the one part of a
/// request that every proxy between the handset and the API writes into its
/// access log — and it is the whole token, replayable against HTTP just as
/// readily as against this socket until it expires. A header is the right
/// place for a credential, but the browser's `WebSocket` accepts none: a URL
/// and a subprotocol list are all it takes. So the token rides as the second
/// subprotocol, which reaches the server as `Sec-WebSocket-Protocol`.
///
/// Deliberately one code path rather than headers on mobile and this on the
/// web: the same handshake everywhere is the one that stays tested.
const _authProtocol = 'reem.auth.bearer';

/// Opens a socket. A seam for tests; the app uses [WebSocketChannel.connect].
typedef ChannelFactory =
    WebSocketChannel Function(Uri uri, Iterable<String> protocols);

/// The chat's live connection to the API (`/ws/chats`).
///
/// **It stays connected.** A socket on a phone is cut all the time — a lift, a
/// handover between towers, the app going to the background, the server
/// restarting for a deploy (it closes with 1001 and expects everyone back).
/// The first version connected once and, on any of those, simply stopped: the
/// conversation looked open and never received another message until she left
/// the screen and came back. Now a dropped connection is reopened with a
/// widening, jittered backoff (so a server restart is not met by every phone at
/// the same instant), the token is read afresh on each attempt (it may have
/// been refreshed meanwhile), and the conversations she had joined are joined
/// again.
///
/// **It says when it came back.** Messages sent while the socket was down
/// were never delivered to it, so after a reconnection [events] carries
/// `{event: connection.restored}` and the screens fetch what they missed. The
/// first connection does not emit it — nothing was missed yet.
///
/// Liveness is the server's job: it pings every 25 s and the platform's
/// WebSocket answers pongs on its own, so the app runs no timer of its own
/// while connected.
class ChatRealtimeService {
  ChatRealtimeService(
    this._storage, {
    ChannelFactory? channelFactory,
    Random? random,
  }) : _channelFactory =
           channelFactory ??
           ((uri, protocols) =>
               WebSocketChannel.connect(uri, protocols: protocols)),
       _random = random ?? Random();

  static const Duration _initialBackoff = Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 30);

  /// How long an opening handshake may take before it is abandoned and
  /// retried. Long, on purpose: a hosted instance that was asleep answers its
  /// first request only once it has started, which takes about a minute — a
  /// shorter limit would abandon exactly the attempt that woke it. Without any
  /// limit, a handshake the network silently dropped would hang for ever and
  /// no retry would ever be scheduled.
  static const Duration handshakeTimeout = Duration(seconds: 90);

  final SecureStorageService _storage;
  final ChannelFactory _channelFactory;
  final Random _random;
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  // Cancelled in [_closeChannel]; the lint cannot follow it through the local.
  // ignore: cancel_subscriptions
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _connecting;
  Timer? _retryTimer;
  int _failures = 0;

  /// Whether a screen wants the connection. Cleared only by [disconnect].
  bool _wanted = false;

  /// Set once a connection has been ready, so the next one is a restoration.
  bool _everReady = false;

  /// Conversations joined, re-joined after every reconnection.
  final Set<String> _rooms = {};

  Stream<Map<String, dynamic>> get events => _events.stream;

  /// True while a socket is open.
  bool get isConnected => _channel != null;

  /// Opens the connection if it is not open, and keeps it open until
  /// [disconnect]. Safe to call from every screen that needs it.
  Future<void> connect() {
    _wanted = true;
    if (_channel != null) return Future.value();
    return _connecting ??= _open().whenComplete(() => _connecting = null);
  }

  /// Reconnects now rather than at the next backoff step — for the app
  /// returning to the foreground, where waiting out a 30 s backoff that grew
  /// while she was away would be the wrong way round.
  void reconnectNow() {
    if (!_wanted || _channel != null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _failures = 0;
    unawaited(connect());
  }

  void join(String chatId) {
    _rooms.add(chatId);
    send({'event': 'conversation.join', 'chat_id': chatId});
  }

  void leave(String chatId) {
    _rooms.remove(chatId);
    send({'event': 'conversation.leave', 'chat_id': chatId});
  }

  void typing(String chatId, bool isTyping) {
    send({'event': 'typing', 'chat_id': chatId, 'is_typing': isTyping});
  }

  void markRead(String chatId, {String? messageId}) {
    send({
      'event': 'message.read',
      'chat_id': chatId,
      'message_id': ?messageId,
    });
  }

  /// Sends a frame if connected. Nothing sent here is the only copy of
  /// anything — messages go through the API — so a frame that finds the
  /// socket down is dropped rather than queued.
  void send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(payload));
  }

  /// Closes the connection and stops reconnecting — sign-out, or the provider
  /// going away.
  Future<void> disconnect() async {
    _wanted = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _rooms.clear();
    _failures = 0;
    _everReady = false;
    await _closeChannel();
  }

  // ── Internals ───────────────────────────────────────────────────────────

  Future<void> _open() async {
    final token = await _storage.read(SecureStorageKeys.accessToken);
    // Signed out: nothing to connect as. A later [connect] tries again.
    if (!_wanted || token == null || token.isEmpty) return;

    WebSocketChannel? attempt;
    try {
      // The token travels as a subprotocol, not in the URL — see [_authProtocol].
      attempt = _channelFactory(_wsUri(), [_authProtocol, token]);
      await attempt.ready.timeout(handshakeTimeout);
    } catch (_) {
      unawaited(attempt?.sink.close().catchError((_) {}));
      _scheduleRetry();
      return;
    }
    final channel = attempt;
    if (!_wanted) {
      await channel.sink.close();
      return;
    }

    _channel = channel;
    _subscription = channel.stream.listen(
      _onFrame,
      onError: (_) => _onDropped(channel),
      onDone: () => _onDropped(channel),
      cancelOnError: true,
    );
  }

  void _onFrame(dynamic event) {
    if (event is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(event);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final payload = Map<String, dynamic>.from(decoded);

    if (payload['event'] == 'connection.ready') {
      _failures = 0;
      for (final chatId in _rooms) {
        send({'event': 'conversation.join', 'chat_id': chatId});
      }
      final restored = _everReady;
      _everReady = true;
      _events.add(payload);
      if (restored) _events.add(const {'event': 'connection.restored'});
      return;
    }
    _events.add(payload);
  }

  void _onDropped(WebSocketChannel channel) {
    // A late callback from a socket already replaced must not tear down the
    // one that replaced it.
    if (!identical(channel, _channel)) return;
    unawaited(_closeChannel());
    _scheduleRetry();
  }

  Future<void> _closeChannel() async {
    final channel = _channel;
    _channel = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    try {
      await channel?.sink.close();
    } catch (_) {
      // Already closed by the other side.
    }
  }

  void _scheduleRetry() {
    if (!_wanted || _retryTimer != null) return;
    final delay = backoffFor(_failures, _random);
    _failures += 1;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_wanted && _channel == null) unawaited(connect());
    });
  }

  /// 1, 2, 4 … capped at 30 s, each with up to a fifth added at random, so a
  /// thousand phones cut by the same restart do not all return in the same
  /// second.
  static Duration backoffFor(int failures, Random random) {
    final exponent = min(failures, 5);
    final base = min(
      _initialBackoff.inMilliseconds * pow(2, exponent).toInt(),
      _maxBackoff.inMilliseconds,
    );
    final jitter = random.nextInt(base ~/ 5 + 1);
    return Duration(milliseconds: base + jitter);
  }

  Uri _wsUri() {
    final base = Uri.parse(AppEnv.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    // Kept under any path prefix the API is served from (`…/api/ws/chats`).
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(scheme: scheme, path: '$prefix/ws/chats');
  }
}
