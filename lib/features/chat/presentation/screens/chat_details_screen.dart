import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_asset.dart';
import 'package:ohara/core/media/media_limits.dart';
import 'package:ohara/core/media/media_providers.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/chat/data/services/chat_realtime_service.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/presentation/providers/chat_notifier.dart';
import 'package:ohara/features/chat/presentation/providers/chat_provider.dart';
import 'package:ohara/features/chat/presentation/providers/chat_state.dart';
import 'package:ohara/features/chat/presentation/widgets/attachment_sheet.dart';
import 'package:ohara/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:ohara/features/chat/presentation/widgets/chat_date_divider.dart';
import 'package:ohara/features/chat/presentation/widgets/chat_input.dart';
import 'package:ohara/features/chat/presentation/widgets/file_message_bubble.dart';
import 'package:ohara/features/chat/presentation/widgets/image_message_bubble.dart';
import 'package:ohara/features/chat/presentation/widgets/message_bubble.dart';
import 'package:ohara/features/chat/presentation/widgets/message_delivery_status.dart';
import 'package:ohara/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:ohara/features/chat/presentation/widgets/voice_message_bubble.dart';
import 'package:ohara/features/chat/presentation/widgets/voice_recorder_bar.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  const ChatDetailsScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController controller;
  StreamSubscription<Map<String, dynamic>>? realtimeSub;

  /// The list is drawn bottom-up (`reverse`), so offset 0 is the newest
  /// message. It used to be drawn top-down from the oldest: a conversation
  /// opened at its first message, and a reply arrived below the fold where
  /// nobody saw it.
  final ScrollController _scroll = ScrollController();

  /// The photograph is on its way. Held here rather than in the notifier
  /// because the message does not exist yet — there is nothing for the message
  /// list to show a spinner on.
  bool _attaching = false;

  /// Kept so `dispose` can leave the room without touching `ref`.
  ChatRealtimeService? _realtime;

  /// Marks the conversation read when she comes back to the app with it open.
  AppLifecycleListener? _lifecycle;

  /// The composer is replaced by the recorder while this is true.
  bool _recording = false;

  ChatMessagesNotifier get _messages =>
      ref.read(chatMessagesNotifierProvider(widget.chatId).notifier);

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scroll.addListener(_maybeLoadOlder);

    if (widget.chatId.isNotEmpty) {
      _lifecycle = AppLifecycleListener(onResume: _markReadIfVisible);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_bootstrap());
      });
    }
  }

  Future<void> _bootstrap() async {
    final realtime = ref.read(chatRealtimeServiceProvider);
    _realtime = realtime;
    // Listening first, loading second: a message that arrives while the page
    // is in flight is merged in rather than lost between the two.
    realtimeSub = realtime.events.listen(_onRealtime);
    // Remembered by the service and replayed whenever the socket is (re)made,
    // so it does not matter that the socket may not be open yet.
    realtime.join(widget.chatId);
    unawaited(realtime.connect());

    await _messages.load();
    if (!mounted) return;
    _markReadIfVisible();
  }

  void _onRealtime(Map<String, dynamic> event) {
    if (!mounted) return;
    switch (event['event']) {
      case 'connection.restored':
        // Anything sent while the socket was down never reached it.
        unawaited(
          _messages.resync().then((_) {
            if (mounted) _markReadIfVisible();
          }),
        );
      case 'presence.changed':
        ref
            .read(chatThreadNotifierProvider(widget.chatId).notifier)
            .applyPresence(event);
      default:
        _messages.applyRealtime(event);
        if (event['event'] == 'message.created' &&
            event['chat_id'] == widget.chatId) {
          _markReadIfVisible();
        }
    }
  }

  /// Reports the conversation read — only while she can actually see it. A
  /// message arriving while the phone sits locked with this screen underneath
  /// used to be marked read, and the sender saw "read" for a message nobody
  /// had looked at.
  void _markReadIfVisible() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    unawaited(_messages.markRead());
  }

  /// Near the top of what is loaded: fetch the page before it.
  void _maybeLoadOlder() {
    if (!_scroll.hasClients || widget.chatId.isEmpty) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(_messages.loadOlder());
    }
  }

  void _jumpToNewest() {
    if (!_scroll.hasClients) return;
    unawaited(
      _scroll.animateTo(0, duration: DsMotion.normal, curve: Curves.easeOut),
    );
  }

  Future<void> _sendText(String text) async {
    _jumpToNewest();
    final sent = await _messages.sendMessage(text);
    if (!sent && mounted) _warn(context.l10n.chatSendFailed);
  }

  Future<void> _retry(ChatMessageEntity message) async {
    final sent = await _messages.retry(message);
    if (!sent && mounted) _warn(context.l10n.chatSendFailed);
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    _lifecycle?.dispose();
    _scroll.dispose();
    // Read during `_bootstrap`, not here: `ref` leans on `BuildContext`, which
    // is already unsafe by the time `dispose` runs. Riverpod says so out loud
    // and the leave never happened — the socket kept this conversation joined
    // after she had left it.
    if (widget.chatId.isNotEmpty) {
      // Leaving mid-sentence must not leave "typing…" on the other screen.
      _realtime?.typing(widget.chatId, false);
      _realtime?.leave(widget.chatId);
    }
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = widget.chatId.isEmpty
        ? const ChatMessagesState()
        : ref.watch(chatMessagesNotifierProvider(widget.chatId));
    final realtime = ref.read(chatRealtimeServiceProvider);
    // Who she is talking to. Loaded on its own so the header is correct even
    // when this screen was opened by deep link and no list ever existed.
    final thread = widget.chatId.isEmpty
        ? null
        : ref.watch(chatThreadNotifierProvider(widget.chatId)).thread;

    // Sellers are written to; the suggested first questions are a shopper's.
    final isSeller = ref.watch(
      authNotifierProvider.select((s) => s.user?.isSeller ?? false),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.dsColors.background,
      // The same slow light as the rest of Ohara's stage. It replaces a live
      // full-screen blur under two drifting orbs, which repainted the whole
      // conversation behind every frame of their animation.
      body: Stack(
        children: [
          const Positioned.fill(child: AuthAurora()),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: ChatAppBar(
                  thread: thread,
                  isPeerTyping: messagesState.isPeerTyping,
                  onOpenSharedMedia: widget.chatId.isEmpty
                      ? null
                      : () => context.push(
                          '${RoutePaths.chatMediaGallery}?id=${widget.chatId}',
                        ),
                  onOpenProfile: thread?.peerId == null
                      ? null
                      : () => context.push(
                          RoutePaths.userProfileOf(thread!.peerId!),
                        ),
                ),
              ),
              Expanded(
                child: _body(context, messagesState, isSeller: isSeller),
              ),
              if (_recording)
                VoiceRecorderBar(
                  onCompleted: _sendVoiceNote,
                  onCancelled: () => setState(() => _recording = false),
                )
              else
                ChatInput(
                  // Only an upload in flight holds the composer: a text
                  // message is on screen the moment it is sent, so she can
                  // write the next one straight away.
                  isSending: _attaching,
                  onTyping: (typing) => realtime.typing(widget.chatId, typing),
                  onImage: _attach,
                  onVoice: () => setState(() => _recording = true),
                  onSend: (text) => unawaited(_sendText(text)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ChatMessagesState state, {
    required bool isSeller,
  }) {
    if (state.isLoading && state.messages.isEmpty) {
      return const DsLoadingIndicator();
    }
    // A conversation that could not be loaded at all. One that could, and
    // then failed to refresh, keeps what it has on screen.
    if (state.error != null && state.messages.isEmpty) {
      return DsErrorState(
        title: context.l10n.chatsLoadFailed,
        message: state.error,
        retryLabel: context.l10n.retry,
        onRetry: () => unawaited(_messages.load()),
      );
    }
    if (state.messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(DsSpacing.xl),
        children: [
          _EmptyConversation(
            onImage: _attach,
            // A boutique is written to rather than writing first, so the
            // shopper's opening questions would be the wrong way round.
            onSuggest: isSeller ? null : (text) => unawaited(_sendText(text)),
          ),
          if (state.isPeerTyping) ...[DsGaps.vMd, const TypingIndicator()],
        ],
      );
    }

    final entries = _entries(context, state);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.lg,
        DsSpacing.lg,
        DsSpacing.lg,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => entries[index],
    );
  }

  /// Newest first, because the list is drawn bottom-up: the typing dots, then
  /// the messages with a day divider wherever the calendar day changes, then
  /// — at the very top — the spinner for an older page.
  List<Widget> _entries(BuildContext context, ChatMessagesState state) {
    final l10n = context.l10n;
    final entries = <Widget>[
      if (state.isPeerTyping)
        const Padding(
          padding: EdgeInsets.only(top: DsSpacing.xs),
          child: TypingIndicator(),
        ),
    ];
    final messages = state.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      // The end of a run: the newer message is from the other side, or from
      // another day, or a few minutes later. Only there does the bubble take a
      // tail and the time show — a run reads as one voice, and a column of
      // identical timestamps says nothing a single one does not.
      final newer = i < messages.length - 1 ? messages[i + 1] : null;
      final endsRun =
          newer == null ||
          newer.isMine != message.isMine ||
          !_sameDay(newer.sentAt, message.sentAt) ||
          newer.sentAt.difference(message.sentAt).abs() > _runGap;
      entries.add(
        Padding(
          key: ValueKey(message.clientId ?? message.id),
          padding: EdgeInsets.only(
            bottom: endsRun ? DsSpacing.md : DsSpacing.xxs,
          ),
          child: _MessageRow(
            message: message,
            endsRun: endsRun,
            onRetry: message.isFailed ? () => unawaited(_retry(message)) : null,
          ),
        ),
      );
      final older = i > 0 ? messages[i - 1] : null;
      if (older == null || !_sameDay(older.sentAt, message.sentAt)) {
        entries.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
            child: ChatDateDivider(title: formatChatDay(l10n, message.sentAt)),
          ),
        );
      }
    }
    if (state.isLoadingOlder) {
      entries.add(
        Padding(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Center(
            child: Semantics(
              label: l10n.chatLoadOlder,
              child: const SizedBox.square(
                dimension: DsSizes.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }
    return entries;
  }

  /// How far apart two messages can be and still read as one run.
  static const _runGap = Duration(minutes: 3);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Capture or choose a photograph, upload it, then send the message.
  ///
  /// Upload first, send second — the same order the product form uses and for
  /// the same reason. The message carries a URL the server already holds, so
  /// what crosses the wire on send is a few hundred bytes rather than a
  /// photograph that might not arrive.
  Future<void> _attach() async {
    final source = await ChatAttachmentSheet.show(context);
    if (source == null || !mounted) return;

    final service = ref.read(mediaUploadServiceProvider);
    final XFile? file;
    try {
      file = switch (source) {
        ChatAttachmentSource.camera => await service.pickImage(
          source: ImageSource.camera,
        ),
        ChatAttachmentSource.gallery => await service.pickImage(
          source: ImageSource.gallery,
        ),
        ChatAttachmentSource.files => await service.pickDocument(),
      };
    } catch (_) {
      // Almost always a denied permission; the platform message is not
      // something to put in front of her.
      if (mounted) _warn(context.l10n.mediaPickFailed);
      return;
    }
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    // A document has its own ceiling, and a scan is legitimately larger than a
    // photograph — holding it to the image limit would refuse the invoice she
    // was asked for.
    final isDocument = file.name.toLowerCase().endsWith('.pdf');
    final limit = isDocument
        ? MediaLimits.documentBytes
        : MediaLimits.imageBytes;
    if (bytes.length > limit) {
      _warn(context.l10n.mediaTooLarge(MediaLimits.megabytes(limit)));
      return;
    }

    setState(() => _attaching = true);
    try {
      final asset = await service.upload(
        file,
        purpose: MediaPurpose.chat,
        bytes: bytes,
      );
      if (!mounted) return;
      // The server sniffed the bytes; its answer decides the message kind, not
      // the extension the file happened to carry.
      final kind = asset.isDocument ? 'FILE' : 'IMAGE';

      _jumpToNewest();
      final sent = await _messages.send(
        // The bubble draws the photograph or names the document; the content
        // is what a notification and a thread preview can say in one word.
        content: asset.isDocument
            ? context.l10n.chatFileMessage
            : context.l10n.chatPhotoMessage,
        kind: kind,
        attachments: [
          {
            'kind': kind,
            'url': asset.url,
            'mime_type': asset.mimeType,
            'size_bytes': asset.byteSize,
            if (asset.isDocument) 'file_name': file.name,
            if (asset.width != null) 'width': asset.width,
            if (asset.height != null) 'height': asset.height,
          },
        ],
      );
      if (!sent && mounted) _warn(context.l10n.chatSendFailed);
    } catch (_) {
      if (mounted) _warn(context.l10n.chatAttachmentFailed);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  /// Upload the finished recording, then send it as a VOICE message.
  ///
  /// Same order as a photograph, and for the same reason: what crosses the wire
  /// on send is a URL the server already holds.
  Future<void> _sendVoiceNote(String path, Duration duration) async {
    setState(() {
      _recording = false;
      _attaching = true;
    });

    try {
      final asset = await ref
          .read(mediaUploadServiceProvider)
          .upload(XFile(path), purpose: MediaPurpose.chat);
      if (!mounted) return;

      _jumpToNewest();
      final sent = await _messages.send(
        content: context.l10n.voiceMessage,
        kind: 'VOICE',
        attachments: [
          {
            'kind': 'VOICE',
            'url': asset.url,
            'mime_type': asset.mimeType,
            'size_bytes': asset.byteSize,
            // Measured by the recorder, not read back from the container: it
            // is the one place the exact figure is already known.
            'duration_ms': duration.inMilliseconds,
          },
        ],
      );
      if (!sent && mounted) _warn(context.l10n.chatSendFailed);
    } catch (_) {
      if (mounted) _warn(context.l10n.chatAttachmentFailed);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  void _warn(String message) =>
      DsSnackbar.show(context, message: message, type: DsSnackbarType.warning);
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, this.endsRun = true, this.onRetry});

  final ChatMessageEntity message;

  /// The last of a run from one side: it carries the tail and the time.
  final bool endsRun;

  /// Set only for a message of hers that failed to send.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bubble = switch (message.kind) {
      'image' when message.attachments.isNotEmpty => ImageMessageBubble(
        isMe: message.isMine,
        image: message.attachments.first.url,
        width: message.attachments.first.width,
        height: message.attachments.first.height,
      ),
      'file' when message.attachments.isNotEmpty => FileMessageBubble(
        isMe: message.isMine,
        url: message.attachments.first.url,
        attachmentId: message.attachments.first.id,
        fileName: message.attachments.first.fileName,
        sizeBytes: message.attachments.first.sizeBytes,
      ),
      'voice' when message.attachments.isNotEmpty => VoiceMessageBubble(
        isMe: message.isMine,
        url: message.attachments.first.url,
        duration: message.attachments.first.durationMs == null
            ? null
            : Duration(milliseconds: message.attachments.first.durationMs!),
      ),
      // Anything else, including a media message whose attachment never
      // arrived: its text is all there is, and drawing a broken frame or a
      // player with nothing behind it would say less.
      _ => MessageBubble(
        isMe: message.isMine,
        message: message.content,
        tail: endsRun,
      ),
    };

    final l10n = context.l10n;
    final colors = context.dsColors;
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.isFailed
              ? l10n.chatMessageNotSent
              : message.isPending
              ? l10n.chatSending
              : formatMessageTime(l10n, message.sentAt),
          style: context.dsText.caption.tint(
            message.isFailed ? colors.error : colors.onSurfaceVariant,
          ),
        ),
        if (message.isMine) ...[
          DsGaps.hXxs,
          MessageDeliveryStatus(
            delivered: message.isDelivered,
            seen: message.isRead,
            pending: message.isPending,
            failed: message.isFailed,
          ),
        ],
      ],
    );

    // A message still on its way, or one that failed, always says so — even
    // inside a run, where the time would otherwise wait for the last bubble.
    final showMeta = endsRun || message.isPending || message.isFailed;
    final row = Column(
      crossAxisAlignment: message.isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Opacity(opacity: message.isPending ? 0.7 : 1, child: bubble),
        if (showMeta) ...[
          DsGaps.vXxs,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
            child: meta,
          ),
        ],
      ],
    );
    if (onRetry == null) return row;
    return Semantics(
      button: true,
      label: l10n.chatMessageNotSent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: row,
      ),
    );
  }
}

/// A conversation with nothing in it yet: the arch, a line of welcome, and —
/// for a shopper — three questions she can send with one tap, because the
/// hardest message to write is the first.
class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.onImage, this.onSuggest});

  final VoidCallback onImage;

  /// Sends a suggested question. Null hides the suggestions.
  final ValueChanged<String>? onSuggest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final suggestions = [
      l10n.chatSuggestAvailable,
      l10n.chatSuggestSizes,
      l10n.chatSuggestDelivery,
    ];

    return Column(
      children: [
        const AuthEmblem(icon: Icons.forum_rounded, size: 84),
        Text(
          l10n.chatStartConversation,
          textAlign: TextAlign.center,
          style: context.dsText.sectionTitle.bold,
        ),
        DsGaps.vXs,
        Text(
          l10n.chatStartConversationHint,
          textAlign: TextAlign.center,
          style: context.dsText.bodyMuted.copyWith(height: 1.6),
        ),
        DsGaps.vSm,
        TextButton.icon(
          onPressed: onImage,
          icon: const Icon(Icons.photo_rounded),
          label: Text(l10n.chatShareImage),
        ),
        if (onSuggest != null) ...[
          DsGaps.vXl,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DsSparkle(size: 9, color: colors.accent),
              DsGaps.hXs,
              Text(
                l10n.chatSuggestTitle,
                style: context.dsText.overline.copyWith(color: colors.primary),
              ),
            ],
          ),
          DsGaps.vSm,
          // Drawn as her own bubbles-to-be, so a tap reads as "say this".
          for (final text in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.sm),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Material(
                  color: Colors.transparent,
                  shape: SilkBubbleBorder(
                    mine: true,
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => onSuggest!(text),
                    customBorder: const SilkBubbleBorder(mine: true),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        DsSpacing.md,
                        DsSpacing.sm,
                        DsSpacing.md + SilkBubbleBorder.tailWidth,
                        DsSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              text,
                              style: context.dsText.body.semibold.tint(
                                colors.primary,
                              ),
                            ),
                          ),
                          DsGaps.hXs,
                          Icon(
                            Icons.near_me_rounded,
                            size: DsSizes.iconXs,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
