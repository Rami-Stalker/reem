import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/media/media_limits.dart';
import 'package:reem/core/media/media_providers.dart';
import 'package:reem/core/router/route_paths.dart';
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

  Future<void> _bootstrap() async {
    await ref.read(chatMessagesNotifierProvider.notifier).load(widget.chatId);
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
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesNotifierProvider);
    final notifier = ref.read(chatMessagesNotifierProvider.notifier);
    final realtime = ref.read(chatRealtimeServiceProvider);
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
                    child: DsLoadingIndicator(),
                  )
                else if (messagesState.error != null)
                  Expanded(child: DsErrorState(message: messagesState.error))
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(DsSpacing.xl),
                      children: [
                        ChatDateDivider(title: context.l10n.todayLabel),
                        DsGaps.vLg,
                        if (messagesState.messages.isEmpty)
                          _EmptyConversation(onImage: _attach)
                        else
                          ...messagesState.messages.map(
                            (message) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: DsSpacing.sm,
                              ),
                              child: _MessageRow(message: message),
                            ),
                          ),
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
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final ChatMessageEntity message;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bubble,
        DsGaps.vXxs,
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
