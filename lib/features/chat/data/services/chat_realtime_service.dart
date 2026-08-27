import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/storage/secure_storage_service.dart';

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

class ChatRealtimeService {
  ChatRealtimeService(this._storage);

  final SecureStorageService _storage;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect() async {
    if (_channel != null) return;
    final token = await _storage.read(SecureStorageKeys.accessToken);
    if (token == null || token.isEmpty) return;

    final uri = _wsUri();
    // The token travels as a subprotocol, not in the URL — see [_authProtocol].
    final channel = WebSocketChannel.connect(
      uri,
      protocols: [_authProtocol, token],
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      (event) {
        if (event is! String) return;
        final decoded = jsonDecode(event);
        if (decoded is Map) {
          _events.add(Map<String, dynamic>.from(decoded));
        }
      },
      onError: (_) => disconnect(),
      onDone: () => disconnect(),
      cancelOnError: true,
    );
  }

  void join(String chatId) {
    send({'event': 'conversation.join', 'chat_id': chatId});
  }

  void leave(String chatId) {
    send({'event': 'conversation.leave', 'chat_id': chatId});
  }

  void typing(String chatId, bool isTyping) {
    send({'event': 'typing', 'chat_id': chatId, 'is_typing': isTyping});
  }

  void markRead(String chatId, {String? messageId}) {
    send({
      'event': 'message.read',
      'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
    });
  }

  void send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(payload));
  }

  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;
    await _subscription?.cancel();
    _subscription = null;
    await channel?.sink.close();
  }

  Uri _wsUri() {
    final base = Uri.parse(AppEnv.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: scheme, path: '/ws/chats');
  }
}
