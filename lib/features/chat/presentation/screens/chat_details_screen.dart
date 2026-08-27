import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/media/media_limits.dart';
import 'package:reem/core/media/media_providers.dart';
import 'package:reem/core/router/route_paths.dart';

import '../../../../core/localization/l10n_extension.dart';
import '../../data/services/chat_realtime_service.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../providers/chat_provider.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_date_divider.dart';
import '../widgets/chat_gradient_orb.dart';
import '../widgets/chat_input.dart';
import '../widgets/file_message_bubble.dart';
import '../widgets/image_message_bubble.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_delivery_status.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/voice_recorder_bar.dart';

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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LuxuryBlurredBackground(
        child: Stack(
          children: [
            const Positioned(
              top: -100,
              right: -100,
              child: ChatGradientOrb(),
            ),
            const Positioned(
              bottom: -120,
              left: -80,
              child: ChatGradientOrb(),
            ),
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: ChatAppBar(
                    onOpenSharedMedia: widget.chatId.isEmpty
                        ? null
                        : () => context.push(
                            '${RoutePaths.chatMediaGallery}?id=${widget.chatId}',
                          ),
                  ),
                ),
                if (messagesState.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (messagesState.error != null)
                  Expanded(
                    child: Center(child: Text(messagesState.error!)),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(22),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        const ChatDateDivider(title: 'Today'),
                        const SizedBox(height: 18),
                        if (messagesState.messages.isEmpty)
                          _EmptyConversation(onImage: _attach)
                        else
                          ...messagesState.messages.map(
                            (message) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MessageRow(message: message),
                            ),
                          ),
                        if (messagesState.isPeerTyping) ...[
                          const SizedBox(height: 8),
                          const TypingIndicator(),
                        ],
                        const SizedBox(height: 30),
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
                    onTyping: (typing) => realtime.typing(widget.chatId, typing),
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

      await ref.read(chatMessagesNotifierProvider.notifier).send(
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

      await ref.read(chatMessagesNotifierProvider.notifier).send(
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

  void _warn(String message) => DsSnackbar.show(
    context,
    message: message,
    type: DsSnackbarType.warning,
  );
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
        const SizedBox(height: 4),
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
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.82),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Icon(Icons.forum_rounded, size: 42, color: Color(0xffFF5C8A)),
            const SizedBox(height: 12),
            Text(
              context.l10n.chatStartConversation,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.chatStartConversationHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 14),
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
