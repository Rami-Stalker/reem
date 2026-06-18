import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/shared/wedgets/backgrounds/luxury_blurred_background.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_date_divider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/image_message_bubble.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_gradient_orb.dart';
import '../widgets/message_delivery_status.dart';

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
    if (widget.chatId.isNotEmpty) {
      ref.read(chatRealtimeServiceProvider).leave(widget.chatId);
    }
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
                const SafeArea(bottom: false, child: ChatAppBar()),
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
                          _EmptyConversation(onImage: _sendImage)
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
                ChatInput(
                  isSending: messagesState.isSending,
                  onTyping: (typing) => realtime.typing(widget.chatId, typing),
                  onImage: _sendImage,
                  onVoice: _sendVoice,
                  onSend: (text) => notifier.sendMessage(text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImage() async {
    final url = await _askForUrl(
      title: 'Share image',
      hint: 'https://example.com/image.jpg',
    );
    if (url == null || url.isEmpty) return;
    await ref.read(chatMessagesNotifierProvider.notifier).send(
      content: 'Image',
      kind: 'IMAGE',
      attachments: [
        {'kind': 'IMAGE', 'url': url, 'mime_type': 'image/jpeg'},
      ],
    );
  }

  Future<void> _sendVoice() async {
    await ref.read(chatMessagesNotifierProvider.notifier).send(
      content: 'Voice message',
      kind: 'VOICE',
      attachments: [
        {
          'kind': 'VOICE',
          'url': 'voice://pending-${DateTime.now().millisecondsSinceEpoch}',
          'mime_type': 'audio/mpeg',
          'duration_ms': 28000,
        },
      ],
    );
  }

  Future<String?> _askForUrl({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: hint),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Share'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final ChatMessageEntity message;

  @override
  Widget build(BuildContext context) {
    final bubble = switch (message.kind) {
      'image' => ImageMessageBubble(
          isMe: message.isMine,
          image: message.attachments.isNotEmpty
              ? message.attachments.first.url
              : message.content,
        ),
      'voice' => VoiceMessageBubble(isMe: message.isMine),
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
            const Text(
              'Start the conversation',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about product details, order status, sizing, delivery, or share images and voice notes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onImage,
              icon: const Icon(Icons.photo_rounded),
              label: const Text('Share image'),
            ),
          ],
        ),
    );
  }
}
