// One conversation's state, driven the way the screen drives it: a page from
// the server, frames from the socket, sends that succeed or fail.
//
// Each group pins a bug the conversation shipped with:
//
//  - the other side's message relayed over the socket carried the *sender's*
//    `is_mine`, so it was drawn as her own;
//  - opening a conversation turned all of her ticks to "read", because her
//    own read was taken for the other side's;
//  - a message appeared only once the server answered, and on failure the
//    text was gone; a retry after a lost answer arrived twice;
//  - "typing…" stayed up for ever when the peer's phone lost signal.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/chat/data/models/chat_message_model.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';
import 'package:ohara/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:ohara/features/chat/domain/usecases/get_threads_usecase.dart';
import 'package:ohara/features/chat/domain/usecases/mark_chat_read_usecase.dart';
import 'package:ohara/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:ohara/features/chat/domain/usecases/start_conversation_usecase.dart';
import 'package:ohara/features/chat/presentation/providers/chat_notifier.dart';

const _chat = 'chat-1';
const _me = 'buyer-1';
const _peer = 'seller-1';

Map<String, dynamic> _json({
  required String id,
  required String sender,
  required String sentAt,
  String content = 'مرحبا',
  String status = 'sent',
  String? clientId,
  bool? isMine,
}) =>
    {
      'id': id,
      'chat_id': _chat,
      'sender_id': sender,
      'content': content,
      'kind': 'text',
      'status': status,
      'sent_at': sentAt,
      'client_id': ?clientId,
      'is_mine': ?isMine,
    };

ChatMessageEntity _message({
  required String id,
  required String sender,
  required String sentAt,
  String status = 'sent',
}) =>
    ChatMessageModel.fromJson(
      _json(id: id, sender: sender, sentAt: sentAt, status: status),
      currentUserId: _me,
    );

class _FakeRepository implements ChatRepository {
  List<ChatMessageEntity> page = [];
  final sends = <Map<String, Object?>>[];
  final reads = <String?>[];

  /// Completes the next send; null answers at once with a stored copy.
  Completer<Result<ChatMessageEntity>>? pendingSend;
  bool failSends = false;

  @override
  Future<Result<List<ChatMessageEntity>>> getMessages(
    String chatId, {
    DateTime? before,
    int limit = 50,
    String? currentUserId,
  }) async =>
      Success(page);

  @override
  Future<Result<ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
    String? currentUserId,
    String? productId,
  }) {
    sends.add({
      'content': content,
      'client_id': clientId,
      'product_id': productId,
    });
    if (pendingSend case final completer?) return completer.future;
    if (failSends) {
      return Future.value(const Error(NetworkFailure('لا يوجد اتصال')));
    }
    return Future.value(
      Success(
        ChatMessageModel.fromJson(
          _json(
            id: 'server-${sends.length}',
            sender: _me,
            sentAt: DateTime.now().toUtc().toIso8601String(),
            content: content,
            clientId: clientId,
          ),
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  Future<Result<void>> markRead(String chatId, {String? messageId}) async {
    reads.add(messageId);
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}

ChatMessagesNotifier _notifier(
  _FakeRepository repository, {
  Duration typingTimeout = kPeerTypingTimeout,
}) =>
    ChatMessagesNotifier(
      chatId: _chat,
      getMessagesUseCase: GetMessagesUseCase(repository),
      sendMessageUseCase: SendMessageUseCase(repository),
      markChatReadUseCase: MarkChatReadUseCase(repository),
      currentUserId: _me,
      typingTimeout: typingTimeout,
    );

void main() {
  group('whose message it is', () {
    test('a relayed message from the other side is not drawn as hers', () {
      final notifier = _notifier(_FakeRepository());
      // Exactly what the old gateway sent everyone: the sender's `is_mine`.
      notifier.applyRealtime({
        'event': 'message.created',
        'chat_id': _chat,
        'message': _json(
          id: 'm-1',
          sender: _peer,
          sentAt: '2026-10-21T10:00:00.000Z',
          isMine: true,
        ),
      });

      expect(notifier.state.messages.single.isMine, isFalse);
    });

    test('times are shown in her time zone, not the server’s', () {
      final message = _message(
        id: 'm-1',
        sender: _peer,
        sentAt: '2026-10-21T10:00:00.000Z',
      );
      expect(message.sentAt.isUtc, isFalse);
      expect(message.sentAt, DateTime.utc(2026, 10, 21, 10).toLocal());
    });
  });

  group('ticks', () {
    late _FakeRepository repository;
    late ChatMessagesNotifier notifier;

    setUp(() async {
      repository = _FakeRepository()
        ..page = [
          _message(id: 'a', sender: _me, sentAt: '2026-10-21T10:00:00.000Z'),
          _message(id: 'b', sender: _peer, sentAt: '2026-10-21T10:01:00.000Z'),
          _message(id: 'c', sender: _me, sentAt: '2026-10-21T10:02:00.000Z'),
        ];
      notifier = _notifier(repository);
      await notifier.load();
    });

    test('her own read does not mark her messages read', () {
      notifier.applyRealtime({
        'event': 'messages.read',
        'chat_id': _chat,
        'user_id': _me,
        'read_at': '2026-10-21T10:05:00.000Z',
      });
      expect(notifier.state.messages.where((m) => m.isRead), isEmpty);
    });

    test('the other side’s read covers only what was sent up to it', () {
      notifier.applyRealtime({
        'event': 'messages.read',
        'chat_id': _chat,
        'user_id': _peer,
        'read_at': '2026-10-21T10:05:00.000Z',
        'up_to': '2026-10-21T10:01:00.000Z',
      });
      final byId = {for (final m in notifier.state.messages) m.id: m};
      expect(byId['a']!.isRead, isTrue);
      expect(byId['c']!.isRead, isFalse, reason: 'sent after what she read');
    });

    test('delivery reaches the sender as a second tick', () {
      notifier.applyRealtime({
        'event': 'messages.delivered',
        'chat_id': _chat,
        'user_id': _peer,
        'message_ids': ['c'],
        'delivered_at': '2026-10-21T10:03:00.000Z',
      });
      final c = notifier.state.messages.firstWhere((m) => m.id == 'c');
      expect(c.isDelivered, isTrue);
      expect(c.isRead, isFalse);
    });

    test('a late copy never takes a tick back', () {
      notifier.applyRealtime({
        'event': 'messages.read',
        'chat_id': _chat,
        'user_id': _peer,
        'read_at': '2026-10-21T10:05:00.000Z',
        'up_to': '2026-10-21T10:02:00.000Z',
      });
      // The page fetched before that read lands afterwards.
      notifier.applyRealtime({
        'event': 'message.created',
        'chat_id': _chat,
        'message': _json(id: 'c', sender: _me, sentAt: '2026-10-21T10:02:00.000Z'),
      });
      expect(notifier.state.messages.firstWhere((m) => m.id == 'c').isRead, isTrue);
    });

    test('events for another conversation are ignored', () {
      notifier.applyRealtime({
        'event': 'message.created',
        'chat_id': 'chat-2',
        'message': _json(id: 'x', sender: _peer, sentAt: '2026-10-21T10:09:00.000Z'),
      });
      expect(notifier.state.messages.map((m) => m.id), ['a', 'b', 'c']);
    });

    test('reading is reported once per new message, over HTTP', () async {
      await notifier.markRead();
      await notifier.markRead();
      expect(repository.reads, ['b']);
    });
  });

  group('sending', () {
    test('the message is on screen before the server answers', () async {
      final repository = _FakeRepository()
        ..pendingSend = Completer<Result<ChatMessageEntity>>();
      final notifier = _notifier(repository);
      await notifier.load();

      final sending = notifier.sendMessage('هل يتوفر مقاس L؟');
      final local = notifier.state.messages.single;
      expect(local.isPending, isTrue);
      expect(local.isMine, isTrue);
      expect(local.content, 'هل يتوفر مقاس L؟');

      // The socket's copy can overtake the HTTP answer; it replaces the local
      // one rather than appearing beside it.
      final clientId = repository.sends.single['client_id'] as String;
      notifier.applyRealtime({
        'event': 'message.created',
        'chat_id': _chat,
        'message': _json(
          id: 'server-1',
          sender: _me,
          sentAt: '2026-10-21T10:00:00.000Z',
          content: 'هل يتوفر مقاس L؟',
          clientId: clientId,
        ),
      });
      expect(notifier.state.messages, hasLength(1));
      expect(notifier.state.messages.single.isPending, isFalse);

      repository.pendingSend!.complete(
        Success(
          ChatMessageModel.fromJson(
            _json(
              id: 'server-1',
              sender: _me,
              sentAt: '2026-10-21T10:00:00.000Z',
              clientId: clientId,
            ),
            currentUserId: _me,
          ),
        ),
      );
      expect(await sending, isTrue);
      expect(notifier.state.messages, hasLength(1));
    });

    test('a failed message stays, marked, and a retry is the same message', () async {
      final repository = _FakeRepository()..failSends = true;
      final notifier = _notifier(repository);
      await notifier.load();

      expect(await notifier.sendMessage('مرحبا'), isFalse);
      final failed = notifier.state.messages.single;
      expect(failed.isFailed, isTrue);
      expect(failed.content, 'مرحبا', reason: 'her text is not lost');
      expect(notifier.state.error, isNull, reason: 'the conversation stays');

      repository.failSends = false;
      expect(await notifier.retry(failed), isTrue);

      expect(notifier.state.messages, hasLength(1));
      expect(notifier.state.messages.single.isLocal, isFalse);
      // Same client id both times — the server stores it once.
      expect(
        repository.sends.map((s) => s['client_id']).toSet(),
        hasLength(1),
      );
    });

    test('a question about a piece carries the piece, retries included',
        () async {
      final repository = _FakeRepository()..failSends = true;
      final notifier = _notifier(repository);
      await notifier.load();

      const dress = ChatProductRef(id: 'product-7', title: 'فستان سهرة');
      expect(
        await notifier.sendMessage('هل يتوفر مقاس M؟', about: dress),
        isFalse,
      );
      // Drawn with its card at once, before the server has answered.
      expect(notifier.state.messages.single.product, dress);

      repository.failSends = false;
      expect(await notifier.retry(notifier.state.messages.single), isTrue);
      // Both attempts name the piece, so the retry is still about it.
      expect(
        repository.sends.map((s) => s['product_id']),
        everyElement('product-7'),
      );
    });

    test("the server's product card is read from the message metadata", () {
      final message = ChatMessageModel.fromJson({
        ..._json(id: 'm-1', sender: _peer, sentAt: '2026-10-21T10:00:00Z'),
        'metadata': {
          'product': {
            'id': 'product-7',
            'title': 'فستان سهرة',
            'image_url': 'https://cdn.example/dress.jpg',
            'price': {'amount': '250000.0000', 'currency': 'SYP'},
          },
        },
      }, currentUserId: _me);

      expect(message.product?.id, 'product-7');
      expect(message.product?.title, 'فستان سهرة');
      expect(message.product?.imageUrl, 'https://cdn.example/dress.jpg');
      expect(message.product?.price, isNotNull);
      expect(
        ChatMessageModel.fromJson(
          _json(id: 'm-2', sender: _peer, sentAt: '2026-10-21T10:00:00Z'),
          currentUserId: _me,
        ).product,
        isNull,
        reason: 'a plain message has no card',
      );
    });

    test('an empty message is not sent', () async {
      final repository = _FakeRepository();
      final notifier = _notifier(repository);
      expect(await notifier.sendMessage('   '), isFalse);
      expect(repository.sends, isEmpty);
    });
  });

  group('typing', () {
    test('"typing…" goes away on its own when the peer goes silent', () async {
      final notifier = _notifier(
        _FakeRepository(),
        typingTimeout: const Duration(milliseconds: 20),
      );
      notifier.applyRealtime({
        'event': 'typing',
        'chat_id': _chat,
        'user_id': _peer,
        'is_typing': true,
      });
      expect(notifier.state.isPeerTyping, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifier.state.isPeerTyping, isFalse);
    });

    test('her own typing, echoed from another phone, is not the peer’s', () {
      final notifier = _notifier(_FakeRepository());
      notifier.applyRealtime({
        'event': 'typing',
        'chat_id': _chat,
        'user_id': _me,
        'is_typing': true,
      });
      expect(notifier.state.isPeerTyping, isFalse);
    });
  });

  group('the inbox', () {
    ChatNotifier inbox(List<ChatThreadEntity> threads) {
      final repository = _ThreadsRepository(threads);
      return ChatNotifier(
        getThreadsUseCase: GetThreadsUseCase(repository),
        startConversationUseCase: StartConversationUseCase(repository),
        currentUserId: _me,
      );
    }

    ChatThreadEntity thread(String id, {String? peerId}) => ChatThreadEntity(
          id: id,
          title: id,
          avatarUrl: '',
          lastMessage: 'old',
          unreadCount: 0,
          updatedAt: DateTime(2026, 10, 20),
          peerId: peerId,
        );

    test('a new message moves its row to the top, with the new preview', () async {
      final notifier = inbox([thread('t1'), thread(_chat)]);
      await notifier.load();

      final refetch = notifier.applyRealtime({
        'event': 'message.created',
        'chat_id': _chat,
        'message': _json(
          id: 'm',
          sender: _peer,
          sentAt: '2026-10-21T10:00:00.000Z',
          content: 'وصل طلبكِ',
        ),
      });

      expect(refetch, isFalse);
      final top = notifier.state.threads.first;
      expect(top.id, _chat);
      expect(top.lastMessage, 'وصل طلبكِ');
      expect(top.unreadCount, 1);
    });

    test('a message in a conversation not on screen asks for a refetch', () async {
      final notifier = inbox([thread('t1')]);
      await notifier.load();
      expect(
        notifier.applyRealtime({
          'event': 'message.created',
          'chat_id': 'brand-new',
          'message': _json(id: 'm', sender: _peer, sentAt: '2026-10-21T10:00:00.000Z'),
        }),
        isTrue,
      );
    });

    test('presence lands on the peer’s row without a refetch', () async {
      final notifier = inbox([thread(_chat, peerId: _peer)]);
      await notifier.load();
      notifier.applyRealtime({
        'event': 'presence.changed',
        'user_id': _peer,
        'status': 'online',
        'last_seen_at': '2026-10-21T10:00:00.000Z',
      });
      expect(notifier.state.threads.single.isOnline, isTrue);
    });
  });
}

class _ThreadsRepository implements ChatRepository {
  _ThreadsRepository(this.threads);
  final List<ChatThreadEntity> threads;

  @override
  Future<Result<List<ChatThreadEntity>>> getThreads({String? query}) async =>
      Success(threads);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}
