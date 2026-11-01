// Long-press on a chat message: what it offers, and what deleting does.
//
//   flutter test test/chat_message_actions_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/chat/data/models/chat_message_model.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';
import 'package:ohara/features/chat/domain/usecases/delete_message_usecase.dart';
import 'package:ohara/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:ohara/features/chat/domain/usecases/mark_chat_read_usecase.dart';
import 'package:ohara/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:ohara/features/chat/presentation/providers/chat_notifier.dart';
import 'package:ohara/features/chat/presentation/widgets/message_actions_sheet.dart';

const _chat = 'chat-1';
const _me = 'buyer-1';
const _peer = 'seller-1';

ChatMessageEntity _message(
  String id, {
  String sender = _me,
  String content = 'مرحبا',
  DateTime? sentAt,
  String status = 'sent',
}) => ChatMessageModel.fromJson({
  'id': id,
  'chat_id': _chat,
  'sender_id': sender,
  'content': content,
  'kind': 'text',
  'status': status,
  'sent_at': (sentAt ?? DateTime.now()).toUtc().toIso8601String(),
}, currentUserId: _me);

class _Repository implements ChatRepository {
  _Repository(this.page);

  final List<ChatMessageEntity> page;
  final deletes = <(String, bool)>[];
  bool failDeletes = false;

  @override
  Future<Result<List<ChatMessageEntity>>> getMessages(
    String chatId, {
    DateTime? before,
    int limit = 50,
    String? currentUserId,
  }) async => Success(page);

  @override
  Future<Result<void>> deleteMessage(
    String chatId,
    String messageId, {
    required bool forEveryone,
  }) async {
    deletes.add((messageId, forEveryone));
    return failDeletes
        ? const Error(ForbiddenFailure('يمكنكِ حذف رسائلكِ أنتِ فقط عند الجميع'))
        : const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used')));
}

Future<ChatMessagesNotifier> _loaded(_Repository repository) async {
  final notifier = ChatMessagesNotifier(
    chatId: _chat,
    getMessagesUseCase: GetMessagesUseCase(repository),
    sendMessageUseCase: SendMessageUseCase(repository),
    markChatReadUseCase: MarkChatReadUseCase(repository),
    deleteMessageUseCase: DeleteMessageUseCase(repository),
    currentUserId: _me,
  );
  await notifier.load();
  return notifier;
}

void main() {
  group('what a long press offers', () {
    test('her own recent message: copy, delete for me and for everyone', () {
      expect(MessageActionsSheet.actionsFor(_message('m')), [
        MessageAction.copy,
        MessageAction.deleteForMe,
        MessageAction.deleteForEveryone,
      ]);
    });

    test('the other side’s message: copy, delete for me, report', () {
      expect(MessageActionsSheet.actionsFor(_message('m', sender: _peer)), [
        MessageAction.copy,
        MessageAction.deleteForMe,
        MessageAction.report,
      ]);
    });

    test('after 48 hours her message can no longer go for everyone', () {
      final old = _message(
        'm',
        sentAt: DateTime.now().subtract(const Duration(hours: 49)),
      );
      expect(
        MessageActionsSheet.actionsFor(old),
        isNot(contains(MessageAction.deleteForEveryone)),
      );
    });

    test('a failed message offers to send again', () {
      final failed = _message('local:x', status: ChatMessageStatus.failed);
      final actions = MessageActionsSheet.actionsFor(failed);
      expect(actions, contains(MessageAction.resend));
      expect(actions, isNot(contains(MessageAction.deleteForEveryone)));
    });

    test('a deleted message can only be cleared from her side', () {
      final gone = _message('m').asDeleted(DateTime.now());
      expect(MessageActionsSheet.actionsFor(gone), [MessageAction.deleteForMe]);
    });
  });

  group('deleting', () {
    test('for me, the message leaves her screen', () async {
      final repository = _Repository([_message('a'), _message('b')]);
      final notifier = await _loaded(repository);

      final failure = await notifier.deleteMessage(
        notifier.state.messages.first,
        forEveryone: false,
      );

      expect(failure, isNull);
      expect(notifier.state.messages.map((m) => m.id), ['b']);
      expect(repository.deletes, [('a', false)]);
    });

    test('for everyone, it becomes a tombstone', () async {
      final repository = _Repository([_message('a')]);
      final notifier = await _loaded(repository);

      await notifier.deleteMessage(
        notifier.state.messages.single,
        forEveryone: true,
      );

      final row = notifier.state.messages.single;
      expect(row.isDeleted, isTrue);
      expect(row.content, isEmpty);
    });

    test('a refusal puts the message back and says why', () async {
      final repository = _Repository([_message('a')])..failDeletes = true;
      final notifier = await _loaded(repository);
      final original = notifier.state.messages.single;

      final failure = await notifier.deleteMessage(original, forEveryone: true);

      expect(failure, contains('رسائلكِ'));
      expect(notifier.state.messages.single, original);
    });

    test('the other side taking a message back reaches this screen', () async {
      final notifier = await _loaded(_Repository([_message('a', sender: _peer)]));

      notifier.applyRealtime({
        'event': 'message.deleted',
        'chat_id': _chat,
        'message_id': 'a',
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(notifier.state.messages.single.isDeleted, isTrue);
    });

    test('a deleted message read from the server stays deleted', () {
      final row = ChatMessageModel.fromJson({
        'id': 'a',
        'chat_id': _chat,
        'sender_id': _peer,
        'content': '',
        'kind': 'text',
        'sent_at': '2026-10-31T10:00:00.000Z',
        'deleted_at': '2026-10-31T10:05:00.000Z',
      }, currentUserId: _me);
      expect(row.isDeleted, isTrue);
    });
  });
}
