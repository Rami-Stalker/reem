import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/storage/secure_storage_service.dart';

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

    final uri = _wsUri(token);
    final channel = WebSocketChannel.connect(uri);
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

  Uri _wsUri(String token) {
    final base = Uri.parse(AppEnv.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/ws/chats',
      queryParameters: {'token': token},
    );
  }
}
