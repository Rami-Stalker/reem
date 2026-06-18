import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    this.onTyping,
    this.onImage,
    this.onVoice,
    this.isSending = false,
  });

  final ValueChanged<String> onSend;
  final ValueChanged<bool>? onTyping;
  final VoidCallback? onImage;
  final VoidCallback? onVoice;
  final bool isSending;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  final textController = TextEditingController();
  Timer? typingTimer;
  bool expanded = false;
  bool typing = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    typingTimer?.cancel();
    textController.dispose();
    controller.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() => expanded = !expanded);
    expanded ? controller.forward() : controller.reverse();
  }

  void send() {
    final text = textController.text.trim();
    if (text.isEmpty || widget.isSending) return;
    textController.clear();
    setTyping(false);
    widget.onSend(text);
  }

  void handleTyping(String value) {
    if (value.trim().isNotEmpty) setTyping(true);
    typingTimer?.cancel();
    typingTimer = Timer(const Duration(milliseconds: 900), () {
      setTyping(false);
    });
  }

  void setTyping(bool value) {
    if (typing == value) return;
    typing = value;
    widget.onTyping?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.86)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizeTransition(
                sizeFactor: controller,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _action(Icons.photo_rounded, 'Image', widget.onImage),
                      _action(Icons.mic_rounded, 'Voice', widget.onVoice),
                      _action(Icons.shopping_bag_rounded, 'Product', null),
                      _action(Icons.receipt_long_rounded, 'Order', null),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Tooltip(
                    message: 'Attachments',
                    child: GestureDetector(
                      onTap: toggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xffFF9EB5), Color(0xffFF5C8A)],
                          ),
                        ),
                        child: AnimatedRotation(
                          turns: expanded ? .125 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: textController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onChanged: handleTyping,
                        onSubmitted: (_) => send(),
                        decoration: InputDecoration(
                          hintText: 'Write a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Send',
                    child: GestureDetector(
                      onTap: send,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xffFF9EB5), Color(0xffFF5C8A)],
                          ),
                        ),
                        child: widget.isSending
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String title, VoidCallback? onTap) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(icon, color: const Color(0xffFF5C8A)),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
