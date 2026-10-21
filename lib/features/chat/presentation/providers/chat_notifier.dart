import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/data/models/chat_message_model.dart';
import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_thread_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_threads_usecase.dart';
import 'package:reem/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:reem/features/chat/domain/usecases/start_conversation_usecase.dart';
import 'package:reem/features/chat/presentation/providers/chat_state.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    required GetThreadsUseCase getThreadsUseCase,
    required StartConversationUseCase startConversationUseCase,
  })  : _getThreads = getThreadsUseCase,
        _startConversation = startConversationUseCase,
        super(const ChatState());

  final GetThreadsUseCase _getThreads;
  final StartConversationUseCase _startConversation;

  Timer? _debounce;

  /// Rises with every search, so a slow reply to an abandoned term cannot
  /// overwrite the results of a newer one.
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> load() => _fetch(state.query);

  /// Pull-to-refresh and the return from a conversation. Keeps the rows on
  /// screen while it runs — blanking a list she is looking at reads as a bug.
  Future<void> refresh() => _fetch(state.query, silent: true);

  /// Typed into the search field. Debounced, because every keystroke would
  /// otherwise be a round trip.
  void search(String term) {
    if (term == state.query) return;
    state = state.copyWith(query: term);
    _debounce?.cancel();
    if (term.trim().isEmpty) {
      // Clearing the box should feel instant; there is nothing to wait for.
      unawaited(_fetch(term));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 320),
      () => unawaited(_fetch(term)),
    );
  }

  Future<void> _fetch(String term, {bool silent = false}) async {
    final requestId = ++_requestId;
    if (!silent) state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getThreads(query: term);
    // She moved on: a newer search is already in flight, or the notifier is
    // gone entirely.
    if (!mounted || requestId != _requestId) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isLoading: false,
          hasLoadedOnce: true,
          threads: data,
          clearError: true,
        ),
      Error(:final failure) => state.copyWith(
          isLoading: false,
          hasLoadedOnce: true,
          error: failure.message,
        ),
    };
  }

  /// Opens the conversation [request] describes and returns it, or null with
  /// [ChatState.error] set when the server refused. The list is refreshed on
  /// success so a brand-new thread is already there when she comes back.
  Future<ChatThreadEntity?> startConversation(ChatStartRequest request) async {
    state = state.copyWith(clearError: true);
    final result = await _startConversation(request);
    if (!mounted) return null;
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(threads: _upsert(data));
          return data;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(error: failure.message);
          return null;
        }(),
    };
  }

  /// Puts a thread at the top of the list, replacing any older copy of it.
  List<ChatThreadEntity> _upsert(ChatThreadEntity thread) {
    return [
      thread,
      ...state.threads.where((existing) => existing.id != thread.id),
    ];
  }
}

/// The header of one conversation — who she is talking to.
///
/// Separate from the message list because it survives on its own: the details
/// screen can be opened by deep link, with no list ever having been loaded.
class ChatThreadNotifier extends StateNotifier<ChatThreadState> {
  ChatThreadNotifier({required GetThreadUseCase getThreadUseCase})
      : _getThread = getThreadUseCase,
        super(const ChatThreadState());

  final GetThreadUseCase _getThread;

  Future<void> load(String chatId) async {
    if (chatId.isEmpty) return;
    state = const ChatThreadState(isLoading: true);
    final result = await _getThread(chatId);
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => ChatThreadState(thread: data),
      // A header that cannot be loaded degrades to a nameless one; the
      // conversation itself is still perfectly usable.
      Error(:final failure) => ChatThreadState(error: failure.message),
    };
  }
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  ChatMessagesNotifier({
    required GetMessagesUseCase getMessagesUseCase,
    required SendMessageUseCase sendMessageUseCase,
    String? currentUserId,
  })  : _getMessages = getMessagesUseCase,
        _sendMessage = sendMessageUseCase,
        _currentUserId = currentUserId,
        super(const ChatMessagesState());

  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;

  /// Who is reading — the one authority on which side a bubble belongs to.
  ///
  /// A payload's own `is_mine` is computed by whoever serialised it, and the
  /// same serialised message is delivered to both people in a conversation.
  /// Deciding here, from the account holding the screen, is what makes that
  /// impossible to get wrong however the message arrived.
  final String? _currentUserId;

  int _clientSeq = 0;

  Future<void> load(String chatId) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearMessages: true,
      chatId: chatId,
    );
    final result = await _getMessages(chatId);
    if (!mounted || state.chatId != chatId) return;
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, messages: data, chatId: chatId),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message, chatId: chatId),
    };
  }

  Future<bool> sendMessage(String content) async {
    return send(
      content: content,
      kind: 'TEXT',
    );
  }

  /// Sends, showing her own words immediately.
  ///
  /// The bubble used to appear only once the server had answered, which on a
  /// Syrian mobile connection is a composer that clears and a thread that does
  /// not change for several seconds — indistinguishable, from her side, from
  /// the message not having been sent at all. It is now on screen at once,
  /// marked as in flight, and the row the server stores *replaces* it: the two
  /// are matched on the client id that travelled with the send, so neither the
  /// reply nor the socket's echo of the same message can leave a second copy.
  Future<bool> send({
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final chatId = state.chatId;
    final trimmed = content.trim();
    if (chatId == null ||
        chatId.isEmpty ||
        (trimmed.isEmpty && attachments.isEmpty)) {
      return false;
    }

    final clientId = _nextClientId();
    final pending = ChatMessageEntity(
      id: clientId,
      chatId: chatId,
      senderId: _currentUserId ?? '',
      content: trimmed,
      sentAt: DateTime.now(),
      isMine: true,
      kind: kind.toLowerCase(),
      status: 'sending',
      clientId: clientId,
      delivery: ChatMessageDelivery.pending,
      attachments: _localAttachments(attachments),
    );

    state = state.copyWith(
      isSending: true,
      clearError: true,
      messages: _merge(pending),
    );

    final result = await _sendMessage(
      chatId: chatId,
      content: trimmed,
      kind: kind,
      attachments: attachments,
      clientId: clientId,
    );
    if (!mounted || state.chatId != chatId) return result is Success;

    switch (result) {
      case Success(:final data):
        state = state.copyWith(isSending: false, messages: _merge(data));
        return true;
      case Error(:final failure):
        // Her words stay on screen, marked failed. Dropping them is how a bad
        // connection ends up looking like an app that ate what she typed.
        state = state.copyWith(
          isSending: false,
          error: failure.message,
          messages: _replace(
            clientId,
            pending.copyWith(
              status: 'failed',
              delivery: ChatMessageDelivery.failed,
            ),
          ),
        );
        return false;
    }
  }

  /// Sends a failed message again, dropping the failed bubble first.
  Future<bool> retry(ChatMessageEntity message) async {
    if (!message.isFailed) return false;
    state = state.copyWith(
      messages: state.messages
          .where((item) => item.id != message.id)
          .toList(growable: false),
    );
    return send(
      content: message.content,
      kind: message.kind.toUpperCase(),
      attachments: [
        for (final attachment in message.attachments)
          {
            'kind': attachment.kind.toUpperCase(),
            'url': attachment.url,
            'mime_type': ?attachment.mimeType,
            'file_name': ?attachment.fileName,
            'size_bytes': ?attachment.sizeBytes,
            'width': ?attachment.width,
            'height': ?attachment.height,
            'duration_ms': ?attachment.durationMs,
          },
      ],
    );
  }

  String _nextClientId() {
    _clientSeq += 1;
    return 'c-' '${DateTime.now().microsecondsSinceEpoch}' '-' '$_clientSeq';
  }

  /// What a pending bubble can draw before the server has stored anything.
  ///
  /// The URL is already real — a photograph is uploaded *before* the message
  /// is sent — so the picture appears in the thread while its message is still
  /// in flight, rather than after it lands.
  List<ChatAttachmentEntity> _localAttachments(
    List<Map<String, dynamic>> attachments,
  ) => [
    for (final attachment in attachments)
      ChatAttachmentEntity(
        id: 'pending-${attachment['url']}',
        kind: (attachment['kind'] as String? ?? 'image').toLowerCase(),
        url: attachment['url'] as String? ?? '',
        mimeType: attachment['mime_type'] as String?,
        fileName: attachment['file_name'] as String?,
        sizeBytes: attachment['size_bytes'] as int?,
        width: attachment['width'] as int?,
        height: attachment['height'] as int?,
        durationMs: attachment['duration_ms'] as int?,
      ),
  ];

  List<ChatMessageEntity> _replace(
    String clientId,
    ChatMessageEntity replacement,
  ) => [
    for (final message in state.messages)
      if (message.clientId == clientId || message.id == clientId)
        replacement
      else
        message,
  ];

  /// Fetches the conversation again without clearing it — after the socket
  /// reconnects, for whatever arrived while it was down. A failure keeps what
  /// is on screen; the next event or visit corrects it.
  Future<void> resync() async {
    final chatId = state.chatId;
    if (chatId == null || chatId.isEmpty) return;
    final result = await _getMessages(chatId);
    if (!mounted || state.chatId != chatId) return;
    if (result case Success(:final data)) {
      state = state.copyWith(messages: data);
    }
  }

  void applyRealtime(Map<String, dynamic> event) {
    final eventName = event['event'];
    if (eventName == 'message.created') {
      final raw = event['message'];
      if (raw is! Map) return;
      final message = ChatMessageModel.fromJson(
        Map<String, dynamic>.from(raw),
        chatId: event['chat_id'] as String?,
        // Which side it goes on is decided from who is reading, not trusted
        // from the payload: the same serialised message is delivered to both
        // people and only one of them wrote it.
        currentUserId: _currentUserId,
      );
      if (message.chatId != state.chatId) return;
      state = state.copyWith(messages: _merge(message), isPeerTyping: false);
      return;
    }
    if (eventName == 'typing' && event['chat_id'] == state.chatId) {
      state = state.copyWith(isPeerTyping: event['is_typing'] == true);
      return;
    }
    if (eventName == 'messages.read' && event['chat_id'] == state.chatId) {
      final readAt = DateTime.tryParse(event['read_at'] as String? ?? '');
      state = state.copyWith(
        messages: state.messages
            .map(
              // Only her own, and only ones that have actually been sent:
              // a read receipt on a message still in flight is a receipt for
              // something the other side has not been given yet.
              (message) =>
                  message.isMine && !message.isPending && !message.isFailed
                  ? message.copyWith(status: 'read', readAt: readAt)
                  : message,
            )
            .toList(growable: false),
      );
    }
  }

  /// Inserts [message], replacing any copy of it already on screen.
  ///
  /// "Already on screen" means the same server id *or* the same client id. The
  /// second is what retires the optimistic bubble, and it is why sending no
  /// longer leaves two of the same message in the thread when the socket echo
  /// and the HTTP reply both arrive.
  List<ChatMessageEntity> _merge(ChatMessageEntity message) {
    final clientId = message.clientId;
    final existing = state.messages.where(
      (item) =>
          item.id != message.id &&
          !(clientId != null &&
              (item.clientId == clientId || item.id == clientId)),
    );
    return [...existing, message]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }
}
