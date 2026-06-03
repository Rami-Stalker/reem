import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/shared/wedgets/backgrounds/luxury_blurred_background.dart';

import '../providers/chat_provider.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_date_divider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/image_message_bubble.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/pinned_message_banner.dart';
import '../widgets/swipe_reply_container.dart';
import '../widgets/chat_input.dart';
import '../widgets/product_share_message.dart';
import '../widgets/chat_gradient_orb.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  const ChatDetailsScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    if (widget.chatId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatMessagesNotifierProvider.notifier).load(widget.chatId);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesNotifierProvider);

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
                        if (messagesState.messages.isEmpty) ...[
                          const PinnedMessageBanner(
                            message:
                                "Luxury summer collection launches tomorrow at 8PM ✨",
                          ),
                          const SizedBox(height: 20),
                          const ChatDateDivider(title: "Today"),
                          const SizedBox(height: 24),
                          FadeTransition(
                            opacity: controller,
                            child: const MessageBubble(
                              isMe: false,
                              message:
                                  "Welcome to our luxury experience 💖",
                            ),
                          ),
                          const SizedBox(height: 18),
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(.4, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: controller,
                                curve: Curves.easeOutQuart,
                              ),
                            ),
                            child: const MessageBubble(
                              isMe: true,
                              message:
                                  "Everything looks absolutely stunning 😍",
                            ),
                          ),
                          const SizedBox(height: 22),
                          const SwipeReplyContainer(
                            child: ImageMessageBubble(
                              image:
                                  "https://images.unsplash.com/photo-1529139574466-a303027c1d8b",
                            ),
                          ),
                          const SizedBox(height: 22),
                          const ProductShareMessage(),
                          const SizedBox(height: 22),
                          const VoiceMessageBubble(isMe: true),
                          const SizedBox(height: 26),
                          const TypingIndicator(),
                        ] else
                          ...messagesState.messages.map(
                            (msg) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MessageBubble(
                                isMe: msg.isMine,
                                message: msg.content,
                              ),
                            ),
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                const ChatInput(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
