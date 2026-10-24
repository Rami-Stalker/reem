import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/data/models/chat_message_model.dart';
import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_thread_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_threads_usecase.dart';
import 'package:reem/features/chat/domain/usecases/mark_chat_read_usecase.dart';
import 'package:reem/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:reem/features/chat/domain/usecases/start_conversation_usecase.dart';
import 'package:reem/features/chat/presentation/providers/chat_state.dart';

/// How long "typing…" survives without being renewed. The composer renews it
/// every few seconds while she types; a peer whose phone lost signal mid-word
/// never sends the "stopped", and the indicator used to stay up for ever.
const Duration kPeerTypingTimeout = Duration(seconds: 6);

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    required GetThreadsUseCase getThreadsUseCase,
    required StartConversationUseCase startConversationUseCase,
    this.currentUserId,
  })  : _getThreads = getThreadsUseCase,
        _startConversation = startConversationUseCase,
        super(const ChatState());

  final GetThreadsUseCase _getThreads;
  final StartConversationUseCase _startConversation;

  /// Whose inbox this is — to tell her own messages and reads from the other
  /// side's.
  final String? currentUserId;

  Timer? _debounce;
  final Map<String, Timer> _typingTimers = {};

  /// Rises with every search, so a slow reply to an abandoned term cannot
  /// overwrite the results of a newer one.
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
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

  /// Applies a socket event to the inbox in place.
  ///
  /// The inbox used to refetch the whole list for every event — including
  /// each presence change of every contact — and showed nothing until the
  /// round trip came back. A new message now moves its row to the top with
  /// the new preview at once; presence and typing are drawn on the row they
  /// belong to.
  ///
  /// Returns true when the event could not be applied locally — a message in
  /// a conversation not on screen yet — and the list should be refetched.
  bool applyRealtime(Map<String, dynamic> event) {
    final chatId = event['chat_id'];
    switch (event['event']) {
      case 'message.created':
        final raw = event['message'];
        if (chatId is! String || raw is! Map) return true;
        final index = state.threads.indexWhere((t) => t.id == chatId);
        // A search is on screen; whether this row belongs in it is the
        // server's call.
        if (index == -1 || state.isSearching) return true;
        final message = ChatMessageModel.fromJson(
          Map<String, dynamic>.from(raw),
          chatId: chatId,
          currentUserId: currentUserId,
        );
        final thread = state.threads[index];
        final updated = thread.copyWith(
          lastMessage: message.content.isNotEmpty
              ? message.content
              : thread.lastMessage,
          updatedAt: message.sentAt,
          unreadCount: message.isMine ? thread.unreadCount : thread.unreadCount + 1,
        );
        _clearTyping(chatId);
        state = state.copyWith(threads: _upsert(updated));
        return false;

      case 'messages.read':
        // Her own read, from this phone or another one, clears her badge.
        // The other side's read changes nothing in her inbox.
        if (chatId is! String || event['user_id'] != currentUserId) return false;
        state = state.copyWith(
          threads: [
            for (final thread in state.threads)
              thread.id == chatId ? thread.copyWith(unreadCount: 0) : thread,
          ],
        );
        return false;

      case 'presence.changed':
        final userId = event['user_id'];
        if (userId is! String) return false;
        final online = event['status'] == 'online';
        final lastSeen = event['last_seen_at'] is String
            ? DateTime.tryParse(event['last_seen_at'] as String)?.toLocal()
            : null;
        state = state.copyWith(
          threads: [
            for (final thread in state.threads)
              thread.peerId == userId
                  ? thread.copyWith(isOnline: online, lastSeenAt: lastSeen)
                  : thread,
          ],
        );
        return false;

      case 'typing':
        if (chatId is! String || event['user_id'] == currentUserId) return false;
        if (event['is_typing'] == true) {
          _typingTimers[chatId]?.cancel();
          _typingTimers[chatId] = Timer(kPeerTypingTimeout, () {
            if (mounted) _clearTyping(chatId);
          });
          state = state.copyWith(
            typingChatIds: {...state.typingChatIds, chatId},
          );
        } else {
          _clearTyping(chatId);
        }
        return false;

      case 'connection.restored':
        return true;
    }
    return false;
  }

  void _clearTyping(String chatId) {
    _typingTimers.remove(chatId)?.cancel();
    if (!state.typingChatIds.contains(chatId)) return;
    state = state.copyWith(
      typingChatIds: {...state.typingChatIds}..remove(chatId),
    );
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

  /// The peer came online or left, live from the socket.
  void applyPresence(Map<String, dynamic> event) {
    final thread = state.thread;
    if (thread == null || event['user_id'] != thread.peerId) return;
    final lastSeen = event['last_seen_at'] is String
        ? DateTime.tryParse(event['last_seen_at'] as String)?.toLocal()
        : null;
    state = ChatThreadState(
      thread: thread.copyWith(
        isOnline: event['status'] == 'online',
        lastSeenAt: lastSeen,
      ),
    );
  }
}

/// What a message she sent was, kept until the server has it — so a failed
/// one can be sent again exactly as it was.
class _Outgoing {
  const _Outgoing(this.content, this.kind, this.attachments, this.product);

  final String content;
  final String kind;
  final List<Map<String, dynamic>> attachments;
  final ChatProductRef? product;
}

/// One conversation's messages.
///
/// One instance per conversation (the provider is a family keyed by chat id).
/// It used to be a single app-wide instance: opening a second conversation
/// from inside the first — her profile, a product, «راسلي المتجر» — loaded
/// the second into it, and going back showed the first conversation's screen
/// filled with the second one's messages.
class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  ChatMessagesNotifier({
    required String chatId,
    required GetMessagesUseCase getMessagesUseCase,
    required SendMessageUseCase sendMessageUseCase,
    required MarkChatReadUseCase markChatReadUseCase,
    this.currentUserId,
    Duration typingTimeout = kPeerTypingTimeout,
    Random? random,
  })  : _chatId = chatId,
        _getMessages = getMessagesUseCase,
        _sendMessage = sendMessageUseCase,
        _markRead = markChatReadUseCase,
        _typingTimeout = typingTimeout,
        _random = random ?? Random(),
        super(ChatMessagesState(chatId: chatId));

  /// Messages per page — the server's default, said out loud.
  static const pageSize = 50;

  final String _chatId;
  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;
  final MarkChatReadUseCase _markRead;
  final Duration _typingTimeout;
  final Random _random;

  /// Who is reading. Decides which messages are hers — see
  /// [ChatMessageModel.fromJson] for why the payload cannot.
  final String? currentUserId;

  final Map<String, _Outgoing> _outbox = {};
  Timer? _typingTimer;
  int _loadGeneration = 0;

  /// The newest message from the other side already reported read, so a
  /// burst of events does not become a burst of requests.
  String? _reportedReadId;

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  /// The newest page. Also the resync after the socket comes back: messages
  /// already on screen — older pages, her unsent ones — are kept, and
  /// anything new is merged in.
  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(
      isLoading: state.messages.isEmpty,
      clearError: true,
    );
    final result = await _getMessages(
      _chatId,
      limit: pageSize,
      currentUserId: currentUserId,
    );
    if (!mounted || generation != _loadGeneration) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isLoading: false,
          messages: _mergeAll(data),
          // Only a first load decides this; a resync must not forget that
          // older pages exist above what it fetched.
          hasMore: state.messages.isEmpty
              ? data.length >= pageSize
              : state.hasMore || data.length >= pageSize,
        ),
      Error(:final failure) => state.copyWith(
          isLoading: false,
          error: failure.message,
        ),
    };
  }

  /// Fetches again without clearing — after the socket reconnects, for what
  /// arrived while it was down.
  Future<void> resync() => load();

  /// The page before the oldest message on screen.
  Future<void> loadOlder() async {
    if (state.isLoading || state.isLoadingOlder || !state.hasMore) return;
    final oldest = state.messages.where((m) => !m.isLocal).firstOrNull;
    if (oldest == null) return;

    state = state.copyWith(isLoadingOlder: true);
    final result = await _getMessages(
      _chatId,
      before: oldest.sentAt,
      limit: pageSize,
      currentUserId: currentUserId,
    );
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isLoadingOlder: false,
          messages: _mergeAll(data),
          hasMore: data.length >= pageSize,
        ),
      // Kept as "more to load", so scrolling up again retries.
      Error() => state.copyWith(isLoadingOlder: false),
    };
  }

  /// [about] attaches the piece she is asking about; see [ChatProductRef].
  Future<bool> sendMessage(String content, {ChatProductRef? about}) =>
      send(content: content, about: about);

  /// Draws the message at once, then sends it.
  ///
  /// It used to appear only once the server answered — on a slow line, a
  /// second or more of nothing after tapping send — and on a failure the
  /// text was already gone from the box and nowhere else. Now it is on screen
  /// immediately, marked as sending; on failure it stays, marked, and
  /// [retry] sends it again under the same `client_id`, which the server
  /// recognises — so a retry after a lost answer never doubles it.
  Future<bool> send({
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    ChatProductRef? about,
  }) async {
    final text = content.trim();
    if (_chatId.isEmpty || (text.isEmpty && attachments.isEmpty)) return false;

    final clientId = _newClientId();
    _outbox[clientId] = _Outgoing(text, kind, attachments, about);
    final local = ChatMessageEntity(
      id: 'local:$clientId',
      chatId: _chatId,
      senderId: currentUserId ?? '',
      content: text,
      sentAt: DateTime.now(),
      isMine: true,
      kind: attachments.isEmpty ? 'text' : kind.toLowerCase(),
      status: ChatMessageStatus.sending,
      clientId: clientId,
      // Drawn with its card at once; the server's copy, built from the
      // catalogue, replaces it when it answers.
      product: about,
      attachments: [
        for (final (index, attachment) in attachments.indexed)
          ChatAttachmentEntity(
            id: 'local:$clientId:$index',
            kind: '${attachment['kind'] ?? kind}'.toLowerCase(),
            url: '${attachment['url'] ?? ''}',
            mimeType: attachment['mime_type'] as String?,
            fileName: attachment['file_name'] as String?,
            sizeBytes: attachment['size_bytes'] as int?,
            width: attachment['width'] as int?,
            height: attachment['height'] as int?,
            durationMs: attachment['duration_ms'] as int?,
          ),
      ],
    );
    state = state.copyWith(messages: _mergeOne(local), clearError: true);
    return _deliver(clientId);
  }

  /// Sends a failed message again, as the same message.
  Future<bool> retry(ChatMessageEntity message) {
    final clientId = message.clientId;
    if (!message.isFailed || clientId == null || !_outbox.containsKey(clientId)) {
      return Future.value(false);
    }
    state = state.copyWith(
      messages: _withLocalStatus(clientId, ChatMessageStatus.sending),
    );
    return _deliver(clientId);
  }

  Future<bool> _deliver(String clientId) async {
    final outgoing = _outbox[clientId];
    if (outgoing == null) return false;
    final result = await _sendMessage(
      chatId: _chatId,
      content: outgoing.content,
      kind: outgoing.kind,
      attachments: outgoing.attachments,
      clientId: clientId,
      currentUserId: currentUserId,
      productId: outgoing.product?.id,
    );
    if (!mounted) return result is Success;
    switch (result) {
      case Success(:final data):
        _outbox.remove(clientId);
        // Whatever the payload claims, the message she just sent is hers.
        final confirmed = data.isMine ? data : data.copyWith(isMine: true);
        state = state.copyWith(messages: _mergeOne(confirmed, clientId: clientId));
        return true;
      case Error():
        state = state.copyWith(
          messages: _withLocalStatus(clientId, ChatMessageStatus.failed),
        );
        return false;
    }
  }

  /// Tells the server she has read the conversation up to the newest message
  /// from the other side. Over HTTP — see [MarkChatReadUseCase] — and once per
  /// message, however many events ask for it.
  Future<void> markRead() async {
    final latest = state.messages.lastWhereOrNull((m) => !m.isMine && !m.isLocal);
    if (latest == null || latest.id == _reportedReadId) return;
    _reportedReadId = latest.id;
    final result = await _markRead(_chatId, messageId: latest.id);
    // Let the next event try again rather than believing it was recorded.
    if (result is Error && _reportedReadId == latest.id) _reportedReadId = null;
  }

  void applyRealtime(Map<String, dynamic> event) {
    if (event['chat_id'] != _chatId) return;
    switch (event['event']) {
      case 'message.created':
        final raw = event['message'];
        if (raw is! Map) return;
        final message = ChatMessageModel.fromJson(
          Map<String, dynamic>.from(raw),
          chatId: _chatId,
          currentUserId: currentUserId,
        );
        if (!message.isMine) _typingTimer?.cancel();
        state = state.copyWith(
          messages: _mergeOne(message),
          // The message she was typing has arrived; she has stopped.
          isPeerTyping: message.isMine ? state.isPeerTyping : false,
        );

      case 'typing':
        if (event['user_id'] == currentUserId) return;
        final typing = event['is_typing'] == true;
        _typingTimer?.cancel();
        if (typing) {
          _typingTimer = Timer(_typingTimeout, () {
            if (mounted) state = state.copyWith(isPeerTyping: false);
          });
        }
        state = state.copyWith(isPeerTyping: typing);

      case 'messages.read':
        // Her own read — from this phone or another one of hers — says
        // nothing about whether the *other side* has seen her messages. It
        // used to turn every one of her ticks to "read" the moment she
        // opened the conversation herself.
        if (currentUserId == null || event['user_id'] == currentUserId) return;
        final readAt = _parseDate(event['read_at']) ?? DateTime.now();
        // Only what was sent up to the message she read — not, as before,
        // everything, including the message sent a second after.
        final upTo = _parseDate(event['up_to']) ?? readAt;
        state = state.copyWith(
          messages: [
            for (final m in state.messages)
              m.isMine && !m.isLocal && !m.isRead && !m.sentAt.isAfter(upTo)
                  ? m.copyWith(status: ChatMessageStatus.read, readAt: readAt)
                  : m,
          ],
        );

      case 'messages.delivered':
        if (event['user_id'] == currentUserId) return;
        final ids = {...?(event['message_ids'] as List?)?.whereType<String>()};
        final at = _parseDate(event['delivered_at']) ?? DateTime.now();
        state = state.copyWith(
          messages: [
            for (final m in state.messages)
              m.isMine && ids.contains(m.id) && !m.isDelivered
                  ? m.copyWith(
                      status: ChatMessageStatus.delivered,
                      deliveredAt: at,
                    )
                  : m,
          ],
        );
    }
  }

  // ── Merging ──────────────────────────────────────────────────────────────

  /// Puts [message] in the list, replacing its earlier copy — the same id, or
  /// the optimistic copy carrying its `client_id`. A copy arriving late never
  /// takes a tick back: the HTTP answer to a send can land after the socket
  /// already said the message was read.
  List<ChatMessageEntity> _mergeOne(
    ChatMessageEntity message, {
    String? clientId,
  }) {
    final key = clientId ?? message.clientId;
    ChatMessageEntity? previous;
    final others = <ChatMessageEntity>[];
    for (final existing in state.messages) {
      final same = existing.id == message.id ||
          (key != null && existing.clientId == key);
      if (same) {
        previous ??= existing.isLocal ? null : existing;
      } else {
        others.add(existing);
      }
    }
    return _sorted([...others, _furthest(previous, message)]);
  }

  List<ChatMessageEntity> _mergeAll(List<ChatMessageEntity> incoming) {
    final byId = {for (final m in state.messages) m.id: m};
    final confirmedClientIds = {
      for (final m in incoming)
        if (m.clientId != null) m.clientId!,
    };
    for (final m in incoming) {
      byId[m.id] = _furthest(byId[m.id], m);
    }
    // An unsent message the server turns out to have after all.
    byId.removeWhere(
      (_, m) => m.isLocal && confirmedClientIds.contains(m.clientId),
    );
    return _sorted(byId.values.toList());
  }

  List<ChatMessageEntity> _withLocalStatus(String clientId, String status) => [
        for (final m in state.messages)
          m.clientId == clientId && m.isLocal ? m.copyWith(status: status) : m,
      ];

  static ChatMessageEntity _furthest(
    ChatMessageEntity? previous,
    ChatMessageEntity next,
  ) {
    if (previous == null || _rank(previous) <= _rank(next)) return next;
    return next.copyWith(
      status: previous.status,
      deliveredAt: previous.deliveredAt,
      readAt: previous.readAt,
    );
  }

  static int _rank(ChatMessageEntity m) => switch (m.status) {
        ChatMessageStatus.read => 3,
        ChatMessageStatus.delivered => 2,
        ChatMessageStatus.sent => 1,
        _ => 0,
      };

  /// Oldest first; her unsent messages after everything the server holds,
  /// since the server will stamp them later than anything it already has.
  static List<ChatMessageEntity> _sorted(List<ChatMessageEntity> list) {
    return list
      ..sort((a, b) {
        if (a.isLocal != b.isLocal) return a.isLocal ? 1 : -1;
        final byTime = a.sentAt.compareTo(b.sentAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
  }

  String _newClientId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = _random.nextInt(1 << 32).toRadixString(36);
    return '$stamp-$noise';
  }

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}
