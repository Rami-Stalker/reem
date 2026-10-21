import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
// `intl` exports a TextDirection of its own; only the formatter is wanted here.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/media/media_limits.dart';
import 'package:reem/core/media/media_providers.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/utils/arabic_numerals.dart';
import 'package:reem/features/chat/data/services/chat_realtime_service.dart';
import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/presentation/providers/chat_provider.dart';
import 'package:reem/features/chat/presentation/widgets/attachment_sheet.dart';
import 'package:reem/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:reem/features/chat/presentation/widgets/chat_date_divider.dart';
import 'package:reem/features/chat/presentation/widgets/chat_gradient_orb.dart';
import 'package:reem/features/chat/presentation/widgets/chat_input.dart';
import 'package:reem/features/chat/presentation/widgets/file_message_bubble.dart';
import 'package:reem/features/chat/presentation/widgets/image_message_bubble.dart';
import 'package:reem/features/chat/presentation/widgets/message_bubble.dart';
import 'package:reem/features/chat/presentation/widgets/message_delivery_status.dart';
import 'package:reem/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:reem/features/chat/presentation/widgets/voice_message_bubble.dart';
import 'package:reem/features/chat/presentation/widgets/voice_recorder_bar.dart';

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

  /// The photograph is on its way. Held here rather than in the notifier
  /// because the message does not exist yet — there is nothing for the message
  /// list to show a spinner on.
  bool _attaching = false;

  /// Kept so `dispose` can leave the room without touching `ref`.
  ChatRealtimeService? _realtime;

  /// The composer is replaced by the recorder while this is true.
  bool _recording = false;

  /// The thread's own scroll position.
  ///
  /// A conversation that does not move when a message arrives is a
  /// conversation that looks like it did not receive one: the bubble was
  /// appended below the fold and nothing said so. This is most of what
  /// «التأخر في وصول الرسائل» was — the messages were arriving on time and
  /// landing off screen.
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    if (widget.chatId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bootstrap();
      });
    }
  }

  /// Rides to the foot of the thread.
  ///
  /// After the frame, because the new bubble has to be laid out before its
  /// extent is part of `maxScrollExtent`. [jump] for the first paint, where an
  /// animation from an empty list reads as a glitch.
  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: DsMotion.normal,
        curve: DsMotion.silk,
      );
    });
  }

  Future<void> _bootstrap() async {
    await ref.read(chatMessagesNotifierProvider.notifier).load(widget.chatId);
    if (!mounted) return;
    // The newest message is the one she opened the conversation to read.
    _scrollToEnd(jump: true);
    final realtime = ref.read(chatRealtimeServiceProvider);
    _realtime = realtime;
    await realtime.connect();
    realtime.join(widget.chatId);
    realtime.markRead(widget.chatId);
    realtimeSub = realtime.events.listen((event) {
      if (event['event'] == 'connection.restored') {
        // Anything sent while the socket was down never reached it.
        unawaited(ref.read(chatMessagesNotifierProvider.notifier).resync());
        realtime.markRead(widget.chatId);
        return;
      }
      ref.read(chatMessagesNotifierProvider.notifier).applyRealtime(event);
      if (event['event'] == 'message.created' &&
          event['chat_id'] == widget.chatId) {
        realtime.markRead(widget.chatId);
      }
    });
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    // Read during `initState`, not here: `ref` leans on `BuildContext`, which
    // is already unsafe by the time `dispose` runs. Riverpod says so out loud
    // and the leave never happened — the socket kept this conversation joined
    // after she had left it.
    if (widget.chatId.isNotEmpty) _realtime?.leave(widget.chatId);
    _scrollController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesNotifierProvider);
    final notifier = ref.read(chatMessagesNotifierProvider.notifier);
    final realtime = ref.read(chatRealtimeServiceProvider);

    // Anything new — hers or the other party's — brings the thread to its
    // foot. Listening on the count rather than the list means an edited status
    // (a read receipt landing) does not yank the page while she is reading
    // back through the history.
    ref.listen(
      chatMessagesNotifierProvider.select((state) => state.messages.length),
      (previous, next) {
        if (previous != null && next > previous) _scrollToEnd();
      },
    );
    // Who she is talking to. Loaded on its own so the header is correct even
    // when this screen was opened by deep link and no list ever existed.
    final thread = widget.chatId.isEmpty
        ? null
        : ref.watch(chatThreadNotifierProvider(widget.chatId)).thread;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LuxuryBlurredBackground(
        child: Stack(
          children: [
            const Positioned(top: -100, right: -100, child: ChatGradientOrb()),
            const Positioned(bottom: -120, left: -80, child: ChatGradientOrb()),
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
                if (messagesState.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (messagesState.error != null)
                  Expanded(child: Center(child: Text(messagesState.error!)))
                else
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(DsSpacing.xl),
                      children: [
                        if (messagesState.messages.isEmpty)
                          _EmptyConversation(onImage: _attach)
                        else
                          // A rule per day, drawn from the messages' own dates.
                          // There used to be exactly one, reading «اليوم», at
                          // the top of every conversation — so a thread going
                          // back three weeks announced that all of it happened
                          // today.
                          ..._dated(messagesState.messages, (message) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: DsSpacing.sm,
                              ),
                              child: _MessageRow(
                                message: message,
                                onRetry: message.isFailed
                                    ? () => notifier.retry(message)
                                    : null,
                              ),
                            );
                          }),
                        if (messagesState.isPeerTyping) ...[
                          DsGaps.vXs,
                          const TypingIndicator(),
                        ],
                        DsGaps.vXxl,
                      ],
                    ),
                  ),
                if (_recording)
                  VoiceRecorderBar(
                    onCompleted: _sendVoiceNote,
                    onCancelled: () => setState(() => _recording = false),
                  )
                else
                  ChatInput(
                    isSending: messagesState.isSending || _attaching,
                    onTyping: (typing) =>
                        realtime.typing(widget.chatId, typing),
                    onImage: _attach,
                    onVoice: () => setState(() => _recording = true),
                    onSend: (text) => notifier.sendMessage(text),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

      if (!mounted) return;
      // The server sniffed the bytes; its answer decides the message kind, not
      // the extension the file happened to carry.
      final kind = asset.isDocument ? 'FILE' : 'IMAGE';

      await ref
          .read(chatMessagesNotifierProvider.notifier)
          .send(
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

      await ref
          .read(chatMessagesNotifierProvider.notifier)
          .send(
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
    } catch (_) {
      if (mounted) _warn(context.l10n.chatAttachmentFailed);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  void _warn(String message) =>
      DsSnackbar.show(context, message: message, type: DsSnackbarType.warning);

  /// The messages, with a date rule wherever the day changes.
  List<Widget> _dated(
    List<ChatMessageEntity> messages,
    Widget Function(ChatMessageEntity) build,
  ) {
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final message in messages) {
      final at = message.sentAt.toLocal();
      final day = DateTime(at.year, at.month, at.day);
      if (lastDay == null || day != lastDay) {
        if (lastDay != null) rows.add(DsGaps.vSm);
        rows.add(ChatDateDivider(title: _dayLabel(context, day)));
        rows.add(DsGaps.vLg);
        lastDay = day;
      }
      rows.add(build(message));
    }
    return rows;
  }
}

/// «اليوم», «أمس», or the date itself.
String _dayLabel(BuildContext context, DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return context.l10n.todayLabel;
  if (difference == 1) return context.l10n.yesterdayLabel;
  final locale = Localizations.localeOf(context).languageCode;
  return toWesternDigits(DateFormat.yMMMd(locale).format(day));
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, this.onRetry});

  final ChatMessageEntity message;

  /// Set only on a message the server refused.
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
      _ => MessageBubble(isMe: message.isMine, message: message.content),
    };

    if (!message.isMine) return bubble;

    // Her own message carries its state under it, which is the whole answer to
    // "did that send?" — on a bad connection the composer clearing was all she
    // used to get.
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // A failed bubble is dimmed rather than removed: the words are hers.
        Opacity(opacity: message.isFailed ? 0.55 : 1, child: bubble),
        DsGaps.vXxs,
        if (message.isPending)
          Text(
            context.l10n.chatSending,
            style: context.dsText.micro.tint(colors.onSurfaceVariant),
          )
        else if (message.isFailed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: colors.error,
              ),
              const SizedBox(width: DsSpacing.xxs),
              Text(
                context.l10n.chatMessageFailed,
                style: context.dsText.micro.tint(colors.error),
              ),
              const SizedBox(width: DsSpacing.xs),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  context.l10n.chatRetrySend,
                  style: context.dsText.micro.semibold.tint(colors.primary),
                ),
              ),
            ],
          )
        else
          MessageDeliveryStatus(
            delivered: message.isDelivered,
            seen: message.isRead,
          ),
      ],
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.onImage});

  final VoidCallback onImage;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: DsSpacing.paddingLg,
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.85),
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.forum_rounded,
            size: DsSizes.iconXl,
            color: colors.primary,
          ),
          DsGaps.vSm,
          Text(
            context.l10n.chatStartConversation,
            style: context.dsText.cardTitle.bold,
          ),
          DsGaps.vXs,
          Text(
            context.l10n.chatStartConversationHint,
            textAlign: TextAlign.center,
            style: context.dsText.bodyMuted,
          ),
          DsGaps.vMd,
          TextButton.icon(
            onPressed: onImage,
            icon: const Icon(Icons.photo_rounded),
            label: Text(context.l10n.chatShareImage),
          ),
        ],
      ),
    );
  }
}
