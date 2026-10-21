import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

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

  /// When "typing" was last said to the other side.
  DateTime? typingSentAt;

  void handleTyping(String value) {
    typingTimer?.cancel();
    if (value.trim().isEmpty) {
      setTyping(false);
      return;
    }
    setTyping(true);
    // Said again every few seconds while she keeps typing: the other side
    // drops "typing…" after a few seconds of silence, so a phone that went
    // offline mid-sentence cannot leave it up for ever.
    final last = typingSentAt;
    if (last != null && DateTime.now().difference(last) > _typingRenewal) {
      typingSentAt = DateTime.now();
      widget.onTyping?.call(true);
    }
    typingTimer = Timer(const Duration(seconds: 2), () => setTyping(false));
  }

  static const _typingRenewal = Duration(seconds: 3);

  void setTyping(bool value) {
    if (typing == value) return;
    typing = value;
    typingSentAt = value ? DateTime.now() : null;
    widget.onTyping?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.borderSheet,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.heavy, sigmaY: DsBlur.heavy),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.md,
            DsSpacing.sm,
            DsSpacing.md,
            DsSpacing.xl,
          ),
          decoration: BoxDecoration(
            // Reads from the theme: a fixed white plate left the composer
            // glowing at the foot of an otherwise aubergine thread.
            color: colors.surfaceElevated.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizeTransition(
                sizeFactor: controller,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Product and Order still have no implementation behind
                      // them, and `_action` draws that rather than offering a
                      // button that swallows the tap.
                      _action(context, Icons.photo_rounded, context.l10n.mediaImage, widget.onImage),
                      _action(context, Icons.mic_rounded, context.l10n.chatVoice, widget.onVoice),
                      _action(context, Icons.shopping_bag_rounded, context.l10n.chatProduct, null),
                      _action(context, Icons.receipt_long_rounded, context.l10n.chatOrder, null),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Tooltip(
                    message: context.l10n.chatAttachments,
                    child: GestureDetector(
                      onTap: toggle,
                      child: AnimatedContainer(
                        duration: DsMotion.moderate,
                        width: DsSizes.controlLg,
                        height: DsSizes.controlLg,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: context.primaryGradient,
                        ),
                        child: AnimatedRotation(
                          turns: expanded ? .125 : 0,
                          duration: DsMotion.normal,
                          child: const Icon(
                            Icons.add_rounded,
                            color: DsColors.onMedia,
                            size: DsSizes.iconMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DsGaps.hSm,
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: DsRadius.borderField,
                        border: Border.all(color: colors.border),
                      ),
                      child: TextField(
                        controller: textController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onChanged: handleTyping,
                        onSubmitted: (_) => send(),
                        decoration: InputDecoration(
                          hintText: context.l10n.chatWriteMessage,
                          border: InputBorder.none,
                          hintStyle: context.dsText.body
                              .tint(context.dsColors.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  DsGaps.hSm,
                  Tooltip(
                    message: context.l10n.send,
                    child: GestureDetector(
                      onTap: send,
                      child: Container(
                        width: DsSizes.controlLg,
                        height: DsSizes.controlLg,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: context.primaryGradient,
                        ),
                        child: widget.isSending
                            ? const Padding(
                                padding: EdgeInsets.all(DsSpacing.md),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DsColors.onMedia,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: DsColors.onMedia,
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

  /// A null [onTap] draws the action as unavailable rather than as a button
  /// that quietly does nothing when pressed — which is what Product and Order
  /// were, and what a tap on them is still worth telling her about honestly.
  Widget _action(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback? onTap,
  ) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: title,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: DsSizes.fabSize,
                height: DsSizes.fabSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.dsColors.surfaceElevated,
                  border: Border.all(color: context.dsColors.border),
                  boxShadow: context.shadowXs,
                ),
                child: Icon(icon, color: context.dsColors.primary),
              ),
              DsGaps.vXs,
              Text(title, style: context.dsText.labelStrong),
            ],
          ),
        ),
      ),
    );
  }
}
